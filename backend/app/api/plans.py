import json
import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.deps import get_current_user
from app.db.database import get_db
from app.db import crud
from app.db.models import User
from app.feedback.llm import _client, MODEL

logger = logging.getLogger(__name__)
router = APIRouter()

_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

_VALID_EXERCISE_TYPES = ["squat", "lunge", "bicep_curl", "jumping_jack", "plank"]

_PLAN_SYSTEM = f"""You are a certified personal trainer AI. Generate a structured weekly workout plan as JSON.
Return ONLY valid JSON, no markdown, no explanation.
The JSON must match exactly:
{{
  "title": "string",
  "description": "string (1-2 sentences)",
  "duration_weeks": integer (2-8),
  "exercises": [
    {{
      "day_of_week": integer (0=Mon, 6=Sun),
      "exercise_type": "MUST be one of: {', '.join(_VALID_EXERCISE_TYPES)} — use the exact string, no plurals, no variants",
      "sets_target": integer,
      "reps_target": integer,
      "duration_target_s": integer or null,
      "notes": "string or null"
    }}
  ]
}}
Schedule 3-5 workout days per week. Rest days have no exercises.
Vary exercises based on the user's goal, fitness level, and available equipment.
IMPORTANT: exercise_type must be exactly one of: {', '.join(_VALID_EXERCISE_TYPES)}"""


def _generate_plan_llm(profile: dict) -> dict:
    prompt = (
        f"User profile:\n"
        f"- Goal: {profile.get('primary_goal', 'general_fitness')}\n"
        f"- Fitness level: {profile.get('fitness_level', 'beginner')}\n"
        f"- Equipment: {profile.get('equipment', 'none')}\n"
        f"- Activity level: {profile.get('activity_level', 'moderate')}\n"
        f"- Weekly workout target: {profile.get('weekly_workout_target', 3)} days/week\n"
        f"- Injuries/notes: {profile.get('injuries') or 'none'}\n\n"
        "Generate a personalised 4-week workout plan."
    )
    try:
        response = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": _PLAN_SYSTEM},
                {"role": "user", "content": prompt},
            ],
        )
        text = (response.choices[0].message.content or "").strip()
        # Strip markdown code fences if present
        if text.startswith("```"):
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        return json.loads(text)
    except Exception as e:
        logger.warning("Plan generation failed: %s — using template", e)
        return _fallback_plan(profile)


def _fallback_plan(profile: dict) -> dict:
    level = profile.get("fitness_level", "beginner")
    goal = profile.get("primary_goal", "general_fitness")
    equipment = profile.get("equipment", "none")

    if equipment == "gym":
        exercises_pool = ["squat", "lunge", "bicep_curl", "plank", "jumping_jack"]
    elif equipment == "home":
        exercises_pool = ["squat", "lunge", "plank", "jumping_jack", "bicep_curl"]
    else:
        exercises_pool = ["squat", "lunge", "plank", "jumping_jack"]

    sets = 2 if level == "beginner" else (4 if level == "advanced" else 3)
    reps = 8 if level == "beginner" else (15 if level == "advanced" else 12)

    workout_days = [0, 2, 4]  # Mon, Wed, Fri
    if profile.get("weekly_workout_target", 3) >= 4:
        workout_days = [0, 1, 3, 4]
    if profile.get("weekly_workout_target", 3) >= 5:
        workout_days = [0, 1, 2, 4, 5]

    exercises = []
    for day in workout_days:
        for i, ex in enumerate(exercises_pool[:3]):
            exercises.append({
                "day_of_week": day,
                "exercise_type": ex,
                "sets_target": sets,
                "reps_target": reps if ex != "plank" else 1,
                "duration_target_s": 30 if ex == "plank" else None,
                "notes": None,
            })

    return {
        "title": f"{goal.replace('_', ' ').title()} Plan",
        "description": f"A {level} {goal.replace('_', ' ')} programme tailored to your profile.",
        "duration_weeks": 4,
        "exercises": exercises,
    }


@router.post("/generate")
async def generate_plan(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await crud.get_profile(db, current_user.id)
    profile_dict = {}
    if profile:
        profile_dict = {
            "primary_goal": profile.primary_goal,
            "fitness_level": profile.fitness_level,
            "equipment": profile.equipment,
            "activity_level": profile.activity_level,
            "weekly_workout_target": profile.weekly_workout_target,
            "injuries": profile.injuries,
        }

    plan_data = _generate_plan_llm(profile_dict)

    # Sanitise: drop any exercise whose type isn't in the known set
    plan_data["exercises"] = [
        ex for ex in plan_data.get("exercises", [])
        if ex.get("exercise_type") in _VALID_EXERCISE_TYPES
    ]

    plan = await crud.create_plan(
        db,
        user_id=current_user.id,
        title=plan_data["title"],
        description=plan_data.get("description", ""),
        duration_weeks=plan_data.get("duration_weeks", 4),
        exercises=plan_data.get("exercises", []),
    )
    return _serialize_plan(plan)


@router.get("")
async def list_plans(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plans = await crud.list_plans(db, current_user.id)
    return [_serialize_plan(p) for p in plans]


@router.get("/{plan_id}")
async def get_plan(
    plan_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan = await crud.get_plan(db, plan_id)
    if not plan or plan.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Plan not found")
    return _serialize_plan(plan)


@router.patch("/{plan_id}/exercises/{exercise_id}/toggle")
async def toggle_exercise(
    plan_id: str,
    exercise_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan = await crud.get_plan(db, plan_id)
    if not plan or plan.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Plan not found")
    ex = await crud.toggle_plan_exercise(db, exercise_id, plan_id)
    if not ex:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return {
        "id": ex.id,
        "completed_at": ex.completed_at.isoformat() if ex.completed_at else None,
    }


@router.delete("/{plan_id}")
async def delete_plan(
    plan_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await crud.delete_plan(db, plan_id, current_user.id)
    return {"ok": True}


def _serialize_plan(plan) -> dict:
    return {
        "id": plan.id,
        "title": plan.title,
        "description": plan.description,
        "duration_weeks": plan.duration_weeks,
        "created_at": plan.created_at.isoformat(),
        "exercises": [
            {
                "id": ex.id,
                "day_of_week": ex.day_of_week,
                "day_name": _DAYS[ex.day_of_week],
                "exercise_type": ex.exercise_type,
                "sets_target": ex.sets_target,
                "reps_target": ex.reps_target,
                "duration_target_s": ex.duration_target_s,
                "notes": ex.notes,
                "completed_at": ex.completed_at.isoformat() if ex.completed_at else None,
            }
            for ex in plan.exercises
        ],
    }

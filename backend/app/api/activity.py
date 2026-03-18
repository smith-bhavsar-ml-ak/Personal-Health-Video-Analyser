import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.deps import get_current_user
from app.db.database import get_db
from app.db import crud
from app.db.models import User

logger = logging.getLogger(__name__)
router = APIRouter()


# ── Schemas ───────────────────────────────────────────────────────────────────

class StartActivityRequest(BaseModel):
    activity_type: str = "walk"  # walk | run | hike | cycle


class CompleteActivityRequest(BaseModel):
    steps: int = 0
    distance_m: float = 0.0
    calories_burned: float = 0.0
    avg_pace_s_per_km: float | None = None
    polyline: list | None = None  # [{lat, lng}, ...]


class SyncStepsRequest(BaseModel):
    steps: int
    date: str | None = None  # ISO date, defaults to today
    calories_burned: float = 0.0
    active_minutes: int = 0


class UpdateStepGoalRequest(BaseModel):
    goal: int  # steps per day, e.g. 8000


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/sessions/start")
async def start_activity(
    body: StartActivityRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new in-progress activity session (GPS tracking started)."""
    act = await crud.create_activity_session(db, current_user.id, body.activity_type)
    return _serialize_activity(act)


@router.post("/sessions/{activity_id}/complete")
async def complete_activity(
    activity_id: str,
    body: CompleteActivityRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Finish a GPS activity session and persist stats."""
    act = await crud.complete_activity_session(
        db,
        activity_id=activity_id,
        user_id=current_user.id,
        steps=body.steps,
        distance_m=body.distance_m,
        calories_burned=body.calories_burned,
        avg_pace_s_per_km=body.avg_pace_s_per_km,
        polyline=body.polyline,
    )
    if not act:
        raise HTTPException(status_code=404, detail="Activity session not found")
    return _serialize_activity(act)


@router.get("/sessions")
async def list_activities(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    activities = await crud.list_activity_sessions(db, current_user.id)
    return [_serialize_activity(a) for a in activities]


@router.post("/steps/sync")
async def sync_steps(
    body: SyncStepsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Sync pedometer steps from the device.
    Called periodically by the Flutter app with the current day's step count.
    Upserts DailyStepLog and updates streak.
    """
    from datetime import date as date_type
    log_date = date_type.fromisoformat(body.date) if body.date else datetime.utcnow().date()
    log = await crud.upsert_daily_step_log(
        db,
        user_id=current_user.id,
        log_date=log_date,
        steps=body.steps,
        calories=body.calories_burned,
        active_minutes=body.active_minutes,
    )
    streak = await crud.update_streak(db, current_user.id, log_date)
    return {
        "date": log.log_date.isoformat(),
        "steps": log.steps,
        "goal": log.goal,
        "calories_burned": log.calories_burned,
        "active_minutes": log.active_minutes,
        "current_streak": streak.current_streak,
        "longest_streak": streak.longest_streak,
    }


@router.get("/steps/today")
async def get_today_steps(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    log = await crud.get_today_steps(db, current_user.id)
    streak = await crud.get_streak(db, current_user.id)
    return {
        "steps": log.steps if log else 0,
        "goal": log.goal if log else 8000,
        "calories_burned": log.calories_burned if log else 0.0,
        "active_minutes": log.active_minutes if log else 0,
        "current_streak": streak.current_streak if streak else 0,
        "longest_streak": streak.longest_streak if streak else 0,
    }


@router.get("/steps/history")
async def get_step_history(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if days > 90:
        days = 90
    logs = await crud.get_step_history(db, current_user.id, days)
    return [
        {
            "date": log.log_date.isoformat(),
            "steps": log.steps,
            "goal": log.goal,
            "calories_burned": log.calories_burned,
            "active_minutes": log.active_minutes,
        }
        for log in logs
    ]


@router.put("/steps/goal")
async def update_step_goal(
    body: UpdateStepGoalRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Update the user's daily step goal.
    Persisted on today's DailyStepLog and used as the default for future logs.
    """
    if not (1000 <= body.goal <= 50000):
        raise HTTPException(status_code=422, detail="goal must be between 1000 and 50000")
    from datetime import date as date_type
    log_date = datetime.utcnow().date()
    log = await crud.upsert_daily_step_log(
        db,
        user_id=current_user.id,
        log_date=log_date,
        steps=None,      # don't overwrite steps
        calories=None,
        active_minutes=None,
        goal=body.goal,
    )
    return {"goal": log.goal}


@router.get("/streak")
async def get_streak(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    streak = await crud.get_streak(db, current_user.id)
    return {
        "current_streak": streak.current_streak if streak else 0,
        "longest_streak": streak.longest_streak if streak else 0,
        "total_active_days": streak.total_active_days if streak else 0,
        "last_activity_date": streak.last_activity_date.isoformat() if streak and streak.last_activity_date else None,
    }


# ── Helpers ───────────────────────────────────────────────────────────────────

def _serialize_activity(act) -> dict:
    duration_s = None
    if act.ended_at and act.started_at:
        duration_s = int((act.ended_at - act.started_at).total_seconds())
    return {
        "id": act.id,
        "activity_type": act.activity_type,
        "started_at": act.started_at.isoformat(),
        "ended_at": act.ended_at.isoformat() if act.ended_at else None,
        "duration_s": duration_s,
        "steps": act.steps,
        "distance_m": act.distance_m,
        "avg_pace_s_per_km": act.avg_pace_s_per_km,
        "calories_burned": act.calories_burned,
    }

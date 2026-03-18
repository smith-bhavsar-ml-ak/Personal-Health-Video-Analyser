from datetime import datetime, date, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func, and_
from sqlalchemy.orm import selectinload

from app.db.models import (
    WorkoutSession, ExerciseSet, PostureError, AIFeedback, VoiceQuery,
    User, UserProfile, WeightLog, WorkoutPlan, PlanExercise,
    Subscription, ActivitySession, DailyStepLog, Streak,
)


# ── User CRUD ────────────────────────────────────────────────────────────────

async def create_user(db: AsyncSession, email: str, hashed_password: str) -> User:
    user = User(email=email, hashed_password=hashed_password)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: str) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


# ── Session CRUD ─────────────────────────────────────────────────────────────

async def create_session(db: AsyncSession, user_id: str) -> WorkoutSession:
    session = WorkoutSession(user_id=user_id)
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


async def get_session(db: AsyncSession, session_id: str, user_id: str | None = None) -> WorkoutSession | None:
    q = (
        select(WorkoutSession)
        .options(
            selectinload(WorkoutSession.exercise_sets).selectinload(ExerciseSet.posture_errors),
            selectinload(WorkoutSession.ai_feedback),
            selectinload(WorkoutSession.voice_queries),
        )
        .where(WorkoutSession.id == session_id)
    )
    if user_id is not None:
        q = q.where(WorkoutSession.user_id == user_id)
    result = await db.execute(q)
    return result.scalar_one_or_none()


async def list_sessions(db: AsyncSession, user_id: str) -> list[WorkoutSession]:
    result = await db.execute(
        select(WorkoutSession)
        .options(selectinload(WorkoutSession.exercise_sets).selectinload(ExerciseSet.posture_errors))
        .where(WorkoutSession.user_id == user_id)
        .order_by(desc(WorkoutSession.created_at))
    )
    return list(result.scalars().all())


async def update_session_completed(
    db: AsyncSession,
    session_id: str,
    duration_s: int,
    exercise_sets: list[dict],
    feedback_text: str,
) -> WorkoutSession:
    session = await get_session(db, session_id)
    session.status = "completed"
    session.duration_s = duration_s

    for es_data in exercise_sets:
        es = ExerciseSet(
            session_id=session_id,
            exercise_type=es_data["exercise_type"],
            rep_count=es_data["rep_count"],
            correct_reps=es_data["correct_reps"],
            duration_s=es_data["duration_s"],
            form_score=es_data["form_score"],
            start_frame=es_data.get("start_frame", 0),
            end_frame=es_data.get("end_frame", 0),
            rep_scores=es_data.get("rep_scores"),
        )
        db.add(es)
        await db.flush()

        for err in es_data.get("posture_errors", []):
            pe = PostureError(
                set_id=es.id,
                error_type=err["error_type"],
                occurrences=err["occurrences"],
                severity=err["severity"],
            )
            db.add(pe)

    feedback = AIFeedback(session_id=session_id, feedback_text=feedback_text)
    db.add(feedback)

    await db.commit()
    return await get_session(db, session_id)


async def update_session_failed(db: AsyncSession, session_id: str, error_msg: str) -> None:
    session = await get_session(db, session_id)
    session.status = "failed"
    session.error_msg = error_msg
    await db.commit()


async def save_voice_query(
    db: AsyncSession, session_id: str, query_text: str, response_text: str
) -> VoiceQuery:
    vq = VoiceQuery(session_id=session_id, query_text=query_text, response_text=response_text)
    db.add(vq)
    await db.commit()
    await db.refresh(vq)
    return vq


async def delete_session(db: AsyncSession, session_id: str, user_id: str | None = None) -> None:
    session = await get_session(db, session_id, user_id=user_id)
    if session:
        await db.delete(session)
        await db.commit()


# ── Profile CRUD ─────────────────────────────────────────────────────────────

async def get_profile(db: AsyncSession, user_id: str) -> UserProfile | None:
    result = await db.execute(select(UserProfile).where(UserProfile.user_id == user_id))
    return result.scalar_one_or_none()


async def upsert_profile(db: AsyncSession, user_id: str, data: dict) -> UserProfile:
    profile = await get_profile(db, user_id)
    if profile is None:
        profile = UserProfile(user_id=user_id, **data)
        db.add(profile)
    else:
        for key, value in data.items():
            setattr(profile, key, value)
    await db.commit()
    await db.refresh(profile)
    return profile


# ── Weight log CRUD ───────────────────────────────────────────────────────────

async def log_weight(db: AsyncSession, user_id: str, weight_kg: float) -> WeightLog:
    entry = WeightLog(user_id=user_id, weight_kg=weight_kg, logged_at=datetime.utcnow())
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


async def get_weight_history(db: AsyncSession, user_id: str, limit: int = 90) -> list[WeightLog]:
    result = await db.execute(
        select(WeightLog)
        .where(WeightLog.user_id == user_id)
        .order_by(desc(WeightLog.logged_at))
        .limit(limit)
    )
    return list(reversed(result.scalars().all()))


# ── Progress queries ──────────────────────────────────────────────────────────

async def get_form_score_trend(
    db: AsyncSession, user_id: str, limit: int = 20
) -> list[dict]:
    """Last N completed sessions with date + avg form score."""
    result = await db.execute(
        select(WorkoutSession)
        .options(selectinload(WorkoutSession.exercise_sets))
        .where(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
        .order_by(desc(WorkoutSession.created_at))
        .limit(limit)
    )
    sessions = list(reversed(result.scalars().all()))
    trend = []
    for s in sessions:
        if s.exercise_sets:
            avg = sum(es.form_score for es in s.exercise_sets) / len(s.exercise_sets)
            trend.append({"date": s.created_at.isoformat(), "avg_form_score": round(avg, 1)})
    return trend


async def get_exercise_stats(db: AsyncSession, user_id: str) -> list[dict]:
    """Total reps + avg form score per exercise type across all sessions."""
    result = await db.execute(
        select(
            ExerciseSet.exercise_type,
            func.sum(ExerciseSet.rep_count).label("total_reps"),
            func.sum(ExerciseSet.correct_reps).label("correct_reps"),
            func.avg(ExerciseSet.form_score).label("avg_form_score"),
            func.count(ExerciseSet.id).label("set_count"),
        )
        .join(WorkoutSession, WorkoutSession.id == ExerciseSet.session_id)
        .where(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
        .group_by(ExerciseSet.exercise_type)
        .order_by(desc(func.sum(ExerciseSet.rep_count)))
    )
    rows = result.all()
    return [
        {
            "exercise_type": r.exercise_type,
            "total_reps": int(r.total_reps or 0),
            "correct_reps": int(r.correct_reps or 0),
            "avg_form_score": round(float(r.avg_form_score or 0), 1),
            "set_count": int(r.set_count or 0),
        }
        for r in rows
    ]


async def get_progress_summary(db: AsyncSession, user_id: str) -> dict:
    """High-level progress KPIs."""
    total_q = await db.execute(
        select(func.count(WorkoutSession.id))
        .where(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
    )
    total_sessions = total_q.scalar() or 0

    reps_q = await db.execute(
        select(func.sum(ExerciseSet.rep_count))
        .join(WorkoutSession)
        .where(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
    )
    total_reps = int(reps_q.scalar() or 0)

    score_q = await db.execute(
        select(func.avg(ExerciseSet.form_score))
        .join(WorkoutSession)
        .where(WorkoutSession.user_id == user_id, WorkoutSession.status == "completed")
    )
    avg_score = round(float(score_q.scalar() or 0), 1)

    return {
        "total_sessions": total_sessions,
        "total_reps": total_reps,
        "avg_form_score": avg_score,
    }


# ── Workout plan CRUD ─────────────────────────────────────────────────────────

async def create_plan(
    db: AsyncSession, user_id: str, title: str, description: str,
    duration_weeks: int, exercises: list[dict],
) -> WorkoutPlan:
    plan = WorkoutPlan(
        user_id=user_id, title=title,
        description=description, duration_weeks=duration_weeks,
        created_at=datetime.utcnow(),
    )
    db.add(plan)
    await db.flush()
    for ex in exercises:
        db.add(PlanExercise(
            plan_id=plan.id,
            day_of_week=ex["day_of_week"],
            exercise_type=ex["exercise_type"],
            sets_target=ex.get("sets_target", 3),
            reps_target=ex.get("reps_target", 10),
            duration_target_s=ex.get("duration_target_s"),
            notes=ex.get("notes"),
        ))
    await db.commit()
    return await get_plan(db, plan.id)


async def get_plan(db: AsyncSession, plan_id: str) -> WorkoutPlan | None:
    result = await db.execute(
        select(WorkoutPlan)
        .options(selectinload(WorkoutPlan.exercises))
        .where(WorkoutPlan.id == plan_id)
    )
    return result.scalar_one_or_none()


async def list_plans(db: AsyncSession, user_id: str) -> list[WorkoutPlan]:
    result = await db.execute(
        select(WorkoutPlan)
        .options(selectinload(WorkoutPlan.exercises))
        .where(WorkoutPlan.user_id == user_id)
        .order_by(desc(WorkoutPlan.created_at))
    )
    return list(result.scalars().all())


async def toggle_plan_exercise(
    db: AsyncSession, exercise_id: str, plan_id: str
) -> PlanExercise | None:
    result = await db.execute(
        select(PlanExercise).where(
            PlanExercise.id == exercise_id,
            PlanExercise.plan_id == plan_id,
        )
    )
    ex = result.scalar_one_or_none()
    if ex:
        ex.completed_at = None if ex.completed_at else datetime.utcnow()
        await db.commit()
        await db.refresh(ex)
    return ex


async def delete_plan(db: AsyncSession, plan_id: str, user_id: str) -> None:
    result = await db.execute(
        select(WorkoutPlan).where(WorkoutPlan.id == plan_id, WorkoutPlan.user_id == user_id)
    )
    plan = result.scalar_one_or_none()
    if plan:
        await db.delete(plan)
        await db.commit()


# ── Auto-progress: link completed video sessions → plan exercises ──────────────

async def auto_complete_plan_exercises(
    db: AsyncSession, user_id: str, exercise_types: list[str]
) -> int:
    """
    After a video analysis completes, mark matching plan exercises for today as done.
    Returns count of exercises auto-completed.
    """
    today = datetime.utcnow().weekday()  # 0=Mon … 6=Sun
    if not exercise_types:
        return 0

    # Load active plans for this user
    result = await db.execute(
        select(WorkoutPlan)
        .options(selectinload(WorkoutPlan.exercises))
        .where(WorkoutPlan.user_id == user_id)
    )
    plans = result.scalars().all()

    completed_count = 0
    for plan in plans:
        for ex in plan.exercises:
            if (
                ex.day_of_week == today
                and ex.exercise_type in exercise_types
                and ex.completed_at is None
            ):
                ex.completed_at = datetime.utcnow()
                completed_count += 1

    if completed_count:
        await db.commit()
    return completed_count


# ── Subscription CRUD ─────────────────────────────────────────────────────────

_TIER_LIMITS = {"free": 10, "pro": 100, "elite": -1}  # -1 = unlimited


async def get_subscription(db: AsyncSession, user_id: str) -> Subscription | None:
    result = await db.execute(
        select(Subscription).where(Subscription.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def get_or_create_subscription(db: AsyncSession, user_id: str) -> Subscription:
    sub = await get_subscription(db, user_id)
    if sub is None:
        sub = Subscription(user_id=user_id, tier="free")
        db.add(sub)
        await db.commit()
        await db.refresh(sub)
    return sub


async def check_analysis_quota(db: AsyncSession, user_id: str) -> dict:
    """Returns {'allowed': bool, 'used': int, 'limit': int, 'tier': str}."""
    sub = await get_or_create_subscription(db, user_id)

    # Reset monthly counter if needed
    now = datetime.utcnow()
    if sub.analyses_reset_at.month != now.month or sub.analyses_reset_at.year != now.year:
        sub.analyses_used_this_month = 0
        sub.analyses_reset_at = now
        await db.commit()
        await db.refresh(sub)

    limit = _TIER_LIMITS.get(sub.tier, 10)
    allowed = limit == -1 or sub.analyses_used_this_month < limit
    return {"allowed": allowed, "used": sub.analyses_used_this_month, "limit": limit, "tier": sub.tier}


async def increment_analysis_usage(db: AsyncSession, user_id: str) -> None:
    sub = await get_or_create_subscription(db, user_id)
    sub.analyses_used_this_month += 1
    await db.commit()


async def upsert_subscription(
    db: AsyncSession, user_id: str, tier: str, expires_at: datetime | None = None
) -> Subscription:
    sub = await get_or_create_subscription(db, user_id)
    sub.tier = tier
    sub.expires_at = expires_at
    sub.is_active = True
    if tier != "free":
        sub.started_at = datetime.utcnow()
    await db.commit()
    await db.refresh(sub)
    return sub


# ── Activity CRUD ─────────────────────────────────────────────────────────────

async def create_activity_session(
    db: AsyncSession, user_id: str, activity_type: str
) -> ActivitySession:
    session = ActivitySession(user_id=user_id, activity_type=activity_type)
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


async def complete_activity_session(
    db: AsyncSession,
    activity_id: str,
    user_id: str,
    steps: int,
    distance_m: float,
    calories_burned: float,
    avg_pace_s_per_km: float | None = None,
    polyline: list | None = None,
) -> ActivitySession | None:
    result = await db.execute(
        select(ActivitySession).where(
            ActivitySession.id == activity_id,
            ActivitySession.user_id == user_id,
        )
    )
    act = result.scalar_one_or_none()
    if not act:
        return None
    act.ended_at = datetime.utcnow()
    act.steps = steps
    act.distance_m = distance_m
    act.calories_burned = calories_burned
    act.avg_pace_s_per_km = avg_pace_s_per_km
    act.polyline = polyline
    await db.commit()

    # Update daily step log + streak
    today = datetime.utcnow().date()
    await upsert_daily_step_log(db, user_id, today, steps=steps, calories=calories_burned)
    await update_streak(db, user_id, today)

    await db.refresh(act)
    return act


async def list_activity_sessions(
    db: AsyncSession, user_id: str, limit: int = 30
) -> list[ActivitySession]:
    result = await db.execute(
        select(ActivitySession)
        .where(ActivitySession.user_id == user_id)
        .order_by(desc(ActivitySession.started_at))
        .limit(limit)
    )
    return list(result.scalars().all())


async def upsert_daily_step_log(
    db: AsyncSession, user_id: str, log_date: date,
    steps: int | None = None, calories: float | None = None,
    active_minutes: int | None = None, goal: int | None = None,
) -> DailyStepLog:
    result = await db.execute(
        select(DailyStepLog).where(
            DailyStepLog.user_id == user_id,
            DailyStepLog.log_date == log_date,
        )
    )
    log = result.scalar_one_or_none()
    if log is None:
        log = DailyStepLog(
            user_id=user_id, log_date=log_date,
            steps=steps or 0,
            calories_burned=calories or 0.0,
            active_minutes=active_minutes or 0,
            goal=goal or 8000,
        )
        db.add(log)
    else:
        if steps is not None:
            log.steps += steps
        if calories is not None:
            log.calories_burned += calories
        if active_minutes is not None:
            log.active_minutes += active_minutes
        if goal is not None:
            log.goal = goal
    await db.commit()
    await db.refresh(log)
    return log


async def get_step_history(
    db: AsyncSession, user_id: str, days: int = 7
) -> list[DailyStepLog]:
    since = datetime.utcnow().date() - timedelta(days=days - 1)
    result = await db.execute(
        select(DailyStepLog)
        .where(DailyStepLog.user_id == user_id, DailyStepLog.log_date >= since)
        .order_by(DailyStepLog.log_date)
    )
    return list(result.scalars().all())


async def get_today_steps(db: AsyncSession, user_id: str) -> DailyStepLog | None:
    today = datetime.utcnow().date()
    result = await db.execute(
        select(DailyStepLog).where(
            DailyStepLog.user_id == user_id,
            DailyStepLog.log_date == today,
        )
    )
    return result.scalar_one_or_none()


# ── Streak CRUD ───────────────────────────────────────────────────────────────

async def get_streak(db: AsyncSession, user_id: str) -> Streak | None:
    result = await db.execute(select(Streak).where(Streak.user_id == user_id))
    return result.scalar_one_or_none()


async def update_streak(db: AsyncSession, user_id: str, activity_date: date) -> Streak:
    result = await db.execute(select(Streak).where(Streak.user_id == user_id))
    streak = result.scalar_one_or_none()
    if streak is None:
        streak = Streak(user_id=user_id)
        db.add(streak)

    if streak.last_activity_date is None:
        streak.current_streak = 1
        streak.total_active_days = 1
    elif activity_date == streak.last_activity_date:
        pass  # already counted today
    elif activity_date == streak.last_activity_date + timedelta(days=1):
        streak.current_streak += 1
        streak.total_active_days += 1
    else:
        streak.current_streak = 1
        streak.total_active_days += 1

    streak.last_activity_date = activity_date
    streak.longest_streak = max(streak.longest_streak, streak.current_streak)
    await db.commit()
    await db.refresh(streak)
    return streak

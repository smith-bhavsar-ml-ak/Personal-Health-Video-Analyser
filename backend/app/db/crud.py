from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from sqlalchemy.orm import selectinload

from app.db.models import WorkoutSession, ExerciseSet, PostureError, AIFeedback, VoiceQuery


async def create_session(db: AsyncSession) -> WorkoutSession:
    session = WorkoutSession()
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


async def get_session(db: AsyncSession, session_id: str) -> WorkoutSession | None:
    result = await db.execute(
        select(WorkoutSession)
        .options(
            selectinload(WorkoutSession.exercise_sets).selectinload(ExerciseSet.posture_errors),
            selectinload(WorkoutSession.ai_feedback),
            selectinload(WorkoutSession.voice_queries),
        )
        .where(WorkoutSession.id == session_id)
    )
    return result.scalar_one_or_none()


async def list_sessions(db: AsyncSession) -> list[WorkoutSession]:
    result = await db.execute(
        select(WorkoutSession)
        .options(selectinload(WorkoutSession.exercise_sets).selectinload(ExerciseSet.posture_errors))
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


async def delete_session(db: AsyncSession, session_id: str) -> None:
    session = await get_session(db, session_id)
    if session:
        await db.delete(session)
        await db.commit()

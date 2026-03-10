from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db import crud
from app.cv.pipeline import run_cv_pipeline
from app.analysis.rule_based import run_analysis
from app.analysis.aggregator import aggregate_results, build_feedback_context
from app.feedback.llm import generate_feedback
from app.schemas.session import SessionResult, SessionSummary

router = APIRouter()


@router.post("/analyze", response_model=SessionResult)
async def analyze_video(
    video: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    # Validate file type
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="File must be a video")

    # Create session record
    session = await crud.create_session(db)

    try:
        # CV pipeline: extract frames + detect poses
        pose_frames, meta = await run_cv_pipeline(video)

        # Exercise analysis
        exercise_results = run_analysis(pose_frames, meta.fps)

        # Build feedback context and generate LLM feedback
        feedback_context = build_feedback_context(exercise_results)
        feedback_text = generate_feedback(feedback_context)

        # Aggregate and persist
        aggregated = aggregate_results(exercise_results)
        updated = await crud.update_session_completed(
            db=db,
            session_id=session.id,
            duration_s=int(meta.duration_s),
            exercise_sets=aggregated["exercise_sets"],
            feedback_text=feedback_text,
        )

        return updated

    except Exception as e:
        await crud.update_session_failed(db, session.id, str(e))
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@router.get("", response_model=list[SessionSummary])
async def list_sessions(db: AsyncSession = Depends(get_db)):
    sessions = await crud.list_sessions(db)
    summaries = []
    for s in sessions:
        total_reps = sum(es.rep_count for es in s.exercise_sets)
        scores = [es.form_score for es in s.exercise_sets if es.form_score > 0]
        avg_score = sum(scores) / len(scores) if scores else 0.0
        exercise_types = list({es.exercise_type for es in s.exercise_sets})
        summaries.append(SessionSummary(
            id=s.id,
            created_at=s.created_at,
            duration_s=s.duration_s,
            status=s.status,
            total_reps=total_reps,
            avg_form_score=round(avg_score, 1),
            exercise_types=exercise_types,
        ))
    return summaries


@router.get("/{session_id}", response_model=SessionResult)
async def get_session(session_id: str, db: AsyncSession = Depends(get_db)):
    session = await crud.get_session(db, session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.delete("/{session_id}", status_code=204)
async def delete_session(session_id: str, db: AsyncSession = Depends(get_db)):
    session = await crud.get_session(db, session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    await crud.delete_session(db, session_id)

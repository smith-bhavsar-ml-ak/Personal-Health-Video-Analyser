import logging
import os
import time

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db import crud
from app.db.models import User
from app.auth.deps import get_current_user
from app.cv.pipeline import run_cv_pipeline
from app.analysis.bilstm_analyser import run_analysis
from app.analysis.aggregator import aggregate_results, build_feedback_context
from app.feedback.llm import generate_feedback
from app.schemas.session import SessionResult, SessionSummary

logger = logging.getLogger(__name__)
router = APIRouter()

MAX_VIDEO_BYTES = int(os.getenv("MAX_VIDEO_SIZE_MB", "200")) * 1024 * 1024


@router.post("/analyze", response_model=SessionResult)
async def analyze_video(
    video: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="File must be a video")

    if video.size and video.size > MAX_VIDEO_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Maximum allowed size is {MAX_VIDEO_BYTES // (1024 * 1024)}MB",
        )

    logger.info("=== NEW ANALYSIS REQUEST === user=%s file=%s type=%s",
                current_user.id, video.filename, video.content_type)

    session = await crud.create_session(db, user_id=current_user.id)
    logger.info("Session created: %s", session.id)

    t_total = time.perf_counter()

    try:
        logger.info("[1/5] Running CV pipeline...")
        t = time.perf_counter()
        pose_frames, meta = await run_cv_pipeline(video)
        logger.info(
            "[1/5] CV done in %.2fs | %dx%d %.1fs @ %.1ffps | extracted=%d detected=%d",
            time.perf_counter() - t,
            meta.width, meta.height, meta.duration_s, meta.fps,
            len(pose_frames),
            sum(1 for f in pose_frames if f.detected),
        )

        logger.info("[2/5] Running exercise analysis...")
        t = time.perf_counter()
        exercise_results = run_analysis(pose_frames, meta.fps)
        for r in exercise_results:
            logger.info(
                "[2/5] %s | reps=%d correct=%d score=%.1f errors=%d",
                r.exercise_type, r.rep_count, r.correct_reps,
                r.form_score, len(r.posture_errors),
            )
        logger.info("[2/5] Analysis done in %.2fs", time.perf_counter() - t)

        logger.info("[3/5] Building feedback context...")
        feedback_context = build_feedback_context(exercise_results)
        logger.debug("Feedback context:\n%s", feedback_context)  # DEBUG — contains user health data

        logger.info("[4/5] Calling LLM for coaching feedback...")
        t = time.perf_counter()
        feedback_text = generate_feedback(feedback_context)
        logger.info("[4/5] LLM done in %.2fs | %d chars", time.perf_counter() - t, len(feedback_text))

        logger.info("[5/5] Persisting results...")
        aggregated = aggregate_results(exercise_results)
        updated = await crud.update_session_completed(
            db=db,
            session_id=session.id,
            duration_s=int(meta.duration_s),
            exercise_sets=aggregated["exercise_sets"],
            feedback_text=feedback_text,
        )
        logger.info("[5/5] Session %s saved | total=%.2fs", session.id, time.perf_counter() - t_total)
        logger.info("=== ANALYSIS COMPLETE ===")

        return updated

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Analysis failed for session %s", session.id)
        await crud.update_session_failed(db, session.id, str(e))
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@router.get("", response_model=list[SessionSummary])
async def list_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sessions = await crud.list_sessions(db, user_id=current_user.id)
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
async def get_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = await crud.get_session(db, session_id, user_id=current_user.id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.delete("/{session_id}", status_code=204)
async def delete_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = await crud.get_session(db, session_id, user_id=current_user.id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    await crud.delete_session(db, session_id, user_id=current_user.id)

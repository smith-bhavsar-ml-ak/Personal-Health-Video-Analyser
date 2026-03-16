import asyncio
import logging
import os
import time

from fastapi import APIRouter, BackgroundTasks, Request, UploadFile, File, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.limiter import limiter
from app.db.database import get_db, AsyncSessionLocal
from app.db import crud
from app.db.models import User
from app.auth.deps import get_current_user
from app.cv.pipeline import run_cv_pipeline_from_bytes
from app.analysis.bilstm_analyser import run_analysis
from app.analysis.aggregator import aggregate_results, build_feedback_context
from app.feedback.llm import generate_feedback
from app.schemas.session import SessionResult, SessionSummary

logger = logging.getLogger(__name__)
router = APIRouter()

MAX_VIDEO_BYTES = int(os.getenv("MAX_VIDEO_SIZE_MB", "200")) * 1024 * 1024
ANALYZE_RATE_LIMIT = os.getenv("ANALYZE_RATE_LIMIT", "10/minute")


async def _run_analysis_background(session_id: str, content: bytes, filename: str) -> None:
    """Full analysis pipeline — runs as a background task with its own DB session."""
    t_total = time.perf_counter()
    async with AsyncSessionLocal() as db:
        try:
            logger.info("[BG:%s] [1/4] Running CV pipeline...", session_id)
            t = time.perf_counter()
            pose_frames, meta = await run_cv_pipeline_from_bytes(content, filename)
            logger.info(
                "[BG:%s] [1/4] CV done in %.2fs | %dx%d %.1fs @ %.1ffps | extracted=%d detected=%d",
                session_id, time.perf_counter() - t,
                meta.width, meta.height, meta.duration_s, meta.fps,
                len(pose_frames), sum(1 for f in pose_frames if f.detected),
            )

            logger.info("[BG:%s] [2/4] Running exercise analysis...", session_id)
            t = time.perf_counter()
            exercise_results = await asyncio.to_thread(run_analysis, pose_frames, meta.fps)
            logger.info("[BG:%s] [2/4] Analysis done in %.2fs", session_id, time.perf_counter() - t)

            feedback_context = build_feedback_context(exercise_results)
            logger.debug("[BG:%s] Feedback context:\n%s", session_id, feedback_context)

            logger.info("[BG:%s] [3/4] Calling LLM...", session_id)
            t = time.perf_counter()
            feedback_text = await asyncio.to_thread(generate_feedback, feedback_context)
            logger.info("[BG:%s] [3/4] LLM done in %.2fs | %d chars", session_id, time.perf_counter() - t, len(feedback_text))

            logger.info("[BG:%s] [4/4] Persisting results...", session_id)
            aggregated = aggregate_results(exercise_results)
            await crud.update_session_completed(
                db=db,
                session_id=session_id,
                duration_s=int(meta.duration_s),
                exercise_sets=aggregated["exercise_sets"],
                feedback_text=feedback_text,
            )
            logger.info("[BG:%s] Done — total=%.2fs", session_id, time.perf_counter() - t_total)

        except Exception as e:
            logger.exception("[BG:%s] Analysis failed", session_id)
            await crud.update_session_failed(db, session_id, str(e))


@router.post("/analyze", response_model=SessionResult)
@limiter.limit(ANALYZE_RATE_LIMIT)
async def analyze_video(
    request: Request,
    background_tasks: BackgroundTasks,
    video: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="File must be a video")

    content = await video.read()
    filename = video.filename or "video.mp4"

    if len(content) > MAX_VIDEO_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Maximum allowed size is {MAX_VIDEO_BYTES // (1024 * 1024)}MB",
        )

    logger.info("=== NEW ANALYSIS REQUEST === user=%s file=%s size=%d",
                current_user.id, filename, len(content))

    session = await crud.create_session(db, user_id=current_user.id)
    logger.info("Session %s created — queuing background analysis", session.id)

    background_tasks.add_task(_run_analysis_background, session.id, content, filename)

    return SessionResult(
        id=session.id,
        created_at=session.created_at,
        duration_s=session.duration_s,
        status=session.status,
        exercise_sets=[],
        ai_feedback=None,
        voice_queries=[],
    )


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

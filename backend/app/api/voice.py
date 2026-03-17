import asyncio
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db import crud
from app.db.models import User
from app.auth.deps import get_current_user
from app.feedback.llm import answer_query
from app.feedback.intent import extract_intent
from app.voice.stt import transcribe_audio
from app.voice.tts import synthesise_speech
from app.analysis.aggregator import build_feedback_context
from app.analysis.base import ExerciseResult
from app.analysis.base import PostureError as PE
from app.schemas.session import VoiceQueryRequest, VoiceQueryResponse

router = APIRouter()


def _session_exercise_results(session) -> list[ExerciseResult]:
    """Convert a WorkoutSession ORM object to a list of ExerciseResult."""
    results = []
    for es in session.exercise_sets:
        errors = [PE(e.error_type, e.occurrences, e.severity) for e in es.posture_errors]
        results.append(ExerciseResult(
            exercise_type=es.exercise_type,
            rep_count=es.rep_count,
            correct_reps=es.correct_reps,
            duration_s=es.duration_s,
            form_score=es.form_score,
            rep_scores=[],
            posture_errors=errors,
        ))
    return results


@router.post("/{session_id}/voice", response_model=VoiceQueryResponse)
async def voice_query(
    session_id: str,
    request: VoiceQueryRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = await crud.get_session(db, session_id, user_id=current_user.id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # ── 1. Resolve query text ───────────────────────────────────────────────
    if request.audio_b64:
        transcribed = await asyncio.to_thread(transcribe_audio, request.audio_b64)
        # Prepend context prefix sent by Flutter (multi-session today summary)
        query_text = f"{request.query_text.strip()} {transcribed}".strip() \
            if request.query_text else transcribed
    elif request.query_text:
        query_text = request.query_text
    else:
        raise HTTPException(status_code=400, detail="Provide query_text or audio_b64")

    # ── 2. Intent detection ─────────────────────────────────────────────────
    intent = extract_intent(query_text)

    # ── 3. Build focused exercise context ──────────────────────────────────
    all_results = _session_exercise_results(session)

    if intent.exercise is not None:
        # User is asking about a specific exercise — only show that data
        focused = [r for r in all_results if r.exercise_type == intent.exercise]
        if not focused:
            # Exercise not found in this session — fall back to all results
            focused = all_results
    else:
        focused = all_results

    session_context = build_feedback_context(focused)

    # ── 4. LLM answer ───────────────────────────────────────────────────────
    # Prepend user profile context if provided so the LLM personalises advice.
    full_context = session_context
    if request.profile_context:
        full_context = f"{request.profile_context}\n\n{session_context}"

    response_text = answer_query(intent.clean_query, full_context)

    # ── 5. TTS ──────────────────────────────────────────────────────────────
    audio_b64 = await asyncio.to_thread(synthesise_speech, response_text)

    await crud.save_voice_query(db, session_id, intent.clean_query, response_text)

    return VoiceQueryResponse(
        query_text=intent.clean_query,
        response_text=response_text,
        audio_b64=audio_b64,
    )

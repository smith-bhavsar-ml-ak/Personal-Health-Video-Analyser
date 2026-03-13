import asyncio
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db import crud
from app.db.models import User
from app.auth.deps import get_current_user
from app.feedback.llm import answer_query
from app.voice.stt import transcribe_audio
from app.voice.tts import synthesise_speech
from app.analysis.aggregator import build_feedback_context
from app.schemas.session import VoiceQueryRequest, VoiceQueryResponse

router = APIRouter()


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

    # Resolve query text — run blocking Whisper in thread pool
    if request.audio_b64:
        query_text = await asyncio.to_thread(transcribe_audio, request.audio_b64)
    elif request.query_text:
        query_text = request.query_text
    else:
        raise HTTPException(status_code=400, detail="Provide query_text or audio_b64")

    # Build session context for LLM
    from app.analysis.base import ExerciseResult, PostureError as PE
    exercise_results = []
    for es in session.exercise_sets:
        errors = [PE(e.error_type, e.occurrences, e.severity) for e in es.posture_errors]
        exercise_results.append(ExerciseResult(
            exercise_type=es.exercise_type,
            rep_count=es.rep_count,
            correct_reps=es.correct_reps,
            duration_s=es.duration_s,
            form_score=es.form_score,
            rep_scores=[],
            posture_errors=errors,
        ))
    session_context = build_feedback_context(exercise_results)

    # LLM answer (already handles its own timeout)
    response_text = answer_query(query_text, session_context)

    # TTS — run blocking pyttsx3 in thread pool
    audio_b64 = await asyncio.to_thread(synthesise_speech, response_text)

    await crud.save_voice_query(db, session_id, query_text, response_text)

    return VoiceQueryResponse(query_text=query_text, response_text=response_text, audio_b64=audio_b64)

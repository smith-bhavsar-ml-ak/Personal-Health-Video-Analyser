from pydantic import BaseModel
from datetime import datetime


class PostureErrorSchema(BaseModel):
    id: str
    error_type: str
    occurrences: int
    severity: str

    class Config:
        from_attributes = True


class ExerciseSetSchema(BaseModel):
    id: str
    exercise_type: str
    rep_count: int
    correct_reps: int
    duration_s: int
    form_score: float
    posture_errors: list[PostureErrorSchema] = []

    class Config:
        from_attributes = True


class AIFeedbackSchema(BaseModel):
    feedback_text: str
    generated_at: datetime

    class Config:
        from_attributes = True


class VoiceQuerySchema(BaseModel):
    id: str
    query_text: str
    response_text: str
    created_at: datetime

    class Config:
        from_attributes = True


class SessionSummary(BaseModel):
    id: str
    created_at: datetime
    duration_s: int | None
    status: str
    total_reps: int
    avg_form_score: float
    exercise_types: list[str]

    class Config:
        from_attributes = True


class SessionResult(BaseModel):
    id: str
    created_at: datetime
    duration_s: int | None
    status: str
    exercise_sets: list[ExerciseSetSchema] = []
    ai_feedback: AIFeedbackSchema | None = None
    voice_queries: list[VoiceQuerySchema] = []

    class Config:
        from_attributes = True


class VoiceQueryRequest(BaseModel):
    query_text: str | None = None
    audio_b64: str | None = None


class VoiceQueryResponse(BaseModel):
    query_text: str
    response_text: str
    audio_b64: str | None = None


class APIResponse(BaseModel):
    success: bool
    data: dict | list | None = None
    error: str | None = None

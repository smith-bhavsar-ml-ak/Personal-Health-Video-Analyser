import uuid
from datetime import datetime
from sqlalchemy import String, Integer, Float, ForeignKey, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


def new_uuid() -> str:
    return str(uuid.uuid4())


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    duration_s: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String, default="processing")  # processing | completed | failed
    error_msg: Mapped[str | None] = mapped_column(Text, nullable=True)

    exercise_sets: Mapped[list["ExerciseSet"]] = relationship(back_populates="session", cascade="all, delete-orphan")
    ai_feedback: Mapped["AIFeedback | None"] = relationship(back_populates="session", cascade="all, delete-orphan", uselist=False)
    voice_queries: Mapped[list["VoiceQuery"]] = relationship(back_populates="session", cascade="all, delete-orphan")


class ExerciseSet(Base):
    __tablename__ = "exercise_sets"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    session_id: Mapped[str] = mapped_column(ForeignKey("workout_sessions.id"))
    exercise_type: Mapped[str] = mapped_column(String)  # squat | jumping_jack | bicep_curl | lunge | plank
    rep_count: Mapped[int] = mapped_column(Integer, default=0)
    correct_reps: Mapped[int] = mapped_column(Integer, default=0)
    duration_s: Mapped[int] = mapped_column(Integer, default=0)
    form_score: Mapped[float] = mapped_column(Float, default=0.0)
    start_frame: Mapped[int] = mapped_column(Integer, default=0)
    end_frame: Mapped[int] = mapped_column(Integer, default=0)

    session: Mapped["WorkoutSession"] = relationship(back_populates="exercise_sets")
    posture_errors: Mapped[list["PostureError"]] = relationship(back_populates="exercise_set", cascade="all, delete-orphan")


class PostureError(Base):
    __tablename__ = "posture_errors"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    set_id: Mapped[str] = mapped_column(ForeignKey("exercise_sets.id"))
    error_type: Mapped[str] = mapped_column(String)
    occurrences: Mapped[int] = mapped_column(Integer, default=1)
    severity: Mapped[str] = mapped_column(String, default="low")  # low | medium | high

    exercise_set: Mapped["ExerciseSet"] = relationship(back_populates="posture_errors")


class AIFeedback(Base):
    __tablename__ = "ai_feedback"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    session_id: Mapped[str] = mapped_column(ForeignKey("workout_sessions.id"))
    feedback_text: Mapped[str] = mapped_column(Text)
    generated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    session: Mapped["WorkoutSession"] = relationship(back_populates="ai_feedback")


class VoiceQuery(Base):
    __tablename__ = "voice_queries"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    session_id: Mapped[str] = mapped_column(ForeignKey("workout_sessions.id"))
    query_text: Mapped[str] = mapped_column(Text)
    response_text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    session: Mapped["WorkoutSession"] = relationship(back_populates="voice_queries")

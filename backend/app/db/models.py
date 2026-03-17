import uuid
from datetime import datetime
from sqlalchemy import String, Integer, Float, ForeignKey, DateTime, Text, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


def new_uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    sessions: Mapped[list["WorkoutSession"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    profile: Mapped["UserProfile | None"] = relationship(back_populates="user", cascade="all, delete-orphan", uselist=False)


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    duration_s: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String, default="processing")  # processing | completed | failed
    error_msg: Mapped[str | None] = mapped_column(Text, nullable=True)

    user: Mapped["User | None"] = relationship(back_populates="sessions")
    exercise_sets: Mapped[list["ExerciseSet"]] = relationship(back_populates="session", cascade="all, delete-orphan")
    ai_feedback: Mapped["AIFeedback | None"] = relationship(back_populates="session", cascade="all, delete-orphan", uselist=False)
    voice_queries: Mapped[list["VoiceQuery"]] = relationship(back_populates="session", cascade="all, delete-orphan")


class ExerciseSet(Base):
    __tablename__ = "exercise_sets"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    session_id: Mapped[str] = mapped_column(ForeignKey("workout_sessions.id"))
    exercise_type: Mapped[str] = mapped_column(String)
    rep_count: Mapped[int] = mapped_column(Integer, default=0)
    correct_reps: Mapped[int] = mapped_column(Integer, default=0)
    duration_s: Mapped[int] = mapped_column(Integer, default=0)
    form_score: Mapped[float] = mapped_column(Float, default=0.0)
    start_frame: Mapped[int] = mapped_column(Integer, default=0)
    end_frame: Mapped[int] = mapped_column(Integer, default=0)
    rep_scores: Mapped[list | None] = mapped_column(JSON, nullable=True)  # [85.0, 92.0, ...]

    session: Mapped["WorkoutSession"] = relationship(back_populates="exercise_sets")
    posture_errors: Mapped[list["PostureError"]] = relationship(back_populates="exercise_set", cascade="all, delete-orphan")


class PostureError(Base):
    __tablename__ = "posture_errors"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    set_id: Mapped[str] = mapped_column(ForeignKey("exercise_sets.id"))
    error_type: Mapped[str] = mapped_column(String)
    occurrences: Mapped[int] = mapped_column(Integer, default=1)
    severity: Mapped[str] = mapped_column(String, default="low")

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


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True, index=True)
    display_name: Mapped[str | None] = mapped_column(String, nullable=True)
    date_of_birth: Mapped[str | None] = mapped_column(String, nullable=True)  # ISO date string
    gender: Mapped[str | None] = mapped_column(String, nullable=True)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    target_weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    fitness_level: Mapped[str | None] = mapped_column(String, nullable=True)
    primary_goal: Mapped[str | None] = mapped_column(String, nullable=True)
    weekly_workout_target: Mapped[int | None] = mapped_column(Integer, nullable=True)
    equipment: Mapped[str | None] = mapped_column(String, nullable=True)
    activity_level: Mapped[str | None] = mapped_column(String, nullable=True)
    injuries: Mapped[str | None] = mapped_column(Text, nullable=True)
    unit_system: Mapped[str] = mapped_column(String, default="metric")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="profile")


class WeightLog(Base):
    __tablename__ = "weight_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    weight_kg: Mapped[float] = mapped_column(Float)
    logged_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    user: Mapped["User"] = relationship()


class WorkoutPlan(Base):
    __tablename__ = "workout_plans"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    duration_weeks: Mapped[int] = mapped_column(Integer, default=4)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    exercises: Mapped[list["PlanExercise"]] = relationship(
        back_populates="plan", cascade="all, delete-orphan",
        order_by="PlanExercise.day_of_week"
    )


class PlanExercise(Base):
    __tablename__ = "plan_exercises"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_uuid)
    plan_id: Mapped[str] = mapped_column(ForeignKey("workout_plans.id", ondelete="CASCADE"), index=True)
    day_of_week: Mapped[int] = mapped_column(Integer)        # 0=Mon … 6=Sun
    exercise_type: Mapped[str] = mapped_column(String)
    sets_target: Mapped[int] = mapped_column(Integer, default=3)
    reps_target: Mapped[int] = mapped_column(Integer, default=10)
    duration_target_s: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    plan: Mapped["WorkoutPlan"] = relationship(back_populates="exercises")

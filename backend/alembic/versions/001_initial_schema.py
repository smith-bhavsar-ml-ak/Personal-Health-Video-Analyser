"""Initial schema

Revision ID: 001
Revises:
Create Date: 2026-03-16
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("hashed_password", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "workout_sessions",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("duration_s", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("error_msg", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_workout_sessions_user_id", "workout_sessions", ["user_id"])

    op.create_table(
        "exercise_sets",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("session_id", sa.String(), sa.ForeignKey("workout_sessions.id"), nullable=False),
        sa.Column("exercise_type", sa.String(), nullable=False),
        sa.Column("rep_count", sa.Integer(), nullable=False),
        sa.Column("correct_reps", sa.Integer(), nullable=False),
        sa.Column("duration_s", sa.Integer(), nullable=False),
        sa.Column("form_score", sa.Float(), nullable=False),
        sa.Column("start_frame", sa.Integer(), nullable=False),
        sa.Column("end_frame", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "posture_errors",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("set_id", sa.String(), sa.ForeignKey("exercise_sets.id"), nullable=False),
        sa.Column("error_type", sa.String(), nullable=False),
        sa.Column("occurrences", sa.Integer(), nullable=False),
        sa.Column("severity", sa.String(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "ai_feedback",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("session_id", sa.String(), sa.ForeignKey("workout_sessions.id"), nullable=False),
        sa.Column("feedback_text", sa.Text(), nullable=False),
        sa.Column("generated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "voice_queries",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("session_id", sa.String(), sa.ForeignKey("workout_sessions.id"), nullable=False),
        sa.Column("query_text", sa.Text(), nullable=False),
        sa.Column("response_text", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("voice_queries")
    op.drop_table("ai_feedback")
    op.drop_table("posture_errors")
    op.drop_table("exercise_sets")
    op.drop_index("ix_workout_sessions_user_id", table_name="workout_sessions")
    op.drop_table("workout_sessions")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")

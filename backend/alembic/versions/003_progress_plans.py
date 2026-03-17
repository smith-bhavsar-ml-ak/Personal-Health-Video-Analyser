"""add weight_logs, rep_scores, workout_plans, plan_exercises

Revision ID: 003
Revises: 002
Create Date: 2026-03-17
"""
from alembic import op
import sqlalchemy as sa

revision = '003'
down_revision = '002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── rep_scores JSON column on exercise_sets ───────────────────────────────
    op.add_column('exercise_sets', sa.Column('rep_scores', sa.JSON(), nullable=True))

    # ── weight_logs ───────────────────────────────────────────────────────────
    op.create_table(
        'weight_logs',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('weight_kg', sa.Float(), nullable=False),
        sa.Column('logged_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_weight_logs_user_id', 'weight_logs', ['user_id'])
    op.create_index('ix_weight_logs_logged_at', 'weight_logs', ['logged_at'])

    # ── workout_plans ─────────────────────────────────────────────────────────
    op.create_table(
        'workout_plans',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('duration_weeks', sa.Integer(), nullable=False, server_default='4'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_workout_plans_user_id', 'workout_plans', ['user_id'])

    # ── plan_exercises ────────────────────────────────────────────────────────
    op.create_table(
        'plan_exercises',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('plan_id', sa.String(), nullable=False),
        sa.Column('day_of_week', sa.Integer(), nullable=False),   # 0=Mon … 6=Sun
        sa.Column('exercise_type', sa.String(), nullable=False),
        sa.Column('sets_target', sa.Integer(), nullable=False, server_default='3'),
        sa.Column('reps_target', sa.Integer(), nullable=False, server_default='10'),
        sa.Column('duration_target_s', sa.Integer(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['plan_id'], ['workout_plans.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_plan_exercises_plan_id', 'plan_exercises', ['plan_id'])


def downgrade() -> None:
    op.drop_index('ix_plan_exercises_plan_id', table_name='plan_exercises')
    op.drop_table('plan_exercises')
    op.drop_index('ix_workout_plans_user_id', table_name='workout_plans')
    op.drop_table('workout_plans')
    op.drop_index('ix_weight_logs_logged_at', table_name='weight_logs')
    op.drop_index('ix_weight_logs_user_id', table_name='weight_logs')
    op.drop_table('weight_logs')
    op.drop_column('exercise_sets', 'rep_scores')

"""add subscriptions, activity_sessions, daily_step_logs, streaks

Revision ID: 004
Revises: 003
Create Date: 2026-03-18
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector

revision = '004'
down_revision = '003'
branch_labels = None
depends_on = None


def _table_exists(conn, table_name: str) -> bool:
    return Inspector.from_engine(conn).has_table(table_name)


def _index_exists(conn, index_name: str, table_name: str) -> bool:
    insp = Inspector.from_engine(conn)
    return any(ix['name'] == index_name for ix in insp.get_indexes(table_name))


def upgrade() -> None:
    conn = op.get_bind()

    # ── subscriptions ─────────────────────────────────────────────────────────
    if not _table_exists(conn, 'subscriptions'):
        op.create_table(
            'subscriptions',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('user_id', sa.String(), nullable=False),
            sa.Column('tier', sa.String(), nullable=False, server_default='free'),
            sa.Column('started_at', sa.DateTime(), nullable=False),
            sa.Column('expires_at', sa.DateTime(), nullable=True),
            sa.Column('analyses_used_this_month', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('analyses_reset_at', sa.DateTime(), nullable=False),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('user_id'),
        )
        op.create_index('ix_subscriptions_user_id', 'subscriptions', ['user_id'])

    # ── activity_sessions ─────────────────────────────────────────────────────
    if not _table_exists(conn, 'activity_sessions'):
        op.create_table(
            'activity_sessions',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('user_id', sa.String(), nullable=False),
            sa.Column('activity_type', sa.String(), nullable=False, server_default='walk'),
            sa.Column('started_at', sa.DateTime(), nullable=False),
            sa.Column('ended_at', sa.DateTime(), nullable=True),
            sa.Column('steps', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('distance_m', sa.Float(), nullable=False, server_default='0'),
            sa.Column('avg_pace_s_per_km', sa.Float(), nullable=True),
            sa.Column('calories_burned', sa.Float(), nullable=False, server_default='0'),
            sa.Column('polyline', sa.JSON(), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index('ix_activity_sessions_user_id', 'activity_sessions', ['user_id'])

    # ── daily_step_logs ───────────────────────────────────────────────────────
    if not _table_exists(conn, 'daily_step_logs'):
        op.create_table(
            'daily_step_logs',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('user_id', sa.String(), nullable=False),
            sa.Column('log_date', sa.Date(), nullable=False),
            sa.Column('steps', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('goal', sa.Integer(), nullable=False, server_default='8000'),
            sa.Column('calories_burned', sa.Float(), nullable=False, server_default='0'),
            sa.Column('active_minutes', sa.Integer(), nullable=False, server_default='0'),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index('ix_daily_step_logs_user_id', 'daily_step_logs', ['user_id'])
        op.create_index('ix_daily_step_logs_log_date', 'daily_step_logs', ['log_date'])

    # ── streaks ───────────────────────────────────────────────────────────────
    if not _table_exists(conn, 'streaks'):
        op.create_table(
            'streaks',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('user_id', sa.String(), nullable=False),
            sa.Column('current_streak', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('longest_streak', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('last_activity_date', sa.Date(), nullable=True),
            sa.Column('total_active_days', sa.Integer(), nullable=False, server_default='0'),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('user_id'),
        )
        op.create_index('ix_streaks_user_id', 'streaks', ['user_id'])


def downgrade() -> None:
    op.drop_index('ix_streaks_user_id', table_name='streaks')
    op.drop_table('streaks')
    op.drop_index('ix_daily_step_logs_log_date', table_name='daily_step_logs')
    op.drop_index('ix_daily_step_logs_user_id', table_name='daily_step_logs')
    op.drop_table('daily_step_logs')
    op.drop_index('ix_activity_sessions_user_id', table_name='activity_sessions')
    op.drop_table('activity_sessions')
    op.drop_index('ix_subscriptions_user_id', table_name='subscriptions')
    op.drop_table('subscriptions')

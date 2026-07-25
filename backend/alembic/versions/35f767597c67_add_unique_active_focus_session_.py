"""add unique active focus session constraint

Revision ID: 35f767597c67
Revises: c768c023f7a3
Create Date: 2026-07-25 20:05:49.951677

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '35f767597c67'
down_revision: Union[str, Sequence[str], None] = 'c768c023f7a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_index(
        "uq_focus_sessions_active_user",
        "focus_sessions",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text(
            "status = 'started'"
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(
        "uq_focus_sessions_active_user",
        table_name="focus_sessions",
    )

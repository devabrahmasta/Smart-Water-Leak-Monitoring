"""0003 room quiet hours

Revision ID: b2e5d3c8f102
Revises: a1f4c2d7e901
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "b2e5d3c8f102"
down_revision: Union[str, None] = "a1f4c2d7e901"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("room_rules", sa.Column("quiet_start", sa.String(5), server_default="01:00", nullable=False))
    op.add_column("room_rules", sa.Column("quiet_end", sa.String(5), server_default="04:00", nullable=False))


def downgrade() -> None:
    op.drop_column("room_rules", "quiet_end")
    op.drop_column("room_rules", "quiet_start")

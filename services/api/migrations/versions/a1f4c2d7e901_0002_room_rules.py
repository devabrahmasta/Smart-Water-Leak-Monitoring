"""0002 room rules

Revision ID: a1f4c2d7e901
Revises: cd11ec3d55bc
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "a1f4c2d7e901"
down_revision: Union[str, None] = "cd11ec3d55bc"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "room_rules",
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("continuous_sec", sa.Integer(), nullable=False),
        sa.Column("stable_sec", sa.Integer(), nullable=False),
        sa.Column("quiet_sec", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("room_id"),
    )


def downgrade() -> None:
    op.drop_table("room_rules")

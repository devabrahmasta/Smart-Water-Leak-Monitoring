"""0004 device live

Revision ID: c3f6e4d9a203
Revises: b2e5d3c8f102
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "c3f6e4d9a203"
down_revision: Union[str, None] = "b2e5d3c8f102"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "device_live",
        sa.Column("device_id", sa.String(50), nullable=False),
        sa.Column("flow_lpm", sa.Float(), nullable=False),
        sa.Column("valve", sa.String(10), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("device_id"),
    )


def downgrade() -> None:
    op.drop_table("device_live")

from datetime import datetime
from sqlalchemy import ForeignKey, Integer, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomRule(Base):
    """Durasi aturan kebocoran per kamar (CONTRACT.md 2.10). Tanpa baris = nilai bawaan."""

    __tablename__ = "room_rules"

    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), primary_key=True
    )
    continuous_sec: Mapped[int] = mapped_column(Integer, nullable=False)
    stable_sec: Mapped[int] = mapped_column(Integer, nullable=False)
    quiet_sec: Mapped[int] = mapped_column(Integer, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

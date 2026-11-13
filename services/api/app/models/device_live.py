from datetime import datetime
from sqlalchemy import DateTime, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class DeviceLive(Base):
    """Debit terakhir dari topik live (CONTRACT.md 2.12). Satu baris per perangkat."""

    __tablename__ = "device_live"

    device_id: Mapped[str] = mapped_column(
        String(50), ForeignKey("devices.id", ondelete="CASCADE"), primary_key=True
    )
    flow_lpm: Mapped[float] = mapped_column(Float, nullable=False)
    valve: Mapped[str] = mapped_column(String(10), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

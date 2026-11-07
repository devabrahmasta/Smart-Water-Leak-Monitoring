from datetime import date
from typing import TYPE_CHECKING
from sqlalchemy import Integer, String, Float, Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.room import Room


class DailyUsage(Base):
    __tablename__ = "daily_usage"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rooms.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    volume_l: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    peak_flow_lpm: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    # Relasi
    room: Mapped["Room"] = relationship("Room", back_populates="daily_usages")

    __table_args__ = (
        UniqueConstraint("room_id", "date", name="uq_daily_usage_room_date"),
    )

    def __repr__(self) -> str:
        return f"<DailyUsage room={self.room_id} date={self.date} volume={self.volume_l}>"


class MonthlyUsage(Base):
    __tablename__ = "monthly_usage"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rooms.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    month: Mapped[str] = mapped_column(String(7), nullable=False)  # Format 'YYYY-MM' (contoh: '2026-11')
    volume_l: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    # Relasi
    room: Mapped["Room"] = relationship("Room", back_populates="monthly_usages")

    __table_args__ = (
        UniqueConstraint("room_id", "month", name="uq_monthly_usage_room_month"),
    )

    def __repr__(self) -> str:
        return f"<MonthlyUsage room={self.room_id} month='{self.month}' volume={self.volume_l}>"


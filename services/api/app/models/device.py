from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
import enum
from sqlalchemy import String, Integer, DateTime, Enum, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.room import Room
    from app.models.telemetry import Telemetry


class ValveState(str, enum.Enum):
    OPEN = "OPEN"
    CLOSED = "CLOSED"


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)  # MQTT Client ID / username ("1", "2")
    room_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rooms.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    valve_state: Mapped[ValveState] = mapped_column(
        Enum(ValveState, name="valvestate"),
        nullable=False,
        default=ValveState.OPEN,
    )
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    firmware_version: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
    )

    # Relasi
    room: Mapped["Room"] = relationship("Room", back_populates="device")
    telemetries: Mapped[List["Telemetry"]] = relationship(
        "Telemetry",
        back_populates="device",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Device id='{self.id}' room_id={self.room_id} valve='{self.valve_state}'>"

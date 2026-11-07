from datetime import datetime
from typing import TYPE_CHECKING, List, Optional, Any, Dict
import enum
from sqlalchemy import Integer, DateTime, Enum, ForeignKey, JSON, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.room import Room
    from app.models.notification import Notification


class AlertType(str, enum.Enum):
    LEAK = "LEAK"
    ANOMALY = "ANOMALY"
    ACTIVITY = "ACTIVITY"


class AlertRule(str, enum.Enum):
    CONTINUOUS = "CONTINUOUS"
    STABLE = "STABLE"
    QUIET_HOURS = "QUIET_HOURS"
    DAILY_RATIO = "DAILY_RATIO"
    MANUAL_BUTTON = "MANUAL_BUTTON"


class AlertStatus(str, enum.Enum):
    OPEN = "OPEN"
    RESOLVED = "RESOLVED"
    INFO = "INFO"


class AlertResolvedBy(str, enum.Enum):
    APP = "APP"
    MANUAL_BUTTON = "MANUAL_BUTTON"


class Alert(Base):
    __tablename__ = "alerts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rooms.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    type: Mapped[AlertType] = mapped_column(
        Enum(AlertType, name="alerttype"),
        nullable=False,
    )
    rule: Mapped[AlertRule] = mapped_column(
        Enum(AlertRule, name="alertrule"),
        nullable=False,
    )
    status: Mapped[AlertStatus] = mapped_column(
        Enum(AlertStatus, name="alertstatus"),
        nullable=False,
        default=AlertStatus.OPEN,
    )
    device_ts: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    resolved_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    resolved_by: Mapped[Optional[AlertResolvedBy]] = mapped_column(
        Enum(AlertResolvedBy, name="alertresolvedby"),
        nullable=True,
    )
    detail: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
    )

    # Relasi
    room: Mapped["Room"] = relationship("Room", back_populates="alerts")
    notifications: Mapped[List["Notification"]] = relationship(
        "Notification",
        back_populates="alert",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Alert id={self.id} room={self.room_id} type='{self.type}' status='{self.status}'>"


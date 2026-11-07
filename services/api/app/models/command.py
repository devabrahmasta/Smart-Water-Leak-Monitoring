from datetime import datetime
from typing import TYPE_CHECKING, Optional
import enum
from sqlalchemy import Integer, String, DateTime, Enum, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.room import Room


class CommandAction(str, enum.Enum):
    OPEN = "OPEN"
    CLOSE = "CLOSE"


class CommandSource(str, enum.Enum):
    APP = "APP"
    AUTO = "AUTO"
    MANUAL_BUTTON = "MANUAL_BUTTON"


class CommandStatus(str, enum.Enum):
    PENDING = "PENDING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"


class ValveCommand(Base):
    __tablename__ = "valve_commands"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)  # command_id
    room_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rooms.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    action: Mapped[CommandAction] = mapped_column(
        Enum(CommandAction, name="commandaction"),
        nullable=False,
    )
    source: Mapped[CommandSource] = mapped_column(
        Enum(CommandSource, name="commandsource"),
        nullable=False,
    )
    user_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    status: Mapped[CommandStatus] = mapped_column(
        Enum(CommandStatus, name="commandstatus"),
        nullable=False,
        default=CommandStatus.PENDING,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    acked_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relasi
    room: Mapped["Room"] = relationship("Room", back_populates="commands")

    def __repr__(self) -> str:
        return f"<ValveCommand id={self.id} room={self.room_id} action='{self.action}' status='{self.status}'>"


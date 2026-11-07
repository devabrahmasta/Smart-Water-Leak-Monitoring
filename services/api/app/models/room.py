from typing import TYPE_CHECKING, List
from sqlalchemy import String, Integer, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.device import Device
    from app.models.usage import DailyUsage, MonthlyUsage
    from app.models.alert import Alert
    from app.models.command import ValveCommand


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_simulated: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Relasi 1-to-1 dengan device
    device: Mapped["Device"] = relationship(
        "Device",
        back_populates="room",
        uselist=False,
        cascade="all, delete-orphan",
    )

    # Relasi 1-to-many dengan usage, alert, command
    daily_usages: Mapped[List["DailyUsage"]] = relationship(
        "DailyUsage",
        back_populates="room",
        cascade="all, delete-orphan",
    )
    monthly_usages: Mapped[List["MonthlyUsage"]] = relationship(
        "MonthlyUsage",
        back_populates="room",
        cascade="all, delete-orphan",
    )
    alerts: Mapped[List["Alert"]] = relationship(
        "Alert",
        back_populates="room",
        cascade="all, delete-orphan",
    )
    commands: Mapped[List["ValveCommand"]] = relationship(
        "ValveCommand",
        back_populates="room",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Room id={self.id} name='{self.name}' is_simulated={self.is_simulated}>"

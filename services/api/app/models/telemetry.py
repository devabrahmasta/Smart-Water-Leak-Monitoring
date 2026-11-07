from datetime import datetime
from typing import TYPE_CHECKING, Optional
from sqlalchemy import BigInteger, String, Float, DateTime, Enum, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.device import ValveState

if TYPE_CHECKING:
    from app.models.device import Device


class Telemetry(Base):
    __tablename__ = "telemetry"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(
        String(50),
        ForeignKey("devices.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    msg_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    device_ts: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    flow_lpm: Mapped[float] = mapped_column(Float, nullable=False)
    volume_l_delta: Mapped[float] = mapped_column(Float, nullable=False)
    valve_state: Mapped[ValveState] = mapped_column(
        Enum(ValveState, name="valvestate"),
        nullable=False,
    )

    # Relasi
    device: Mapped["Device"] = relationship("Device", back_populates="telemetries")

    # Constraint deduplikasi (KPI K4)
    __table_args__ = (
        UniqueConstraint("device_id", "msg_id", name="uq_telemetry_device_msg"),
    )

    def __repr__(self) -> str:
        return f"<Telemetry id={self.id} device='{self.device_id}' msg_id={self.msg_id} flow={self.flow_lpm}>"

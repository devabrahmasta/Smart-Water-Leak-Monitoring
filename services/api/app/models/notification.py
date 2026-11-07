from datetime import datetime
from typing import TYPE_CHECKING, Optional
from sqlalchemy import Integer, String, Text, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

if TYPE_CHECKING:
    from app.models.alert import Alert


class PushToken(Base):
    __tablename__ = "push_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    token: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    platform: Mapped[str] = mapped_column(String(20), default="android", nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    def __repr__(self) -> str:
        return f"<PushToken id={self.id} platform='{self.platform}'>"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    alert_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("alerts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sent_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    attempts: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    last_error: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relasi
    alert: Mapped["Alert"] = relationship("Alert", back_populates="notifications")

    def __repr__(self) -> str:
        return f"<Notification id={self.id} alert_id={self.alert_id} attempts={self.attempts}>"

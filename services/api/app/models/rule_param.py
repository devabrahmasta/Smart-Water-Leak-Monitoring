from typing import Optional
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RuleParam(Base):
    __tablename__ = "rule_params"

    key: Mapped[str] = mapped_column(String(50), primary_key=True)
    value: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    def as_int(self) -> int:
        return int(float(self.value))

    def as_float(self) -> float:
        return float(self.value)

    def as_str(self) -> str:
        return str(self.value)

    def __repr__(self) -> str:
        return f"<RuleParam key='{self.key}' value='{self.value}'>"


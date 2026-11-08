"""
Pydantic Schemas untuk Room dan Detail Kamar (R-07).
"""

from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.alert import AlertDetailResponse
from app.schemas.command import ValveCommandDetailResponse


class RoomStatusEnum(str, Enum):
    NORMAL = "NORMAL"
    LEAK = "LEAK"
    CLOSED = "CLOSED"
    OFFLINE = "OFFLINE"


class RoomListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    status: RoomStatusEnum
    valve: str  # OPEN or CLOSED
    today_l: Optional[float] = None
    flow_lpm: Optional[float] = None
    is_highest: bool = False
    last_seen_at: Optional[str] = None


class RoomListResponse(BaseModel):
    rooms: List[RoomListItem]


class RoomDetailResponse(BaseModel):
    room: RoomListItem
    month_l: float
    avg_daily_l: float
    recent_alerts: List[AlertDetailResponse] = []


class RoomCommandsResponse(BaseModel):
    commands: List[ValveCommandDetailResponse] = []


class RoomRulesBody(BaseModel):
    """Durasi aturan dalam detik dan jam sepi WIB (CONTRACT.md 2.10)."""

    continuous_sec: int = Field(ge=1, le=86400)
    stable_sec: int = Field(ge=1, le=86400)
    quiet_sec: int = Field(ge=1, le=86400)
    quiet_start: str = Field(pattern=r"^([01][0-9]|2[0-3]):[0-5][0-9]$")
    quiet_end: str = Field(pattern=r"^([01][0-9]|2[0-3]):[0-5][0-9]$")

    @model_validator(mode="after")
    def _quiet_range_not_empty(self):
        if self.quiet_start == self.quiet_end:
            raise ValueError("Jam mulai dan selesai tidak boleh sama")
        return self


class RoomRulesResponse(RoomRulesBody):
    room_id: int


class DemoScenarioEnum(str, Enum):
    NORMAL = "NORMAL"
    LEAK_CONTINUOUS = "LEAK_CONTINUOUS"
    LEAK_STABLE = "LEAK_STABLE"
    LEAK_QUIET_HOURS = "LEAK_QUIET_HOURS"
    OFFLINE = "OFFLINE"
    NO_ACK = "NO_ACK"


class DemoScenarioBody(BaseModel):
    scenario: DemoScenarioEnum

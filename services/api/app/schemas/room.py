"""
Pydantic Schemas untuk Room dan Detail Kamar (R-07).
"""

from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, ConfigDict

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

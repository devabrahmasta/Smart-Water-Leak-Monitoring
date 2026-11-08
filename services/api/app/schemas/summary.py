"""
Pydantic Schemas untuk Summary Dashboard (R-07).
"""

from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class LatestOpenAlertSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    room_id: int
    room_name: str
    type: str
    created_at: str


class SummaryTally(BaseModel):
    normal: int = 0
    closed: int = 0
    offline: int = 0
    leak: Optional[int] = 0


class SummaryResponse(BaseModel):
    today_l: float
    month_l: float
    last_7_days_end: str
    last_7_days_l: List[float]
    tally: SummaryTally
    open_alert_count: int
    latest_open_alert: Optional[LatestOpenAlertSummary] = None

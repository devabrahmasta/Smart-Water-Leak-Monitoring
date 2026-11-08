"""
Pydantic Schemas untuk Alert dan Notifikasi Sistem (R-07).
"""

from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict


class AlertDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    room_id: int
    room_name: str
    type: str  # LEAK, ANOMALY, ACTIVITY
    rule: str  # CONTINUOUS, STABLE, QUIET_HOURS, DAILY_RATIO, MANUAL_BUTTON
    status: str  # OPEN, RESOLVED, INFO
    created_at: str  # ISO 8601 UTC string
    resolved_at: Optional[str] = None
    resolved_by: Optional[str] = None  # APP, MANUAL_BUTTON
    detail: Optional[Dict[str, Any]] = None


class AlertListResponse(BaseModel):
    items: List[AlertDetailResponse]
    next_before: Optional[int] = None

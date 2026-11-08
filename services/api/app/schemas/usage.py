"""
Pydantic Schemas untuk Grafik dan Rekap Penggunaan Air (R-07).
"""

from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class UsageDataPoint(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    label: str  # YYYY-MM-DD untuk daily atau YYYY-MM untuk monthly
    volume_l: float


class UsageByRoom(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    room_id: int
    name: str
    volume_l: float


class UsageResponse(BaseModel):
    period: str  # "daily" | "monthly"
    series: List[UsageDataPoint] = []
    total_l: float
    average_l: float
    peak: Optional[UsageDataPoint] = None
    by_room: Optional[List[UsageByRoom]] = None

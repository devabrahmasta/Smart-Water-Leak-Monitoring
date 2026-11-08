"""
Pydantic Schemas untuk Perintah Kendali Valve (R-05).
"""

from enum import Enum
from typing import Optional
from pydantic import BaseModel, ConfigDict


class ValveActionEnum(str, Enum):
    OPEN = "OPEN"
    CLOSE = "CLOSE"


class ValveCommandCreateRequest(BaseModel):
    action: ValveActionEnum


class ValveCommandCreateResponse(BaseModel):
    command_id: int
    status: str = "PENDING"


class ValveCommandDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    room_id: int
    action: str
    source: str
    status: str
    created_at: str
    acked_at: Optional[str] = None


class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail

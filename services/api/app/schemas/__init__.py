"""
Pydantic Schemas Package untuk API REST Smart Water.
"""

from app.schemas.command import (
    ValveActionEnum,
    ValveCommandCreateRequest,
    ValveCommandCreateResponse,
    ValveCommandDetailResponse,
    ErrorDetail,
    ErrorResponse,
)
from app.schemas.alert import AlertDetailResponse, AlertListResponse
from app.schemas.summary import (
    LatestOpenAlertSummary,
    SummaryTally,
    SummaryResponse,
)
from app.schemas.room import (
    RoomStatusEnum,
    RoomListItem,
    RoomListResponse,
    RoomDetailResponse,
    RoomCommandsResponse,
)
from app.schemas.usage import (
    UsageDataPoint,
    UsageByRoom,
    UsageResponse,
)
from app.schemas.notification import PushTokenCreateRequest

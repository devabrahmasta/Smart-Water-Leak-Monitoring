"""
Pydantic Schemas untuk Pendaftaran Push Token FCM (R-07).
"""

from typing import Literal
from pydantic import BaseModel


class PushTokenCreateRequest(BaseModel):
    token: str
    platform: Literal["android", "ios"] = "android"

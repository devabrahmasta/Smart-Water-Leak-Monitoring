"""
Job deteksi perangkat offline (CONTRACT.md 2.8 & US-18).
Ambang batas: perangkat dianggap offline bila tidak ada pesan selama > 30 detik.
"""

import logging
from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy.orm import Session

from app.models.device import Device

logger = logging.getLogger(__name__)


def check_offline_devices(
    db: Session,
    timeout_seconds: float = 30.0,
    now_utc: Optional[datetime] = None,
) -> List[str]:
    """
    Mengidentifikasi perangkat yang sedang offline (tidak mengirim telemetri > 30 detik).
    Mengembalikan daftar device_id yang offline.
    """
    if now_utc is None:
        now_utc = datetime.now(timezone.utc)

    devices = db.query(Device).all()
    offline_device_ids: List[str] = []

    for device in devices:
        last_seen = device.last_seen_at
        if last_seen is None:
            offline_device_ids.append(device.id)
            continue

        if last_seen.tzinfo is None:
            last_seen = last_seen.replace(tzinfo=timezone.utc)

        idle_seconds = (now_utc - last_seen).total_seconds()
        if idle_seconds > timeout_seconds:
            offline_device_ids.append(device.id)

    return offline_device_ids


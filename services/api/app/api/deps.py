"""
FastAPI Dependencies: DB session, auth token verification, dan MQTT publisher (R-05).
"""

import json
import logging
from typing import Generator
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.config import settings
from app.database import SessionLocal

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)


def get_db() -> Generator[Session, None, None]:
    """Dependency untuk mendapatkan SQLAlchemy database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def verify_owner_token(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> str:
    """
    Dependency untuk memverifikasi token Bearer pemilik.
    Semua route kecuali /health menolak 401 tanpa token yang valid.
    """
    if not credentials or credentials.credentials != settings.API_OWNER_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "UNAUTHORIZED",
                "message": "Token autentikasi tidak valid atau tidak disertakan",
            },
        )
    return credentials.credentials


class RealMQTTPublisher:
    """Publisher pesan MQTT ke broker Mosquitto."""
    def __init__(self):
        self._client = None

    def _get_client(self):
        if self._client is None:
            from app.mqtt.client import create_mqtt_client
            self._client = create_mqtt_client(client_id="smartwater-api-publisher")
            try:
                self._client.connect(settings.MQTT_HOST, settings.MQTT_PORT, keepalive=60)
                self._client.loop_start()
            except Exception as e:
                logger.error(f"Gagal menghubungkan MQTT publisher ke broker: {e}")
        return self._client

    def publish(self, topic: str, payload: dict, qos: int = 1) -> bool:
        client = self._get_client()
        if not client:
            return False
        try:
            payload_bytes = json.dumps(payload).encode("utf-8")
            client.publish(topic, payload_bytes, qos=qos)
            return True
        except Exception as e:
            logger.error(f"Gagal publish ke {topic}: {e}")
            return False


_global_publisher = RealMQTTPublisher()


def get_mqtt_publisher():
    """Dependency untuk inject MQTT publisher (bisa di-override saat pengujian)."""
    return _global_publisher

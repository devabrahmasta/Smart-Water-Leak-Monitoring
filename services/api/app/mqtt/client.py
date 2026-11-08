"""
Paho MQTT Client untuk Ingest Worker dengan dukungan TLS v1.2/v1.3 dan auto-reconnect.
"""

import ssl
import logging
from pathlib import Path
from typing import Optional, Callable
import paho.mqtt.client as mqtt
from sqlalchemy.orm import Session

from app.config import settings, ROOT_DIR
from app.database import SessionLocal
from app.mqtt.handlers import route_mqtt_message

logger = logging.getLogger(__name__)

# Topik yang didengarkan oleh Ingest Worker
INGEST_TOPICS = [
    ("swm/+/telemetry", 1),
    ("swm/+/alert", 1),
    ("swm/+/status", 1),
]


def create_mqtt_client(
    client_id: str = "smartwater-backend-ingest",
    session_factory: Optional[Callable[[], Session]] = None,
) -> mqtt.Client:
    """
    Membuat dan mengonfigurasi instance Paho MQTT Client dengan kredensial & TLS.
    """
    if session_factory is None:
        session_factory = SessionLocal

    client = mqtt.Client(
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        client_id=client_id,
        clean_session=False,
    )

    # Otentikasi username & password
    if settings.MQTT_USERNAME and settings.MQTT_PASSWORD:
        client.username_pw_set(settings.MQTT_USERNAME, settings.MQTT_PASSWORD)

    # Konfigurasi TLS
    ca_path = Path(settings.MQTT_CA_CERT)
    if not ca_path.is_absolute():
        ca_path = ROOT_DIR / ca_path

    if ca_path.exists():
        client.tls_set(
            ca_certs=str(ca_path),
            cert_reqs=ssl.CERT_REQUIRED,
            tls_version=ssl.PROTOCOL_TLS_CLIENT,
        )
        logger.info(f"TLS dikonfigurasi dengan CA cert: {ca_path}")
    else:
        logger.warning(f"CA cert tidak ditemukan di {ca_path}, TLS tidak diaktifkan!")

    def on_connect(client_instance, userdata, flags, reason_code, properties):
        if reason_code == 0:
            logger.info("Berhasil terhubung ke MQTT Broker Mosquitto.")
            client_instance.subscribe(INGEST_TOPICS)
            logger.info(f"Berlangganan topik: {[t[0] for t in INGEST_TOPICS]}")
        else:
            logger.error(f"Gagal terhubung ke broker: reason_code={reason_code}")

    def on_disconnect(client_instance, userdata, flags, reason_code, properties):
        logger.warning(f"Terputus dari MQTT broker: reason_code={reason_code}")

    def on_message(client_instance, userdata, message):
        logger.debug(f"Pesan diterima pada topik: {message.topic} (QoS {message.qos})")
        db = session_factory()
        try:
            result = route_mqtt_message(db, message.topic, message.payload)
            if not result.success:
                logger.warning(f"Pesan pada '{message.topic}' gagal diproses: {result.error}")
            elif result.is_duplicate:
                logger.info(f"Pesan pada '{message.topic}' diabaikan: {result.message}")
        except Exception as e:
            logger.error(f"Error tidak terduga saat memproses pesan '{message.topic}': {e}", exc_info=True)
            db.rollback()
        finally:
            db.close()

    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message

    return client


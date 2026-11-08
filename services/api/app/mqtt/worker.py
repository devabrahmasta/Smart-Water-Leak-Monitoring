"""
Entrypoint untuk MQTT Ingestion Worker Process (R-03).
Dijalankan secara standalone via:
python -m app.mqtt.worker
"""

import sys
import signal
import logging
from pathlib import Path

# Pastikan services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from app.config import settings
from app.mqtt.client import create_mqtt_client

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
)
logger = logging.getLogger("mqtt_worker")


def main():
    logger.info("Memulai Smart Water MQTT Ingestion Worker...")
    logger.info(f"Broker: {settings.MQTT_HOST}:{settings.MQTT_PORT} (TLS)")

    client = create_mqtt_client()

    def shutdown_handler(signum, frame):
        logger.info(f"Menerima sinyal {signum}, mematikan MQTT Ingest Worker secara aman...")
        client.disconnect()
        client.loop_stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    try:
        client.connect(settings.MQTT_HOST, settings.MQTT_PORT, keepalive=60)
        logger.info("Memulai event loop MQTT...")
        client.loop_forever()
    except Exception as e:
        logger.critical(f"MQTT Ingest Worker berhenti karena galat: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()


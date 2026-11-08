"""
Konfigurasi Simulator Kamar Dummy (device_id=2).
"""

from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
ENV_FILE = ROOT_DIR / ".env"


class SimulatorSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_FILE if ENV_FILE.exists() else None,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Mosquitto Broker TLS
    MQTT_HOST: str = "localhost"
    MQTT_PORT: int = 8883
    MQTT_CA_CERT: str = "infra/mosquitto/certs/ca.crt"

    # Kredensial Simulator (Device 2)
    SIM_DEVICE_ID: str = "2"
    SIM_MQTT_USERNAME: str = "2"
    SIM_MQTT_PASSWORD: str = "sim_dev_pass"

    # Interval Telemetri (detik)
    TELEMETRY_INTERVAL_SEC: float = 10.0


settings = SimulatorSettings()


"""
Konfigurasi Simulator Kamar Dummy (Kamar 3 Mode demo, atau pengganti ESP32 saat uji).
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

    # Kredensial Simulator Kamar 3 (username = device_id "3")
    SIM3_MQTT_PASSWORD: str = "sim3_dev_pass"

    # Interval Telemetri (detik)
    TELEMETRY_INTERVAL_SEC: float = 10.0


def mqtt_credentials(device_id: str) -> tuple[str, str]:
    """Username dan password broker per perangkat simulator."""
    if device_id == "3":
        return "3", settings.SIM3_MQTT_PASSWORD
    if device_id == settings.SIM_DEVICE_ID:
        return settings.SIM_MQTT_USERNAME, settings.SIM_MQTT_PASSWORD
    return device_id, settings.SIM_MQTT_PASSWORD


settings = SimulatorSettings()


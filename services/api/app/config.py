from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

# Cari root repository (dua tingkat di atas services/api/app)
ROOT_DIR = Path(__file__).resolve().parent.parent.parent.parent
ENV_FILE = ROOT_DIR / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_FILE if ENV_FILE.exists() else None,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    DATABASE_URL: str = "postgresql+psycopg://smartwater:smartwater_secret@localhost:5433/smartwater"
    POSTGRES_USER: str = "smartwater"
    POSTGRES_PASSWORD: str = "smartwater_secret"
    POSTGRES_DB: str = "smartwater"
    POSTGRES_PORT: int = 5433

    # Mosquitto
    MQTT_HOST: str = "localhost"
    MQTT_PORT: int = 8883
    MQTT_USERNAME: str = "backend"
    MQTT_PASSWORD: str = "backend_dev_pass"
    MQTT_CA_CERT: str = "infra/mosquitto/certs/ca.crt"

    # REST API
    API_OWNER_TOKEN: str = "dev_owner_token_smartwater_2026"
    API_PORT: int = 8000
    TZ_DISPLAY: str = "Asia/Jakarta"

    # FCM
    FCM_PROJECT_ID: str = "smartwater-demo"
    FCM_SERVICE_ACCOUNT_PATH: str = "services/api/service-account.json"

    # Simulator
    SIM_DEVICE_ID: str = "2"
    SIM_MQTT_USERNAME: str = "2"
    SIM_MQTT_PASSWORD: str = "sim_dev_pass"


settings = Settings()

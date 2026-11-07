# services/api

FastAPI + worker MQTT + APScheduler dalam satu proses (PRD 4.1, keputusan 2).

**Pemilik:** Backend. **Langkah:** R-02, R-03, R-05 s.d. R-08.

```
app/
├── api/v1/    router REST (CONTRACT.md bagian 3)
├── mqtt/      ingest telemetry/alert/status, kirim cmd, terima ack
├── jobs/      agregasi harian/bulanan, anomali, deteksi offline, timeout perintah
├── rules/     logika anomali sebagai fungsi murni (diuji unit test)
├── notify/    FCM HTTP v1 + retry
├── models/    SQLAlchemy (PRD 4.3)
└── schemas/   Pydantic, sumber openapi.json
migrations/    Alembic
tests/
```

Stack: Python 3.12, FastAPI, SQLAlchemy 2, Alembic, Pydantic v2, paho-mqtt, APScheduler.

## Mulai

1. Buat `pyproject.toml` (atau `requirements.txt`) dengan stack di atas.
2. `make dev` dari root untuk Postgres + Mosquitto.
3. Ikuti kriteria selesai R-02 di PRD 5.2.

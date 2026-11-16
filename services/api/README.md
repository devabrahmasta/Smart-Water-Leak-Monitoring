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

1. Buat virtual environment dan instal dependensi:
   ```bash
   uv pip install -r requirements.txt
   ```
2. Jalankan database & broker MQTT dari root:
   ```bash
   make dev
   ```
3. Migrasi database:
   ```bash
   alembic upgrade head
   python -m app.seed
   ```
4. Menjalankan REST API Server (beserta APScheduler lifespan):
   ```bash
   uvicorn app.main:app --reload --port 8000
   ```
   > **Catatan Background Jobs (R-06):**
   > Secara default, `ENABLE_SCHEDULER=True` di mana FastAPI lifespan akan otomatis menyalakan APScheduler dengan 4 background jobs:
   > - **Agregasi Berjalan (Tiap 5 menit):** menghitung total liter hari berjalan (WIB) & bulan berjalan.
   > - **Penutupan Hari (Setiap 00:10 WIB):** rekonsiliasi final penggunaan air hari kemarin.
   > - **Deteksi Anomali Pemakaian (Tiap 1 jam):** mengevaluasi rasio pemakaian vs rata-rata 7 hari sebelumnya (>1,5x).
   > - **Pengecekan Timeout & Offline (Tiap 5 detik):** mendeteksi perintah valve yang kedaluwarsa (>15 detik) dan menandai status kamar offline jika idle >30 detik.
   >
   > Untuk mematikan scheduler saat pengujian atau debugging terisolasi, set environment variable:
   > ```bash
   > export ENABLE_SCHEDULER=False   # Linux / macOS
   > $env:ENABLE_SCHEDULER="False"    # PowerShell
   > ```

5. Menjalankan Worker MQTT Ingestion (secara terpisah):
   ```bash
   python -m app.mqtt.worker
   ```

## Pengujian (Tests)

Jalankan seluruh rangkaian test API:
```bash
pytest services/api/tests/ -v
```

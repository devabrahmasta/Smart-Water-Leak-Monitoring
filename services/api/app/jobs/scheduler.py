"""
APScheduler untuk orkestrasi background jobs pada Smart Water Backend (R-06).
Menjadwalkan:
- Agregasi harian berjalan tiap 5 menit (US-15)
- Penutupan hari sebelumnya tiap pukul 00:10 WIB (US-15)
- Deteksi anomali tiap 1 jam (US-16)
- Pengecekan timeout perintah tiap 5 detik (R-05)
- Pengecekan perangkat offline tiap 10 detik (US-18)
"""

import logging
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger

from app.database import SessionLocal
from app.jobs.aggregation import aggregate_daily_usage, aggregate_monthly_usage
from app.jobs.anomaly import run_anomaly_detection
from app.jobs.offline import check_offline_devices
from app.jobs.timeouts import expire_stale_commands

logger = logging.getLogger("scheduler")

scheduler = BackgroundScheduler()


def _job_daily_aggregation():
    """Job agregasi harian berjalan tiap 5 menit."""
    db = SessionLocal()
    try:
        aggregate_daily_usage(db)
        aggregate_monthly_usage(db)
    except Exception as e:
        logger.error(f"Galat pada job agregasi berkala: {e}")
    finally:
        db.close()


def _job_midnight_day_close():
    """Job penutupan hari kemarin yang dijalankan pukul 00:10 WIB."""
    db = SessionLocal()
    try:
        now_wib = datetime.now(timezone.utc).astimezone(ZoneInfo("Asia/Jakarta"))
        yesterday_wib = (now_wib - timedelta(days=1)).date()
        logger.info(f"Menjalankan penutupan hari untuk tanggal {yesterday_wib} WIB...")
        aggregate_daily_usage(db, target_date=yesterday_wib)
        aggregate_monthly_usage(db)
    except Exception as e:
        logger.error(f"Galat pada job penutupan hari: {e}")
    finally:
        db.close()


def _job_hourly_anomaly():
    """Job deteksi anomali pemakaian air berjalan tiap 1 jam."""
    db = SessionLocal()
    try:
        run_anomaly_detection(db)
    except Exception as e:
        logger.error(f"Galat pada job deteksi anomali: {e}")
    finally:
        db.close()


def _job_frequent_checks():
    """Job pengecekan offline (10s) dan timeout perintah (5s)."""
    db = SessionLocal()
    try:
        expire_stale_commands(db, timeout_seconds=15.0)
        check_offline_devices(db, timeout_seconds=30.0)
    except Exception as e:
        logger.error(f"Galat pada job frequent checks: {e}")
    finally:
        db.close()


def setup_jobs(sched: BackgroundScheduler):
    """Mendaftarkan seluruh trigger ke scheduler."""
    # 1. Agregasi harian tiap 5 menit
    sched.add_job(
        _job_daily_aggregation,
        trigger=IntervalTrigger(minutes=5),
        id="job_daily_aggregation",
        replace_existing=True,
    )

    # 2. Penutupan hari kemarin pukul 00:10 WIB
    sched.add_job(
        _job_midnight_day_close,
        trigger=CronTrigger(hour=0, minute=10, timezone=ZoneInfo("Asia/Jakarta")),
        id="job_midnight_day_close",
        replace_existing=True,
    )

    # 3. Deteksi anomali tiap 1 jam
    sched.add_job(
        _job_hourly_anomaly,
        trigger=IntervalTrigger(hours=1),
        id="job_hourly_anomaly",
        replace_existing=True,
    )

    # 4. Pengecekan timeout perintah & offline tiap 5 detik
    sched.add_job(
        _job_frequent_checks,
        trigger=IntervalTrigger(seconds=5),
        id="job_frequent_checks",
        replace_existing=True,
    )


def start_scheduler():
    """Memulai background scheduler jika belum berjalan."""
    if not scheduler.running:
        setup_jobs(scheduler)
        scheduler.start()
        logger.info("APScheduler berhasil dimulai (4 background jobs terdaftar).")


def stop_scheduler():
    """Menghentikan background scheduler secara aman."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("APScheduler dihentikan.")


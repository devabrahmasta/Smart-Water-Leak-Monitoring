"""
Job deteksi anomali pemakaian air harian di server (US-16 & US-13).
Aturan:
- Membandingkan pemakaian hari ini dengan rata-rata historis (default: 7 hari).
- Anomali jika: hari ini > 1.5x rata-rata historis.
- Membutuhkan minimal 3 hari data historis sebelum aktif.
- Dibatasi maksimal 1 alert anomali per kamar per hari (US-13).
"""

import logging
from datetime import datetime, date, timezone, timedelta
from zoneinfo import ZoneInfo
from typing import Optional, List
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.usage import DailyUsage
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus
from app.models.rule_param import RuleParam
from app.rules.anomaly import evaluate_daily_anomaly
from app.notify.dispatcher import dispatch_alert_notification

logger = logging.getLogger(__name__)


def run_anomaly_detection(
    db: Session,
    target_date: Optional[date] = None,
    tz_name: str = "Asia/Jakarta",
) -> List[Alert]:
    """
    Menjalankan pemeriksaan deteksi anomali untuk semua kamar:
    - Mengambil parameter aturan dari rule_params jika ada (anomaly_ratio, anomaly_window_days).
    - Memeriksa pemakaian hari ini terhadap rata-rata historis.
    - Menerbitkan Alert ANOMALY (status OPEN) jika terdeteksi dan belum pernah diterbitkan hari ini.
    """
    wib_tz = ZoneInfo(tz_name)
    if target_date is None:
        now_wib = datetime.now(timezone.utc).astimezone(wib_tz)
        target_date = now_wib.date()

    # Ambil parameter ambang batas dari database jika ada, atau gunakan default
    ratio_param = db.query(RuleParam).filter_by(key="anomaly_ratio").first()
    ratio_threshold = ratio_param.as_float(1.5) if ratio_param else 1.5

    window_param = db.query(RuleParam).filter_by(key="anomaly_window_days").first()
    window_days = window_param.as_int(7) if window_param else 7

    rooms = db.query(Room).all()
    created_alerts: List[Alert] = []
    now_utc = datetime.now(timezone.utc)

    for room in rooms:
        # 1. Ambil pemakaian hari ini
        today_usage = (
            db.query(DailyUsage)
            .filter_by(room_id=room.id, date=target_date)
            .first()
        )
        if not today_usage or today_usage.volume_l <= 0.0:
            continue

        # 2. Ambil data historis jendela hari sebelumnya
        start_date = target_date - timedelta(days=window_days)
        history_records = (
            db.query(DailyUsage)
            .filter(
                DailyUsage.room_id == room.id,
                DailyUsage.date >= start_date,
                DailyUsage.date < target_date,
            )
            .all()
        )

        history_volumes = [h.volume_l for h in history_records]

        # 3. Evaluasi anomali via fungsi murni
        is_anomaly, ratio, avg_daily = evaluate_daily_anomaly(
            today_volume=today_usage.volume_l,
            history_volumes=history_volumes,
            ratio_threshold=ratio_threshold,
            min_history_days=3,
        )

        if not is_anomaly:
            continue

        # 4. Pastikan maksimal 1 alert anomali per kamar per hari (US-13)
        existing_alerts = (
            db.query(Alert)
            .filter(
                Alert.room_id == room.id,
                Alert.type == AlertType.ANOMALY,
            )
            .all()
        )

        already_alerted_today = False
        target_date_str = target_date.isoformat()
        for a in existing_alerts:
            # Cek tanggal dari detail atau waktu pembuatan (WIB)
            detail_date = (a.detail or {}).get("date")
            if detail_date == target_date_str:
                already_alerted_today = True
                break

            ca = a.created_at
            if ca is not None:
                if ca.tzinfo is None:
                    ca = ca.replace(tzinfo=timezone.utc)
                if ca.astimezone(wib_tz).date() == target_date:
                    already_alerted_today = True
                    break

        if already_alerted_today:
            logger.debug(f"Alert anomali untuk Kamar {room.id} sudah pernah diterbitkan hari ini ({target_date}).")
            continue

        # 5. Terbitkan alert ANOMALY baru
        new_alert = Alert(
            room_id=room.id,
            type=AlertType.ANOMALY,
            rule=AlertRule.DAILY_RATIO,
            status=AlertStatus.OPEN,
            created_at=now_utc,
            detail={
                "date": target_date_str,
                "today_l": today_usage.volume_l,
                "avg_daily_l": avg_daily,
                "ratio": ratio,
                "window_days": window_days,
            },
        )
        db.add(new_alert)
        created_alerts.append(new_alert)
        logger.warning(
            f"ANOMALI TERDETEKSI: {room.name} pemakaian {today_usage.volume_l}L = {ratio}x rata-rata ({avg_daily}L)!"
        )

    if created_alerts:
        try:
            db.commit()
            for alert in created_alerts:
                db.refresh(alert)
                try:
                    dispatch_alert_notification(db, alert)
                except Exception as notify_err:
                    logger.error(f"Gagal mengirim notifikasi anomali alert {alert.id}: {notify_err}")
        except Exception as e:
            db.rollback()
            logger.error(f"Gagal menyimpan alert anomali: {e}")
            return []

    return created_alerts

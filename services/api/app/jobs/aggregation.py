"""
Job agregasi pemakaian air harian dan bulanan (US-15).
Aturan:
- Batas hari dihitung berdasarkan WIB (Asia/Jakarta).
- Idempoten: melakukan upsert pada daily_usage dan monthly_usage.
- Memenuhi KPI K5: selisih rekap harian vs volume mentah <= 1%.
"""

import logging
from datetime import datetime, date, timezone
from zoneinfo import ZoneInfo
from typing import Optional
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.telemetry import Telemetry
from app.models.usage import DailyUsage, MonthlyUsage

logger = logging.getLogger(__name__)


def aggregate_daily_usage(
    db: Session,
    target_date: Optional[date] = None,
    tz_name: str = "Asia/Jakarta",
) -> int:
    """
    Merangkum volume per kamar untuk tanggal WIB tertentu (atau hari ini jika None).
    Menghitung total liter (sum volume_l_delta) dan debit puncak (max flow_lpm).
    Melakukan upsert idempoten ke tabel daily_usage.
    """
    wib_tz = ZoneInfo(tz_name)
    if target_date is None:
        now_wib = datetime.now(timezone.utc).astimezone(wib_tz)
        target_date = now_wib.date()

    rooms = db.query(Room).all()
    updated_count = 0

    for room in rooms:
        device = room.device
        if not device:
            continue

        telemetries = (
            db.query(Telemetry)
            .filter(Telemetry.device_id == device.id)
            .all()
        )

        # Kelompokkan telemetri berdasarkan tanggal WIB
        day_records = []
        for t in telemetries:
            ts = t.device_ts or t.received_at
            if ts is not None:
                if ts.tzinfo is None:
                    ts = ts.replace(tzinfo=timezone.utc)
                ts_wib = ts.astimezone(wib_tz)
                if ts_wib.date() == target_date:
                    day_records.append(t)

        if not day_records:
            continue

        total_volume = round(sum(t.volume_l_delta for t in day_records), 2)
        peak_flow = round(max(t.flow_lpm for t in day_records), 2)

        # Upsert ke daily_usage
        existing = (
            db.query(DailyUsage)
            .filter_by(room_id=room.id, date=target_date)
            .first()
        )
        if existing:
            existing.volume_l = total_volume
            existing.peak_flow_lpm = peak_flow
        else:
            new_record = DailyUsage(
                room_id=room.id,
                date=target_date,
                volume_l=total_volume,
                peak_flow_lpm=peak_flow,
            )
            db.add(new_record)

        updated_count += 1

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Gagal commit agregasi harian untuk tanggal {target_date}: {e}")
        return 0

    logger.info(f"Agregasi harian selesai untuk tanggal {target_date}: {updated_count} kamar diperbarui.")
    return updated_count


def aggregate_monthly_usage(
    db: Session,
    target_month: Optional[str] = None,
    tz_name: str = "Asia/Jakarta",
) -> int:
    """
    Merangkum total pemakaian bulanan per kamar dari daily_usage untuk bulan target (format 'YYYY-MM').
    Melakukan upsert idempoten ke tabel monthly_usage.
    """
    wib_tz = ZoneInfo(tz_name)
    if target_month is None:
        now_wib = datetime.now(timezone.utc).astimezone(wib_tz)
        target_month = now_wib.strftime("%Y-%m")

    rooms = db.query(Room).all()
    updated_count = 0

    for room in rooms:
        daily_records = (
            db.query(DailyUsage)
            .filter_by(room_id=room.id)
            .all()
        )

        month_records = [
            d for d in daily_records if d.date.strftime("%Y-%m") == target_month
        ]
        if not month_records:
            continue

        month_total = round(sum(d.volume_l for d in month_records), 2)

        existing = (
            db.query(MonthlyUsage)
            .filter_by(room_id=room.id, month=target_month)
            .first()
        )
        if existing:
            existing.volume_l = month_total
        else:
            new_month = MonthlyUsage(
                room_id=room.id,
                month=target_month,
                volume_l=month_total,
            )
            db.add(new_month)

        updated_count += 1

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Gagal commit agregasi bulanan untuk bulan {target_month}: {e}")
        return 0

    logger.info(f"Agregasi bulanan selesai untuk bulan {target_month}: {updated_count} kamar diperbarui.")
    return updated_count


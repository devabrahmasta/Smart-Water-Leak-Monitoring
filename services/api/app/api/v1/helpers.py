"""
Helper utilities untuk REST API v1 Smart Water (R-07).
Menghitung status kamar, konsumsi hari ini (WIB), dan konversi datetime UTC.
"""

from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, date, timezone
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.telemetry import Telemetry
from app.models.usage import DailyUsage, MonthlyUsage
from app.models.alert import Alert, AlertType, AlertStatus
from app.schemas.room import RoomStatusEnum, RoomListItem

WIB_TZ = ZoneInfo("Asia/Jakarta")


def _ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def format_iso_utc(dt: Optional[datetime]) -> Optional[str]:
    if dt is None:
        return None
    utc_dt = _ensure_utc(dt)
    return utc_dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def get_current_wib_date(now_utc: Optional[datetime] = None) -> date:
    if now_utc is None:
        now_utc = datetime.now(timezone.utc)
    else:
        now_utc = _ensure_utc(now_utc)
    return now_utc.astimezone(WIB_TZ).date()


def get_wib_date_utc_range(target_date: date) -> Tuple[datetime, datetime]:
    start_wib = datetime(target_date.year, target_date.month, target_date.day, 0, 0, 0, tzinfo=WIB_TZ)
    start_utc = start_wib.astimezone(timezone.utc)
    end_utc = datetime.fromtimestamp(start_utc.timestamp() + 86400, tz=timezone.utc)
    return start_utc, end_utc


def get_all_rooms_metrics(
    db: Session,
    now_utc: Optional[datetime] = None,
    offline_threshold_seconds: float = 30.0,
) -> List[RoomListItem]:
    """
    Menghitung status, hari ini liter, flow_lpm, dan is_highest untuk setiap kamar.
    Aturan CONTRACT.md:
    - OFFLINE jika device last_seen_at kosong atau > 30 detik.
    - Kamar OFFLINE: today_l dan flow_lpm bernilai None (null).
    - LEAK jika online dan ada alert LEAK dengan status OPEN.
    - CLOSED jika online, tidak bocor, tapi valve CLOSED.
    - NORMAL jika online, tidak bocor, valve OPEN.
    - is_highest bernilai True untuk kamar dengan today_l tertinggi (jika > 0).
    """
    if now_utc is None:
        now_utc = datetime.now(timezone.utc)
    else:
        now_utc = _ensure_utc(now_utc)

    today_wib = get_current_wib_date(now_utc)
    start_utc, end_utc = get_wib_date_utc_range(today_wib)

    rooms = db.query(Room).order_by(Room.sort_order.asc(), Room.id.asc()).all()

    # Ambil open leak alert per room
    open_leaks = (
        db.query(Alert.room_id)
        .filter(Alert.type == AlertType.LEAK, Alert.status == AlertStatus.OPEN)
        .distinct()
        .all()
    )
    open_leak_room_ids = {r[0] for r in open_leaks}

    # Ambil daily_usage hari ini jika sudah diagregasi
    daily_usages = db.query(DailyUsage).filter(DailyUsage.date == today_wib).all()
    usage_by_room = {u.room_id: round(float(u.volume_l), 2) for u in daily_usages}

    result_items: List[RoomListItem] = []
    room_today_volumes: Dict[int, float] = {}

    for room in rooms:
        device = db.query(Device).filter(Device.room_id == room.id).first()
        is_offline = True
        valve_str = "CLOSED"
        last_seen_str = None
        flow_lpm = None

        if device:
            valve_str = device.valve_state.value if hasattr(device.valve_state, "value") else str(device.valve_state)
            if device.last_seen_at:
                dev_last_seen = _ensure_utc(device.last_seen_at)
                last_seen_str = format_iso_utc(dev_last_seen)
                diff = (now_utc - dev_last_seen).total_seconds()
                if diff <= offline_threshold_seconds:
                    is_offline = False

            # Ambil latest telemetry untuk flow_lpm
            latest_telem = (
                db.query(Telemetry)
                .filter(Telemetry.device_id == device.id)
                .order_by(Telemetry.id.desc())
                .first()
            )
            if latest_telem:
                flow_lpm = round(float(latest_telem.flow_lpm), 2)
            else:
                flow_lpm = 0.0

        # Tentukan status kamar
        if is_offline:
            status = RoomStatusEnum.OFFLINE
            today_l = None
            flow_lpm = None
        elif room.id in open_leak_room_ids:
            status = RoomStatusEnum.LEAK
        elif valve_str == "CLOSED":
            status = RoomStatusEnum.CLOSED
        else:
            status = RoomStatusEnum.NORMAL

        if not is_offline:
            # Hitung today_l: gunakan DailyUsage jika ada, atau hitung langsung dari telemetri hari ini
            if room.id in usage_by_room:
                today_l = usage_by_room[room.id]
            else:
                if device:
                    sum_delta = (
                        db.query(func.coalesce(func.sum(Telemetry.volume_l_delta), 0.0))
                        .filter(
                            Telemetry.device_id == device.id,
                            Telemetry.received_at >= start_utc,
                            Telemetry.received_at < end_utc,
                        )
                        .scalar()
                    )
                    today_l = round(float(sum_delta), 2)
                else:
                    today_l = 0.0
            room_today_volumes[room.id] = today_l

        item = RoomListItem(
            id=room.id,
            name=room.name,
            status=status,
            valve=valve_str,
            today_l=today_l,
            flow_lpm=flow_lpm,
            is_highest=False,  # diisi pada second pass
            last_seen_at=last_seen_str,
        )
        result_items.append(item)

    # Tentukan kamar dengan today_l tertinggi (jika > 0)
    if room_today_volumes:
        max_vol = max(room_today_volumes.values())
        if max_vol > 0:
            for item in result_items:
                if item.today_l is not None and item.today_l == max_vol:
                    item.is_highest = True
                    break

    return result_items

"""
REST API Router untuk Kamar (Rooms) dan Detail Kamar (R-07).
Endpoints:
- GET /v1/rooms
- GET /v1/rooms/{room_id}
- GET /v1/rooms/{room_id}/commands
- GET /v1/rooms/{room_id}/usage
"""

from typing import Optional, List
from datetime import datetime, date, timedelta, timezone
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.api.deps import get_db, verify_owner_token
from app.api.v1.helpers import (
    get_all_rooms_metrics,
    get_current_wib_date,
    format_iso_utc,
)
from app.models.room import Room
from app.models.usage import DailyUsage, MonthlyUsage
from app.models.alert import Alert
from app.models.command import ValveCommand
from app.schemas.room import (
    RoomListResponse,
    RoomDetailResponse,
    RoomCommandsResponse,
    RoomStatusEnum,
)
from app.schemas.alert import AlertDetailResponse
from app.schemas.command import ValveCommandDetailResponse
from app.schemas.usage import UsageResponse

router = APIRouter(prefix="/v1/rooms", tags=["Rooms"])


@router.get(
    "",
    response_model=RoomListResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Daftar kamar kos dengan status dan volume hari ini",
)
def get_rooms(
    filter: str = Query("all", description="Filter kamar: all | attention | offline"),
    db: Session = Depends(get_db),
):
    """
    Mengembalikan daftar seluruh kamar kos:
    - filter=all: seluruh kamar
    - filter=attention: kamar bocor (LEAK), offline (OFFLINE), atau tertutup (CLOSED)
    - filter=offline: hanya kamar yang sedang offline (> 30s)
    """
    rooms_metrics = get_all_rooms_metrics(db)

    if filter == "attention":
        filtered = [
            rm for rm in rooms_metrics
            if rm.status in (RoomStatusEnum.LEAK, RoomStatusEnum.OFFLINE, RoomStatusEnum.CLOSED)
        ]
    elif filter == "offline":
        filtered = [rm for rm in rooms_metrics if rm.status == RoomStatusEnum.OFFLINE]
    else:
        filtered = rooms_metrics

    return RoomListResponse(rooms=filtered)


@router.get(
    "/{room_id}",
    response_model=RoomDetailResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Detail satu kamar kos beserta metrik dan 3 alert terakhir",
)
def get_room_detail(room_id: int, db: Session = Depends(get_db)):
    """Mengembalikan detail satu kamar, volume bulan berjalan, rata-rata harian, dan 3 alert terkini."""
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": f"Kamar dengan ID {room_id} tidak ditemukan"},
        )

    rooms_metrics = get_all_rooms_metrics(db)
    matched_room = next((rm for rm in rooms_metrics if rm.id == room_id), None)
    if not matched_room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": f"Kamar dengan ID {room_id} tidak ditemukan"},
        )

    now_utc = datetime.now(timezone.utc)
    today_wib = get_current_wib_date(now_utc)
    current_month_str = today_wib.strftime("%Y-%m")

    # Volume bulan ini untuk kamar ini
    month_usage = (
        db.query(MonthlyUsage)
        .filter(MonthlyUsage.room_id == room_id, MonthlyUsage.month == current_month_str)
        .first()
    )
    month_l = float(month_usage.volume_l) if month_usage else 0.0

    # Rata-rata harian (jendela 7 hari terakhir dari daily_usage)
    start_7d = today_wib - timedelta(days=7)
    past_days = (
        db.query(DailyUsage.volume_l)
        .filter(DailyUsage.room_id == room_id, DailyUsage.date >= start_7d, DailyUsage.date < today_wib)
        .all()
    )
    if past_days:
        avg_daily_l = round(sum(float(p[0]) for p in past_days) / len(past_days), 1)
    else:
        avg_daily_l = round(matched_room.today_l or 0.0, 1)

    # 3 Alert terakhir untuk kamar ini
    recent_alerts_orm = (
        db.query(Alert)
        .filter(Alert.room_id == room_id)
        .order_by(Alert.id.desc())
        .limit(3)
        .all()
    )
    recent_alerts: List[AlertDetailResponse] = []
    for a in recent_alerts_orm:
        recent_alerts.append(
            AlertDetailResponse(
                id=a.id,
                room_id=a.room_id,
                room_name=room.name,
                type=a.type.value if hasattr(a.type, "value") else str(a.type),
                rule=a.rule.value if hasattr(a.rule, "value") else str(a.rule),
                status=a.status.value if hasattr(a.status, "value") else str(a.status),
                created_at=format_iso_utc(a.created_at) or "",
                resolved_at=format_iso_utc(a.resolved_at),
                resolved_by=a.resolved_by.value if hasattr(a.resolved_by, "value") and a.resolved_by else (str(a.resolved_by) if a.resolved_by else None),
                detail=a.detail,
            )
        )

    return RoomDetailResponse(
        room=matched_room,
        month_l=round(month_l, 1),
        avg_daily_l=avg_daily_l,
        recent_alerts=recent_alerts,
    )


@router.get(
    "/{room_id}/commands",
    response_model=RoomCommandsResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Riwayat perintah kendali valve kamar",
)
def get_room_commands(
    room_id: int,
    limit: int = Query(10, ge=1, le=50, description="Batas maksimal riwayat"),
    db: Session = Depends(get_db),
):
    """Mengambil riwayat perintah buka/tutup valve untuk kamar tertentu."""
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": f"Kamar dengan ID {room_id} tidak ditemukan"},
        )

    commands_orm = (
        db.query(ValveCommand)
        .filter(ValveCommand.room_id == room_id)
        .order_by(ValveCommand.id.desc())
        .limit(limit)
        .all()
    )

    result_cmds: List[ValveCommandDetailResponse] = []
    for c in commands_orm:
        result_cmds.append(
            ValveCommandDetailResponse(
                id=c.id,
                room_id=c.room_id,
                action=c.action.value if hasattr(c.action, "value") else str(c.action),
                source=c.source.value if hasattr(c.source, "value") else str(c.source),
                status=c.status.value if hasattr(c.status, "value") else str(c.status),
                created_at=format_iso_utc(c.created_at) or "",
                acked_at=format_iso_utc(c.acked_at),
            )
        )

    return RoomCommandsResponse(commands=result_cmds)


@router.get(
    "/{room_id}/usage",
    response_model=UsageResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Data grafik penggunaan air per kamar",
)
def get_room_usage(
    room_id: int,
    period: str = Query("daily", description="Periode grafik: daily | monthly"),
    db: Session = Depends(get_db),
):
    """Alias langsung ke router /v1/usage dengan parameter room_id."""
    from app.api.v1.usage import fetch_usage_data
    return fetch_usage_data(db=db, period=period, room_id=room_id)

"""
REST API Router untuk Seri Grafik Penggunaan Air (R-07).
Endpoint: GET /v1/usage
"""

from typing import Optional, List, Dict
from datetime import datetime, date, timedelta, timezone
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.api.deps import get_db, verify_owner_token
from app.api.v1.helpers import get_current_wib_date
from app.models.room import Room
from app.models.usage import DailyUsage, MonthlyUsage
from app.schemas.usage import (
    UsageResponse,
    UsageDataPoint,
    UsageByRoom,
)

router = APIRouter(prefix="/v1", tags=["Usage"])


def fetch_usage_data(
    db: Session,
    period: str = "daily",
    room_id: Optional[int] = None,
) -> UsageResponse:
    """Helper fungsi untuk mengambil dan mengagregasi data grafik daily maupun monthly."""
    if period not in ("daily", "monthly"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_PAYLOAD", "message": "Periode harus bernilai 'daily' atau 'monthly'"},
        )

    if room_id is not None:
        room = db.query(Room).filter(Room.id == room_id).first()
        if not room:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"code": "NOT_FOUND", "message": f"Kamar dengan ID {room_id} tidak ditemukan"},
            )

    series: List[UsageDataPoint] = []
    by_room: Optional[List[UsageByRoom]] = None

    if period == "daily":
        now_utc = datetime.now(timezone.utc)
        today_wib = get_current_wib_date(now_utc)
        start_date = today_wib - timedelta(days=29)  # Ambil hingga 30 hari terakhir

        query = db.query(DailyUsage.date, func.sum(DailyUsage.volume_l).label("vol"))
        if room_id is not None:
            query = query.filter(DailyUsage.room_id == room_id)
        query = query.filter(DailyUsage.date >= start_date).group_by(DailyUsage.date).order_by(DailyUsage.date.asc())
        rows = query.all()

        for r in rows:
            series.append(UsageDataPoint(label=r.date.isoformat(), volume_l=round(float(r.vol), 1)))

        # Jika seluruh kamar (room_id is None), hitung rincian by_room
        if room_id is None:
            by_room = []
            rooms = db.query(Room).order_by(Room.sort_order.asc(), Room.id.asc()).all()
            for rm in rooms:
                vol_sum = (
                    db.query(func.coalesce(func.sum(DailyUsage.volume_l), 0.0))
                    .filter(DailyUsage.room_id == rm.id, DailyUsage.date >= start_date)
                    .scalar()
                )
                by_room.append(UsageByRoom(room_id=rm.id, name=rm.name, volume_l=round(float(vol_sum), 1)))

    else:  # monthly
        query = db.query(MonthlyUsage.month, func.sum(MonthlyUsage.volume_l).label("vol"))
        if room_id is not None:
            query = query.filter(MonthlyUsage.room_id == room_id)
        query = query.group_by(MonthlyUsage.month).order_by(MonthlyUsage.month.asc())
        rows = query.all()

        for r in rows:
            series.append(UsageDataPoint(label=r.month, volume_l=round(float(r.vol), 1)))

        if room_id is None:
            by_room = []
            rooms = db.query(Room).order_by(Room.sort_order.asc(), Room.id.asc()).all()
            for rm in rooms:
                vol_sum = (
                    db.query(func.coalesce(func.sum(MonthlyUsage.volume_l), 0.0))
                    .filter(MonthlyUsage.room_id == rm.id)
                    .scalar()
                )
                by_room.append(UsageByRoom(room_id=rm.id, name=rm.name, volume_l=round(float(vol_sum), 1)))

    total_l = round(sum(dp.volume_l for dp in series), 1)
    average_l = round(total_l / len(series), 1) if series else 0.0

    peak: Optional[UsageDataPoint] = None
    if series:
        max_dp = max(series, key=lambda x: x.volume_l)
        if max_dp.volume_l > 0:
            peak = max_dp

    return UsageResponse(
        period=period,
        series=series,
        total_l=total_l,
        average_l=average_l,
        peak=peak,
        by_room=by_room,
    )


@router.get(
    "/usage",
    response_model=UsageResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Data seri grafik pemakaian air kos atau kamar",
)
def get_usage(
    period: str = Query("daily", description="Periode grafik: daily | monthly"),
    room_id: Optional[int] = Query(None, description="Filter kamar tertentu (opsional)"),
    db: Session = Depends(get_db),
):
    """Mengembalikan data deret grafik harian atau bulanan beserta total, rata-rata, puncak, dan distribusi kamar."""
    return fetch_usage_data(db=db, period=period, room_id=room_id)

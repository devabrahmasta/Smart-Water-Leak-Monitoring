"""
REST API Router untuk Summary Dashboard (R-07).
Endpoint: GET /v1/summary
"""

from typing import List
from datetime import datetime, date, timedelta, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.api.deps import get_db, verify_owner_token
from app.api.v1.helpers import (
    get_all_rooms_metrics,
    get_current_wib_date,
    format_iso_utc,
)
from app.models.usage import DailyUsage, MonthlyUsage
from app.models.alert import Alert, AlertStatus
from app.schemas.summary import (
    SummaryResponse,
    SummaryTally,
    LatestOpenAlertSummary,
)
from app.schemas.room import RoomStatusEnum

router = APIRouter(prefix="/v1", tags=["Summary"])


@router.get(
    "/summary",
    response_model=SummaryResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Ringkasan pemantauan air kos (Beranda)",
)
def get_summary(db: Session = Depends(get_db)):
    """
    Mengembalikan data agregasi ringkasan dashboard:
    - today_l: total liter hari ini (WIB)
    - month_l: total liter bulan berjalan
    - last_7_days_end: tanggal hari ini WIB
    - last_7_days_l: deret volume 7 hari terakhir
    - tally: jumlah kamar normal, closed, offline, leak
    - open_alert_count: jumlah alert berstatus OPEN
    - latest_open_alert: alert OPEN terbaru
    """
    now_utc = datetime.now(timezone.utc)
    today_wib = get_current_wib_date(now_utc)
    current_month_str = today_wib.strftime("%Y-%m")

    # 1. Metrik Kamar & Tally
    rooms_metrics = get_all_rooms_metrics(db, now_utc=now_utc)
    tally = SummaryTally(normal=0, closed=0, offline=0, leak=0)
    for rm in rooms_metrics:
        if rm.status == RoomStatusEnum.NORMAL:
            tally.normal += 1
        elif rm.status == RoomStatusEnum.CLOSED:
            tally.closed += 1
        elif rm.status == RoomStatusEnum.OFFLINE:
            tally.offline += 1
        elif rm.status == RoomStatusEnum.LEAK:
            tally.leak = (tally.leak or 0) + 1

    # 2. Total hari ini (sum dari DailyUsage hari ini)
    today_sum = (
        db.query(func.coalesce(func.sum(DailyUsage.volume_l), 0.0))
        .filter(DailyUsage.date == today_wib)
        .scalar()
    )
    # Jika belum ada daily_usage, jumlahkan dari today_l kamar aktif
    if float(today_sum) == 0.0:
        today_l_val = round(sum(rm.today_l for rm in rooms_metrics if rm.today_l is not None), 2)
    else:
        today_l_val = round(float(today_sum), 2)

    # 3. Total bulan ini (sum dari MonthlyUsage bulan ini, atau sum DailyUsage bulan ini)
    month_sum = (
        db.query(func.coalesce(func.sum(MonthlyUsage.volume_l), 0.0))
        .filter(MonthlyUsage.month == current_month_str)
        .scalar()
    )
    if float(month_sum) == 0.0:
        # Fallback sum daily_usage bulan ini
        month_sum = (
            db.query(func.coalesce(func.sum(DailyUsage.volume_l), 0.0))
            .filter(func.to_char(DailyUsage.date, "YYYY-MM") == current_month_str if db.bind.dialect.name == "postgresql" else DailyUsage.date >= date(today_wib.year, today_wib.month, 1))
            .scalar()
        )
    month_l_val = round(float(month_sum), 2)
    # Pastikan month_l setidaknya mencakup today_l jika today_l lebih besar
    if today_l_val > month_l_val:
        month_l_val = today_l_val

    # 4. Deret 7 hari terakhir (6 hari lalu sampai hari ini)
    last_7_days_l: List[float] = []
    start_7_days = today_wib - timedelta(days=6)
    
    # Query daily_usage dalam rentang 7 hari
    usages_7d = (
        db.query(DailyUsage.date, func.sum(DailyUsage.volume_l).label("daily_total"))
        .filter(DailyUsage.date >= start_7_days, DailyUsage.date <= today_wib)
        .group_by(DailyUsage.date)
        .all()
    )
    daily_map = {u.date: round(float(u.daily_total), 2) for u in usages_7d}

    for i in range(7):
        d = start_7_days + timedelta(days=i)
        if d == today_wib and d not in daily_map:
            vol = today_l_val
        else:
            vol = daily_map.get(d, 0.0)
        last_7_days_l.append(vol)

    # 5. Open Alert Count & Latest Open Alert
    open_alerts = (
        db.query(Alert)
        .filter(Alert.status == AlertStatus.OPEN)
        .order_by(Alert.id.desc())
        .all()
    )
    open_alert_count = len(open_alerts)
    latest_open_alert = None
    if open_alerts:
        top_alert = open_alerts[0]
        room_name = f"Kamar {top_alert.room_id}"
        if top_alert.room:
            room_name = top_alert.room.name
        latest_open_alert = LatestOpenAlertSummary(
            id=top_alert.id,
            room_id=top_alert.room_id,
            room_name=room_name,
            type=top_alert.type.value if hasattr(top_alert.type, "value") else str(top_alert.type),
            created_at=format_iso_utc(top_alert.created_at) or "",
        )

    return SummaryResponse(
        today_l=today_l_val,
        month_l=month_l_val,
        last_7_days_end=today_wib.isoformat(),
        last_7_days_l=last_7_days_l,
        tally=tally,
        open_alert_count=open_alert_count,
        latest_open_alert=latest_open_alert,
    )

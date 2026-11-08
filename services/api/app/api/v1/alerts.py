"""
REST API Router untuk Alerts dan Notifikasi Riwayat (R-07).
Endpoints:
- GET /v1/alerts
- GET /v1/alerts/{alert_id}
- POST /v1/alerts/{alert_id}/resolve
"""

from typing import Optional, List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, verify_owner_token
from app.api.v1.helpers import format_iso_utc
from app.models.alert import Alert, AlertStatus, AlertResolvedBy
from app.models.room import Room
from app.schemas.alert import AlertDetailResponse, AlertListResponse

router = APIRouter(prefix="/v1/alerts", tags=["Alerts"])


def _to_alert_detail(a: Alert) -> AlertDetailResponse:
    room_name = f"Kamar {a.room_id}"
    if a.room:
        room_name = a.room.name
    return AlertDetailResponse(
        id=a.id,
        room_id=a.room_id,
        room_name=room_name,
        type=a.type.value if hasattr(a.type, "value") else str(a.type),
        rule=a.rule.value if hasattr(a.rule, "value") else str(a.rule),
        status=a.status.value if hasattr(a.status, "value") else str(a.status),
        created_at=format_iso_utc(a.created_at) or "",
        resolved_at=format_iso_utc(a.resolved_at),
        resolved_by=a.resolved_by.value if hasattr(a.resolved_by, "value") and a.resolved_by else (str(a.resolved_by) if a.resolved_by else None),
        detail=a.detail,
    )


@router.get(
    "",
    response_model=AlertListResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Daftar alert dengan filter status dan pagination cursor",
)
def get_alerts(
    status_filter: str = Query("all", alias="status", description="Filter status: all | open | resolved"),
    limit: int = Query(20, ge=1, le=50, description="Maksimal item per halaman"),
    before: Optional[int] = Query(None, description="Cursor ID untuk pagination (id < before)"),
    db: Session = Depends(get_db),
):
    """Mengambil daftar notifikasi/alert dengan filter status dan pagination cursor 'before'."""
    query = db.query(Alert)

    if status_filter == "open":
        query = query.filter(Alert.status == AlertStatus.OPEN)
    elif status_filter == "resolved":
        query = query.filter(Alert.status == AlertStatus.RESOLVED)

    if before is not None:
        query = query.filter(Alert.id < before)

    query = query.order_by(Alert.id.desc()).limit(limit)
    rows = query.all()

    items = [_to_alert_detail(r) for r in rows]
    next_before = items[-1].id if len(items) == limit else None

    return AlertListResponse(items=items, next_before=next_before)


@router.get(
    "/{alert_id}",
    response_model=AlertDetailResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Detail lengkap satu alert",
)
def get_alert_detail(alert_id: int, db: Session = Depends(get_db)):
    """Mengambil rincian data satu alert (detail metrik, durasi, flow_lpm, rasio)."""
    alert = db.query(Alert).filter(Alert.id == alert_id).first()
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": f"Alert dengan ID {alert_id} tidak ditemukan"},
        )
    return _to_alert_detail(alert)


@router.post(
    "/{alert_id}/resolve",
    response_model=AlertDetailResponse,
    dependencies=[Depends(verify_owner_token)],
    summary="Resolusi manual sebuah alert oleh pemilik",
)
def resolve_alert(alert_id: int, db: Session = Depends(get_db)):
    """Menandai alert sebagai RESOLVED oleh aplikasi (APP)."""
    alert = db.query(Alert).filter(Alert.id == alert_id).first()
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": f"Alert dengan ID {alert_id} tidak ditemukan"},
        )

    if alert.status == AlertStatus.OPEN:
        alert.status = AlertStatus.RESOLVED
        alert.resolved_by = AlertResolvedBy.APP
        alert.resolved_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(alert)

    return _to_alert_detail(alert)

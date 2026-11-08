"""
REST API Router untuk Notifikasi & Pendaftaran Token FCM (R-07).
Endpoint: POST /v1/push-tokens
"""

from datetime import datetime, timezone
from fastapi import APIRouter, Depends, status, Response
from sqlalchemy.orm import Session

from app.api.deps import get_db, verify_owner_token
from app.models.notification import PushToken
from app.schemas.notification import PushTokenCreateRequest

router = APIRouter(prefix="/v1", tags=["Notifications"])


@router.post(
    "/push-tokens",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(verify_owner_token)],
    summary="Mendaftarkan atau memperbarui token FCM perangkat",
)
def register_push_token(
    payload: PushTokenCreateRequest,
    db: Session = Depends(get_db),
):
    """
    Mendaftarkan token FCM HP pemilik untuk push notification alert.
    Jika token sudah ada, perbarui waktu dan platform secara idempoten.
    Mengembalikan HTTP 204 No Content.
    """
    now_utc = datetime.now(timezone.utc)
    token_row = db.query(PushToken).filter(PushToken.token == payload.token).first()
    if token_row:
        token_row.platform = payload.platform
        token_row.updated_at = now_utc
    else:
        token_row = PushToken(
            token=payload.token,
            platform=payload.platform,
            updated_at=now_utc,
        )
        db.add(token_row)

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

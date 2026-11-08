import logging
import time
from datetime import datetime, timezone
from typing import Dict, List, Optional
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.alert import Alert, AlertType, AlertRule
from app.models.notification import PushToken, Notification
from app.notify.fcm import FCMClient, FCMResponse

logger = logging.getLogger("smartwater.notify.dispatcher")


def format_alert_payload(alert: Alert, room: Optional[Room] = None) -> Dict[str, str]:
    """
    Menyusun payload notifikasi push bertipe data sesuai CONTRACT.md Bagian 4.
    Semua field bertipe string murni.
    """
    room_name = room.name if room else f"Kamar {alert.room_id}"

    if alert.type == AlertType.LEAK:
        title = "Kebocoran terdeteksi"
        if alert.rule == AlertRule.CONTINUOUS:
            body = f"{room_name}: aliran terus menerus. Valve sudah ditutup."
        elif alert.rule == AlertRule.STABLE:
            body = f"{room_name}: aliran stabil terdeteksi. Valve sudah ditutup."
        elif alert.rule == AlertRule.QUIET_HOURS:
            body = f"{room_name}: aliran di jam sepi terdeteksi. Valve sudah ditutup."
        else:
            body = f"Kebocoran di {room_name}, valve ditutup."
    elif alert.type == AlertType.ANOMALY:
        title = "Anomali pemakaian terdeteksi"
        detail = alert.detail or {}
        ratio = detail.get("ratio")
        if ratio is not None:
            ratio_str = f"{float(ratio):.1f}".replace(".", ",")
            body = f"Pemakaian {room_name} hari ini {ratio_str}× rata-rata."
        else:
            body = f"Pemakaian {room_name} hari ini melebihi rata-rata."
    else:
        title = "Pemberitahuan Sistem"
        body = f"Aktivitas terdeteksi pada {room_name}."

    return {
        "type": alert.type.value,
        "alert_id": str(alert.id),
        "room_id": str(alert.room_id),
        "room_name": room_name,
        "title": title,
        "body": body,
    }


def dispatch_alert_notification(
    db: Session,
    alert: Alert,
    fcm_client: Optional[FCMClient] = None,
    retry_delays: Optional[List[float]] = None,
) -> Optional[Notification]:
    """
    Mendistribusikan notifikasi push ke seluruh token terdaftar di push_tokens:
    1. Filter: Alert ACTIVITY (tombol fisik) TIDAK dikirim push (CONTRACT.md 4.3).
    2. Format payload string murni (CONTRACT.md Bagian 4).
    3. Retry mechanism dengan backoff saat gagal (US-12).
    4. Pruning token expired/unregistered dari tabel push_tokens.
    5. Pencatatan audit ke tabel notifications (bukti pemenuhan KPI K1).
    """
    # 1. Kontrak 4.3: Alert ACTIVITY tidak dikirim push
    if alert.type == AlertType.ACTIVITY:
        logger.debug(f"Alert {alert.id} bertipe ACTIVITY, lewati push notification.")
        return None

    if alert.type not in (AlertType.LEAK, AlertType.ANOMALY):
        logger.debug(f"Alert {alert.id} bertipe {alert.type}, lewati push notification.")
        return None

    room = db.query(Room).filter_by(id=alert.room_id).first()
    client = fcm_client or FCMClient()
    tokens = db.query(PushToken).all()

    now_utc = datetime.now(timezone.utc)

    # Bila belum ada token yang terdaftar
    if not tokens:
        logger.info(f"Belum ada push token terdaftar untuk mengirim notifikasi alert {alert.id}.")
        notif = Notification(
            alert_id=alert.id,
            sent_at=now_utc,
            attempts=0,
            last_error="NO_REGISTERED_TOKENS",
        )
        db.add(notif)
        try:
            db.commit()
            db.refresh(notif)
        except Exception as e:
            db.rollback()
            logger.error(f"Gagal mencatat log notifikasi: {e}")
        return notif

    payload_data = format_alert_payload(alert, room)
    delays = [5.0, 15.0, 45.0] if retry_delays is None else retry_delays

    batch_max_attempts = 1
    any_success = False
    tokens_to_prune: List[PushToken] = []
    last_err: Optional[str] = None

    for token_obj in tokens:
        token_str = token_obj.token
        attempt = 1
        resp = client.send_message(token_str, payload_data)

        if resp.success:
            any_success = True
        elif resp.error_code == "UNREGISTERED":
            tokens_to_prune.append(token_obj)
            last_err = resp.error_message or "UNREGISTERED"
        else:
            # Kegagalan transient -> lakukan retry dengan exponential backoff (US-12)
            for delay in delays:
                if delay > 0:
                    time.sleep(delay)
                attempt += 1
                resp = client.send_message(token_str, payload_data)
                if resp.success:
                    any_success = True
                    break
                if resp.error_code == "UNREGISTERED":
                    tokens_to_prune.append(token_obj)
                    last_err = resp.error_message or "UNREGISTERED"
                    break

            if not resp.success:
                last_err = resp.error_message or resp.error_code or "Pengiriman gagal setelah retry"

        batch_max_attempts = max(batch_max_attempts, attempt)

    # Pruning token tidak valid
    if tokens_to_prune:
        for t in tokens_to_prune:
            db.delete(t)
        try:
            db.commit()
            logger.info(f"Berhasil menghapus {len(tokens_to_prune)} token unregistered.")
        except Exception as e:
            db.rollback()
            logger.error(f"Gagal menghapus token unregistered: {e}")

    # Catat audit log ke tabel notifications
    final_error = None if any_success else last_err
    notif = Notification(
        alert_id=alert.id,
        sent_at=datetime.now(timezone.utc),
        attempts=batch_max_attempts,
        last_error=final_error,
    )
    db.add(notif)
    try:
        db.commit()
        db.refresh(notif)
    except Exception as e:
        db.rollback()
        logger.error(f"Gagal mencatat log notifikasi ke DB: {e}")

    return notif

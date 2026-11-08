"""
Job pengecekan timeout perintah kendali valve (15 detik) sesuai CONTRACT.md 2.7.
"""

import logging
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session

from app.models.command import ValveCommand, CommandStatus

logger = logging.getLogger(__name__)


def expire_stale_commands(db: Session, timeout_seconds: float = 15.0) -> int:
    """
    Menandai perintah berstatus PENDING yang sudah melewati batas waktu timeout (15 detik)
    menjadi FAILED.
    """
    now_utc = datetime.now(timezone.utc)
    pending_commands = (
        db.query(ValveCommand)
        .filter(ValveCommand.status == CommandStatus.PENDING)
        .all()
    )

    expired_count = 0
    for cmd in pending_commands:
        cmd_created = (
            cmd.created_at.replace(tzinfo=timezone.utc)
            if cmd.created_at.tzinfo is None
            else cmd.created_at
        )
        if (now_utc - cmd_created).total_seconds() >= timeout_seconds:
            logger.warning(
                f"Perintah valve id={cmd.id} (room={cmd.room_id}) kedaluwarsa setelah {timeout_seconds} detik tanpa ACK. Status -> FAILED"
            )
            cmd.status = CommandStatus.FAILED
            expired_count += 1

    if expired_count == 0:
        return 0

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Gagal commit status FAILED untuk perintah kedaluwarsa: {e}")
        return 0

    return expired_count

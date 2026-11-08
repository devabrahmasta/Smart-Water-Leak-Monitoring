"""
REST API Router untuk Kendali Valve dan Status Perintah (R-05).
Endpoints:
- POST /v1/rooms/{room_id}/valve
- GET  /v1/commands/{command_id}
"""

import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, verify_owner_token, get_mqtt_publisher
from app.models.room import Room
from app.models.device import Device
from app.models.command import ValveCommand, CommandAction, CommandSource, CommandStatus
from app.schemas.command import (
    ValveCommandCreateRequest,
    ValveCommandCreateResponse,
    ValveCommandDetailResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1", tags=["Valve Commands"])


def _ensure_utc(dt: datetime) -> datetime:
    """Memastikan datetime memiliki timezone UTC (kompatibilitas SQLite & Postgres)."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


@router.post(
    "/rooms/{room_id}/valve",
    response_model=ValveCommandCreateResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Kirim perintah buka/tutup valve ke kamar",
)
def create_valve_command(
    room_id: int,
    payload: ValveCommandCreateRequest,
    db: Session = Depends(get_db),
    _token: str = Depends(verify_owner_token),
    mqtt_publisher=Depends(get_mqtt_publisher),
):
    """
    Mengirim perintah buka/tutup valve ke kamar:
    1. Cek kamar dan device terdaftar
    2. Cek perangkat online (last_seen_at <= 30 detik)
    3. Cek tidak ada perintah PENDING yang sedang berlangsung
    4. Simpan record PENDING ke valve_commands
    5. Publish pesan cmd ke broker Mosquitto (swm/{device_id}/cmd)
    6. Balas 202 Accepted dengan command_id dan status PENDING
    """
    # 1. Cek kamar
    room = db.query(Room).filter_by(id=room_id).first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Kamar tidak ditemukan"},
        )

    # 2. Cek device terhubung
    device = room.device
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": f"Perangkat untuk {room.name} tidak ditemukan"},
        )

    # 3. Cek apakah perangkat offline (> 30 detik tanpa pesan)
    now_utc = datetime.now(timezone.utc)
    last_seen = _ensure_utc(device.last_seen_at) if device.last_seen_at else None
    if not last_seen or (now_utc - last_seen).total_seconds() > 30.0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DEVICE_OFFLINE",
                "message": f"Perangkat {room.name} sedang offline",
            },
        )

    # 4. Cek apakah ada perintah PENDING yang sedang berjalan
    pending_cmd = (
        db.query(ValveCommand)
        .filter(
            ValveCommand.room_id == room_id,
            ValveCommand.status == CommandStatus.PENDING,
        )
        .first()
    )
    if pending_cmd:
        pending_created = _ensure_utc(pending_cmd.created_at)
        # Cek apakah sudah kadaluarsa (>= 15 detik)
        if (now_utc - pending_created).total_seconds() >= 15.0:
            pending_cmd.status = CommandStatus.FAILED
            db.commit()
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "COMMAND_IN_PROGRESS",
                    "message": f"Masih ada perintah pending pada {room.name}",
                },
            )

    # 5. Buat entri perintah baru di tabel valve_commands
    command_action = CommandAction(payload.action.value)
    new_cmd = ValveCommand(
        room_id=room_id,
        action=command_action,
        source=CommandSource.APP,
        status=CommandStatus.PENDING,
        created_at=now_utc,
    )
    db.add(new_cmd)
    db.commit()
    db.refresh(new_cmd)

    # 6. Terbitkan pesan MQTT pada topik swm/{device_id}/cmd
    cmd_topic = f"swm/{device.id}/cmd"
    cmd_payload = {
        "command_id": new_cmd.id,
        "action": payload.action.value,
    }
    published = mqtt_publisher.publish(cmd_topic, cmd_payload, qos=1)
    if not published:
        logger.warning(f"Gagal menerbitkan perintah MQTT ke {cmd_topic}")

    return ValveCommandCreateResponse(
        command_id=new_cmd.id,
        status="PENDING",
    )


@router.get(
    "/commands/{command_id}",
    response_model=ValveCommandDetailResponse,
    summary="Cek status perintah kendali valve (polling)",
)
def get_command_status(
    command_id: int,
    db: Session = Depends(get_db),
    _token: str = Depends(verify_owner_token),
):
    """
    Mengambil status perintah valve terkini:
    Jika status masih PENDING dan telah melewati 15 detik, otomatis ditransisikan ke FAILED.
    """
    cmd = db.query(ValveCommand).filter_by(id=command_id).first()
    if not cmd:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Perintah tidak ditemukan"},
        )

    # Evaluasi timeout deterministik (15 detik)
    if cmd.status == CommandStatus.PENDING:
        now_utc = datetime.now(timezone.utc)
        cmd_created = _ensure_utc(cmd.created_at)
        if (now_utc - cmd_created).total_seconds() >= 15.0:
            cmd.status = CommandStatus.FAILED
            db.commit()
            db.refresh(cmd)

    acked_at_str = (
        cmd.acked_at.strftime("%Y-%m-%dT%H:%M:%SZ") if cmd.acked_at else None
    )

    return ValveCommandDetailResponse(
        id=cmd.id,
        room_id=cmd.room_id,
        action=cmd.action.value,
        source=cmd.source.value,
        status=cmd.status.value,
        created_at=cmd.created_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
        acked_at=acked_at_str,
    )

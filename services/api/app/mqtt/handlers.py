"""
Handler pemrosesan pesan MQTT untuk Ingest Worker (R-03).
Menangani topik:
- swm/{device_id}/telemetry
- swm/{device_id}/alert
- swm/{device_id}/status
"""

import json
import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, Any, Optional

from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models.device import Device, ValveState
from app.models.telemetry import Telemetry
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus, AlertResolvedBy
from app.models.command import ValveCommand, CommandAction, CommandSource, CommandStatus
from app.mqtt.validator import validate_payload

logger = logging.getLogger(__name__)


@dataclass
class IngestResult:
    success: bool
    is_duplicate: bool = False
    error: Optional[str] = None
    message: Optional[str] = None


def _parse_timestamp(raw_ts: Optional[str], default_now: datetime) -> datetime:
    """
    Parse ISO 8601 UTC timestamp dari perangkat.
    Jika null (NTP belum sync) atau format tidak valid, gunakan waktu server UTC saat diterima.
    """
    if not raw_ts:
        return default_now
    try:
        return datetime.fromisoformat(raw_ts.replace("Z", "+00:00"))
    except Exception:
        return default_now


def handle_telemetry(db: Session, device_id: str, payload: Dict[str, Any]) -> IngestResult:
    """
    Memproses payload telemetri periodik:
    1. Validasi JSON Schema
    2. Cek pendaftaran perangkat
    3. Cek deduplikasi msg_id (KPI K4)
    4. Simpan baris Telemetry
    5. Update devices.last_seen_at dan devices.valve_state
    """
    # 1. Validasi skema
    is_valid, err_msg = validate_payload("telemetry", payload)
    if not is_valid:
        logger.warning(f"Telemetry dari device '{device_id}' ditolak: {err_msg}")
        return IngestResult(success=False, error=err_msg)

    # 2. Cek perangkat terdaftar
    device = db.query(Device).filter_by(id=device_id).first()
    if not device:
        err = f"Perangkat tidak terdaftar: {device_id}"
        logger.warning(err)
        return IngestResult(success=False, error=err)

    msg_id = int(payload["msg_id"])

    # 3. Deduplikasi msg_id per perangkat (KPI K4)
    existing = db.query(Telemetry).filter_by(device_id=device_id, msg_id=msg_id).first()
    if existing:
        logger.info(f"Duplicate telemetry ignored: device={device_id}, msg_id={msg_id}")
        return IngestResult(
            success=True,
            is_duplicate=True,
            message=f"Pesan duplikat diabaikan: {msg_id}",
        )

    now_utc = datetime.now(timezone.utc)
    device_ts = _parse_timestamp(payload.get("ts"), now_utc)
    valve_state = ValveState(payload["valve"])

    # 4. Buat record telemetri
    telemetry_record = Telemetry(
        device_id=device_id,
        msg_id=msg_id,
        device_ts=device_ts,
        received_at=now_utc,
        flow_lpm=float(payload["flow_lpm"]),
        volume_l_delta=float(payload["volume_l_delta"]),
        valve_state=valve_state,
    )
    db.add(telemetry_record)

    # 5. Perbarui status perangkat
    device.last_seen_at = now_utc
    device.valve_state = valve_state

    try:
        db.commit()
        return IngestResult(success=True, is_duplicate=False)
    except IntegrityError:
        db.rollback()
        logger.info(f"Concurrent duplicate telemetry caught by DB constraint: device={device_id}, msg_id={msg_id}")
        return IngestResult(
            success=True,
            is_duplicate=True,
            message=f"Pesan duplikat ditangani konstrain DB: {msg_id}",
        )
    except Exception as e:
        db.rollback()
        err = f"Gagal menyimpan telemetri: {str(e)}"
        logger.error(err)
        return IngestResult(success=False, error=err)


def handle_alert(db: Session, device_id: str, payload: Dict[str, Any]) -> IngestResult:
    """
    Memproses payload alert kebocoran dari perangkat:
    1. Validasi JSON Schema
    2. Cek pendaftaran perangkat
    3. Simpan alert LEAK dengan status OPEN
    4. Update devices.valve_state = CLOSED dan perbarui devices.last_seen_at
    """
    # 1. Validasi skema
    is_valid, err_msg = validate_payload("alert", payload)
    if not is_valid:
        logger.warning(f"Alert dari device '{device_id}' ditolak: {err_msg}")
        return IngestResult(success=False, error=err_msg)

    # 2. Cek perangkat terdaftar
    device = db.query(Device).filter_by(id=device_id).first()
    if not device:
        err = f"Perangkat tidak terdaftar: {device_id}"
        logger.warning(err)
        return IngestResult(success=False, error=err)

    now_utc = datetime.now(timezone.utc)
    device_ts = _parse_timestamp(payload.get("ts"), now_utc)
    rule_enum = AlertRule(payload["rule"])

    # 3. Simpan alert LEAK
    alert_record = Alert(
        room_id=device.room_id,
        type=AlertType.LEAK,
        rule=rule_enum,
        status=AlertStatus.OPEN,
        device_ts=device_ts,
        created_at=now_utc,
        detail={
            "flow_lpm": float(payload["flow_lpm"]),
            "msg_id": int(payload["msg_id"]),
        },
    )
    db.add(alert_record)

    # 4. Perbarui status valve & last_seen_at di perangkat
    device.valve_state = ValveState.CLOSED
    device.last_seen_at = now_utc

    try:
        db.commit()
        return IngestResult(success=True)
    except Exception as e:
        db.rollback()
        err = f"Gagal menyimpan alert: {str(e)}"
        logger.error(err)
        return IngestResult(success=False, error=err)


def handle_status(db: Session, device_id: str, payload: Dict[str, Any]) -> IngestResult:
    """
    Memproses status dari perangkat:
    - BOOT: Pemulihan status perangkat setelah restart
    - MANUAL_BUTTON: Perubahan valve fisik lewat tombol pada hardware
      (mencatat valve_commands SUCCESS, alert ACTIVITY/INFO, dan me-resolve alert leak aktif bila membuka valve)
    """
    # 1. Validasi skema
    is_valid, err_msg = validate_payload("status", payload)
    if not is_valid:
        logger.warning(f"Status dari device '{device_id}' ditolak: {err_msg}")
        return IngestResult(success=False, error=err_msg)

    # 2. Cek perangkat terdaftar
    device = db.query(Device).filter_by(id=device_id).first()
    if not device:
        err = f"Perangkat tidak terdaftar: {device_id}"
        logger.warning(err)
        return IngestResult(success=False, error=err)

    now_utc = datetime.now(timezone.utc)
    device_ts = _parse_timestamp(payload.get("ts"), now_utc)
    valve_state = ValveState(payload["valve"])
    source = payload["source"]  # "BOOT" | "MANUAL_BUTTON"

    # 3. Perbarui status perangkat
    device.valve_state = valve_state
    device.last_seen_at = now_utc

    # 4. Tangani event tombol fisik (MANUAL_BUTTON)
    if source == "MANUAL_BUTTON":
        command_action = CommandAction(payload["valve"])

        # Catat ke riwayat valve_commands
        cmd = ValveCommand(
            room_id=device.room_id,
            action=command_action,
            source=CommandSource.MANUAL_BUTTON,
            status=CommandStatus.SUCCESS,
            created_at=now_utc,
            acked_at=now_utc,
        )
        db.add(cmd)

        # Catat aktivitas ke tabel alerts
        activity_alert = Alert(
            room_id=device.room_id,
            type=AlertType.ACTIVITY,
            rule=AlertRule.MANUAL_BUTTON,
            status=AlertStatus.INFO,
            device_ts=device_ts,
            created_at=now_utc,
            detail={
                "valve": payload["valve"],
                "msg_id": int(payload["msg_id"]),
            },
        )
        db.add(activity_alert)

        # Jika tombol fisik membuka valve, resolve alert kebocoran yang berstatus OPEN
        if valve_state == ValveState.OPEN:
            open_leak_alerts = (
                db.query(Alert)
                .filter(
                    Alert.room_id == device.room_id,
                    Alert.type == AlertType.LEAK,
                    Alert.status == AlertStatus.OPEN,
                )
                .all()
            )
            for open_alert in open_leak_alerts:
                open_alert.status = AlertStatus.RESOLVED
                open_alert.resolved_by = AlertResolvedBy.MANUAL_BUTTON
                open_alert.resolved_at = now_utc

    try:
        db.commit()
        return IngestResult(success=True)
    except Exception as e:
        db.rollback()
        err = f"Gagal memproses status: {str(e)}"
        logger.error(err)
        return IngestResult(success=False, error=err)


def route_mqtt_message(db: Session, topic: str, raw_payload: bytes) -> IngestResult:
    """
    Rute pesan MQTT berdasarkan format topik swm/{device_id}/{message_type}.
    Decode JSON dan teruskan ke handler terkait.
    """
    parts = topic.strip("/").split("/")
    if len(parts) != 3 or parts[0] != "swm":
        err = f"Format topik tidak valid: {topic}"
        logger.warning(err)
        return IngestResult(success=False, error=err)

    device_id = parts[1]
    msg_type = parts[2]

    # Decode JSON UTF-8
    try:
        payload = json.loads(raw_payload.decode("utf-8"))
    except Exception as e:
        err = f"JSON tidak valid: {str(e)}"
        logger.warning(f"Pesan pada topik '{topic}' ditolak: {err}")
        return IngestResult(success=False, error=err)

    if not isinstance(payload, dict):
        err = "Payload JSON harus berupa objek/dictionary"
        logger.warning(f"Pesan pada topik '{topic}' ditolak: {err}")
        return IngestResult(success=False, error=err)

    # Teruskan ke handler yang sesuai
    if msg_type == "telemetry":
        return handle_telemetry(db, device_id, payload)
    elif msg_type == "alert":
        return handle_alert(db, device_id, payload)
    elif msg_type == "status":
        return handle_status(db, device_id, payload)
    else:
        err = f"Topik tidak dikenali: {msg_type}"
        logger.warning(f"Pesan pada topik '{topic}' diabaikan: {err}")
        return IngestResult(success=False, error=err)

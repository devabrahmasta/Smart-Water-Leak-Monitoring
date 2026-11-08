"""
Unit & Integration Tests untuk Perintah Kendali Valve (R-05).
Kriteria Selesai (PRD 5.2):
- ACK sukses -> SUCCESS
- Tanpa ACK -> FAILED dalam 15 detik (timeout)
- OPEN me-RESOLVE alert LEAK terbuka
- Validasi REST API (401, 404, 409 DEVICE_OFFLINE, 409 COMMAND_IN_PROGRESS, 422 INVALID_PAYLOAD)
"""

import sys
import json
import unittest
from pathlib import Path
from datetime import datetime, timezone, timedelta

# Pastikan path services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool
from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.database import Base
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus, AlertResolvedBy
from app.models.command import ValveCommand, CommandAction, CommandSource, CommandStatus
from app.mqtt.handlers import handle_ack, route_mqtt_message
from app.jobs.timeouts import expire_stale_commands
from app.main import app
from app.api.deps import get_db, get_mqtt_publisher


class MockMQTTPublisher:
    def __init__(self):
        self.published_messages = []

    def publish(self, topic: str, payload: dict, qos: int = 1) -> bool:
        self.published_messages.append({"topic": topic, "payload": payload, "qos": qos})
        return True


class TestValveCommand(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Database SQLite in-memory untuk pengujian terisolasi (StaticPool agar bisa dishare antar thread TestClient)
        cls.engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(cls.engine)
        cls.Session = sessionmaker(bind=cls.engine)

        cls.mock_mqtt = MockMQTTPublisher()

        def override_get_db():
            db = cls.Session()
            try:
                yield db
            finally:
                db.close()

        def override_get_mqtt_publisher():
            return cls.mock_mqtt

        app.dependency_overrides[get_db] = override_get_db
        app.dependency_overrides[get_mqtt_publisher] = override_get_mqtt_publisher
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        app.dependency_overrides.clear()

    def setUp(self):
        self.db = self.Session()
        self.mock_mqtt.published_messages.clear()

        # Bersihkan data lama
        self.db.query(Alert).delete()
        self.db.query(ValveCommand).delete()
        self.db.query(Device).delete()
        self.db.query(Room).delete()
        self.db.commit()

        # Seed Kamar 1 (device 1) dan Kamar 2 (device 2)
        r1 = Room(id=1, name="Kamar 1", sort_order=1, is_simulated=False)
        r2 = Room(id=2, name="Kamar 2", sort_order=2, is_simulated=True)
        self.db.add_all([r1, r2])
        self.db.flush()

        # Device online (last_seen_at baru saja)
        now_utc = datetime.now(timezone.utc)
        d1 = Device(id="1", room_id=1, valve_state=ValveState.OPEN, last_seen_at=now_utc)
        d2 = Device(id="2", room_id=2, valve_state=ValveState.OPEN, last_seen_at=now_utc)
        self.db.add_all([d1, d2])
        self.db.commit()

        self.auth_headers = {"Authorization": f"Bearer {settings.API_OWNER_TOKEN}"}

    def tearDown(self):
        self.db.close()

    def test_post_valve_command_success(self):
        """Memverifikasi POST 202 Accepted, record PENDING dibuat di DB, dan MQTT cmd terbit."""
        response = self.client.post(
            "/v1/rooms/1/valve",
            json={"action": "CLOSE"},
            headers=self.auth_headers,
        )

        self.assertEqual(response.status_code, 202)
        data = response.json()
        self.assertIn("command_id", data)
        self.assertEqual(data["status"], "PENDING")

        cmd_id = data["command_id"]
        # Cek record di database
        cmd = self.db.query(ValveCommand).filter_by(id=cmd_id).first()
        self.assertIsNotNone(cmd)
        self.assertEqual(cmd.action, CommandAction.CLOSE)
        self.assertEqual(cmd.source, CommandSource.APP)
        self.assertEqual(cmd.status, CommandStatus.PENDING)

        # Cek pesan MQTT terbit pada topik swm/1/cmd
        self.assertEqual(len(self.mock_mqtt.published_messages), 1)
        msg = self.mock_mqtt.published_messages[0]
        self.assertEqual(msg["topic"], "swm/1/cmd")
        self.assertEqual(msg["payload"]["command_id"], cmd_id)
        self.assertEqual(msg["payload"]["action"], "CLOSE")

    def test_post_valve_command_unauthorized(self):
        """Memverifikasi request tanpa token atau token salah ditolak 401."""
        # Tanpa header
        r1 = self.client.post("/v1/rooms/1/valve", json={"action": "OPEN"})
        self.assertEqual(r1.status_code, 401)
        self.assertEqual(r1.json()["error"]["code"], "UNAUTHORIZED")

        # Token salah
        r2 = self.client.post(
            "/v1/rooms/1/valve",
            json={"action": "OPEN"},
            headers={"Authorization": "Bearer token_salah_123"},
        )
        self.assertEqual(r2.status_code, 401)
        self.assertEqual(r2.json()["error"]["code"], "UNAUTHORIZED")

    def test_post_valve_command_room_not_found(self):
        """Memverifikasi kamar yang tidak ada ditolak 404 NOT_FOUND."""
        res = self.client.post(
            "/v1/rooms/999/valve",
            json={"action": "OPEN"},
            headers=self.auth_headers,
        )
        self.assertEqual(res.status_code, 404)
        self.assertEqual(res.json()["error"]["code"], "NOT_FOUND")

    def test_post_valve_command_device_offline(self):
        """Memverifikasi perintah ke perangkat offline (> 30s) ditolak 409 DEVICE_OFFLINE."""
        # Set last_seen_at device 1 menjadi 35 detik yang lalu
        d1 = self.db.query(Device).filter_by(id="1").first()
        d1.last_seen_at = datetime.now(timezone.utc) - timedelta(seconds=35)
        self.db.commit()

        res = self.client.post(
            "/v1/rooms/1/valve",
            json={"action": "CLOSE"},
            headers=self.auth_headers,
        )
        self.assertEqual(res.status_code, 409)
        self.assertEqual(res.json()["error"]["code"], "DEVICE_OFFLINE")
        self.assertIn("offline", res.json()["error"]["message"].lower())

    def test_post_valve_command_in_progress(self):
        """Memverifikasi penolakan 409 COMMAND_IN_PROGRESS jika masih ada perintah PENDING."""
        # Buat perintah PENDING yang aktif (dibuat 5 detik lalu)
        now_utc = datetime.now(timezone.utc)
        cmd_active = ValveCommand(
            room_id=1,
            action=CommandAction.OPEN,
            source=CommandSource.APP,
            status=CommandStatus.PENDING,
            created_at=now_utc - timedelta(seconds=5),
        )
        self.db.add(cmd_active)
        self.db.commit()

        # Kirim perintah kedua pada kamar yang sama
        res = self.client.post(
            "/v1/rooms/1/valve",
            json={"action": "CLOSE"},
            headers=self.auth_headers,
        )
        self.assertEqual(res.status_code, 409)
        self.assertEqual(res.json()["error"]["code"], "COMMAND_IN_PROGRESS")

    def test_post_valve_command_invalid_payload(self):
        """Memverifikasi action selain OPEN atau CLOSE ditolak 422 INVALID_PAYLOAD."""
        res = self.client.post(
            "/v1/rooms/1/valve",
            json={"action": "RESTART"},
            headers=self.auth_headers,
        )
        self.assertEqual(res.status_code, 422)
        self.assertEqual(res.json()["error"]["code"], "INVALID_PAYLOAD")

    def test_ack_success_updates_command_and_device(self):
        """Memverifikasi penerimaan ACK sukses mengubah status menjadi SUCCESS dan posisi valve di device."""
        now_utc = datetime.now(timezone.utc)
        cmd = ValveCommand(
            room_id=1,
            action=CommandAction.CLOSE,
            source=CommandSource.APP,
            status=CommandStatus.PENDING,
            created_at=now_utc,
        )
        self.db.add(cmd)
        self.db.commit()

        # Simulasi pesan ACK dari broker: swm/1/ack
        ack_payload = {"command_id": cmd.id, "result": "OK", "valve": "CLOSED"}
        res = handle_ack(self.db, "1", ack_payload)
        self.assertTrue(res.success)

        # Cek update status perintah
        self.db.refresh(cmd)
        self.assertEqual(cmd.status, CommandStatus.SUCCESS)
        self.assertIsNotNone(cmd.acked_at)

        # Cek update valve perangkat
        d1 = self.db.query(Device).filter_by(id="1").first()
        self.assertEqual(d1.valve_state, ValveState.CLOSED)

    def test_ack_error_marks_command_failed(self):
        """Memverifikasi ACK dengan result ERROR menandai perintah FAILED."""
        now_utc = datetime.now(timezone.utc)
        cmd = ValveCommand(
            room_id=1,
            action=CommandAction.CLOSE,
            source=CommandSource.APP,
            status=CommandStatus.PENDING,
            created_at=now_utc,
        )
        self.db.add(cmd)
        self.db.commit()

        ack_payload = {"command_id": cmd.id, "result": "ERROR", "valve": "OPEN"}
        res = handle_ack(self.db, "1", ack_payload)
        self.assertTrue(res.success)

        self.db.refresh(cmd)
        self.assertEqual(cmd.status, CommandStatus.FAILED)
        self.assertIsNotNone(cmd.acked_at)

    def test_ack_open_resolves_open_leak_alert(self):
        """Kriteria Selesai PRD 5.2: Perintah OPEN me-RESOLVE alert LEAK aktif."""
        now_utc = datetime.now(timezone.utc)
        # 1. Buat alert LEAK berstatus OPEN
        leak_alert = Alert(
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            created_at=now_utc - timedelta(minutes=5),
            detail={"flow_lpm": 6.4},
        )
        self.db.add(leak_alert)

        # 2. Buat perintah OPEN berstatus PENDING
        cmd = ValveCommand(
            room_id=1,
            action=CommandAction.OPEN,
            source=CommandSource.APP,
            status=CommandStatus.PENDING,
            created_at=now_utc,
        )
        self.db.add(cmd)
        self.db.commit()

        # 3. ACK OPEN datang dari ESP32
        ack_payload = {"command_id": cmd.id, "result": "OK", "valve": "OPEN"}
        res = handle_ack(self.db, "1", ack_payload)
        self.assertTrue(res.success)

        # 4. Verifikasi alert LEAK otomatis RESOLVED oleh APP
        self.db.refresh(leak_alert)
        self.assertEqual(leak_alert.status, AlertStatus.RESOLVED)
        self.assertEqual(leak_alert.resolved_by, AlertResolvedBy.APP)
        self.assertIsNotNone(leak_alert.resolved_at)

    def test_command_timeout_transitions_to_failed_after_15s(self):
        """Kriteria Selesai PRD 5.2: Tanpa ACK -> FAILED dalam 15 detik."""
        now_utc = datetime.now(timezone.utc)
        # Perintah dibuat 16 detik yang lalu (tanpa ACK)
        cmd = ValveCommand(
            room_id=1,
            action=CommandAction.CLOSE,
            source=CommandSource.APP,
            status=CommandStatus.PENDING,
            created_at=now_utc - timedelta(seconds=16),
        )
        self.db.add(cmd)
        self.db.commit()

        # Jalankan pengecekan timeout
        expired_count = expire_stale_commands(self.db, timeout_seconds=15.0)
        self.assertGreaterEqual(expired_count, 1)

        # Cek status perintah di database
        self.db.refresh(cmd)
        self.assertEqual(cmd.status, CommandStatus.FAILED)

    def test_get_command_status_polling_and_dynamic_timeout(self):
        """Memverifikasi endpoint GET /v1/commands/{id} untuk polling aplikasi."""
        now_utc = datetime.now(timezone.utc)
        cmd = ValveCommand(
            room_id=1,
            action=CommandAction.OPEN,
            source=CommandSource.APP,
            status=CommandStatus.PENDING,
            created_at=now_utc - timedelta(seconds=16),  # Sudah lewat 15s
        )
        self.db.add(cmd)
        self.db.commit()

        # Saat aplikasi memanggil GET /v1/commands/{id}, jika sudah lewat 15 detik langsung return FAILED
        res = self.client.get(f"/v1/commands/{cmd.id}", headers=self.auth_headers)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["id"], cmd.id)
        self.assertEqual(data["room_id"], 1)
        self.assertEqual(data["action"], "OPEN")
        self.assertEqual(data["status"], "FAILED")

        # Test command not found
        res404 = self.client.get("/v1/commands/9999", headers=self.auth_headers)
        self.assertEqual(res404.status_code, 404)
        self.assertEqual(res404.json()["error"]["code"], "NOT_FOUND")


if __name__ == "__main__":
    unittest.main()

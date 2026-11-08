"""
Unit & Integration Tests untuk MQTT Ingestion Worker (R-03).
Menguji penanganan:
- Telemetri (payload valid, fallback ts null, deduplikasi K4)
- Alert kebocoran (status OPEN, penutupan valve, pembaruan last_seen_at)
- Status (BOOT, MANUAL_BUTTON, pencatatan command & alert ACTIVITY, resolusi leak alert)
- Validasi skema & routing pesan MQTT
"""

import os
import sys
import json
from pathlib import Path
from datetime import datetime, timezone
import unittest

# Pastikan services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

# Path ke root proyek dan fixtures
root_dir = api_dir.parent.parent
fixtures_dir = root_dir / "packages" / "contracts" / "fixtures"

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.telemetry import Telemetry
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus, AlertResolvedBy
from app.models.command import ValveCommand, CommandAction, CommandSource, CommandStatus

# Import modul mqtt yang akan diuji
from app.mqtt.validator import validate_payload
from app.mqtt.handlers import (
    handle_telemetry,
    handle_alert,
    handle_status,
    route_mqtt_message,
    IngestResult,
)


class TestMqttIngest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Gunakan SQLite in-memory untuk pengujian unit & integrasi terisolasi dan cepat
        cls.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(cls.engine)
        cls.Session = sessionmaker(bind=cls.engine)

        # Muat fixtures kontrak
        with open(fixtures_dir / "telemetry.json", "r", encoding="utf-8") as f:
            cls.telemetry_fixture = json.load(f)

        with open(fixtures_dir / "telemetry_null_ts.json", "r", encoding="utf-8") as f:
            cls.telemetry_null_ts_fixture = json.load(f)

        with open(fixtures_dir / "alert_continuous.json", "r", encoding="utf-8") as f:
            cls.alert_fixture = json.load(f)

        with open(fixtures_dir / "status_boot.json", "r", encoding="utf-8") as f:
            cls.status_boot_fixture = json.load(f)

        with open(fixtures_dir / "status_manual.json", "r", encoding="utf-8") as f:
            cls.status_manual_fixture = json.load(f)

    def setUp(self):
        self.db = self.Session()
        # Bersihkan data sebelum tiap pengujian
        self.db.query(Telemetry).delete()
        self.db.query(Alert).delete()
        self.db.query(ValveCommand).delete()
        self.db.query(Device).delete()
        self.db.query(Room).delete()
        self.db.commit()

        # Seed 2 kamar dan 2 perangkat untuk pengujian
        r1 = Room(id=1, name="Kamar 1", sort_order=1, is_simulated=False)
        r2 = Room(id=2, name="Kamar 2", sort_order=2, is_simulated=True)
        self.db.add_all([r1, r2])
        self.db.flush()

        d1 = Device(id="1", room_id=1, valve_state=ValveState.OPEN)
        d2 = Device(id="2", room_id=2, valve_state=ValveState.OPEN)
        self.db.add_all([d1, d2])
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def test_validator_valid_and_invalid_payloads(self):
        """Memverifikasi validator JSON Schema mendeteksi payload valid dan invalid."""
        # Valid telemetry
        is_valid, err = validate_payload("telemetry", self.telemetry_fixture)
        self.assertTrue(is_valid)
        self.assertIsNone(err)

        # Invalid telemetry (missing flow_lpm)
        invalid_telemetry = {"msg_id": 1, "ts": "2026-11-07T07:00:00Z", "valve": "OPEN"}
        is_valid, err = validate_payload("telemetry", invalid_telemetry)
        self.assertFalse(is_valid)
        self.assertIsNotNone(err)

    def test_handle_telemetry_valid(self):
        """Memverifikasi payload telemetri valid tersimpan dan mengupdate status perangkat."""
        result = handle_telemetry(self.db, "1", self.telemetry_fixture)

        self.assertTrue(result.success)
        self.assertFalse(result.is_duplicate)

        # Cek baris telemetry di database
        t = self.db.query(Telemetry).filter_by(device_id="1", msg_id=self.telemetry_fixture["msg_id"]).first()
        self.assertIsNotNone(t)
        self.assertEqual(t.flow_lpm, 6.4)
        self.assertEqual(t.volume_l_delta, 1.07)
        self.assertEqual(t.valve_state, ValveState.OPEN)
        self.assertIsNotNone(t.device_ts)
        self.assertIsNotNone(t.received_at)

        # Cek pembaruan pada device
        d = self.db.query(Device).filter_by(id="1").first()
        self.assertIsNotNone(d.last_seen_at)
        self.assertEqual(d.valve_state, ValveState.OPEN)

    def test_handle_telemetry_null_ts_fallback(self):
        """Memverifikasi fallback ts: null menggunakan received_at (waktu server UTC)."""
        result = handle_telemetry(self.db, "1", self.telemetry_null_ts_fixture)

        self.assertTrue(result.success)
        t = self.db.query(Telemetry).filter_by(device_id="1", msg_id=self.telemetry_null_ts_fixture["msg_id"]).first()
        self.assertIsNotNone(t)
        self.assertEqual(t.valve_state, ValveState.CLOSED)
        # device_ts harus diisi fallback received_at
        self.assertIsNotNone(t.device_ts)

        d = self.db.query(Device).filter_by(id="1").first()
        self.assertEqual(d.valve_state, ValveState.CLOSED)
        self.assertIsNotNone(d.last_seen_at)

    def test_handle_telemetry_deduplication_k4(self):
        """Memverifikasi KPI K4: deduplikasi msg_id per perangkat (idempotent, 0 duplikat)."""
        # Pengiriman pertama
        res1 = handle_telemetry(self.db, "1", self.telemetry_fixture)
        self.assertTrue(res1.success)
        self.assertFalse(res1.is_duplicate)

        # Pengiriman ulang isi buffer (msg_id yang sama persis)
        res2 = handle_telemetry(self.db, "1", self.telemetry_fixture)
        self.assertTrue(res2.success)
        self.assertTrue(res2.is_duplicate)

        # Pastikan hanya ada tepat 1 baris di tabel telemetry
        count = self.db.query(Telemetry).filter_by(device_id="1", msg_id=self.telemetry_fixture["msg_id"]).count()
        self.assertEqual(count, 1)

    def test_handle_telemetry_invalid_schema_discarded(self):
        """Memverifikasi telemetri dengan skema tidak valid dibuang tanpa throw/crash."""
        bad_payload = {"msg_id": 999, "flow_lpm": "bukan_angka"}
        res = handle_telemetry(self.db, "1", bad_payload)
        self.assertFalse(res.success)
        self.assertIsNotNone(res.error)

        count = self.db.query(Telemetry).filter_by(device_id="1", msg_id=999).count()
        self.assertEqual(count, 0)

    def test_handle_alert_leak(self):
        """Memverifikasi alert kebocoran tersimpan dengan status OPEN dan menutup valve."""
        result = handle_alert(self.db, "1", self.alert_fixture)

        self.assertTrue(result.success)

        # Cek alert di tabel alerts
        a = self.db.query(Alert).filter_by(room_id=1).first()
        self.assertIsNotNone(a)
        self.assertEqual(a.type, AlertType.LEAK)
        self.assertEqual(a.rule, AlertRule.CONTINUOUS)
        self.assertEqual(a.status, AlertStatus.OPEN)
        self.assertIsNone(a.resolved_at)
        self.assertIn("flow_lpm", a.detail)
        self.assertEqual(a.detail["flow_lpm"], 6.4)

        # Cek valve di device berubah menjadi CLOSED
        d = self.db.query(Device).filter_by(id="1").first()
        self.assertEqual(d.valve_state, ValveState.CLOSED)
        self.assertIsNotNone(d.last_seen_at)

    def test_handle_status_boot(self):
        """Memverifikasi status BOOT memperbarui status valve dan last_seen_at."""
        res = handle_status(self.db, "1", self.status_boot_fixture)

        self.assertTrue(res.success)
        d = self.db.query(Device).filter_by(id="1").first()
        self.assertEqual(d.valve_state, ValveState.CLOSED)
        self.assertIsNotNone(d.last_seen_at)

    def test_handle_status_manual_button(self):
        """Memverifikasi event MANUAL_BUTTON mencatat command, alert ACTIVITY, dan resolve alert leak aktif."""
        # 1. Buat alert LEAK aktif terlebih dahulu
        leak_alert = Alert(
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
            detail={"flow_lpm": 6.4},
        )
        self.db.add(leak_alert)
        self.db.commit()

        # 2. ESP32 mengirim status MANUAL_BUTTON dengan valve OPEN
        res = handle_status(self.db, "1", self.status_manual_fixture)
        self.assertTrue(res.success)

        # 3. Cek pencatatan di valve_commands
        cmd = self.db.query(ValveCommand).filter_by(room_id=1, source=CommandSource.MANUAL_BUTTON).first()
        self.assertIsNotNone(cmd)
        self.assertEqual(cmd.action, CommandAction.OPEN)
        self.assertEqual(cmd.status, CommandStatus.SUCCESS)
        self.assertIsNotNone(cmd.acked_at)

        # 4. Cek pencatatan di alerts (ACTIVITY / INFO)
        act_alert = self.db.query(Alert).filter_by(room_id=1, type=AlertType.ACTIVITY).first()
        self.assertIsNotNone(act_alert)
        self.assertEqual(act_alert.rule, AlertRule.MANUAL_BUTTON)
        self.assertEqual(act_alert.status, AlertStatus.INFO)

        # 5. Cek alert LEAK sebelumnya otomatis RESOLVED oleh MANUAL_BUTTON
        self.db.refresh(leak_alert)
        self.assertEqual(leak_alert.status, AlertStatus.RESOLVED)
        self.assertEqual(leak_alert.resolved_by, AlertResolvedBy.MANUAL_BUTTON)
        self.assertIsNotNone(leak_alert.resolved_at)

        # 6. Cek status device berubah menjadi OPEN
        d = self.db.query(Device).filter_by(id="1").first()
        self.assertEqual(d.valve_state, ValveState.OPEN)
        self.assertIsNotNone(d.last_seen_at)

    def test_handle_unregistered_device(self):
        """Memverifikasi penanganan pesan dari device yang tidak terdaftar ditolak secara aman."""
        res = handle_telemetry(self.db, "999", self.telemetry_fixture)
        self.assertFalse(res.success)
        self.assertIn("Perangkat tidak terdaftar", res.error)

    def test_route_mqtt_message(self):
        """Memverifikasi fungsi perutean pesan (route_mqtt_message) berdasarkan topik."""
        # Topik telemetry
        payload_bytes = json.dumps(self.telemetry_fixture).encode("utf-8")
        res = route_mqtt_message(self.db, "swm/1/telemetry", payload_bytes)
        self.assertTrue(res.success)

        # Topik alert
        alert_bytes = json.dumps(self.alert_fixture).encode("utf-8")
        res = route_mqtt_message(self.db, "swm/1/alert", alert_bytes)
        self.assertTrue(res.success)

        # Topik tidak dikenal
        res = route_mqtt_message(self.db, "swm/1/unknown", payload_bytes)
        self.assertFalse(res.success)
        self.assertIn("Topik tidak dikenali", res.error)

        # Topik format salah
        res = route_mqtt_message(self.db, "invalid_topic", payload_bytes)
        self.assertFalse(res.success)

        # Malformed JSON
        res = route_mqtt_message(self.db, "swm/1/telemetry", b"invalid json content{")
        self.assertFalse(res.success)
        self.assertIn("JSON tidak valid", res.error)

    def test_create_mqtt_client_and_on_message_callback(self):
        """Memverifikasi instance MQTT client terbuat dan callback on_message memproses pesan."""
        from app.mqtt.client import create_mqtt_client

        class MockMQTTMessage:
            def __init__(self, topic: str, payload: bytes, qos: int = 1):
                self.topic = topic
                self.payload = payload
                self.qos = qos

        client = create_mqtt_client(
            client_id="test-client-ingest",
            session_factory=self.Session,
        )
        self.assertIsNotNone(client)

        # Simulasikan pesan telemetry masuk lewat on_message
        msg = MockMQTTMessage(
            topic="swm/1/telemetry",
            payload=json.dumps(self.telemetry_fixture).encode("utf-8"),
        )
        client.on_message(client, None, msg)

        # Verifikasi data tersimpan di DB
        t = self.db.query(Telemetry).filter_by(device_id="1", msg_id=self.telemetry_fixture["msg_id"]).first()
        self.assertIsNotNone(t)
        self.assertEqual(t.flow_lpm, 6.4)


if __name__ == "__main__":
    unittest.main()

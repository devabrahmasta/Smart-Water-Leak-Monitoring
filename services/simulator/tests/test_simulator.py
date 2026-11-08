"""
Unit & Integration Tests untuk Simulator Kamar Dummy (R-04).
Menguji 6 skenario (normal, leak-continuous, leak-stable, quiet-hours, offline, no-ack),
kendali perintah valve (cmd -> ack), event boot/tombol fisik, dan integrasi dengan ingest worker.
"""

import sys
import unittest
from pathlib import Path
from datetime import datetime, timezone

# Tambahkan root repo ke sys.path
root_dir = Path(__file__).resolve().parent.parent.parent.parent
api_dir = root_dir / "services" / "api"
sim_dir = root_dir / "services" / "simulator"

for p in [str(root_dir), str(api_dir), str(sim_dir)]:
    if p not in sys.path:
        sys.path.insert(0, p)

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.telemetry import Telemetry
from app.mqtt.validator import validate_payload
from app.mqtt.handlers import handle_telemetry

from services.simulator.state import SimulatorState
from services.simulator.scenarios import (
    NormalScenario,
    ContinuousLeakScenario,
    StableLeakScenario,
    QuietHoursScenario,
    OfflineScenario,
    NoAckScenario,
    get_scenario,
)
from services.simulator.device import SimulatedDevice


class TestSimulator(unittest.TestCase):
    def setUp(self):
        # Buat state baru untuk setiap test tanpa menyimpan ke disk
        self.state = SimulatorState(device_id="2", valve_state="OPEN", persist_path=None)
        self.device = SimulatedDevice(state=self.state)

    def test_simulator_initialization_and_monotonic_msg_id(self):
        """Memverifikasi inisialisasi state dan kenaikan monotonik msg_id."""
        self.assertEqual(self.state.device_id, "2")
        self.assertEqual(self.state.valve_state, "OPEN")
        m1 = self.state.next_msg_id()
        m2 = self.state.next_msg_id()
        self.assertEqual(m2, m1 + 1)

    def test_normal_telemetry_schema(self):
        """Memverifikasi payload telemetri pada skenario normal sesuai kontrak JSON Schema."""
        self.device.set_scenario("normal")
        telemetry = self.device.step()
        self.assertIsNotNone(telemetry)

        is_valid, err = validate_payload("telemetry", telemetry)
        self.assertTrue(is_valid, f"Telemetry tidak valid: {err}")
        self.assertEqual(telemetry["valve"], "OPEN")
        self.assertGreaterEqual(telemetry["flow_lpm"], 0.0)
        self.assertGreaterEqual(telemetry["volume_l_delta"], 0.0)
        self.assertIsNotNone(telemetry["ts"])

    def test_cmd_open_close_and_ack_flow(self):
        """Memverifikasi penerimaan perintah cmd menghasilkan ack yang valid dan mengubah status valve."""
        self.device.set_scenario("normal")

        # Perintah TUTUP
        cmd_close = {"command_id": 512, "action": "CLOSE"}
        ack = self.device.handle_command(cmd_close)

        self.assertIsNotNone(ack)
        is_valid, err = validate_payload("ack", ack)
        self.assertTrue(is_valid, f"ACK tidak valid: {err}")
        self.assertEqual(ack["command_id"], 512)
        self.assertEqual(ack["result"], "OK")
        self.assertEqual(ack["valve"], "CLOSED")
        self.assertEqual(self.state.valve_state, "CLOSED")

        # Telemetri saat valve CLOSED harus memiliki flow 0.0 dan volume 0.0
        telemetry = self.device.step()
        self.assertEqual(telemetry["valve"], "CLOSED")
        self.assertEqual(telemetry["flow_lpm"], 0.0)
        self.assertEqual(telemetry["volume_l_delta"], 0.0)

        # Perintah BUKA
        cmd_open = {"command_id": 513, "action": "OPEN"}
        ack_open = self.device.handle_command(cmd_open)
        self.assertIsNotNone(ack_open)
        self.assertEqual(ack_open["result"], "OK")
        self.assertEqual(ack_open["valve"], "OPEN")
        self.assertEqual(self.state.valve_state, "OPEN")

    def test_no_ack_scenario(self):
        """Memverifikasi skenario no-ack sengaja tidak mengembalikan respons ACK."""
        self.device.set_scenario("no-ack")

        cmd = {"command_id": 514, "action": "CLOSE"}
        ack = self.device.handle_command(cmd)

        self.assertIsNone(ack, "Skenario no-ack seharusnya tidak menghasilkan pesan ACK")
        # Valve tetap berubah secara internal pada perangkat
        self.assertEqual(self.state.valve_state, "CLOSED")

    def test_leak_continuous_scenario_triggers_alert_and_closes_valve(self):
        """Memverifikasi skenario leak-continuous memicu alert CONTINUOUS dan menutup valve."""
        # Gunakan ticks_to_trigger rendah untuk pengujian cepat
        self.device.set_scenario("leak-continuous", ticks_to_trigger=3)

        # Step 1 & 2: Aliran kontinu normal
        t1 = self.device.step()
        self.assertIsNotNone(t1)
        self.assertIsNone(self.device.last_alert)

        t2 = self.device.step()
        self.assertIsNotNone(t2)
        self.assertIsNone(self.device.last_alert)

        # Step 3: Ambang batas tercapai -> alert terpicu
        t3 = self.device.step()
        self.assertIsNotNone(self.device.last_alert)

        alert = self.device.last_alert
        is_valid, err = validate_payload("alert", alert)
        self.assertTrue(is_valid, f"Alert tidak valid: {err}")
        self.assertEqual(alert["rule"], "CONTINUOUS")
        self.assertEqual(alert["valve"], "CLOSED")
        self.assertEqual(self.state.valve_state, "CLOSED")

    def test_leak_stable_scenario_triggers_alert_and_closes_valve(self):
        """Memverifikasi skenario leak-stable memicu alert STABLE dan menutup valve."""
        self.device.set_scenario("leak-stable", ticks_to_trigger=3)

        for _ in range(3):
            self.device.step()

        self.assertIsNotNone(self.device.last_alert)
        alert = self.device.last_alert
        is_valid, err = validate_payload("alert", alert)
        self.assertTrue(is_valid, f"Alert tidak valid: {err}")
        self.assertEqual(alert["rule"], "STABLE")
        self.assertEqual(alert["valve"], "CLOSED")
        self.assertEqual(self.state.valve_state, "CLOSED")

    def test_quiet_hours_scenario_triggers_alert_and_closes_valve(self):
        """Memverifikasi skenario quiet-hours memicu alert QUIET_HOURS dan menutup valve."""
        self.device.set_scenario("quiet-hours", ticks_to_trigger=3)

        for _ in range(3):
            self.device.step()

        self.assertIsNotNone(self.device.last_alert)
        alert = self.device.last_alert
        is_valid, err = validate_payload("alert", alert)
        self.assertTrue(is_valid, f"Alert tidak valid: {err}")
        self.assertEqual(alert["rule"], "QUIET_HOURS")
        self.assertEqual(alert["valve"], "CLOSED")
        self.assertEqual(self.state.valve_state, "CLOSED")

    def test_offline_scenario_produces_no_telemetry(self):
        """Memverifikasi skenario offline tidak menghasilkan pesan telemetri (diam)."""
        self.device.set_scenario("offline")
        telemetry = self.device.step()
        self.assertIsNone(telemetry, "Skenario offline tidak boleh menghasilkan telemetri")

    def test_manual_button_event(self):
        """Memverifikasi penekanan tombol fisik menghasilkan payload status MANUAL_BUTTON."""
        status_msg = self.device.press_button()

        self.assertIsNotNone(status_msg)
        is_valid, err = validate_payload("status", status_msg)
        self.assertTrue(is_valid, f"Status MANUAL_BUTTON tidak valid: {err}")
        self.assertEqual(status_msg["source"], "MANUAL_BUTTON")
        # Valve awalnya OPEN, setelah tombol fisik ditekan menjadi CLOSED
        self.assertEqual(status_msg["valve"], "CLOSED")
        self.assertEqual(self.state.valve_state, "CLOSED")

    def test_boot_status_event(self):
        """Memverifikasi restart/boot menghasilkan payload status BOOT."""
        status_msg = self.device.boot()

        self.assertIsNotNone(status_msg)
        is_valid, err = validate_payload("status", status_msg)
        self.assertTrue(is_valid, f"Status BOOT tidak valid: {err}")
        self.assertEqual(status_msg["source"], "BOOT")
        self.assertEqual(status_msg["valve"], self.state.valve_state)

    def test_simulator_telemetry_ingest_roundtrip(self):
        """Memverifikasi telemetri dari simulator diproses dan tersimpan di database backend (kriteria R-04)."""
        # Siapkan SQLite DB in-memory untuk backend ingest
        engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(engine)
        db = sessionmaker(bind=engine)()

        # Seed Kamar 2 dan Device 2
        r2 = Room(id=2, name="Kamar 2", sort_order=2, is_simulated=True)
        db.add(r2)
        db.flush()
        d2 = Device(id="2", room_id=2, valve_state=ValveState.OPEN)
        db.add(d2)
        db.commit()

        # Generate telemetri dari simulator skenario normal
        self.device.set_scenario("normal")
        telemetry = self.device.step()
        self.assertIsNotNone(telemetry)

        # Proses lewat ingest handler backend
        result = handle_telemetry(db, "2", telemetry)
        self.assertTrue(result.success)
        self.assertFalse(result.is_duplicate)

        # Cek data tersimpan di tabel telemetry
        saved = db.query(Telemetry).filter_by(device_id="2", msg_id=telemetry["msg_id"]).first()
        self.assertIsNotNone(saved)
        self.assertEqual(saved.valve_state, ValveState.OPEN)

        # Cek devices.last_seen_at terupdate
        db.refresh(d2)
        self.assertIsNotNone(d2.last_seen_at)
        db.close()


if __name__ == "__main__":
    unittest.main()

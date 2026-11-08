"""Ambang per kamar dan skenario simulator (CONTRACT.md versi 1.1)."""

import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_db, get_mqtt_publisher
from app.config import settings
from app.database import Base
from app.main import app
from app.models.alert import Alert, AlertRule, AlertStatus, AlertType
from app.models.device import Device, ValveState
from app.models.room import Room
from app.mqtt.handlers import handle_alert


class FakePublisher:
    def __init__(self):
        self.messages = []

    def publish(self, topic, payload, qos=1, retain=False):
        self.messages.append((topic, payload, qos, retain))
        return True


class TestRoomRules(unittest.TestCase):
    def setUp(self):
        engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(engine)
        self.Session = sessionmaker(bind=engine)
        db = self.Session()
        db.add_all(
            [
                Room(id=1, name="Kamar 1", sort_order=1, is_simulated=False),
                Room(id=2, name="Kamar 2", sort_order=2, is_simulated=True),
                Device(id="1", room_id=1, valve_state=ValveState.OPEN),
                Device(id="2", room_id=2, valve_state=ValveState.CLOSED),
            ]
        )
        db.commit()
        db.close()

        def override_db():
            session = self.Session()
            try:
                yield session
            finally:
                session.close()

        self.mqtt = FakePublisher()
        app.dependency_overrides[get_db] = override_db
        app.dependency_overrides[get_mqtt_publisher] = lambda: self.mqtt
        self.client = TestClient(app)
        self.auth = {"Authorization": f"Bearer {settings.API_OWNER_TOKEN}"}

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_default_rules(self):
        r = self.client.get("/v1/rooms/1/rules", headers=self.auth)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(
            r.json(),
            {
                "room_id": 1,
                "continuous_sec": 2700,
                "stable_sec": 300,
                "quiet_sec": 300,
                "quiet_start": "01:00",
                "quiet_end": "04:00",
            },
        )

    def test_update_is_per_room_and_published_retained(self):
        body = {
            "continuous_sec": 600,
            "stable_sec": 1,
            "quiet_sec": 900,
            "quiet_start": "22:30",
            "quiet_end": "05:00",
        }
        r = self.client.put("/v1/rooms/1/rules", json=body, headers=self.auth)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["stable_sec"], 1)
        self.assertEqual(r.json()["quiet_start"], "22:30")
        self.assertEqual(self.mqtt.messages, [("swm/1/config", body, 1, True)])
        # Kamar lain tetap memakai nilai bawaan.
        other = self.client.get("/v1/rooms/2/rules", headers=self.auth).json()
        self.assertEqual(other["stable_sec"], 300)

    def test_update_rejects_out_of_range(self):
        valid = {
            "continuous_sec": 2700,
            "stable_sec": 300,
            "quiet_sec": 300,
            "quiet_start": "01:00",
            "quiet_end": "04:00",
        }
        for change in (
            {"continuous_sec": 0},
            {"stable_sec": 86401},
            {"quiet_start": "25:00"},
            {"quiet_end": "1:00"},
            {"quiet_end": "01:00"},
        ):
            with self.subTest(change=change):
                r = self.client.put(
                    "/v1/rooms/1/rules", json={**valid, **change}, headers=self.auth
                )
                self.assertEqual(r.status_code, 422)
                self.assertEqual(r.json()["error"]["code"], "INVALID_PAYLOAD")
        self.assertEqual(self.mqtt.messages, [])

    def test_rules_need_token_and_room(self):
        self.assertEqual(self.client.get("/v1/rooms/1/rules").status_code, 401)
        self.assertEqual(self.client.get("/v1/rooms/9/rules", headers=self.auth).status_code, 404)

    def test_demo_rejected_for_real_room(self):
        r = self.client.post(
            "/v1/rooms/1/demo-scenario", json={"scenario": "LEAK_STABLE"}, headers=self.auth
        )
        self.assertEqual(r.status_code, 409)
        self.assertEqual(r.json()["error"]["code"], "NOT_SIMULATED")
        self.assertEqual(self.mqtt.messages, [])

    def test_demo_resets_simulated_room_and_publishes(self):
        db = self.Session()
        db.add(
            Alert(
                room_id=2,
                type=AlertType.LEAK,
                rule=AlertRule.STABLE,
                status=AlertStatus.OPEN,
                created_at=datetime.now(timezone.utc),
                detail={},
            )
        )
        db.commit()
        db.close()

        r = self.client.post(
            "/v1/rooms/2/demo-scenario", json={"scenario": "LEAK_STABLE"}, headers=self.auth
        )
        self.assertEqual(r.status_code, 202)
        self.assertEqual(self.mqtt.messages, [("swm/2/demo", {"scenario": "LEAK_STABLE"}, 1, False)])

        db = self.Session()
        self.assertEqual(db.query(Alert).first().status, AlertStatus.RESOLVED)
        self.assertEqual(db.query(Device).filter_by(id="2").first().valve_state, ValveState.OPEN)
        db.close()

    def test_demo_rejects_unknown_scenario(self):
        r = self.client.post(
            "/v1/rooms/2/demo-scenario", json={"scenario": "ASAL"}, headers=self.auth
        )
        self.assertEqual(r.status_code, 422)


class TestAlertDedup(unittest.TestCase):
    """Pesan QoS 1 bisa terkirim ulang: msg_id sama tidak boleh jadi dua alert."""

    def test_same_msg_id_creates_one_alert(self):
        engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(engine)
        db = sessionmaker(bind=engine)()
        db.add_all(
            [
                Room(id=2, name="Kamar 2", sort_order=2, is_simulated=True),
                Device(id="2", room_id=2, valve_state=ValveState.OPEN),
            ]
        )
        db.commit()
        payload = {
            "msg_id": 2237,
            "ts": "2026-11-08T15:24:46Z",
            "rule": "STABLE",
            "flow_lpm": 6.0,
            "valve": "CLOSED",
        }
        self.assertTrue(handle_alert(db, "2", payload).success)
        second = handle_alert(db, "2", payload)
        self.assertTrue(second.success)
        self.assertTrue(second.is_duplicate)
        self.assertEqual(db.query(Alert).count(), 1)

        payload_new = {**payload, "msg_id": 2238}
        self.assertFalse(handle_alert(db, "2", payload_new).is_duplicate)
        self.assertEqual(db.query(Alert).count(), 2)
        db.close()


if __name__ == "__main__":
    unittest.main()

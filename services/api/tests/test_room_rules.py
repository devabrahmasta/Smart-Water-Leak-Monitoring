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
            {"room_id": 1, "continuous_sec": 2700, "stable_sec": 300, "quiet_sec": 300},
        )

    def test_update_is_per_room_and_published_retained(self):
        body = {"continuous_sec": 600, "stable_sec": 1800, "quiet_sec": 900}
        r = self.client.put("/v1/rooms/1/rules", json=body, headers=self.auth)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["stable_sec"], 1800)
        self.assertEqual(self.mqtt.messages, [("swm/1/config", body, 1, True)])
        # Kamar lain tetap memakai nilai bawaan.
        other = self.client.get("/v1/rooms/2/rules", headers=self.auth).json()
        self.assertEqual(other["stable_sec"], 300)

    def test_update_rejects_out_of_range(self):
        body = {"continuous_sec": 5, "stable_sec": 300, "quiet_sec": 300}
        r = self.client.put("/v1/rooms/1/rules", json=body, headers=self.auth)
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


if __name__ == "__main__":
    unittest.main()

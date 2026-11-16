"""Debit langsung dan grafik aliran (CONTRACT.md versi 1.3)."""

import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_db
from app.config import settings
from app.database import Base
from app.main import app
from app.models.device import Device, ValveState
from app.models.device_live import DeviceLive
from app.models.room import Room
from app.models.telemetry import Telemetry
from app.mqtt.handlers import route_mqtt_message


class TestLiveFlow(unittest.TestCase):
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
                Device(id="1", room_id=1, valve_state=ValveState.OPEN),
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

        app.dependency_overrides[get_db] = override_db
        self.client = TestClient(app)
        self.auth = {"Authorization": f"Bearer {settings.API_OWNER_TOKEN}"}

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_live_message_keeps_only_latest_and_marks_online(self):
        db = self.Session()
        for flow in (1.0, 6.4):
            result = route_mqtt_message(
                db, "swm/1/live", f'{{"flow_lpm": {flow}, "valve": "OPEN"}}'.encode()
            )
            self.assertTrue(result.success)
        self.assertEqual(db.query(DeviceLive).count(), 1)
        self.assertEqual(db.query(DeviceLive).first().flow_lpm, 6.4)
        self.assertIsNotNone(db.query(Device).first().last_seen_at)
        self.assertEqual(db.query(Telemetry).count(), 0)
        db.close()

    def test_live_message_rejects_invalid_payload(self):
        db = self.Session()
        result = route_mqtt_message(db, "swm/1/live", b'{"flow_lpm": -1, "valve": "OPEN"}')
        self.assertFalse(result.success)
        db.close()

    def test_live_endpoint_fresh_and_stale(self):
        db = self.Session()
        db.add(DeviceLive(device_id="1", flow_lpm=3.25, valve="OPEN", updated_at=datetime.now(timezone.utc)))
        db.commit()
        r = self.client.get("/v1/rooms/1/live", headers=self.auth).json()
        self.assertEqual(r["flow_lpm"], 3.25)
        self.assertEqual(r["valve"], "OPEN")

        live = db.query(DeviceLive).first()
        live.updated_at = datetime.now(timezone.utc) - timedelta(seconds=30)
        db.commit()
        db.close()
        r = self.client.get("/v1/rooms/1/live", headers=self.auth).json()
        self.assertIsNone(r["flow_lpm"])
        self.assertIsNotNone(r["at"])

    def test_flow_hourly_and_minute(self):
        db = self.Session()
        # 07:05 dan 07:05:30 WIB = 00:05 UTC; 08:00 WIB = 01:00 UTC.
        base = datetime(2026, 11, 13, 0, 5, tzinfo=timezone.utc)
        for i, (ts, flow) in enumerate(
            [(base, 2.0), (base + timedelta(seconds=30), 6.0), (base + timedelta(hours=1, minutes=-5), 1.0)]
        ):
            db.add(
                Telemetry(
                    device_id="1",
                    msg_id=i + 1,
                    device_ts=ts,
                    received_at=ts,
                    flow_lpm=flow,
                    volume_l_delta=0.1,
                    valve_state=ValveState.OPEN,
                )
            )
        db.commit()
        db.close()

        hourly = self.client.get("/v1/rooms/1/flow?date=2026-11-13", headers=self.auth).json()
        self.assertEqual(hourly["resolution"], "HOUR")
        self.assertEqual(len(hourly["series"]), 24)
        self.assertEqual(hourly["series"][7], {"label": "07", "avg_lpm": 4.0, "max_lpm": 6.0})
        self.assertEqual(hourly["series"][8]["max_lpm"], 1.0)

        minute = self.client.get("/v1/rooms/1/flow?date=2026-11-13&hour=7", headers=self.auth).json()
        self.assertEqual(minute["resolution"], "MINUTE")
        self.assertEqual(len(minute["series"]), 60)
        self.assertEqual(minute["series"][5]["max_lpm"], 6.0)
        self.assertEqual(minute["series"][6]["max_lpm"], 0.0)

    def test_flow_validation(self):
        self.assertEqual(self.client.get("/v1/rooms/1/flow?hour=24", headers=self.auth).status_code, 422)
        self.assertEqual(self.client.get("/v1/rooms/9/flow", headers=self.auth).status_code, 404)
        self.assertEqual(self.client.get("/v1/rooms/1/live").status_code, 401)


if __name__ == "__main__":
    unittest.main()

"""
Integration & Contract Tests untuk REST API Lengkap Bagian 4.5 & Ekspor openapi.json (R-07).
Kriteria Selesai (PRD 5.2):
- Tiap endpoint punya tes respons terhadap fixture
- Endpoint merespons sesuai struktur CONTRACT.md Bagian 3
- make contracts tidak menghasilkan diff (idempoten)
- Autentikasi Bearer token pemilik diuji di semua endpoint v1
"""

import os
import sys
import json
import unittest
from pathlib import Path
from datetime import datetime, date, timedelta, timezone
from zoneinfo import ZoneInfo

# Matikan scheduler saat testing
os.environ["ENABLE_SCHEDULER"] = "false"

# Pastikan services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

root_dir = api_dir.parent.parent
fixtures_dir = root_dir / "packages" / "contracts" / "fixtures"

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from app.database import Base
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.telemetry import Telemetry
from app.models.usage import DailyUsage, MonthlyUsage
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus, AlertResolvedBy
from app.models.command import ValveCommand, CommandAction, CommandSource, CommandStatus
from app.models.notification import PushToken
from app.main import app
from app.api.deps import get_db, get_mqtt_publisher
from app.config import settings
from scripts.export_openapi import export_openapi


def load_fixture(name: str) -> dict:
    with open(fixtures_dir / name, "r", encoding="utf-8") as f:
        return json.load(f)


class MockMQTTPublisher:
    def __init__(self):
        self.published = []

    def publish(self, topic: str, payload: dict, qos: int = 1) -> bool:
        self.published.append({"topic": topic, "payload": payload, "qos": qos})
        return True


class TestRestAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Database SQLite in-memory dengan StaticPool agar dapat diakses across threads
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

        def override_get_mqtt():
            return cls.mock_mqtt

        app.dependency_overrides[get_db] = override_get_db
        app.dependency_overrides[get_mqtt_publisher] = override_get_mqtt

        cls.client = TestClient(app)
        cls.auth_headers = {"Authorization": f"Bearer {settings.API_OWNER_TOKEN}"}
        cls.wib_tz = ZoneInfo("Asia/Jakarta")

    def setUp(self):
        self.db = self.Session()
        # Bersihkan seluruh tabel
        self.db.query(PushToken).delete()
        self.db.query(ValveCommand).delete()
        self.db.query(Alert).delete()
        self.db.query(DailyUsage).delete()
        self.db.query(MonthlyUsage).delete()
        self.db.query(Telemetry).delete()
        self.db.query(Device).delete()
        self.db.query(Room).delete()
        self.db.commit()

        # Seed data awal 2 kamar
        self.room1 = Room(id=1, name="Kamar 1", sort_order=1, is_simulated=False)
        self.room2 = Room(id=2, name="Kamar 2", sort_order=2, is_simulated=True)
        self.db.add_all([self.room1, self.room2])
        self.db.commit()

        now_utc = datetime.now(timezone.utc)

        # Device 1: ONLINE, OPEN, flow_lpm = 6.4
        self.dev1 = Device(
            id="1",
            room_id=1,
            valve_state=ValveState.OPEN,
            last_seen_at=now_utc - timedelta(seconds=5),
            firmware_version="1.0.0",
        )
        # Device 2: OFFLINE (> 30s), OPEN
        self.dev2 = Device(
            id="2",
            room_id=2,
            valve_state=ValveState.OPEN,
            last_seen_at=now_utc - timedelta(seconds=60),
            firmware_version="1.0.0",
        )
        self.db.add_all([self.dev1, self.dev2])
        self.db.commit()

        # Telemetry terbaru untuk Kamar 1 (flow_lpm = 6.4)
        t1 = Telemetry(
            device_id="1",
            msg_id=101,
            device_ts=now_utc - timedelta(seconds=5),
            received_at=now_utc - timedelta(seconds=5),
            flow_lpm=6.4,
            volume_l_delta=1.07,
            valve_state=ValveState.OPEN,
        )
        self.db.add(t1)

        # Daily usage hari ini untuk Kamar 1 (182.4 L)
        today_wib = now_utc.astimezone(self.wib_tz).date()
        du1 = DailyUsage(
            room_id=1,
            date=today_wib,
            volume_l=182.4,
            peak_flow_lpm=6.4,
        )
        self.db.add(du1)

        # Monthly usage bulan ini untuk Kamar 1 (2410.0 L)
        month_str = today_wib.strftime("%Y-%m")
        mu1 = MonthlyUsage(
            room_id=1,
            month=month_str,
            volume_l=2410.0,
        )
        self.db.add(mu1)

        # Alert OPEN untuk Kamar 1
        a1 = Alert(
            id=31,
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            created_at=now_utc - timedelta(minutes=10),
            detail={"flow_lpm": 6.4, "duration_min": 45},
        )
        self.db.add(a1)
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def test_get_summary_success_and_matches_fixture_keys(self):
        """Memverifikasi respons GET /v1/summary sesuai kontrak dan fixture rest_summary.json."""
        resp = self.client.get("/v1/summary", headers=self.auth_headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        fixture = load_fixture("rest_summary.json")
        for key in fixture.keys():
            self.assertIn(key, data, f"Key '{key}' harus ada pada respons /v1/summary")

        # Verifikasi tipe dan nilai dasar
        self.assertIsInstance(data["today_l"], (int, float))
        self.assertIsInstance(data["month_l"], (int, float))
        self.assertEqual(len(data["last_7_days_l"]), 7)
        self.assertIn("normal", data["tally"])
        self.assertIn("closed", data["tally"])
        self.assertIn("offline", data["tally"])
        self.assertEqual(data["tally"]["offline"], 1)  # Kamar 2 offline
        self.assertEqual(data["open_alert_count"], 1)
        self.assertIsNotNone(data["latest_open_alert"])
        self.assertEqual(data["latest_open_alert"]["id"], 31)
        self.assertEqual(data["latest_open_alert"]["type"], "LEAK")

    def test_get_rooms_all_filter_and_offline_null_values(self):
        """Memverifikasi GET /v1/rooms?filter=all dan aturan null untuk kamar offline."""
        resp = self.client.get("/v1/rooms", headers=self.auth_headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn("rooms", data)
        rooms = data["rooms"]
        self.assertEqual(len(rooms), 2)

        fixture = load_fixture("rest_rooms.json")
        fixture_item_keys = set(fixture["rooms"][0].keys())
        for rm in rooms:
            self.assertEqual(set(rm.keys()), fixture_item_keys)

        # Kamar 1: ONLINE, memiliki LEAK alert aktif -> status LEAK
        r1 = next(r for r in rooms if r["id"] == 1)
        self.assertEqual(r1["status"], "LEAK")
        self.assertEqual(r1["today_l"], 182.4)
        self.assertEqual(r1["flow_lpm"], 6.4)
        self.assertTrue(r1["is_highest"])

        # Kamar 2: OFFLINE -> today_l dan flow_lpm harus NULL sesuai CONTRACT.md
        r2 = next(r for r in rooms if r["id"] == 2)
        self.assertEqual(r2["status"], "OFFLINE")
        self.assertIsNone(r2["today_l"])
        self.assertIsNone(r2["flow_lpm"])
        self.assertFalse(r2["is_highest"])

    def test_get_rooms_filtered_attention_and_offline(self):
        """Memverifikasi filter query pada GET /v1/rooms: attention dan offline."""
        # filter=offline -> hanya Kamar 2
        resp_off = self.client.get("/v1/rooms?filter=offline", headers=self.auth_headers)
        self.assertEqual(resp_off.status_code, 200)
        rooms_off = resp_off.json()["rooms"]
        self.assertEqual(len(rooms_off), 1)
        self.assertEqual(rooms_off[0]["id"], 2)

        # filter=attention -> Kamar 1 (LEAK) dan Kamar 2 (OFFLINE)
        resp_att = self.client.get("/v1/rooms?filter=attention", headers=self.auth_headers)
        self.assertEqual(resp_att.status_code, 200)
        rooms_att = resp_att.json()["rooms"]
        self.assertEqual(len(rooms_att), 2)

    def test_get_room_detail_success_and_not_found(self):
        """Memverifikasi GET /v1/rooms/{id} sukses dan 404 jika tidak ditemukan."""
        resp = self.client.get("/v1/rooms/1", headers=self.auth_headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        fixture = load_fixture("rest_room_detail.json")
        for key in fixture.keys():
            self.assertIn(key, data, f"Key '{key}' harus ada pada /v1/rooms/1")

        self.assertEqual(data["room"]["id"], 1)
        self.assertEqual(data["month_l"], 2410.0)
        self.assertIsInstance(data["avg_daily_l"], (int, float))
        self.assertEqual(len(data["recent_alerts"]), 1)
        self.assertEqual(data["recent_alerts"][0]["id"], 31)

        # 404 test
        resp_404 = self.client.get("/v1/rooms/999", headers=self.auth_headers)
        self.assertEqual(resp_404.status_code, 404)
        self.assertEqual(resp_404.json()["error"]["code"], "NOT_FOUND")

    def test_get_room_commands_history(self):
        """Memverifikasi GET /v1/rooms/{id}/commands mengembalikan riwayat perintah valve."""
        now_utc = datetime.now(timezone.utc)
        cmd = ValveCommand(
            id=512,
            room_id=2,
            action=CommandAction.OPEN,
            source=CommandSource.APP,
            status=CommandStatus.PENDING,
            created_at=now_utc - timedelta(seconds=10),
        )
        self.db.add(cmd)
        self.db.commit()

        resp = self.client.get("/v1/rooms/2/commands?limit=10", headers=self.auth_headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn("commands", data)
        self.assertEqual(len(data["commands"]), 1)
        self.assertEqual(data["commands"][0]["id"], 512)
        self.assertEqual(data["commands"][0]["action"], "OPEN")
        self.assertEqual(data["commands"][0]["status"], "PENDING")

    def test_get_usage_daily_and_by_room(self):
        """Memverifikasi GET /v1/usage?period=daily sesuai format rest_usage_daily.json."""
        resp = self.client.get("/v1/usage?period=daily", headers=self.auth_headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        fixture = load_fixture("rest_usage_daily.json")
        for key in fixture.keys():
            self.assertIn(key, data)

        self.assertEqual(data["period"], "daily")
        self.assertGreater(len(data["series"]), 0)
        self.assertEqual(data["total_l"], 182.4)
        self.assertIsNotNone(data["peak"])
        self.assertIsNotNone(data["by_room"])
        self.assertEqual(len(data["by_room"]), 2)

        # Test per kamar: GET /v1/rooms/1/usage?period=daily
        resp_room = self.client.get("/v1/rooms/1/usage?period=daily", headers=self.auth_headers)
        self.assertEqual(resp_room.status_code, 200)
        self.assertEqual(resp_room.json()["period"], "daily")

    def test_get_usage_monthly(self):
        """Memverifikasi GET /v1/usage?period=monthly."""
        resp = self.client.get("/v1/usage?period=monthly", headers=self.auth_headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["period"], "monthly")
        self.assertEqual(len(data["series"]), 1)
        self.assertEqual(data["total_l"], 2410.0)

    def test_get_alerts_pagination_and_status_filter(self):
        """Memverifikasi GET /v1/alerts dengan cursor pagination 'before' dan filter status."""
        now_utc = datetime.now(timezone.utc)
        # Tambahkan alert kedua
        a2 = Alert(
            id=32,
            room_id=1,
            type=AlertType.ANOMALY,
            rule=AlertRule.DAILY_RATIO,
            status=AlertStatus.RESOLVED,
            created_at=now_utc - timedelta(minutes=5),
            resolved_at=now_utc - timedelta(minutes=1),
            resolved_by=AlertResolvedBy.APP,
            detail={"today_l": 160.0, "avg_daily_l": 100.0, "ratio": 1.6},
        )
        self.db.add(a2)
        self.db.commit()

        # Filter open -> hanya ID 31
        resp_open = self.client.get("/v1/alerts?status=open", headers=self.auth_headers)
        self.assertEqual(resp_open.status_code, 200)
        items_open = resp_open.json()["items"]
        self.assertEqual(len(items_open), 1)
        self.assertEqual(items_open[0]["id"], 31)

        # Pagination: limit=1
        resp_p1 = self.client.get("/v1/alerts?limit=1", headers=self.auth_headers)
        self.assertEqual(resp_p1.status_code, 200)
        data_p1 = resp_p1.json()
        self.assertEqual(len(data_p1["items"]), 1)
        self.assertEqual(data_p1["items"][0]["id"], 32)
        self.assertEqual(data_p1["next_before"], 32)

        # Fetch next page using before=32
        resp_p2 = self.client.get("/v1/alerts?limit=1&before=32", headers=self.auth_headers)
        self.assertEqual(resp_p2.status_code, 200)
        data_p2 = resp_p2.json()
        self.assertEqual(len(data_p2["items"]), 1)
        self.assertEqual(data_p2["items"][0]["id"], 31)

    def test_get_alert_detail_and_manual_resolve(self):
        """Memverifikasi GET /v1/alerts/{id} dan POST /v1/alerts/{id}/resolve."""
        # 1. Detail alert
        resp = self.client.get("/v1/alerts/31", headers=self.auth_headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        fixture = load_fixture("rest_alert_detail.json")
        for key in fixture.keys():
            self.assertIn(key, data)
        self.assertEqual(data["id"], 31)
        self.assertEqual(data["status"], "OPEN")

        # 2. Resolve alert
        resp_res = self.client.post("/v1/alerts/31/resolve", headers=self.auth_headers)
        self.assertEqual(resp_res.status_code, 200)
        data_res = resp_res.json()
        self.assertEqual(data_res["status"], "RESOLVED")
        self.assertEqual(data_res["resolved_by"], "APP")
        self.assertIsNotNone(data_res["resolved_at"])

    def test_post_push_tokens_upsert_idempotent(self):
        """Memverifikasi pendaftaran token FCM POST /v1/push-tokens idempoten (HTTP 204)."""
        payload = {"token": "sample-fcm-test-token-12345", "platform": "android"}

        # First registration
        resp1 = self.client.post("/v1/push-tokens", json=payload, headers=self.auth_headers)
        self.assertEqual(resp1.status_code, 204)

        token_row = self.db.query(PushToken).filter_by(token="sample-fcm-test-token-12345").first()
        self.assertIsNotNone(token_row)
        self.assertEqual(token_row.platform, "android")

        # Second registration with platform change -> idempoten update
        payload["platform"] = "ios"
        resp2 = self.client.post("/v1/push-tokens", json=payload, headers=self.auth_headers)
        self.assertEqual(resp2.status_code, 204)

        self.db.refresh(token_row)
        self.assertEqual(token_row.platform, "ios")
        self.assertEqual(self.db.query(PushToken).count(), 1)

    def test_all_endpoints_require_bearer_auth(self):
        """Memverifikasi bahwa semua endpoint v1 menolak 401 UNAUTHORIZED jika token absen atau salah."""
        endpoints = [
            ("GET", "/v1/summary"),
            ("GET", "/v1/rooms"),
            ("GET", "/v1/rooms/1"),
            ("GET", "/v1/rooms/1/commands"),
            ("GET", "/v1/usage"),
            ("GET", "/v1/alerts"),
            ("GET", "/v1/alerts/31"),
            ("POST", "/v1/push-tokens"),
        ]

        for method, path in endpoints:
            with self.subTest(method=method, path=path):
                # 1. Tanpa header Authorization
                if method == "GET":
                    r = self.client.get(path)
                else:
                    r = self.client.post(path, json={})
                self.assertEqual(r.status_code, 401, f"{path} harus 401 tanpa token")
                self.assertEqual(r.json()["error"]["code"], "UNAUTHORIZED")

                # 2. Token salah
                bad_header = {"Authorization": "Bearer wrong_token_secret"}
                if method == "GET":
                    r2 = self.client.get(path, headers=bad_header)
                else:
                    r2 = self.client.post(path, json={}, headers=bad_header)
                self.assertEqual(r2.status_code, 401, f"{path} harus 401 dengan token salah")
                self.assertEqual(r2.json()["error"]["code"], "UNAUTHORIZED")

    def test_openapi_export_idempotent_no_diff(self):
        """Memverifikasi bahwa ekspor openapi.json idempoten dan memuat seluruh endpoint v1."""
        export_openapi()
        openapi_file = root_dir / "packages" / "contracts" / "openapi.json"
        self.assertTrue(openapi_file.exists())

        with open(openapi_file, "r", encoding="utf-8") as f:
            spec = json.load(f)

        paths = spec.get("paths", {})
        expected_paths = [
            "/health",
            "/v1/summary",
            "/v1/rooms",
            "/v1/rooms/{room_id}",
            "/v1/rooms/{room_id}/commands",
            "/v1/rooms/{room_id}/usage",
            "/v1/usage",
            "/v1/alerts",
            "/v1/alerts/{alert_id}",
            "/v1/alerts/{alert_id}/resolve",
            "/v1/push-tokens",
            "/v1/rooms/{room_id}/valve",
            "/v1/commands/{command_id}",
        ]
        for p in expected_paths:
            self.assertIn(p, paths, f"Path '{p}' harus terdaftar dalam openapi.json")


if __name__ == "__main__":
    unittest.main()

"""
Unit & Integration Tests untuk Database Models, Migrasi Alembic, dan Seeding (R-02).
"""

import os
import sys
import socket
from pathlib import Path
from datetime import date, datetime, timezone
import unittest

# Pastikan services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from sqlalchemy import inspect, create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import IntegrityError

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.telemetry import Telemetry
from app.models.usage import DailyUsage, MonthlyUsage
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus, AlertResolvedBy
from app.models.command import ValveCommand, CommandAction, CommandSource, CommandStatus
from app.models.rule_param import RuleParam
from app.models.notification import PushToken, Notification
from app.seed import seed_database


class TestDatabaseModelsAndSeed(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Periksa apakah PostgreSQL aktif via socket timeout singkat (0.5s)
        pg_alive = False
        try:
            with socket.create_connection(("localhost", settings.POSTGRES_PORT), timeout=0.5):
                pg_alive = True
        except OSError:
            pg_alive = False

        if pg_alive:
            try:
                with engine.connect() as conn:
                    pass
                cls.engine = engine
                cls.db = SessionLocal()
            except Exception:
                pg_alive = False

        if not pg_alive:
            cls.engine = create_engine("sqlite:///:memory:")
            Base.metadata.create_all(cls.engine)
            cls.Session = sessionmaker(bind=cls.engine)
            cls.db = cls.Session()

        seed_database(cls.db)

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    def setUp(self):
        self.db.rollback()
        # Bersihkan data uji sementara jika ada dari pengujian sebelumnya
        self.db.query(Telemetry).filter(Telemetry.msg_id >= 90000).delete()
        self.db.query(DailyUsage).filter(DailyUsage.date == date(2026, 11, 7)).delete()
        self.db.query(MonthlyUsage).filter(MonthlyUsage.month == "2026-11").delete()
        self.db.query(PushToken).filter(PushToken.token.like("sample-fcm-%")).delete()
        self.db.query(ValveCommand).filter(ValveCommand.user_id == "test_user").delete()
        self.db.commit()

    def tearDown(self):
        self.db.rollback()
        # Bersihkan data uji setelah pengujian
        self.db.query(Telemetry).filter(Telemetry.msg_id >= 90000).delete()
        self.db.query(DailyUsage).filter(DailyUsage.date == date(2026, 11, 7)).delete()
        self.db.query(MonthlyUsage).filter(MonthlyUsage.month == "2026-11").delete()
        self.db.query(PushToken).filter(PushToken.token.like("sample-fcm-%")).delete()
        self.db.query(Alert).filter(Alert.type == AlertType.LEAK).delete()
        self.db.query(Notification).delete()
        self.db.commit()

    def test_tables_created(self):
        """Memverifikasi bahwa seluruh 10 tabel aplikasi ada di database."""
        inspector = inspect(self.engine)
        table_names = inspector.get_table_names()
        expected_tables = [
            "rooms",
            "devices",
            "telemetry",
            "daily_usage",
            "monthly_usage",
            "alerts",
            "valve_commands",
            "rule_params",
            "push_tokens",
            "notifications",
        ]
        for table in expected_tables:
            with self.subTest(table=table):
                self.assertIn(table, table_names)

    def test_seeded_rooms_and_devices(self):
        """Memverifikasi bahwa seeding menghasilkan 2 kamar dan 2 perangkat sesuai spesifikasi."""
        rooms = self.db.query(Room).order_by(Room.sort_order).all()
        self.assertEqual(len(rooms), 2)

        # Kamar 1
        kamar1 = rooms[0]
        self.assertEqual(kamar1.name, "Kamar 1")
        self.assertEqual(kamar1.sort_order, 1)
        self.assertFalse(kamar1.is_simulated)
        self.assertIsNotNone(kamar1.device)
        self.assertEqual(kamar1.device.id, "1")
        self.assertEqual(kamar1.device.valve_state, ValveState.OPEN)

        # Kamar 2
        kamar2 = rooms[1]
        self.assertEqual(kamar2.name, "Kamar 2")
        self.assertEqual(kamar2.sort_order, 2)
        self.assertTrue(kamar2.is_simulated)
        self.assertIsNotNone(kamar2.device)
        self.assertEqual(kamar2.device.id, "2")
        self.assertEqual(kamar2.device.valve_state, ValveState.OPEN)

    def test_seeded_rule_params(self):
        """Memverifikasi 9 parameter aturan default dan fungsi helper konversi tipenya."""
        params = self.db.query(RuleParam).all()
        self.assertEqual(len(params), 9)

        leak_duration = self.db.query(RuleParam).filter(RuleParam.key == "leak_duration_min").first()
        self.assertIsNotNone(leak_duration)
        self.assertEqual(leak_duration.as_int(), 45)

        night_threshold = self.db.query(RuleParam).filter(RuleParam.key == "night_flow_threshold_lpm").first()
        self.assertIsNotNone(night_threshold)
        self.assertAlmostEqual(night_threshold.as_float(), 1.0)

        anomaly_ratio = self.db.query(RuleParam).filter(RuleParam.key == "anomaly_ratio").first()
        self.assertIsNotNone(anomaly_ratio)
        self.assertAlmostEqual(anomaly_ratio.as_float(), 1.5)

        quiet_start = self.db.query(RuleParam).filter(RuleParam.key == "quiet_start").first()
        self.assertIsNotNone(quiet_start)
        self.assertEqual(quiet_start.as_str(), "01:00")

    def test_telemetry_unique_constraint(self):
        """Memverifikasi batasan unik (device_id, msg_id) untuk deduplikasi (KPI K4)."""
        now = datetime.now(timezone.utc)
        t1 = Telemetry(
            device_id="1",
            msg_id=99901,
            device_ts=now,
            flow_lpm=5.5,
            volume_l_delta=0.9,
            valve_state=ValveState.OPEN,
        )
        self.db.add(t1)
        self.db.commit()

        # Duplikasi msg_id pada device_id yang sama harus melempar IntegrityError
        t2 = Telemetry(
            device_id="1",
            msg_id=99901,
            device_ts=now,
            flow_lpm=5.5,
            volume_l_delta=0.9,
            valve_state=ValveState.OPEN,
        )
        self.db.add(t2)
        with self.assertRaises(IntegrityError):
            self.db.commit()
        self.db.rollback()

    def test_daily_usage_unique_constraint(self):
        """Memverifikasi batasan unik (room_id, date) pada daily_usage."""
        today = date(2026, 11, 7)
        u1 = DailyUsage(room_id=1, date=today, volume_l=150.0, peak_flow_lpm=8.0)
        self.db.add(u1)
        self.db.commit()

        u2 = DailyUsage(room_id=1, date=today, volume_l=200.0, peak_flow_lpm=9.0)
        self.db.add(u2)
        with self.assertRaises(IntegrityError):
            self.db.commit()
        self.db.rollback()

    def test_monthly_usage_unique_constraint(self):
        """Memverifikasi batasan unik (room_id, month) pada monthly_usage."""
        u1 = MonthlyUsage(room_id=1, month="2026-11", volume_l=1500.0)
        self.db.add(u1)
        self.db.commit()

        u2 = MonthlyUsage(room_id=1, month="2026-11", volume_l=2000.0)
        self.db.add(u2)
        with self.assertRaises(IntegrityError):
            self.db.commit()
        self.db.rollback()

    def test_valve_command_lifecycle(self):
        """Memverifikasi pembuatan dan pembaruan perintah valve_command."""
        cmd = ValveCommand(
            room_id=1,
            action=CommandAction.OPEN,
            source=CommandSource.APP,
            user_id="test_user",
            status=CommandStatus.PENDING,
        )
        self.db.add(cmd)
        self.db.commit()
        self.assertIsNotNone(cmd.id)
        self.assertEqual(cmd.status, CommandStatus.PENDING)

        cmd.status = CommandStatus.SUCCESS
        cmd.acked_at = datetime.now(timezone.utc)
        self.db.commit()
        self.assertEqual(cmd.status, CommandStatus.SUCCESS)

    def test_alert_and_notification(self):
        """Memverifikasi pembuatan alert dan pencatatan riwayat notification."""
        alert = Alert(
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            detail={"flow_lpm": 6.4, "duration_min": 45},
        )
        self.db.add(alert)
        self.db.commit()
        self.assertIsNotNone(alert.id)

        notif = Notification(
            alert_id=alert.id,
            attempts=1,
        )
        self.db.add(notif)
        self.db.commit()
        self.assertIsNotNone(notif.id)

    def test_push_token_unique(self):
        """Memverifikasi keunikan token pada tabel push_tokens."""
        pt1 = PushToken(token="sample-fcm-token-123", platform="android")
        self.db.add(pt1)
        self.db.commit()

        pt2 = PushToken(token="sample-fcm-token-123", platform="android")
        self.db.add(pt2)
        with self.assertRaises(IntegrityError):
            self.db.commit()
        self.db.rollback()


if __name__ == "__main__":
    unittest.main()

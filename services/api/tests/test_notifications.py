"""
Unit & Integration Tests untuk Notifikasi FCM, Retry Mechanism, dan Aktivitas Tombol Fisik (R-08).
Kriteria Selesai (PRD 5.2 & CONTRACT.md Section 4):
- Alert dari simulator / MQTT sampai dan tercatat di tabel notifications
- Payload notifikasi bertipe data dengan nilai string murni (CONTRACT.md Bagian 4)
- Retry mechanism dengan jeda backoff saat pengiriman gagal (US-12)
- Token kadaluwarsa/unregistered otomatis dibersihkan dari tabel push_tokens
- Alert ACTIVITY dari tombol fisik TIDAK mengirim push notification (CONTRACT.md 4.3)
- Log memenuhi K1 di 20 percobaan (P95 latensi <= 3 detik)
- Integrasi MQTT handle_alert dan job deteksi anomali memicu pengiriman notifikasi
"""

import sys
import time
import unittest
from pathlib import Path
from datetime import datetime, date, timezone, timedelta
from typing import Dict, Any, Optional, List

# Pastikan services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus
from app.models.notification import PushToken, Notification
from app.models.usage import DailyUsage

# Modul notifikasi yang diuji
from app.notify.fcm import FCMClient, FCMResponse
from app.notify.dispatcher import (
    format_alert_payload,
    dispatch_alert_notification,
)
from app.mqtt.handlers import handle_alert, handle_status
from app.jobs.anomaly import run_anomaly_detection


class TestNotifications(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(cls.engine)
        cls.Session = sessionmaker(bind=cls.engine)

    def setUp(self):
        self.db = self.Session()
        # Bersihkan data setiap test
        self.db.query(Notification).delete()
        self.db.query(PushToken).delete()
        self.db.query(Alert).delete()
        self.db.query(DailyUsage).delete()
        self.db.query(Device).delete()
        self.db.query(Room).delete()
        self.db.commit()

        # Seed 1 kamar dan 1 perangkat
        self.room = Room(id=1, name="Kamar 1", sort_order=1, is_simulated=False)
        self.db.add(self.room)
        self.db.commit()

        self.device = Device(
            id="esp32_kamar1",
            room_id=1,
            valve_state=ValveState.OPEN,
            last_seen_at=datetime.now(timezone.utc),
            firmware_version="1.0.0",
        )
        self.db.add(self.device)
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def test_format_alert_payload_leak_continuous(self):
        """Format payload LEAK CONTINUOUS harus memenuhi CONTRACT.md Section 4 (semua value string)."""
        alert = Alert(
            id=31,
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
            detail={"flow_lpm": 6.4, "leak_duration_min": 45},
        )
        payload = format_alert_payload(alert, self.room)

        self.assertEqual(payload["type"], "LEAK")
        self.assertEqual(payload["alert_id"], "31")
        self.assertEqual(payload["room_id"], "1")
        self.assertEqual(payload["room_name"], "Kamar 1")
        self.assertEqual(payload["title"], "Kebocoran terdeteksi")
        self.assertIn("aliran terus menerus", payload["body"])
        self.assertIn("Valve sudah ditutup", payload["body"])

        # Verifikasi semua value adalah string murni
        for k, v in payload.items():
            self.assertIsInstance(k, str)
            self.assertIsInstance(v, str)

    def test_format_alert_payload_anomaly(self):
        """Format payload ANOMALY harus memenuhi CONTRACT.md Section 4."""
        alert = Alert(
            id=32,
            room_id=1,
            type=AlertType.ANOMALY,
            rule=AlertRule.DAILY_RATIO,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
            detail={"ratio": 1.7, "today_l": 170.0, "avg_daily_l": 100.0},
        )
        payload = format_alert_payload(alert, self.room)

        self.assertEqual(payload["type"], "ANOMALY")
        self.assertEqual(payload["alert_id"], "32")
        self.assertEqual(payload["room_id"], "1")
        self.assertEqual(payload["room_name"], "Kamar 1")
        self.assertEqual(payload["title"], "Anomali pemakaian terdeteksi")
        self.assertIn("1,7× rata-rata", payload["body"])

        # Verifikasi tipe string
        for k, v in payload.items():
            self.assertIsInstance(v, str)

    def test_activity_alert_does_not_trigger_push(self):
        """Alert ACTIVITY (tombol fisik) TIDAK dikirim push sesuai CONTRACT.md 4.3."""
        alert = Alert(
            id=33,
            room_id=1,
            type=AlertType.ACTIVITY,
            rule=AlertRule.MANUAL_BUTTON,
            status=AlertStatus.INFO,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(alert)
        self.db.commit()

        # Daftarkan token
        token = PushToken(token="fcm_token_123", platform="android")
        self.db.add(token)
        self.db.commit()

        mock_called = []
        def mock_send(t, d):
            mock_called.append((t, d))
            return FCMResponse(success=True, status_code=200)

        fcm_client = FCMClient(mock_sender=mock_send)
        result = dispatch_alert_notification(self.db, alert, fcm_client=fcm_client)

        self.assertIsNone(result)
        self.assertEqual(len(mock_called), 0)
        # Pastikan tidak ada rekaman di tabel notifications
        notif_count = self.db.query(Notification).count()
        self.assertEqual(notif_count, 0)

    def test_dispatch_without_registered_tokens_logs_notification(self):
        """Bila belum ada token terdaftar, sistem mencatat Notification dengan attempts=0 dan error keterangan."""
        alert = Alert(
            id=34,
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(alert)
        self.db.commit()

        fcm_client = FCMClient()
        notif = dispatch_alert_notification(self.db, alert, fcm_client=fcm_client)

        self.assertIsNotNone(notif)
        self.assertEqual(notif.alert_id, 34)
        self.assertEqual(notif.attempts, 0)
        self.assertEqual(notif.last_error, "NO_REGISTERED_TOKENS")

    def test_dispatch_success_first_attempt(self):
        """Pengiriman berhasil pada percobaan pertama (attempts=1, last_error=None)."""
        token = PushToken(token="token_abc", platform="android")
        self.db.add(token)
        alert = Alert(
            id=35,
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.STABLE,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(alert)
        self.db.commit()

        calls = []
        def mock_sender(t, d):
            calls.append(t)
            return FCMResponse(success=True, status_code=200)

        client = FCMClient(mock_sender=mock_sender)
        notif = dispatch_alert_notification(self.db, alert, fcm_client=client, retry_delays=[0.0, 0.0, 0.0])

        self.assertIsNotNone(notif)
        self.assertEqual(notif.attempts, 1)
        self.assertIsNone(notif.last_error)
        self.assertEqual(len(calls), 1)

    def test_dispatch_retry_succeeds_on_second_attempt(self):
        """Pengiriman gagal sekali lalu berhasil pada percobaan kedua (US-12)."""
        token = PushToken(token="token_abc", platform="android")
        self.db.add(token)
        alert = Alert(
            id=36,
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.QUIET_HOURS,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(alert)
        self.db.commit()

        call_count = 0
        def mock_sender(t, d):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return FCMResponse(success=False, status_code=503, error_message="Service Unavailable")
            return FCMResponse(success=True, status_code=200)

        client = FCMClient(mock_sender=mock_sender)
        notif = dispatch_alert_notification(self.db, alert, fcm_client=client, retry_delays=[0.0, 0.0, 0.0])

        self.assertIsNotNone(notif)
        self.assertEqual(call_count, 2)
        self.assertEqual(notif.attempts, 2)
        self.assertIsNone(notif.last_error)

    def test_dispatch_retry_exhausted_records_failure(self):
        """Pengiriman gagal terus hingga batas retry habis (total 4 attempts) mencatat error (US-12)."""
        token = PushToken(token="token_abc", platform="android")
        self.db.add(token)
        alert = Alert(
            id=37,
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(alert)
        self.db.commit()

        call_count = 0
        def mock_sender(t, d):
            nonlocal call_count
            call_count += 1
            return FCMResponse(success=False, status_code=500, error_message="Internal Server Error")

        client = FCMClient(mock_sender=mock_sender)
        # Default 3 retry (delays 3 item)
        notif = dispatch_alert_notification(self.db, alert, fcm_client=client, retry_delays=[0.0, 0.0, 0.0])

        self.assertIsNotNone(notif)
        self.assertEqual(call_count, 4)  # 1 initial + 3 retries
        self.assertEqual(notif.attempts, 4)
        self.assertIn("Internal Server Error", notif.last_error)

    def test_unregistered_token_is_pruned(self):
        """Token yang tidak valid (UNREGISTERED) otomatis dihapus dari database push_tokens."""
        token_bad = PushToken(token="expired_token", platform="android")
        token_good = PushToken(token="valid_token", platform="android")
        self.db.add_all([token_bad, token_good])
        alert = Alert(
            id=38,
            room_id=1,
            type=AlertType.LEAK,
            rule=AlertRule.CONTINUOUS,
            status=AlertStatus.OPEN,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(alert)
        self.db.commit()

        def mock_sender(t, d):
            if t == "expired_token":
                return FCMResponse(success=False, status_code=404, error_code="UNREGISTERED", error_message="Token is not registered")
            return FCMResponse(success=True, status_code=200)

        client = FCMClient(mock_sender=mock_sender)
        dispatch_alert_notification(self.db, alert, fcm_client=client, retry_delays=[0.0, 0.0, 0.0])

        remaining_tokens = [p.token for p in self.db.query(PushToken).all()]
        self.assertNotIn("expired_token", remaining_tokens)
        self.assertIn("valid_token", remaining_tokens)

    def test_kpi_k1_latency_benchmark_20_trials(self):
        """
        Pengujian K1: P95 latensi <= 3 detik dalam 20 percobaan dan log tercatat di notifications.
        """
        token = PushToken(token="benchmark_token", platform="android")
        self.db.add(token)
        self.db.commit()

        latencies = []
        client = FCMClient(dry_run=True)

        for i in range(1, 21):
            alert = Alert(
                id=100 + i,
                room_id=1,
                type=AlertType.LEAK,
                rule=AlertRule.CONTINUOUS,
                status=AlertStatus.OPEN,
                created_at=datetime.now(timezone.utc),
            )
            self.db.add(alert)
            self.db.commit()

            start_t = time.perf_counter()
            notif = dispatch_alert_notification(self.db, alert, fcm_client=client, retry_delays=[0.0, 0.0, 0.0])
            elapsed = time.perf_counter() - start_t

            latencies.append(elapsed)
            self.assertIsNotNone(notif)
            self.assertEqual(notif.attempts, 1)
            self.assertIsNone(notif.last_error)

        # Hitung P95
        latencies.sort()
        # Index p95 = ceil(0.95 * 20) - 1 = 18 (0-indexed)
        p95_latency = latencies[int(0.95 * len(latencies)) - 1]

        self.assertLessEqual(p95_latency, 3.0, f"P95 latensi melebihi 3 detik: {p95_latency:.4f}s")
        # Pastikan tepat 20 notifikasi tercatat di tabel notifications
        notif_count = self.db.query(Notification).filter(Notification.alert_id >= 101, Notification.alert_id <= 120).count()
        self.assertEqual(notif_count, 20)

    def test_mqtt_handle_alert_triggers_notification(self):
        """Integrasi: handle_alert MQTT secara otomatis memicu pengiriman notifikasi dan tercatat di DB."""
        token = PushToken(token="mqtt_test_token", platform="android")
        self.db.add(token)
        self.db.commit()

        alert_payload = {
            "msg_id": 999,
            "ts": datetime.now(timezone.utc).isoformat(),
            "rule": "CONTINUOUS",
            "flow_lpm": 6.4,
            "valve": "CLOSED",
        }

        result = handle_alert(self.db, "esp32_kamar1", alert_payload)
        self.assertTrue(result.success)

        # Cek Alert dibuat
        alert = self.db.query(Alert).filter(Alert.type == AlertType.LEAK).first()
        self.assertIsNotNone(alert)

        # Cek Notifikasi dibuat dan terhubung ke alert ini
        notif = self.db.query(Notification).filter(Notification.alert_id == alert.id).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.attempts, 1)

    def test_mqtt_handle_status_manual_button_does_not_create_notification(self):
        """Integrasi: handle_status MANUAL_BUTTON membuat alert ACTIVITY tapi TIDAK membuat notifikasi push."""
        token = PushToken(token="manual_btn_token", platform="android")
        self.db.add(token)
        self.db.commit()

        status_payload = {
            "msg_id": 1000,
            "ts": datetime.now(timezone.utc).isoformat(),
            "valve": "OPEN",
            "source": "MANUAL_BUTTON",
        }

        result = handle_status(self.db, "esp32_kamar1", status_payload)
        self.assertTrue(result.success)

        # Alert ACTIVITY ada
        activity_alert = self.db.query(Alert).filter(Alert.type == AlertType.ACTIVITY).first()
        self.assertIsNotNone(activity_alert)

        # TIDAK ada notifikasi yang dibuat untuk alert ini
        notif = self.db.query(Notification).filter(Notification.alert_id == activity_alert.id).first()
        self.assertIsNone(notif)

    def test_anomaly_detection_job_triggers_notification(self):
        """Integrasi: job run_anomaly_detection secara otomatis memicu pengiriman notifikasi untuk alert anomali."""
        token = PushToken(token="anomaly_test_token", platform="android")
        self.db.add(token)

        # Buat data historis 3 hari rata-rata 100 L
        today = date.today()
        for i in range(1, 4):
            hist_date = today - timedelta(days=i)
            self.db.add(DailyUsage(room_id=1, date=hist_date, volume_l=100.0, peak_flow_lpm=5.0))

        # Buat pemakaian hari ini 160 L (> 1.5x)
        self.db.add(DailyUsage(room_id=1, date=today, volume_l=160.0, peak_flow_lpm=8.0))
        self.db.commit()

        created_alerts = run_anomaly_detection(self.db, target_date=today)
        self.assertEqual(len(created_alerts), 1)

        anomaly_alert = created_alerts[0]
        notif = self.db.query(Notification).filter(Notification.alert_id == anomaly_alert.id).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.attempts, 1)


if __name__ == "__main__":
    unittest.main()


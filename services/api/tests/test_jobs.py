"""
Unit & Integration Tests untuk Job Agregasi, Deteksi Anomali Server, dan Deteksi Kamar Offline (R-06).
Kriteria Selesai (PRD 5.2):
- Unit test fungsi murni rules/ untuk batas 1,49x dan 1,51x
- K5 lulus di data simulator 3 hari (selisih rekap harian vs jumlah volume mentah <= 1%)
- Agregasi harian dan bulanan idempoten (upsert)
- Deteksi anomali server (maks 1 alert/hari/kamar, detail metrik)
- Deteksi perangkat offline 30 detik
"""

import sys
import unittest
from pathlib import Path
from datetime import datetime, date, timezone, timedelta
from zoneinfo import ZoneInfo

# Pastikan services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.telemetry import Telemetry
from app.models.usage import DailyUsage, MonthlyUsage
from app.models.alert import Alert, AlertType, AlertRule, AlertStatus

# Import modul rules dan jobs yang akan diuji
from app.rules.anomaly import evaluate_daily_anomaly
from app.jobs.aggregation import aggregate_daily_usage, aggregate_monthly_usage
from app.jobs.anomaly import run_anomaly_detection
from app.jobs.offline import check_offline_devices
from app.jobs.scheduler import setup_jobs
from apscheduler.schedulers.background import BackgroundScheduler


class TestJobsAndRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Database SQLite in-memory untuk pengujian
        cls.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(cls.engine)
        cls.Session = sessionmaker(bind=cls.engine)
        cls.wib_tz = ZoneInfo("Asia/Jakarta")

    def setUp(self):
        self.db = self.Session()
        self.db.query(Alert).delete()
        self.db.query(DailyUsage).delete()
        self.db.query(MonthlyUsage).delete()
        self.db.query(Telemetry).delete()
        self.db.query(Device).delete()
        self.db.query(Room).delete()
        self.db.commit()

        # Seed 2 kamar dan 2 perangkat
        r1 = Room(id=1, name="Kamar 1", sort_order=1, is_simulated=False)
        r2 = Room(id=2, name="Kamar 2", sort_order=2, is_simulated=True)
        self.db.add_all([r1, r2])
        self.db.flush()

        now_utc = datetime.now(timezone.utc)
        d1 = Device(id="1", room_id=1, valve_state=ValveState.OPEN, last_seen_at=now_utc)
        d2 = Device(id="2", room_id=2, valve_state=ValveState.OPEN, last_seen_at=now_utc)
        self.db.add_all([d1, d2])
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def test_anomaly_rule_boundary_149_and_151(self):
        """
        Kriteria Selesai PRD 5.2:
        Unit test fungsi murni rules/ untuk batas 1,49x dan 1,51x.
        """
        # Historis 7 hari dengan rata-rata 100.0 L/hari
        history = [100.0] * 7

        # 1. Kasus batas 1.49x (149.0 L) -> Bukan anomali
        is_ano_149, ratio_149, avg_149 = evaluate_daily_anomaly(
            today_volume=149.0,
            history_volumes=history,
            ratio_threshold=1.5,
            min_history_days=3,
        )
        self.assertFalse(is_ano_149)
        self.assertEqual(ratio_149, 1.49)
        self.assertEqual(avg_149, 100.0)

        # 2. Kasus pas di batas 1.50x (150.0 L) -> Bukan anomali (kondisi: > 1.5x)
        is_ano_150, ratio_150, _ = evaluate_daily_anomaly(
            today_volume=150.0,
            history_volumes=history,
            ratio_threshold=1.5,
            min_history_days=3,
        )
        self.assertFalse(is_ano_150)
        self.assertEqual(ratio_150, 1.50)

        # 3. Kasus batas 1.51x (151.0 L) -> Terdeteksi anomali!
        is_ano_151, ratio_151, avg_151 = evaluate_daily_anomaly(
            today_volume=151.0,
            history_volumes=history,
            ratio_threshold=1.5,
            min_history_days=3,
        )
        self.assertTrue(is_ano_151)
        self.assertEqual(ratio_151, 1.51)
        self.assertEqual(avg_151, 100.0)

    def test_anomaly_rule_insufficient_history(self):
        """Memverifikasi aturan anomali tidak aktif bila riwayat kurang dari min_history_days (3 hari)."""
        # Hanya ada 2 hari data historis
        history = [100.0, 100.0]
        is_ano, ratio, avg = evaluate_daily_anomaly(
            today_volume=300.0,  # 3.0x rata-rata
            history_volumes=history,
            ratio_threshold=1.5,
            min_history_days=3,
        )
        self.assertFalse(is_ano)
        self.assertIsNone(ratio)
        self.assertIsNone(avg)

    def test_daily_aggregation_k5_accuracy_3_days(self):
        """
        Kriteria Selesai PRD 5.2 (KPI K5):
        K5 lulus di data simulator 3 hari dengan selisih rekap harian vs jumlah volume mentah <= 1%.
        """
        dates = [date(2026, 11, 1), date(2026, 11, 2), date(2026, 11, 3)]
        msg_counter = 1

        expected_totals = {}

        # Buat telemetri untuk masing-masing dari 3 hari WIB
        for d in dates:
            expected_totals[d] = 0.0
            # Pagi hari WIB: jam 07:00 WIB = 00:00 UTC
            start_utc = datetime(d.year, d.month, d.day, 0, 0, 0, tzinfo=timezone.utc)
            for i in range(10):
                flow = 6.4 if i % 2 == 0 else 3.2
                delta = round((flow / 60.0) * 10, 2)
                t = Telemetry(
                    device_id="2",
                    msg_id=msg_counter,
                    device_ts=start_utc + timedelta(minutes=i * 10),
                    received_at=start_utc + timedelta(minutes=i * 10),
                    flow_lpm=flow,
                    volume_l_delta=delta,
                    valve_state=ValveState.OPEN,
                )
                self.db.add(t)
                expected_totals[d] += delta
                msg_counter += 1

        self.db.commit()

        # Jalankan agregasi harian untuk masing-masing hari
        for d in dates:
            count = aggregate_daily_usage(self.db, target_date=d)
            self.assertEqual(count, 1)

            # Ambil hasil rekap daily_usage
            rec = self.db.query(DailyUsage).filter_by(room_id=2, date=d).first()
            self.assertIsNotNone(rec)

            raw_total = expected_totals[d]
            rekap_total = rec.volume_l

            # Verifikasi KPI K5: selisih <= 1%
            diff_pct = abs(rekap_total - raw_total) / raw_total
            self.assertLessEqual(diff_pct, 0.01, f"Selisih rekap hari {d} melebihi 1%: {diff_pct:.4f}")
            self.assertEqual(rec.peak_flow_lpm, 6.4)

    def test_daily_aggregation_idempotent_upsert(self):
        """Memverifikasi agregasi harian bersifat idempoten (upsert tanpa duplikasi baris)."""
        target_d = date(2026, 11, 4)
        ts_utc = datetime(2026, 11, 4, 1, 0, 0, tzinfo=timezone.utc)

        t1 = Telemetry(
            device_id="1",
            msg_id=101,
            device_ts=ts_utc,
            received_at=ts_utc,
            flow_lpm=5.0,
            volume_l_delta=10.0,
            valve_state=ValveState.OPEN,
        )
        self.db.add(t1)
        self.db.commit()

        # Agregasi pertama
        aggregate_daily_usage(self.db, target_date=target_d)
        rec1 = self.db.query(DailyUsage).filter_by(room_id=1, date=target_d).first()
        self.assertEqual(rec1.volume_l, 10.0)

        # Agregasi kedua tanpa data baru -> nilai tetap sama, jumlah baris tetap 1
        aggregate_daily_usage(self.db, target_date=target_d)
        total_rows = self.db.query(DailyUsage).filter_by(room_id=1, date=target_d).count()
        self.assertEqual(total_rows, 1)

        # Tambahkan data baru di hari yang sama, lalu agregasi ulang -> volume bertambah
        t2 = Telemetry(
            device_id="1",
            msg_id=102,
            device_ts=ts_utc + timedelta(minutes=5),
            received_at=ts_utc + timedelta(minutes=5),
            flow_lpm=7.0,
            volume_l_delta=15.0,
            valve_state=ValveState.OPEN,
        )
        self.db.add(t2)
        self.db.commit()

        aggregate_daily_usage(self.db, target_date=target_d)
        self.db.refresh(rec1)
        self.assertEqual(rec1.volume_l, 25.0)
        self.assertEqual(rec1.peak_flow_lpm, 7.0)

    def test_monthly_aggregation(self):
        """Memverifikasi agregasi bulanan merangkum total liter dari daily_usage secara akurat."""
        # Buat rekap harian untuk bulan 2026-11
        d1 = DailyUsage(room_id=1, date=date(2026, 11, 1), volume_l=50.0, peak_flow_lpm=5.0)
        d2 = DailyUsage(room_id=1, date=date(2026, 11, 2), volume_l=75.0, peak_flow_lpm=6.0)
        d3 = DailyUsage(room_id=2, date=date(2026, 11, 1), volume_l=40.0, peak_flow_lpm=4.0)
        self.db.add_all([d1, d2, d3])
        self.db.commit()

        aggregate_monthly_usage(self.db, target_month="2026-11")

        # Cek rekap bulanan Kamar 1 (50 + 75 = 125 L)
        m1 = self.db.query(MonthlyUsage).filter_by(room_id=1, month="2026-11").first()
        self.assertIsNotNone(m1)
        self.assertEqual(m1.volume_l, 125.0)

        # Cek rekap bulanan Kamar 2 (40 L)
        m2 = self.db.query(MonthlyUsage).filter_by(room_id=2, month="2026-11").first()
        self.assertIsNotNone(m2)
        self.assertEqual(m2.volume_l, 40.0)

    def test_anomaly_job_creates_open_alert_and_enforces_one_per_day(self):
        """Memverifikasi deteksi anomali server menerbitkan alert ANOMALY OPEN dan dibatasi maks 1 per hari."""
        # Buat 3 hari riwayat historis kamar 1 (100 L per hari)
        for i in range(1, 4):
            self.db.add(DailyUsage(
                room_id=1,
                date=date(2026, 11, i),
                volume_l=100.0,
                peak_flow_lpm=6.0,
            ))

        # Hari ke-4 (target_date): pemakaian 160 L (rasio 1.6x > 1.5x)
        today = date(2026, 11, 4)
        self.db.add(DailyUsage(
            room_id=1,
            date=today,
            volume_l=160.0,
            peak_flow_lpm=7.0,
        ))
        self.db.commit()

        # Jalankan job deteksi anomali
        alerts = run_anomaly_detection(self.db, target_date=today)
        self.assertEqual(len(alerts), 1)

        alert = alerts[0]
        self.assertEqual(alert.room_id, 1)
        self.assertEqual(alert.type, AlertType.ANOMALY)
        self.assertEqual(alert.rule, AlertRule.DAILY_RATIO)
        self.assertEqual(alert.status, AlertStatus.OPEN)
        self.assertEqual(alert.detail["today_l"], 160.0)
        self.assertEqual(alert.detail["avg_daily_l"], 100.0)
        self.assertEqual(alert.detail["ratio"], 1.6)

        # Jalankan lagi untuk hari yang sama -> tidak boleh membuat alert kedua (maks 1 per hari)
        second_run_alerts = run_anomaly_detection(self.db, target_date=today)
        self.assertEqual(len(second_run_alerts), 0)

        total_anomalies = self.db.query(Alert).filter_by(room_id=1, type=AlertType.ANOMALY).count()
        self.assertEqual(total_anomalies, 1)

    def test_offline_detection_30s(self):
        """Memverifikasi perangkat yang tidak aktif > 30 detik teridentifikasi offline."""
        now_utc = datetime.now(timezone.utc)
        # Device 1: aktif 10 detik lalu (ONLINE)
        d1 = self.db.query(Device).filter_by(id="1").first()
        d1.last_seen_at = now_utc - timedelta(seconds=10)

        # Device 2: aktif 40 detik lalu (OFFLINE)
        d2 = self.db.query(Device).filter_by(id="2").first()
        d2.last_seen_at = now_utc - timedelta(seconds=40)
        self.db.commit()

        offline_ids = check_offline_devices(self.db, timeout_seconds=30.0, now_utc=now_utc)
        self.assertIn("2", offline_ids)
        self.assertNotIn("1", offline_ids)

    def test_scheduler_jobs_registration(self):
        """Memverifikasi bahwa seluruh background jobs didaftarkan dengan benar ke scheduler."""
        test_sched = BackgroundScheduler()
        setup_jobs(test_sched)
        job_ids = [j.id for j in test_sched.get_jobs()]
        self.assertIn("job_daily_aggregation", job_ids)
        self.assertIn("job_midnight_day_close", job_ids)
        self.assertIn("job_hourly_anomaly", job_ids)
        self.assertIn("job_frequent_checks", job_ids)


if __name__ == "__main__":
    unittest.main()

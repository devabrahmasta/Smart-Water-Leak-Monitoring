"""
Unit & Contract Tests for Smart Water MQTT Schemas & Fixtures (R-01).

Memvalidasi bahwa setiap fixture JSON di packages/contracts/fixtures/ lolos
validasi skemanya di packages/contracts/schemas/, serta menguji bahwa pelanggaran
skema (negative test) ditolak dengan benar.
"""

import json
from pathlib import Path
import unittest

from jsonschema import validate, ValidationError, Draft7Validator

ROOT_DIR = Path(__file__).resolve().parent
SCHEMAS_DIR = ROOT_DIR / "schemas"
FIXTURES_DIR = ROOT_DIR / "fixtures"


def load_json(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


class TestMQTTContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schemas = {
            "telemetry": load_json(SCHEMAS_DIR / "telemetry.json"),
            "alert": load_json(SCHEMAS_DIR / "alert.json"),
            "status": load_json(SCHEMAS_DIR / "status.json"),
            "cmd": load_json(SCHEMAS_DIR / "cmd.json"),
            "ack": load_json(SCHEMAS_DIR / "ack.json"),
            "config": load_json(SCHEMAS_DIR / "config.json"),
            "demo": load_json(SCHEMAS_DIR / "demo.json"),
        }

        # Pastikan seluruh skema adalah Draft7Validator yang valid
        for name, schema in cls.schemas.items():
            Draft7Validator.check_schema(schema)

    # ---------------------------------------------------------
    # Positive Tests: Setiap fixture lolos validasi skema
    # ---------------------------------------------------------
    def test_telemetry_fixtures(self):
        fixture_standard = load_json(FIXTURES_DIR / "telemetry.json")
        validate(instance=fixture_standard, schema=self.schemas["telemetry"])

        fixture_null_ts = load_json(FIXTURES_DIR / "telemetry_null_ts.json")
        validate(instance=fixture_null_ts, schema=self.schemas["telemetry"])

    def test_alert_fixtures(self):
        for fixture_name in ["alert_continuous.json", "alert_stable.json", "alert_quiet_hours.json"]:
            with self.subTest(fixture=fixture_name):
                fixture = load_json(FIXTURES_DIR / fixture_name)
                validate(instance=fixture, schema=self.schemas["alert"])

    def test_status_fixtures(self):
        for fixture_name in ["status_manual.json", "status_boot.json"]:
            with self.subTest(fixture=fixture_name):
                fixture = load_json(FIXTURES_DIR / fixture_name)
                validate(instance=fixture, schema=self.schemas["status"])

    def test_cmd_fixtures(self):
        for fixture_name in ["cmd_open.json", "cmd_close.json"]:
            with self.subTest(fixture=fixture_name):
                fixture = load_json(FIXTURES_DIR / fixture_name)
                validate(instance=fixture, schema=self.schemas["cmd"])

    def test_ack_fixtures(self):
        for fixture_name in ["ack_ok.json", "ack_error.json"]:
            with self.subTest(fixture=fixture_name):
                fixture = load_json(FIXTURES_DIR / fixture_name)
                validate(instance=fixture, schema=self.schemas["ack"])

    def test_config_and_demo_fixtures(self):
        validate(instance=load_json(FIXTURES_DIR / "config.json"), schema=self.schemas["config"])
        validate(instance=load_json(FIXTURES_DIR / "demo_leak_stable.json"), schema=self.schemas["demo"])

    def test_config_rejects_too_short(self):
        with self.assertRaises(ValidationError):
            validate(
                instance={"continuous_sec": 5, "stable_sec": 300, "quiet_sec": 300},
                schema=self.schemas["config"],
            )

    # ---------------------------------------------------------
    # Negative Tests: Memastikan pelanggaran skema tertolak
    # ---------------------------------------------------------
    def test_telemetry_rejects_negative_flow(self):
        invalid_payload = {
            "msg_id": 1,
            "ts": "2026-11-07T07:21:30Z",
            "flow_lpm": -0.5,
            "volume_l_delta": 1.0,
            "valve": "OPEN",
        }
        with self.assertRaises(ValidationError):
            validate(instance=invalid_payload, schema=self.schemas["telemetry"])

    def test_telemetry_rejects_invalid_valve_enum(self):
        invalid_payload = {
            "msg_id": 1,
            "ts": "2026-11-07T07:21:30Z",
            "flow_lpm": 5.0,
            "volume_l_delta": 1.0,
            "valve": "open",  # harus huruf besar
        }
        with self.assertRaises(ValidationError):
            validate(instance=invalid_payload, schema=self.schemas["telemetry"])

    def test_telemetry_rejects_missing_required_field(self):
        invalid_payload = {
            "ts": "2026-11-07T07:21:30Z",
            "flow_lpm": 5.0,
            "volume_l_delta": 1.0,
            "valve": "OPEN",
            # missing msg_id
        }
        with self.assertRaises(ValidationError):
            validate(instance=invalid_payload, schema=self.schemas["telemetry"])

    def test_telemetry_rejects_unexpected_properties(self):
        invalid_payload = {
            "msg_id": 1,
            "ts": "2026-11-07T07:21:30Z",
            "flow_lpm": 5.0,
            "volume_l_delta": 1.0,
            "valve": "OPEN",
            "extra_field": "unallowed",
        }
        with self.assertRaises(ValidationError):
            validate(instance=invalid_payload, schema=self.schemas["telemetry"])

    def test_alert_rejects_server_side_rule(self):
        # Rule DAILY_RATIO hanya untuk server backend, bukan perangkat
        invalid_payload = {
            "msg_id": 2,
            "ts": "2026-11-07T07:22:00Z",
            "rule": "DAILY_RATIO",
            "flow_lpm": 6.4,
            "valve": "CLOSED",
        }
        with self.assertRaises(ValidationError):
            validate(instance=invalid_payload, schema=self.schemas["alert"])

    def test_cmd_rejects_invalid_action(self):
        invalid_payload = {
            "command_id": 100,
            "action": "TOGGLE",
        }
        with self.assertRaises(ValidationError):
            validate(instance=invalid_payload, schema=self.schemas["cmd"])

    def test_ack_rejects_invalid_result(self):
        invalid_payload = {
            "command_id": 100,
            "result": "PENDING",
            "valve": "OPEN",
        }
        with self.assertRaises(ValidationError):
            validate(instance=invalid_payload, schema=self.schemas["ack"])


if __name__ == "__main__":
    unittest.main()


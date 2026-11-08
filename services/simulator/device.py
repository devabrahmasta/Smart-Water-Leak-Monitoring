"""
Engine perangkat simulator (SimulatedDevice) yang mengontrol status valve,
penerbitan payload MQTT ke broker, serta pemrosesan perintah kendali.
"""

import ssl
import json
import logging
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional, Dict, Any, Callable

import paho.mqtt.client as mqtt

from services.simulator.config import settings, ROOT_DIR
from services.simulator.state import SimulatorState
from services.simulator.scenarios import BaseScenario, get_scenario

logger = logging.getLogger(__name__)


def _now_iso_utc() -> str:
    """Mengembalikan waktu saat ini dalam format ISO 8601 UTC."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class SimulatedDevice:
    def __init__(
        self,
        state: Optional[SimulatorState] = None,
        scenario_name: str = "normal",
        interval_sec: float = 10.0,
        ticks_to_trigger: Optional[int] = None,
    ):
        if state is None:
            state_file = ROOT_DIR / "services" / "simulator" / ".simulator_state.json"
            state = SimulatorState(
                device_id=settings.SIM_DEVICE_ID,
                valve_state="OPEN",
                persist_path=state_file,
            )
        self.state = state
        self.interval_sec = interval_sec
        self.scenario: BaseScenario = get_scenario(scenario_name, interval_sec, ticks_to_trigger)
        self.last_alert: Optional[Dict[str, Any]] = None
        self.mqtt_client: Optional[mqtt.Client] = None

    def set_scenario(self, name: str, ticks_to_trigger: Optional[int] = None) -> None:
        """Mengganti skenario aktif pada simulator."""
        self.scenario = get_scenario(name, self.interval_sec, ticks_to_trigger)
        self.last_alert = None
        logger.info(f"Skenario simulator diatur ke: '{name}'")

    def step(self) -> Optional[Dict[str, Any]]:
        """
        Menjalankan 1 interval/tick simulasi:
        1. Menghitung debit dan mengecek pemicu aturan kebocoran.
        2. Jika aturan kebocoran terpicu, otomatis menutup valve dan menerbitkan alert.
        3. Menghasilkan dan menerbitkan payload telemetri (kecuali skenario offline).
        """
        flow_lpm, alert_rule = self.scenario.step(self.state.valve_state)

        # Skenario offline tidak memancarkan telemetri
        if flow_lpm is None:
            return None

        # Jika aturan kebocoran terpicu
        if alert_rule:
            self.state.set_valve("CLOSED")
            alert_payload = {
                "msg_id": self.state.next_msg_id(),
                "ts": _now_iso_utc(),
                "rule": alert_rule,
                "flow_lpm": flow_lpm,
                "valve": "CLOSED",
            }
            self.last_alert = alert_payload
            self.publish("alert", alert_payload)
            logger.warning(f"ALERT terpicu: rule={alert_rule}, valve ditutup otomatis!")

        # Hitung volume delta
        volume_delta = self.scenario.calculate_volume_delta(flow_lpm)

        telemetry_payload = {
            "msg_id": self.state.next_msg_id(),
            "ts": _now_iso_utc(),
            "flow_lpm": flow_lpm,
            "volume_l_delta": volume_delta,
            "valve": self.state.valve_state,
        }

        self.publish("telemetry", telemetry_payload)
        return telemetry_payload

    def handle_command(self, cmd_payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Memproses perintah buka/tutup valve dari broker:
        - Jika skenario no-ack: ubah status valve tetapi jangan kirimkan ACK.
        - Jika skenario lain: ubah status valve dan kirimkan ACK (result: OK).
        """
        command_id = cmd_payload.get("command_id")
        action = cmd_payload.get("action")

        if action not in ("OPEN", "CLOSE"):
            logger.warning(f"Aksi perintah tidak valid: {action}")
            return None

        target_valve = "CLOSED" if action == "CLOSE" else "OPEN"
        logger.info(f"Menerima perintah cmd: command_id={command_id}, action={action} -> valve={target_valve}")
        self.state.set_valve(target_valve)

        # Skenario no-ack sengaja tidak membalas ACK
        if self.scenario.name == "no-ack":
            logger.info("Skenario no-ack aktif: balasan ACK ditekan (tidak dikirim).")
            return None

        ack_payload = {
            "command_id": command_id,
            "result": "OK",
            "valve": self.state.valve_state,
        }
        self.publish("ack", ack_payload)
        return ack_payload

    def press_button(self) -> Dict[str, Any]:
        """Simulasi penekanan tombol fisik (MANUAL_BUTTON): membalikkan status valve."""
        new_state = self.state.toggle_valve()
        status_payload = {
            "msg_id": self.state.next_msg_id(),
            "ts": _now_iso_utc(),
            "valve": new_state,
            "source": "MANUAL_BUTTON",
        }
        self.publish("status", status_payload)
        logger.info(f"Tombol fisik ditekan -> valve sekarang: {new_state}")
        return status_payload

    def boot(self) -> Dict[str, Any]:
        """Simulasi boot perangkat: memulihkan status valve terakhir."""
        status_payload = {
            "msg_id": self.state.next_msg_id(),
            "ts": _now_iso_utc(),
            "valve": self.state.valve_state,
            "source": "BOOT",
        }
        self.publish("status", status_payload)
        logger.info(f"Simulator boot selesai -> valve: {self.state.valve_state}")
        return status_payload

    def publish(self, msg_type: str, payload: Dict[str, Any]) -> None:
        """Menerbitkan payload ke topik swm/{device_id}/{msg_type} dengan QoS 1."""
        if not self.mqtt_client:
            return

        topic = f"swm/{self.state.device_id}/{msg_type}"
        payload_bytes = json.dumps(payload).encode("utf-8")
        try:
            self.mqtt_client.publish(topic, payload_bytes, qos=1)
            logger.debug(f"Published ke {topic}: {payload}")
        except Exception as e:
            logger.error(f"Gagal publish ke {topic}: {e}")

    def setup_mqtt(self) -> mqtt.Client:
        """Mengonfigurasi Paho MQTT Client dengan kredensial & TLS."""
        client = mqtt.Client(
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
            client_id=f"sim-{self.state.device_id}",
            clean_session=False,
        )

        # Autentikasi username & password
        client.username_pw_set(
            settings.SIM_MQTT_USERNAME,
            settings.SIM_MQTT_PASSWORD,
        )

        # Konfigurasi TLS
        ca_path = Path(settings.MQTT_CA_CERT)
        if not ca_path.is_absolute():
            ca_path = ROOT_DIR / ca_path

        if ca_path.exists():
            client.tls_set(
                ca_certs=str(ca_path),
                cert_reqs=ssl.CERT_REQUIRED,
                tls_version=ssl.PROTOCOL_TLS_CLIENT,
            )
            logger.info(f"TLS aktif menggunakan CA cert: {ca_path}")
        else:
            logger.warning(f"CA cert tidak ditemukan di {ca_path}!")

        cmd_topic = f"swm/{self.state.device_id}/cmd"

        def on_connect(client_instance, userdata, flags, reason_code, properties):
            if reason_code == 0:
                logger.info(f"Simulator terhubung ke broker. Berlangganan topik perintah: {cmd_topic}")
                client_instance.subscribe(cmd_topic, qos=1)
                # Kirim status BOOT saat pertama kali terhubung
                self.boot()
            else:
                logger.error(f"Gagal terhubung ke broker: reason_code={reason_code}")

        def on_message(client_instance, userdata, message):
            if message.topic == cmd_topic:
                try:
                    payload = json.loads(message.payload.decode("utf-8"))
                    self.handle_command(payload)
                except Exception as e:
                    logger.error(f"Gagal memproses pesan perintah: {e}")

        client.on_connect = on_connect
        client.on_message = on_message
        self.mqtt_client = client
        return client

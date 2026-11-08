"""
CLI Entrypoint untuk Simulator Kamar Dummy (R-04).
Penggunaan:
  python -m services.simulator.main --scenario normal
  python -m services.simulator.main --scenario leak-continuous --accel
  python -m services.simulator.main --scenario no-ack
"""

import sys
import time
import signal
import logging
import argparse
from pathlib import Path

# Pastikan root proyek masuk ke sys.path
root_dir = Path(__file__).resolve().parent.parent.parent
if str(root_dir) not in sys.path:
    sys.path.insert(0, str(root_dir))

from services.simulator.config import settings
from services.simulator.state import SimulatorState
from services.simulator.device import SimulatedDevice

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [sim-%(name)s] %(message)s",
)
logger = logging.getLogger("device-2")


def parse_args():
    parser = argparse.ArgumentParser(description="Simulator Kamar Dummy Smart Water (device_id=2)")
    parser.add_argument(
        "--scenario",
        type=str,
        default="normal",
        choices=["normal", "leak-continuous", "leak-stable", "quiet-hours", "offline", "no-ack"],
        help="Skenario simulasi yang akan dijalankan (default: normal)",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=settings.TELEMETRY_INTERVAL_SEC,
        help="Interval pengiriman telemetri dalam detik (default: 10.0)",
    )
    parser.add_argument(
        "--accel",
        action="store_true",
        help="Mode akselerasi: mempercepat pemicuan kebocoran menjadi 3 tick (~30 detik)",
    )
    parser.add_argument(
        "--ticks",
        type=int,
        default=None,
        help="Jumlah tick maksimal sebelum simulator berhenti (default: berjalan terus)",
    )
    parser.add_argument(
        "--device-id",
        type=str,
        default=settings.SIM_DEVICE_ID,
        help="Device ID unik simulator (default: 2)",
    )
    parser.add_argument(
        "--button",
        action="store_true",
        help="Picu penekanan tombol fisik sekali lalu keluar",
    )
    parser.add_argument(
        "--boot",
        action="store_true",
        help="Picu pengiriman event boot sekali lalu keluar",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    ticks_to_trigger = 3 if args.accel else None

    state_file = root_dir / "services" / "simulator" / ".simulator_state.json"
    state = SimulatorState(
        device_id=args.device_id,
        valve_state="OPEN",
        persist_path=state_file,
    )

    device = SimulatedDevice(
        state=state,
        scenario_name=args.scenario,
        interval_sec=args.interval,
        ticks_to_trigger=ticks_to_trigger,
    )

    logger.info("=== Menyiapkan Simulator Perangkat Kamar 2 ===")
    logger.info(f"Device ID: {state.device_id} | Skenario: {args.scenario} | Interval: {args.interval}s")
    logger.info(f"Broker: {settings.MQTT_HOST}:{settings.MQTT_PORT} (TLS)")

    # Konfigurasi koneksi MQTT
    client = device.setup_mqtt()

    running = True

    def signal_handler(signum, frame):
        nonlocal running
        logger.info(f"Menerima sinyal {signum}, menghentikan simulator...")
        running = False

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        client.connect(settings.MQTT_HOST, settings.MQTT_PORT, keepalive=60)
        client.loop_start()
    except Exception as e:
        logger.error(f"Koneksi broker gagal: {e}. Simulator berjalan dalam mode lokal/offline.")

    # Jika hanya memicu tombol fisik
    if args.button:
        time.sleep(0.5)  # Beri waktu koneksi
        device.press_button()
        time.sleep(0.5)
        client.loop_stop()
        client.disconnect()
        return

    # Jika hanya memicu status boot
    if args.boot:
        time.sleep(0.5)
        device.boot()
        time.sleep(0.5)
        client.loop_stop()
        client.disconnect()
        return

    tick_count = 0
    try:
        while running:
            tick_count += 1
            payload = device.step()
            if payload:
                logger.info(
                    f"[Tick #{tick_count}] Telemetri terkirim: msg_id={payload['msg_id']}, "
                    f"flow={payload['flow_lpm']} L/min, delta={payload['volume_l_delta']} L, valve={payload['valve']}"
                )
            else:
                logger.info(f"[Tick #{tick_count}] Mode offline (tidak ada telemetri dipancarkan).")

            if args.ticks and tick_count >= args.ticks:
                logger.info(f"Target {args.ticks} tick tercapai. Menghentikan simulator.")
                break

            time.sleep(args.interval)
    except KeyboardInterrupt:
        logger.info("Simulator dihentikan oleh pengguna.")
    finally:
        client.loop_stop()
        try:
            client.disconnect()
        except Exception:
            pass
        logger.info("Simulator selesai.")


if __name__ == "__main__":
    main()


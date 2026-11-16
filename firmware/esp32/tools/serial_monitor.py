"""
Serial monitor untuk beberapa ESP32 sekaligus (Kamar 1 dan Kamar 2).

Setiap baris diberi jam dan label kamar, tampil di satu terminal, dan juga
disimpan ke logs/serial/<label>-<tanggal>.log. Kalau kabel dicabut, monitor
menunggu lalu menyambung lagi sendiri.

Pemakaian (dari root proyek):
  python firmware/esp32/tools/serial_monitor.py --list
  python firmware/esp32/tools/serial_monitor.py --port COM3=Kamar1 --port COM5=Kamar2

Tutup Serial Monitor Arduino IDE dulu (port COM hanya bisa dibuka satu
program), dan hentikan skrip ini (Ctrl+C) sebelum upload sketch.
"""

import argparse
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    sys.exit("pyserial belum terpasang: pip install -r firmware/esp32/tools/requirements.txt")

ROOT_DIR = Path(__file__).resolve().parents[3]
LOG_DIR = ROOT_DIR / "logs" / "serial"
COLORS = ["\033[96m", "\033[93m", "\033[95m", "\033[92m"]
RESET = "\033[0m"

print_lock = threading.Lock()
stop = threading.Event()


def watch(port: str, label: str, baud: int, color: str) -> None:
    log_path = LOG_DIR / f"{label}-{datetime.now():%Y%m%d}.log"
    with log_path.open("a", encoding="utf-8") as log:
        while not stop.is_set():
            try:
                with serial.Serial(port, baud, timeout=0.5) as conn:
                    emit(log, color, label, f"--- tersambung ke {port} ({baud} baud) ---")
                    buffer = b""
                    while not stop.is_set():
                        buffer += conn.read(conn.in_waiting or 1)
                        while b"\n" in buffer:
                            raw, buffer = buffer.split(b"\n", 1)
                            line = raw.decode("utf-8", errors="replace").rstrip("\r")
                            if line:
                                emit(log, color, label, line)
            except serial.SerialException as err:
                emit(log, color, label, f"--- {port} tidak tersedia ({err}), coba lagi 3 dtk ---")
                stop.wait(3)


def emit(log, color: str, label: str, line: str) -> None:
    stamp = datetime.now().strftime("%H:%M:%S")
    with print_lock:
        print(f"{color}{stamp} [{label}]{RESET} {line}", flush=True)
    log.write(f"{stamp} {line}\n")
    log.flush()


def main() -> None:
    parser = argparse.ArgumentParser(description="Serial monitor beberapa ESP32 sekaligus")
    parser.add_argument("--port", action="append", default=[], metavar="COM3=Kamar1",
                        help="Port dan label kamar. Ulangi untuk tiap ESP32.")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--list", action="store_true", help="Tampilkan port COM yang terdeteksi")
    args = parser.parse_args()

    if args.list or not args.port:
        ports = list(list_ports.comports())
        if not ports:
            print("Tidak ada port COM. Cek kabel USB dan driver CH340/CP210x.")
        for p in ports:
            print(f"{p.device}\t{p.description}")
        if not args.port:
            print("\nContoh: --port COM3=Kamar1 --port COM5=Kamar2")
        return

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    threads = []
    for i, spec in enumerate(args.port):
        port, _, label = spec.partition("=")
        t = threading.Thread(
            target=watch,
            args=(port, label or port, args.baud, COLORS[i % len(COLORS)]),
            daemon=True,
        )
        t.start()
        threads.append(t)

    print(f"Log disimpan di {LOG_DIR}. Ctrl+C untuk berhenti.")
    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        stop.set()
        for t in threads:
            t.join(timeout=2)


if __name__ == "__main__":
    main()

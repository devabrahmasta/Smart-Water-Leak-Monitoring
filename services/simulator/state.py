"""
Manajemen state internal simulator kamar dummy (valve_state, msg_id monolitik).
"""

import json
import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


class SimulatorState:
    def __init__(
        self,
        device_id: str = "2",
        valve_state: str = "OPEN",
        msg_id: int = 1,
        persist_path: Optional[Path] = None,
    ):
        self.device_id = device_id
        self.valve_state = valve_state
        self.msg_id = msg_id
        self.persist_path = persist_path

        # Muat state yang tersimpan jika ada file persistensi
        if self.persist_path and self.persist_path.exists():
            self.load()

    def next_msg_id(self) -> int:
        """Menghasilkan msg_id berikutnya secara monotonik naik."""
        current = self.msg_id
        self.msg_id += 1
        self.save()
        return current

    def set_valve(self, state: str) -> None:
        """Memperbarui status valve ('OPEN' atau 'CLOSED')."""
        if state not in ("OPEN", "CLOSED"):
            raise ValueError(f"Status valve tidak valid: {state}")
        self.valve_state = state
        self.save()

    def toggle_valve(self) -> str:
        """Membalikkan status valve (untuk simulasi tombol fisik)."""
        new_state = "CLOSED" if self.valve_state == "OPEN" else "OPEN"
        self.set_valve(new_state)
        return new_state

    def save(self) -> None:
        """Menyimpan state ke file JSON agar bertahan saat reboot."""
        if not self.persist_path:
            return
        try:
            data = {
                "device_id": self.device_id,
                "valve_state": self.valve_state,
                "msg_id": self.msg_id,
            }
            with open(self.persist_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            logger.warning(f"Gagal menyimpan simulator state ke {self.persist_path}: {e}")

    def load(self) -> None:
        """Memuat state dari file JSON."""
        if not self.persist_path or not self.persist_path.exists():
            return
        try:
            with open(self.persist_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.device_id = data.get("device_id", self.device_id)
            self.valve_state = data.get("valve_state", self.valve_state)
            self.msg_id = data.get("msg_id", self.msg_id)
        except Exception as e:
            logger.warning(f"Gagal membaca simulator state dari {self.persist_path}: {e}")


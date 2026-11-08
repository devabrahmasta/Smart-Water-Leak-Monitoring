"""
Implementasi 6 skenario perilaku simulator kamar dummy (US-17):
1. normal
2. leak-continuous
3. leak-stable
4. quiet-hours
5. offline
6. no-ack
"""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any, Tuple


class BaseScenario(ABC):
    name: str = "base"

    def __init__(self, interval_sec: float = 10.0, ticks_to_trigger: Optional[int] = None):
        self.interval_sec = interval_sec
        self.ticks_to_trigger = ticks_to_trigger
        self.tick_count = 0

    @abstractmethod
    def step(self, valve_state: str) -> Tuple[Optional[float], Optional[str]]:
        """
        Menghasilkan debit (flow_lpm) dan alert_rule jika terpicu.
        Mengembalikan (flow_lpm, alert_rule_or_None).
        Jika mengembalikan (None, None), tidak ada telemetri yang dikirim (misal offline).
        """
        pass

    def calculate_volume_delta(self, flow_lpm: float) -> float:
        """Menghitung delta volume dalam liter: (flow_lpm / 60) * interval_sec."""
        return round((flow_lpm / 60.0) * self.interval_sec, 2)


class NormalScenario(BaseScenario):
    """
    Skenario normal: Penggunaan wajar sehari-hari.
    Berulang antara periode diam (0.0 LPM) dan pemakaian air wajar (5.0 - 7.0 LPM).
    """
    name = "normal"

    def step(self, valve_state: str) -> Tuple[Optional[float], Optional[str]]:
        self.tick_count += 1
        if valve_state == "CLOSED":
            return 0.0, None

        # Siklus sederhana: 3 tick mengalir (shower/cuci tangan), 3 tick mati
        cycle = self.tick_count % 6
        if cycle in (1, 2, 3):
            flow = 6.4
        else:
            flow = 0.0
        return flow, None


class ContinuousLeakScenario(BaseScenario):
    """
    Skenario kebocoran kontinu:
    Aliran tanpa jeda sampai aturan 45 menit terpicu (atau ticks_to_trigger tercapai pada mode demo).
    """
    name = "leak-continuous"

    def __init__(self, interval_sec: float = 10.0, ticks_to_trigger: Optional[int] = None):
        # 45 menit * 60 detik / 10 detik per tick = 270 tick jika tidak diakselerasi
        default_ticks = int((45 * 60) / interval_sec)
        super().__init__(interval_sec, ticks_to_trigger or default_ticks)
        self.leak_ticks = 0
        self.alert_triggered = False

    def step(self, valve_state: str) -> Tuple[Optional[float], Optional[str]]:
        self.tick_count += 1
        if valve_state == "CLOSED":
            return 0.0, None

        self.leak_ticks += 1
        flow = 6.4

        # Cek apakah ambang batas kebocoran kontinu tercapai
        if not self.alert_triggered and self.leak_ticks >= self.ticks_to_trigger:
            self.alert_triggered = True
            return flow, "CONTINUOUS"

        return flow, None


class StableLeakScenario(BaseScenario):
    """
    Skenario kebocoran stabil:
    Variasi debit kecil (<= +-10%) selama >= 5 menit (atau ticks_to_trigger pada mode demo).
    """
    name = "leak-stable"

    def __init__(self, interval_sec: float = 10.0, ticks_to_trigger: Optional[int] = None):
        # 5 menit * 60 detik / 10 detik per tick = 30 tick jika tidak diakselerasi
        default_ticks = int((5 * 60) / interval_sec)
        super().__init__(interval_sec, ticks_to_trigger or default_ticks)
        self.stable_ticks = 0
        self.alert_triggered = False

    def step(self, valve_state: str) -> Tuple[Optional[float], Optional[str]]:
        self.tick_count += 1
        if valve_state == "CLOSED":
            return 0.0, None

        self.stable_ticks += 1
        # Variasi kecil dalam rentang +-5% dari 6.0 LPM
        variation = (self.stable_ticks % 3 - 1) * 0.2
        flow = round(6.0 + variation, 2)

        if not self.alert_triggered and self.stable_ticks >= self.ticks_to_trigger:
            self.alert_triggered = True
            return flow, "STABLE"

        return flow, None


class QuietHoursScenario(BaseScenario):
    """
    Skenario kebocoran jam sepi:
    Aliran > 1.0 LPM selama 5 menit pada jam sepi (01:00 - 04:00 WIB).
    """
    name = "quiet-hours"

    def __init__(self, interval_sec: float = 10.0, ticks_to_trigger: Optional[int] = None):
        # 5 menit * 60 detik / 10 detik per tick = 30 tick jika tidak diakselerasi
        default_ticks = int((5 * 60) / interval_sec)
        super().__init__(interval_sec, ticks_to_trigger or default_ticks)
        self.quiet_ticks = 0
        self.alert_triggered = False

    def step(self, valve_state: str) -> Tuple[Optional[float], Optional[str]]:
        self.tick_count += 1
        if valve_state == "CLOSED":
            return 0.0, None

        self.quiet_ticks += 1
        flow = 2.5  # Di atas ambang 1.0 LPM

        if not self.alert_triggered and self.quiet_ticks >= self.ticks_to_trigger:
            self.alert_triggered = True
            return flow, "QUIET_HOURS"

        return flow, None


class OfflineScenario(BaseScenario):
    """
    Skenario offline:
    Simulator berhenti mengirimkan pesan (diam) untuk menguji deteksi offline 30 detik.
    """
    name = "offline"

    def step(self, valve_state: str) -> Tuple[Optional[float], Optional[str]]:
        self.tick_count += 1
        return None, None


class NoAckScenario(NormalScenario):
    """
    Skenario no-ack:
    Mengirim telemetri normal, namun saat menerima perintah cmd, sengaja tidak membalas ack
    untuk menguji timeout 15 detik pada backend.
    """
    name = "no-ack"


SCENARIO_MAP = {
    "normal": NormalScenario,
    "leak-continuous": ContinuousLeakScenario,
    "leak-stable": StableLeakScenario,
    "quiet-hours": QuietHoursScenario,
    "offline": OfflineScenario,
    "no-ack": NoAckScenario,
}


def get_scenario(
    name: str,
    interval_sec: float = 10.0,
    ticks_to_trigger: Optional[int] = None,
) -> BaseScenario:
    """Mengembalikan instance skenario yang sesuai berdasarkan nama."""
    cls = SCENARIO_MAP.get(name.lower())
    if not cls:
        valid_names = ", ".join(SCENARIO_MAP.keys())
        raise ValueError(f"Skenario tidak dikenal: '{name}'. Pilihan yang valid: {valid_names}")
    return cls(interval_sec=interval_sec, ticks_to_trigger=ticks_to_trigger)

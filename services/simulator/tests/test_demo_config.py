"""Skenario dari Mode demo dan ambang per kamar (CONTRACT.md versi 1.1)."""

import unittest

from services.simulator.device import SimulatedDevice
from services.simulator.state import SimulatorState


def _device(**kwargs):
    return SimulatedDevice(state=SimulatorState(device_id="2", valve_state="OPEN"), **kwargs)


class TestDemoConfig(unittest.TestCase):
    def test_demo_opens_valve_and_triggers_on_first_tick(self):
        device = _device()
        device.state.set_valve("CLOSED")
        device.apply_demo({"scenario": "LEAK_STABLE"})
        self.assertEqual(device.state.valve_state, "OPEN")
        device.step()
        self.assertEqual(device.last_alert["rule"], "STABLE")
        self.assertEqual(device.state.valve_state, "CLOSED")

    def test_demo_ignores_unknown_scenario(self):
        device = _device()
        device.apply_demo({"scenario": "ASAL"})
        self.assertEqual(device.scenario.name, "normal")

    def test_config_changes_trigger_of_active_scenario(self):
        device = _device(scenario_name="leak-stable", interval_sec=10.0)
        device.apply_config({"continuous_sec": 2700, "stable_sec": 20, "quiet_sec": 300})
        self.assertEqual(device.scenario.ticks_to_trigger, 2)

    def test_config_does_not_slow_accelerated_scenario(self):
        device = _device(scenario_name="leak-stable", interval_sec=10.0, ticks_to_trigger=3)
        device.apply_config({"continuous_sec": 2700, "stable_sec": 600, "quiet_sec": 300})
        self.assertEqual(device.scenario.ticks_to_trigger, 3)


if __name__ == "__main__":
    unittest.main()

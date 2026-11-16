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


class TestLive(unittest.TestCase):
    def test_live_follows_last_flow_and_valve(self):
        device = _device()
        self.assertIsNone(device.publish_live())
        device.state.set_valve("OPEN")
        device.scenario = device.scenario.__class__()
        device.last_flow = 6.4
        self.assertEqual(device.publish_live(), {"flow_lpm": 6.4, "valve": "OPEN"})
        device.state.set_valve("CLOSED")
        self.assertEqual(device.publish_live(), {"flow_lpm": 0.0, "valve": "CLOSED"})

    def test_live_silent_when_offline(self):
        device = _device(scenario_name="offline")
        device.last_flow = 1.0
        self.assertIsNone(device.publish_live())


if __name__ == "__main__":
    unittest.main()

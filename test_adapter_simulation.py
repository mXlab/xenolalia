"""
Simulation of the Eisode 2026 door-open scenario.

Timeline:
  T=0    /standby (15 min ahead) — session starts
  T=0    /porte — first group enters; 10-min delay timer armed
  T=5    /porte — door opens again; should NOT rearm (allow_retrigger=false)
  T=10   timer fires → experiment starts
  T=20   /porte — experiment running; should be rejected (require_inactive)
  T=50   experiment ends (state → IDLE)
  T=51   /porte — people leaving; should be rejected (max_per_session=1)
"""
import time
import threading
import unittest
from unittest.mock import MagicMock, patch, call

import xeno_adapter

# Minimal adapter config matching eisode2026.yaml /porte handler.
FAKE_CONFIG = {
    "adapter": "Simulation",
    "receive_port": 9999,
    "handlers": {
        "/standby": {
            "type": "standby",
        },
        "/porte": {
            "type": "start",
            "require_on_time": True,
            "late_threshold_minutes": 30,
            "delay_minutes": 10,
            "allow_retrigger": False,
            "max_per_session": 1,
        },
    },
}


def make_adapter():
    xenopi_client = MagicMock()
    adapter = xeno_adapter.OscAdapter.__new__(xeno_adapter.OscAdapter)
    # Manually run __init__ body without needing a real config file.
    with patch("builtins.open"), patch("yaml.safe_load", return_value=FAKE_CONFIG):
        adapter.__init__("fake_path.yaml", xenopi_client)
    return adapter, xenopi_client


class TestEisodeScenario(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi = make_adapter()
        # Freeze time at T=0 (reservation starts now).
        self.t0 = time.time()

    def _set_time(self, minutes_from_t0):
        """Patch time.time() to return a fixed offset from t0."""
        return patch("time.time", return_value=self.t0 + minutes_from_t0 * 60)

    def _fire_pending_timer(self):
        """Manually fire the pending start timer (simulates timer expiry)."""
        t = self.adapter._pending_start_timer
        self.assertIsNotNone(t, "Expected a pending timer but found none.")
        t.cancel()  # prevent it firing for real
        self.adapter._trigger_start()

    # ------------------------------------------------------------------

    def test_scenario(self):
        # T=0: /standby — reservation starts in 30 min.
        # This means require_on_time won't expire until T=60, so T=51 is still in-window.
        with self._set_time(0):
            self.adapter._handle_standby({}, 30)

        self.assertEqual(self.adapter._session_experiment_count, 0,
                         "Session count should be 0 after standby.")
        print("T=0  /standby (30 min ahead) → session reset ✓")

        # T=0: /porte — first group enters; timer should be armed.
        with self._set_time(0):
            self.adapter._handle_start(FAKE_CONFIG["handlers"]["/porte"], 1)

        self.assertIsNotNone(self.adapter._pending_start_timer,
                             "Timer should be armed after first /porte.")
        timer_after_first = self.adapter._pending_start_timer
        print("T=0  /porte #1 → timer armed ✓")

        # T=5: /porte — door opens again; timer should NOT be rearmed.
        with self._set_time(5):
            self.adapter._handle_start(FAKE_CONFIG["handlers"]["/porte"], 1)

        self.assertIs(self.adapter._pending_start_timer, timer_after_first,
                      "Timer should not have been replaced by second /porte.")
        print("T=5  /porte #2 → timer unchanged (allow_retrigger=false) ✓")

        # T=10: timer fires → experiment starts.
        with self._set_time(10):
            self._fire_pending_timer()

        self.xenopi.send_message.assert_called_with("/xeno/control/begin", [])
        self.assertEqual(self.adapter._session_experiment_count, 1,
                         "Session count should be 1 after experiment starts.")
        print("T=10 timer fires → /xeno/control/begin sent, session_count=1 ✓")

        # Simulate XenoPi state: experiment is now active.
        self.adapter.on_experiment_state("MAIN")
        self.assertTrue(self.adapter._experiment_active,
                        "Experiment should be active after MAIN state.")
        print("T=10 XenoPi state=MAIN → _experiment_active=True ✓")

        # T=20: /porte — experiment running; should be rejected.
        self.xenopi.reset_mock()
        with self._set_time(20):
            self.adapter._handle_start(FAKE_CONFIG["handlers"]["/porte"], 1)

        self.xenopi.send_message.assert_not_called()
        print("T=20 /porte #3 → rejected (experiment active) ✓")

        # T=50: experiment ends (state → IDLE).
        self.adapter.on_experiment_state("IDLE")
        self.assertFalse(self.adapter._experiment_active,
                         "Experiment should be inactive after IDLE state.")
        print("T=50 XenoPi state=IDLE → _experiment_active=False ✓")

        # T=51: /porte — people leaving; should be rejected (max_per_session=1).
        self.xenopi.reset_mock()
        with self._set_time(51):
            self.adapter._handle_start(FAKE_CONFIG["handlers"]["/porte"], 1)

        self.xenopi.send_message.assert_not_called()
        self.assertEqual(self.adapter._session_experiment_count, 1,
                         "Session count should still be 1.")
        print("T=51 /porte #4 → rejected (max_per_session=1) ✓")

        print("\nAll checks passed.")


if __name__ == "__main__":
    unittest.main(verbosity=0)

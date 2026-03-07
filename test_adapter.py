"""
test_adapter.py — Tests for xeno_adapter.OscAdapter

Simulates gallery OSC events and verifies the correct control messages
are sent to XenoPi and Pd. No real network connections are made —
all OSC clients are mocked.

Run with:
    python -m pytest test_adapter.py -v
    python test_adapter.py
"""

import os
import tempfile
import unittest
from unittest.mock import MagicMock, call, patch

import yaml

import xeno_adapter
from xeno_adapter import OscAdapter

# Arbitrary fixed epoch second used to control time in tests.
NOW = 1_000_000.0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_adapter(config=None):
    """
    Build an OscAdapter from an inline config dict with mocked OSC clients.
    Returns (adapter, xenopi_mock, pd_mock).
    """
    xenopi = MagicMock()
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.safe_dump(config or {}, f)
        path = f.name
    try:
        adapter = OscAdapter(path, xenopi)
    finally:
        os.unlink(path)
    pd = MagicMock()
    adapter._targets['pd'] = pd
    return adapter, xenopi, pd


def fire(adapter, handler_type, params=None, *osc_args):
    """Invoke a handler directly without going through the OSC dispatcher."""
    fn = adapter._make_handler(handler_type, params or {})
    fn('/test', *osc_args)


class CapturedTimer:
    """
    Drop-in replacement for threading.Timer in tests.
    Captures the delay and callback without scheduling anything.
    Call .fire() to invoke the callback immediately.
    """
    def __init__(self, delay, fn, *args, **kwargs):
        self.delay = delay
        self.fn = fn
        self._alive = True

    def start(self):
        pass

    def cancel(self):
        self._alive = False

    def is_alive(self):
        return self._alive

    def fire(self):
        if self.fn:
            self.fn()


# ---------------------------------------------------------------------------
# Standby handler
# ---------------------------------------------------------------------------

class TestStandby(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def test_records_reservation_start_time(self):
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', {}, 15)
        self.assertAlmostEqual(self.adapter._reservation_start_time, NOW + 15 * 60, places=1)

    def test_sends_volume_reset_to_pd(self):
        params = {'osc': [{'target': 'pd', 'address': '/vol', 'type': 'f', 'value': 0.8}]}
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', params, 10)
        self.pd.send_message.assert_called_once_with('/vol', 0.8)

    def test_informs_xenopi(self):
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', {}, 20)
        self.xenopi.send_message.assert_called_with('/xeno/control/standby', 20)

    def test_cancels_any_pending_start(self):
        timer = CapturedTimer(600, lambda: None)
        self.adapter._pending_start_timer = timer
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', {}, 10)
        self.assertFalse(timer.is_alive())

    def test_zero_minutes_means_reservation_starts_now(self):
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', {}, 0)
        self.assertAlmostEqual(self.adapter._reservation_start_time, NOW, places=1)


# ---------------------------------------------------------------------------
# Start — unconditional (no guards, no delay)
# ---------------------------------------------------------------------------

class TestStartUnconditional(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def test_fires_immediately(self):
        fire(self.adapter, 'start', {})
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_cancels_pending_timer_before_firing(self):
        timer = CapturedTimer(600, lambda: None)
        self.adapter._pending_start_timer = timer
        fire(self.adapter, 'start', {})
        self.assertFalse(timer.is_alive())
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_updates_last_experiment_start_time(self):
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'start', {})
        self.assertAlmostEqual(self.adapter._last_experiment_start, NOW, places=1)


# ---------------------------------------------------------------------------
# Start — with delay
# ---------------------------------------------------------------------------

class TestStartWithDelay(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def test_schedules_timer_with_correct_delay(self):
        with patch('xeno_adapter.threading.Timer', CapturedTimer):
            fire(self.adapter, 'start', {'delay_minutes': 10})
        timer = self.adapter._pending_start_timer
        self.assertIsInstance(timer, CapturedTimer)
        self.assertAlmostEqual(timer.delay, 600.0, places=1)

    def test_does_not_fire_immediately(self):
        with patch('xeno_adapter.threading.Timer', CapturedTimer):
            fire(self.adapter, 'start', {'delay_minutes': 10})
        self.xenopi.send_message.assert_not_called()

    def test_begin_sent_when_timer_fires(self):
        with patch('xeno_adapter.threading.Timer', CapturedTimer):
            fire(self.adapter, 'start', {'delay_minutes': 10})
        self.adapter._pending_start_timer.fire()
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_new_trigger_cancels_previous_timer(self):
        with patch('xeno_adapter.threading.Timer', CapturedTimer):
            fire(self.adapter, 'start', {'delay_minutes': 10})
            first_timer = self.adapter._pending_start_timer
            fire(self.adapter, 'start', {'delay_minutes': 5})
        self.assertFalse(first_timer.is_alive())


# ---------------------------------------------------------------------------
# Start — require_on_time guard
# ---------------------------------------------------------------------------

class TestStartRequireOnTime(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()
        # Reservation starts 15 min from NOW.
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', {}, 15)
        # _reservation_start_time = NOW + 900
        self.xenopi.reset_mock()

    def _porte(self, elapsed_minutes):
        """Simulate /porte arriving `elapsed_minutes` after the reservation start."""
        t = NOW + 900 + elapsed_minutes * 60
        with patch('xeno_adapter.time.time', return_value=t):
            fire(self.adapter, 'start',
                 {'require_on_time': True, 'late_threshold_minutes': 30})

    def test_on_time_starts(self):
        self._porte(5)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_exactly_at_threshold_starts(self):
        self._porte(30)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_one_minute_late_does_not_start(self):
        self._porte(31)
        self.xenopi.send_message.assert_not_called()

    def test_very_late_does_not_start(self):
        self._porte(59)
        self.xenopi.send_message.assert_not_called()

    def test_no_standby_starts_anyway(self):
        # Reset reservation state.
        self.adapter._reservation_start_time = None
        fire(self.adapter, 'start', {'require_on_time': True, 'late_threshold_minutes': 30})
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])


# ---------------------------------------------------------------------------
# Start — require_inactive guard
# ---------------------------------------------------------------------------

class TestStartRequireInactive(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()
        self.params = {'require_inactive': True, 'cooldown_minutes': 90}

    def test_inactive_starts(self):
        self.adapter._experiment_active = False
        fire(self.adapter, 'start', self.params)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_active_does_not_start(self):
        self.adapter._experiment_active = True
        fire(self.adapter, 'start', self.params)
        self.xenopi.send_message.assert_not_called()

    def test_cooldown_blocks_start(self):
        self.adapter._experiment_active = False
        self.adapter._last_experiment_start = NOW - 30 * 60  # 30 min ago
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'start', self.params)
        self.xenopi.send_message.assert_not_called()

    def test_cooldown_elapsed_allows_start(self):
        self.adapter._experiment_active = False
        self.adapter._last_experiment_start = NOW - 91 * 60  # 91 min ago, past the 90-min cooldown
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'start', self.params)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_zero_cooldown_ignores_last_start_time(self):
        self.adapter._experiment_active = False
        self.adapter._last_experiment_start = NOW - 5  # 5 seconds ago
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'start', {'require_inactive': True, 'cooldown_minutes': 0})
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])


# ---------------------------------------------------------------------------
# Start — combined guards
# ---------------------------------------------------------------------------

class TestStartCombinedGuards(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()
        # Reservation starts at NOW.
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', {}, 0)
        self.xenopi.reset_mock()
        self.params = {
            'require_on_time':       True,
            'late_threshold_minutes': 30,
            'require_inactive':      True,
        }

    def test_both_guards_satisfied_starts(self):
        self.adapter._experiment_active = False
        with patch('xeno_adapter.time.time', return_value=NOW + 10 * 60):  # 10 min in, on time
            fire(self.adapter, 'start', self.params)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_on_time_but_experiment_active_does_not_start(self):
        self.adapter._experiment_active = True
        with patch('xeno_adapter.time.time', return_value=NOW + 10 * 60):
            fire(self.adapter, 'start', self.params)
        self.xenopi.send_message.assert_not_called()

    def test_inactive_but_too_late_does_not_start(self):
        self.adapter._experiment_active = False
        with patch('xeno_adapter.time.time', return_value=NOW + 45 * 60):  # 45 min in, too late
            fire(self.adapter, 'start', self.params)
        self.xenopi.send_message.assert_not_called()


# ---------------------------------------------------------------------------
# Stop handler
# ---------------------------------------------------------------------------

class TestStop(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def test_sends_stop_to_xenopi(self):
        fire(self.adapter, 'stop', {})
        self.xenopi.send_message.assert_called_once_with('/xeno/control/stop', [])

    def test_cancels_pending_start(self):
        timer = CapturedTimer(600, lambda: None)
        self.adapter._pending_start_timer = timer
        fire(self.adapter, 'stop', {})
        self.assertFalse(timer.is_alive())

    def test_does_not_send_begin(self):
        fire(self.adapter, 'stop', {})
        self.assertNotIn(
            call('/xeno/control/begin', []),
            self.xenopi.send_message.call_args_list,
        )


# ---------------------------------------------------------------------------
# Route handler and value resolution
# ---------------------------------------------------------------------------

class TestRoute(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def test_forwards_fixed_value_to_target(self):
        params = {'osc': [{'target': 'pd', 'address': '/volume', 'type': 'f', 'value': 0.7}]}
        fire(self.adapter, 'route', params, 0.7)
        self.pd.send_message.assert_called_once_with('/volume', 0.7)

    def test_arg_passthrough(self):
        params = {'osc': [{'target': 'pd', 'address': '/volume', 'type': 'f', 'value': '{0}'}]}
        fire(self.adapter, 'route', params, 0.5)
        self.pd.send_message.assert_called_once_with('/volume', 0.5)

    def test_math_expression(self):
        params = {'osc': [{'target': 'pd', 'address': '/vol_db', 'type': 'f', 'value': '{0} * 0.5'}]}
        fire(self.adapter, 'route', params, 1.0)
        self.pd.send_message.assert_called_once_with('/vol_db', 0.5)

    def test_multiple_targets(self):
        params = {'osc': [
            {'target': 'pd',     'address': '/volume',    'type': 'f', 'value': '{0}'},
            {'target': 'xenopi', 'address': '/xeno/test', 'type': 'i', 'value': 1},
        ]}
        fire(self.adapter, 'route', params, 0.8)
        self.pd.send_message.assert_called_once_with('/volume', 0.8)
        self.xenopi.send_message.assert_called_once_with('/xeno/test', 1)

    def test_does_not_send_to_xenopi_by_default(self):
        params = {'osc': [{'target': 'pd', 'address': '/volume', 'type': 'f', 'value': 0.5}]}
        fire(self.adapter, 'route', params, 0.5)
        self.xenopi.send_message.assert_not_called()

    def test_unknown_target_does_not_crash(self):
        params = {'osc': [{'target': 'nonexistent', 'address': '/x', 'type': 'i', 'value': 1}]}
        fire(self.adapter, 'route', params)  # must not raise

    def test_no_osc_items_does_not_crash(self):
        fire(self.adapter, 'route', {})  # must not raise


# ---------------------------------------------------------------------------
# Experiment state tracking
# ---------------------------------------------------------------------------

class TestExperimentState(unittest.TestCase):

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def test_active_states_set_flag(self):
        for state in ('NEW', 'REFRESH', 'POST_REFRESH', 'FLASH',
                      'SNAPSHOT', 'WAIT_FOR_GLYPH', 'MAIN', 'PRESENTATION'):
            with self.subTest(state=state):
                self.adapter.on_experiment_state(state)
                self.assertTrue(self.adapter._experiment_active)

    def test_idle_clears_flag(self):
        self.adapter.on_experiment_state('MAIN')
        self.adapter.on_experiment_state('IDLE')
        self.assertFalse(self.adapter._experiment_active)

    def test_init_clears_flag(self):
        self.adapter.on_experiment_state('MAIN')
        self.adapter.on_experiment_state('INIT')
        self.assertFalse(self.adapter._experiment_active)


# ---------------------------------------------------------------------------
# Dispatcher registration
# ---------------------------------------------------------------------------

class TestStartServer(unittest.TestCase):

    def test_server_listens_on_configured_port(self):
        """start_server() binds to the receive_port in the adapter config."""
        config = {
            'receive_port': 19876,
            'handlers': {'/start': {'type': 'start', 'params': {}}},
        }
        adapter, xenopi, _ = make_adapter(config)
        adapter.start_server()
        try:
            self.assertEqual(adapter._server.server_address[1], 19876)
        finally:
            adapter.shutdown()

    def test_shutdown_cancels_pending_timer(self):
        """shutdown() cancels any pending start timer."""
        config = {'receive_port': 19878, 'handlers': {}}
        adapter, _, _ = make_adapter(config)
        timer = CapturedTimer(600, lambda: None)
        adapter._pending_start_timer = timer
        adapter.start_server()
        adapter.shutdown()
        self.assertFalse(timer.is_alive())


class TestDispatcherRegistration(unittest.TestCase):

    def test_handlers_are_registered_from_config(self):
        config = {
            'handlers': {
                '/standby': {'type': 'standby', 'params': {}},
                '/porte':   {'type': 'start',   'params': {'delay_minutes': 5}},
                '/stop':    {'type': 'stop',     'params': {}},
                '/volume':  {'type': 'route',    'params': {}},
            }
        }
        adapter, _, _ = make_adapter(config)
        registered = {}

        class FakeDispatcher:
            def map(self, addr, fn):
                registered[addr] = fn

        adapter.register_handlers(FakeDispatcher())
        self.assertIn('/standby', registered)
        self.assertIn('/porte',   registered)
        self.assertIn('/stop',    registered)
        self.assertIn('/volume',  registered)

    def test_unknown_handler_type_does_not_register(self):
        config = {'handlers': {'/foo': {'type': 'nonexistent', 'params': {}}}}
        adapter, _, _ = make_adapter(config)
        registered = {}

        class FakeDispatcher:
            def map(self, addr, fn):
                registered[addr] = fn

        adapter.register_handlers(FakeDispatcher())
        self.assertNotIn('/foo', registered)


# ---------------------------------------------------------------------------
# End-to-end scenario: Eisode 2026 (reservation-based)
# ---------------------------------------------------------------------------

class TestScenarioEisode(unittest.TestCase):
    """
    Simulates the Eisode 2026 flow:
      /standby → /porte → delayed experiment start (or rejection if too late).
    """

    STANDBY_PARAMS  = {'osc': [{'target': 'pd', 'address': '/volume', 'type': 'f', 'value': 1.0}]}
    PORTE_PARAMS    = {'require_on_time': True, 'late_threshold_minutes': 30, 'delay_minutes': 10}

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def _standby(self, minutes_ahead):
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', self.STANDBY_PARAMS, minutes_ahead)
        # _reservation_start_time = NOW + minutes_ahead * 60
        self.xenopi.reset_mock()
        self.pd.reset_mock()

    def _porte_direct(self, elapsed_minutes_into_slot):
        t = NOW + 15 * 60 + elapsed_minutes_into_slot * 60
        with patch('xeno_adapter.time.time', return_value=t), \
             patch('xeno_adapter.threading.Timer', CapturedTimer):
            fire(self.adapter, 'start', self.PORTE_PARAMS)

    def test_on_time_schedules_delayed_start(self):
        """Visitors arrive 5 min into slot → timer for 10 min delay is created."""
        self._standby(15)
        self._porte_direct(5)

        timer = self.adapter._pending_start_timer
        self.assertIsInstance(timer, CapturedTimer)
        self.assertAlmostEqual(timer.delay, 600.0, places=1)
        self.xenopi.send_message.assert_not_called()

    def test_timer_fires_begin(self):
        """When the delay timer fires, /xeno/control/begin is sent."""
        self._standby(15)
        self._porte_direct(5)
        self.adapter._pending_start_timer.fire()
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_late_arrival_does_not_start(self):
        """Visitors arrive 45 min into slot → no timer, no start."""
        self._standby(15)
        self._porte_direct(45)
        self.assertIsNone(self.adapter._pending_start_timer)
        self.xenopi.send_message.assert_not_called()

    def test_manual_start_overrides_late_arrival(self):
        """Even if visitors are too late, operator /start fires immediately."""
        self._standby(15)
        self._porte_direct(45)
        self.xenopi.send_message.assert_not_called()
        fire(self.adapter, 'start', {})  # unconditional
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_stop_cancels_pending_start(self):
        """If /stop arrives while waiting for the delay, the timer is cancelled."""
        self._standby(15)
        self._porte_direct(5)
        timer = self.adapter._pending_start_timer
        self.assertIsInstance(timer, CapturedTimer)

        fire(self.adapter, 'stop', {})
        self.assertFalse(timer.is_alive())
        self.xenopi.send_message.assert_called_once_with('/xeno/control/stop', [])

    def test_standby_resets_volume(self):
        """Volume is reset to 1.0 when /standby is received."""
        self._standby(15)
        # We reset mocks in _standby(), so re-fire standby directly:
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'standby', self.STANDBY_PARAMS, 15)
        self.pd.send_message.assert_called_with('/volume', 1.0)

    def test_volume_forwarded_to_pd(self):
        params = {'osc': [{'target': 'pd', 'address': '/volume', 'type': 'f', 'value': '{0}'}]}
        fire(self.adapter, 'route', params, 0.75)
        self.pd.send_message.assert_called_once_with('/volume', 0.75)


# ---------------------------------------------------------------------------
# End-to-end scenario: proximity sensor (no time slots)
# ---------------------------------------------------------------------------

class TestScenarioProximity(unittest.TestCase):
    """
    Simulates an installation with a PIR/proximity sensor:
      First detection when idle → start.
      Detections while running → ignored.
      Operator /stop → IDLE.
      Next detection after IDLE → start again.
    """

    PARAMS = {'require_inactive': True, 'cooldown_minutes': 90}

    def setUp(self):
        self.adapter, self.xenopi, self.pd = make_adapter()

    def test_first_detection_starts_experiment(self):
        self.adapter._experiment_active = False
        fire(self.adapter, 'start', self.PARAMS)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_detection_while_active_is_ignored(self):
        self.adapter._experiment_active = True
        fire(self.adapter, 'start', self.PARAMS)
        self.xenopi.send_message.assert_not_called()

    def test_repeated_detections_ignored_within_cooldown(self):
        self.adapter._experiment_active = False
        self.adapter._last_experiment_start = NOW - 30 * 60  # only 30 min ago
        with patch('xeno_adapter.time.time', return_value=NOW):
            fire(self.adapter, 'start', self.PARAMS)
        self.xenopi.send_message.assert_not_called()

    def test_experiment_end_allows_new_start(self):
        """After XenoPi reports IDLE, the next detection can start a new experiment."""
        self.adapter._experiment_active = True
        self.adapter.on_experiment_state('IDLE')
        self.assertFalse(self.adapter._experiment_active)

        self.adapter._last_experiment_start = None  # no cooldown to worry about
        fire(self.adapter, 'start', self.PARAMS)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_stop_sends_idle_to_xenopi(self):
        fire(self.adapter, 'stop', {})
        self.xenopi.send_message.assert_called_once_with('/xeno/control/stop', [])

    def test_manual_start_bypasses_all_guards(self):
        """Operator /start works even while an experiment is active."""
        self.adapter._experiment_active = True
        fire(self.adapter, 'start', {})  # no guards
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])

    def test_full_cycle(self):
        """
        Full lifecycle: idle → detection → experiment runs → stop → idle → detection → start.
        """
        # 1. System starts idle.
        self.adapter._experiment_active = False

        # 2. Someone approaches — experiment starts.
        fire(self.adapter, 'start', self.PARAMS)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])
        self.xenopi.reset_mock()

        # 3. XenoPi reports experiment is running.
        self.adapter.on_experiment_state('MAIN')
        self.assertTrue(self.adapter._experiment_active)

        # 4. Another person approaches — ignored.
        fire(self.adapter, 'start', self.PARAMS)
        self.xenopi.send_message.assert_not_called()

        # 5. Operator stops the piece.
        fire(self.adapter, 'stop', {})
        self.xenopi.send_message.assert_called_once_with('/xeno/control/stop', [])
        self.xenopi.reset_mock()

        # 6. XenoPi transitions to IDLE.
        self.adapter.on_experiment_state('IDLE')
        self.assertFalse(self.adapter._experiment_active)

        # 7. New visitor — starts again.
        self.adapter._last_experiment_start = None
        fire(self.adapter, 'start', self.PARAMS)
        self.xenopi.send_message.assert_called_once_with('/xeno/control/begin', [])


if __name__ == '__main__':
    unittest.main(verbosity=2)

"""
xeno_bridge.py — Exhibition context bridge for Xenolalia.

Imported as a module by xeno_server.py. Translates venue-specific OSC
messages into canonical Xenolalia control commands.

Usage (in xeno_server.py):
    import xeno_bridge
    bridge = xeno_bridge.VenueBridge("venues/eisode2026.yaml", xenopi_client)
    bridge.start_server()   # starts listening on receive_port from the venue YAML
    # Then in handle_state: bridge.on_experiment_state(state)

Venue configs live in venues/<name>.yaml. See venues/bian_2026.yaml for
a full example and venues/default.yaml for a minimal starting point.

Built-in handler types
----------------------
start    Trigger an experiment, with optional guards:
           delay_minutes (default 0): wait before starting
           require_on_time (default false): only start if within reservation window
             late_threshold_minutes (default 30): minutes of grace after reservation start
           require_inactive (default false): only start if no experiment is running
             cooldown_minutes (default 0): heuristic fallback if XenoPi state unknown
standby  /standby i <minutes>   Record reservation timing; reset volume.
stop     <any>                  Send stop signal to XenoPi (→ IDLE state).
volume   /volume  f <level>     Forward volume to Pd.
"""

import logging
import threading
import time

import yaml
from pythonosc import dispatcher as _dispatcher_mod
from pythonosc import osc_server
from pythonosc import udp_client

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Active experiment states from XenoPi's state machine.
# IDLE is excluded (added by us to signal "stopped").
# ---------------------------------------------------------------------------
_EXPERIMENT_ACTIVE_STATES = {
    'NEW', 'REFRESH', 'POST_REFRESH', 'FLASH',
    'SNAPSHOT', 'WAIT_FOR_GLYPH', 'MAIN', 'PRESENTATION',
}


class VenueBridge:
    """
    Translates venue-specific OSC into canonical Xenolalia control messages.

    Parameters
    ----------
    config_path : str
        Path to the venue YAML config file.
    xenopi_client : udp_client.SimpleUDPClient
        Shared OSC client from xeno_server.py, already pointed at XenoPi.
    """

    def __init__(self, config_path, xenopi_client):
        with open(config_path, "r") as f:
            self._config = yaml.safe_load(f)

        log.info(f"Bridge loaded venue: {self._config.get('venue', config_path)}")

        self._xenopi_client = xenopi_client

        # Optional Pd client, created from config if a 'pd' target is defined.
        self._pd_client = None
        pd_cfg = self._config.get("targets", {}).get("pd", {})
        if pd_cfg:
            self._pd_client = udp_client.SimpleUDPClient(
                pd_cfg.get("host", "127.0.0.1"),
                int(pd_cfg.get("port", 9000)),
            )
            log.info(f"  Pd target: {pd_cfg.get('host')}:{pd_cfg.get('port')}")

        # Internal state.
        self._reservation_start_time = None  # epoch seconds when reservation begins
        self._pending_start_timer    = None  # threading.Timer for deferred start
        self._experiment_active      = False  # updated by on_experiment_state()
        self._last_experiment_start  = None  # epoch seconds, heuristic fallback

        # OSC server (created by start_server()).
        self._server = None

    # -----------------------------------------------------------------------
    # Public interface
    # -----------------------------------------------------------------------

    def register_handlers(self, osc_dispatcher):
        """Register all venue handlers into the given pythonosc Dispatcher."""
        for address, handler_cfg in self._config.get("handlers", {}).items():
            handler_type = handler_cfg.get("type")
            params       = handler_cfg.get("params", {})
            fn = self._make_handler(handler_type, params)
            if fn:
                osc_dispatcher.map(address, fn)
                log.info(f"  Bridge: {address} → [{handler_type}]")

    def start_server(self):
        """
        Start the bridge's own OSC server on the port defined by receive_port
        in the venue config. Runs in a daemon thread so it does not block
        xeno_server.py's main loop.
        """
        disp = _dispatcher_mod.Dispatcher()
        disp.set_default_handler(
            lambda addr, *args: log.debug(f"Bridge: unhandled {addr} {args}")
        )
        self.register_handlers(disp)

        port = int(self._config.get("receive_port", 8001))
        self._server = osc_server.BlockingOSCUDPServer(("0.0.0.0", port), disp)

        t = threading.Thread(target=self._server.serve_forever, daemon=True)
        t.start()
        log.info(f"Bridge server listening on port {port} (venue: {self._config.get('venue', '?')})")

    def on_experiment_state(self, state):
        """
        Called by xeno_server.py whenever /xeno/exp/state is received from XenoPi.
        Used to accurately track whether an experiment is currently running.
        """
        was_active = self._experiment_active
        self._experiment_active = state in _EXPERIMENT_ACTIVE_STATES
        if self._experiment_active != was_active:
            log.info(f"Bridge: experiment {'started' if self._experiment_active else 'ended'} (state={state})")

    def shutdown(self):
        """Stop the bridge server and cancel any pending timers."""
        self._cancel_pending_start()
        if self._server:
            self._server.server_close()

    # -----------------------------------------------------------------------
    # Internals
    # -----------------------------------------------------------------------

    def _trigger_start(self):
        log.info("Bridge: → /xeno/control/begin")
        self._last_experiment_start = time.time()
        self._xenopi_client.send_message("/xeno/control/begin", [])

    def _cancel_pending_start(self):
        if self._pending_start_timer is not None and self._pending_start_timer.is_alive():
            self._pending_start_timer.cancel()
            log.info("Bridge: cancelled pending experiment start.")
        self._pending_start_timer = None

    def _minutes_since_reservation_start(self):
        if self._reservation_start_time is None:
            return None
        return (time.time() - self._reservation_start_time) / 60.0

    def _make_handler(self, handler_type, params):
        _handler_map = {
            "start":   self._handle_start,
            "standby": self._handle_standby,
            "stop":    self._handle_stop,
            "volume":  self._handle_volume,
        }
        fn = _handler_map.get(handler_type)
        if fn is None:
            log.error(f"Bridge: unknown handler type {handler_type!r}. Known: {list(_handler_map)}")
            return None

        def handler(addr, *args):
            log.debug(f"Bridge received {addr} {args}")
            try:
                fn(params, *args)
            except Exception as e:
                log.exception(f"Bridge error in handler for {addr}: {e}")

        return handler

    # -----------------------------------------------------------------------
    # Handler implementations
    # -----------------------------------------------------------------------

    def _handle_standby(self, params, *osc_args):
        """
        /standby i <minutes>
        Reservation starts in N minutes. Reset volume and record timing.
        """
        self._cancel_pending_start()
        minutes_ahead = int(osc_args[0]) if osc_args else 0
        self._reservation_start_time = time.time() + minutes_ahead * 60.0
        log.info(
            f"Bridge: standby — reservation in {minutes_ahead} min "
            f"(at {time.strftime('%H:%M:%S', time.localtime(self._reservation_start_time))})."
        )
        # Reset volume.
        reset_volume = float(params.get("reset_volume", 1.0))
        self._send_volume(params.get("pd_volume_address", "/volume"), reset_volume)
        # Inform XenoPi (informational; XenoPi may use this for display in the future).
        self._xenopi_client.send_message("/xeno/control/standby", minutes_ahead)

    def _handle_start(self, params, *osc_args):
        """
        Unified start trigger with optional guards.

        Guards (all default to off):
          require_on_time    — reject if visitors arrived too late into the reservation
            late_threshold_minutes  (default 30)
          require_inactive   — reject if an experiment is already running
            cooldown_minutes        (default 0, heuristic fallback)

        Scheduling:
          delay_minutes      — wait N minutes before firing (default 0 = immediate)
        """
        # Guard: on-time check.
        if params.get("require_on_time", False):
            threshold = float(params.get("late_threshold_minutes", 30.0))
            elapsed   = self._minutes_since_reservation_start()
            if elapsed is None:
                log.warning("Bridge: require_on_time but no /standby seen — proceeding anyway.")
            elif elapsed > threshold:
                log.warning(
                    f"Bridge: {elapsed:.1f} min late (threshold: {threshold} min) — NOT starting."
                )
                return
            else:
                log.info(f"Bridge: on time ({elapsed:.1f}/{threshold} min elapsed).")

        # Guard: inactive check.
        if params.get("require_inactive", False):
            if self._experiment_active:
                log.info("Bridge: experiment already active — ignoring.")
                return
            cooldown = float(params.get("cooldown_minutes", 0.0))
            if cooldown > 0 and self._last_experiment_start is not None:
                elapsed = (time.time() - self._last_experiment_start) / 60.0
                if elapsed < cooldown:
                    log.info(
                        f"Bridge: cooldown not elapsed ({elapsed:.0f}/{cooldown:.0f} min) — ignoring."
                    )
                    return

        # Schedule or fire.
        delay = float(params.get("delay_minutes", 0.0))
        self._cancel_pending_start()
        if delay > 0:
            log.info(f"Bridge: scheduling start in {delay:.0f} min.")
            self._pending_start_timer = threading.Timer(delay * 60.0, self._trigger_start)
            self._pending_start_timer.daemon = True
            self._pending_start_timer.start()
        else:
            log.info("Bridge: starting immediately.")
            self._trigger_start()

    def _handle_stop(self, params, *osc_args):
        """Stop the current experiment. XenoPi transitions to IDLE (black screen)."""
        self._cancel_pending_start()
        log.info("Bridge: stop → /xeno/control/stop")
        self._xenopi_client.send_message("/xeno/control/stop", [])

    def _handle_volume(self, params, *osc_args):
        """/volume f <level> — Forward to Pd at the configured address."""
        level      = float(osc_args[0]) if osc_args else 1.0
        pd_address = params.get("pd_volume_address", "/volume")
        self._send_volume(pd_address, level)

    def _send_volume(self, address, level):
        if self._pd_client:
            self._pd_client.send_message(address, float(level))
            log.info(f"Bridge: volume {level:.3f} → {address}")
        else:
            log.debug("Bridge: volume message skipped — no Pd target configured.")

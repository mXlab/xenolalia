"""
xeno_adapter.py — Exhibition OSC adapter for Xenolalia.

Imported as a module by xeno_server.py. Translates external OSC
messages into canonical Xenolalia control commands, and fires
time-based scheduled OSC messages.

Usage (in xeno_server.py):
    import xeno_adapter
    adapter = xeno_adapter.OscAdapter("config/adapters/eisode2026.yaml", xenopi_client)
    adapter.start_server()   # starts listening on receive_port from the adapter YAML
    # Then in handle_state: adapter.on_experiment_state(state)

Adapter configs live in config/adapters/<name>.yaml. See
config/adapters/default.yaml for a minimal starting point and
config/adapters/proximity_example.yaml for an example with guards.

Built-in handler types
----------------------
start    Trigger an experiment, with optional guards:
           delay_minutes (default 0): wait before starting
           allow_retrigger (default true): if a delayed start is pending, cancel and rearm;
             set false to ignore subsequent triggers while one is already pending
           require_on_time (default false): only start if within reservation window
             late_threshold_minutes (default 30): minutes of grace after reservation start
           require_inactive (default true): only start if no experiment is running
             cooldown_minutes (default 0): heuristic fallback if XenoPi state unknown
           max_per_session (default unlimited): max experiments allowed since last /standby
standby  Record reservation timing, reset session counter, notify XenoPi, fire osc: side effects.

Top-level config keys
---------------------
auto_refresh:
  interval_minutes: N   — send /xeno/refresh to apparatus every N minutes when no
                          experiment is active. Timer resets on experiment start.
stop     Cancel any pending start, send stop to XenoPi, then fire osc: side effects.
route    Forward incoming args to configured OSC targets (no built-in logic).

All handler types support an osc: list of side-effect messages:

  /standby:
    type: standby
    osc:
      - target: pd
        address: /volume
        type: f
        value: 1.0          # fixed value

  /volume:
    type: route
    osc:
      - target: pd
        address: /volume
        type: f
        value: "{0}"        # incoming arg passthrough
      - target: pd
        address: /volume_db
        type: f
        value: "{0} * 0.5"  # math expression on incoming arg

Values in osc: items may be literals or expressions using {0}, {1}, ...
to reference incoming OSC arguments. Arithmetic operators are supported
(+, -, *, /, //, **, ()). Supported types: i (int), f (float), s (string).

Schedule
--------
Fires OSC messages at specific times of day:

  schedule:
    - time: "22:30"
      target: apparatus
      address: /xeno/ring/grow
      type: i
      value: 1
    - time: "09:00"
      target: pd
      address: /volume
      type: f
      value: 0.5

Targets are resolved first from the targets: section of xenopc.yaml (the
venue-level config loaded by xeno_server.py), then from any targets: section
in the adapter config. xenopc.yaml takes precedence. The built-in target
'xenopi' always resolves to the XenoPi client.

Standard named targets (defined in xenopc.yaml):
  server     xeno_server.py          192.168.0.100:7000
  macroscope XenoProjection display  192.168.0.100:7001
  sonoscope  xeno_sonoscope.pd       192.168.0.100:7002
  neurons    xeno_osc.py (neural net)192.168.0.101:7000
  mesoscope  XenoPi Processing       192.168.0.101:7001
  orbiter    xeno_orbiter.py (OLED)  192.168.0.101:7002
  apparatus  ESP32 apparatus         192.168.0.102:7000
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


class OscAdapter:
    """
    Translates external OSC messages into canonical Xenolalia control commands.

    Parameters
    ----------
    config_path : str
        Path to the adapter YAML config file.
    xenopi_client : udp_client.SimpleUDPClient
        Shared OSC client from xeno_server.py, already pointed at XenoPi.
    extra_targets : dict, optional
        Additional named targets as ``{name: {host, port}}`` dicts, typically
        loaded from xenopc.yaml. These take precedence over targets defined
        in the adapter config.
    """

    def __init__(self, config_path, xenopi_client, extra_targets=None, monitor_client=None):
        with open(config_path, "r") as f:
            self._config = yaml.safe_load(f)

        log.info(f"Adapter loaded: {self._config.get('adapter', config_path)}")

        self._xenopi_client = xenopi_client

        # Build named target dict. 'xenopi' is always available.
        # Adapter-config targets are loaded first; xenopc.yaml targets override.
        self._targets = {"xenopi": xenopi_client}
        for name, cfg in self._config.get("targets", {}).items():
            client = udp_client.SimpleUDPClient(
                cfg.get("host", "127.0.0.1"),
                int(cfg.get("port", 9000)),
            )
            self._targets[name] = client
            log.info(f"  Target '{name}': {cfg.get('host')}:{cfg.get('port')}")
        for name, cfg in (extra_targets or {}).items():
            client = udp_client.SimpleUDPClient(
                cfg.get("host", "127.0.0.1"),
                int(cfg.get("port", 9000)),
            )
            self._targets[name] = client
            log.info(f"  Target '{name}': {cfg.get('host')}:{cfg.get('port')} (from xenopc.yaml)")

        # Schedule: list of timed OSC items.
        self._schedule = self._config.get("schedule", [])

        # Internal state.
        self._reservation_start_time = None  # epoch seconds when reservation begins
        self._pending_start_timer    = None  # threading.Timer for deferred start
        self._experiment_active      = False  # updated by on_experiment_state()
        self._last_experiment_start  = None  # epoch seconds, heuristic fallback for cooldown
        self._session_experiment_count = 0   # reset on /standby; enforces max_per_session
        self._last_refresh_time      = time.time()  # epoch seconds; reset on experiment start or auto-refresh

        # Optional monitor client for OSC forwarding to Open Stage Control.
        self._monitor = monitor_client

        # OSC server and scheduler thread (created by start_server()).
        self._server     = None
        self._stop_event = threading.Event()

    # -----------------------------------------------------------------------
    # Public interface
    # -----------------------------------------------------------------------

    def register_handlers(self, osc_dispatcher):
        """Register all adapter handlers into the given pythonosc Dispatcher."""
        for address, handler_cfg in self._config.get("handlers", {}).items():
            handler_type = handler_cfg.get("type")
            params       = {k: v for k, v in handler_cfg.items() if k != "type"}
            fn = self._make_handler(handler_type, params)
            if fn:
                osc_dispatcher.map(address, fn)
                log.info(f"  Adapter: {address} → [{handler_type}]")

    def start_server(self):
        """
        Start the adapter's own OSC server on the port defined by receive_port
        in the adapter config. Runs in a daemon thread so it does not block
        xeno_server.py's main loop.
        """
        disp = _dispatcher_mod.Dispatcher()
        disp.set_default_handler(
            lambda addr, *args: log.debug(f"Adapter: unhandled {addr} {args}")
        )
        self.register_handlers(disp)

        port = int(self._config.get("receive_port", 8001))
        self._server = osc_server.BlockingOSCUDPServer(("0.0.0.0", port), disp)

        t = threading.Thread(target=self._server.serve_forever, daemon=True)
        t.start()
        log.info(f"Adapter server listening on port {port} (adapter: {self._config.get('adapter', '?')})")

        self._auto_refresh_interval = None
        ar = self._config.get("auto_refresh", {})
        if ar.get("interval_minutes"):
            self._auto_refresh_interval = float(ar["interval_minutes"])
            log.info(f"Adapter auto-refresh: every {self._auto_refresh_interval:.0f} min when inactive.")

        if self._schedule or self._auto_refresh_interval:
            s = threading.Thread(target=self._run_schedule, daemon=True)
            s.start()
            log.info(f"Adapter scheduler started ({len(self._schedule)} item(s)).")

    def on_experiment_state(self, state):
        """
        Called by xeno_server.py whenever /xeno/exp/state is received from XenoPi.
        Used to accurately track whether an experiment is currently running.
        """
        was_active = self._experiment_active
        self._experiment_active = state in _EXPERIMENT_ACTIVE_STATES
        if self._experiment_active != was_active:
            log.info(f"Adapter: experiment {'started' if self._experiment_active else 'ended'} (state={state})")
            self._monitor_send("/xeno/adapter/active", 1 if self._experiment_active else 0)

    def shutdown(self):
        """Stop the adapter server, scheduler, and cancel any pending timers."""
        self._stop_event.set()
        self._cancel_pending_start()
        if self._server:
            self._server.server_close()

    # -----------------------------------------------------------------------
    # OSC item helpers
    # -----------------------------------------------------------------------

    def _resolve_value(self, value, osc_args, type_):
        """
        Resolve a value that may contain {n} arg references and math expressions.
        e.g. "{0}/100" with osc_args=(75,) → 0.75 (as float).
        """
        if isinstance(value, str) and '{' in value:
            expr = value.format(*[str(a) for a in osc_args])
            value = eval(expr, {"__builtins__": {}}, {})
        return {'f': float, 's': str}.get(type_, int)(value)

    def _fire_osc_items(self, items, osc_args):
        """Send a list of OSC items, resolving {n} templates and math expressions."""
        for item in items:
            target_name = item.get('target', 'xenopi')
            client = self._targets.get(target_name)
            if client is None:
                log.warning(f"Adapter: unknown target '{target_name}'")
                continue
            address = item.get('address')
            if not address:
                log.warning(f"Adapter: missing address in osc item {item}")
                continue
            type_ = item.get('type', 'i')
            raw   = item.get('value', '{0}')
            try:
                value = self._resolve_value(raw, osc_args, type_)
            except Exception as e:
                log.warning(f"Adapter: could not resolve value '{raw}': {e}")
                continue
            client.send_message(address, value)
            log.info(f"Adapter: → [{target_name}] {address} {value}")

    # -----------------------------------------------------------------------
    # Scheduler
    # -----------------------------------------------------------------------

    def _run_schedule(self):
        """Background thread: fire scheduled OSC items at their configured times,
        and trigger auto-refresh of the apparatus when idle too long."""
        last_fired_minute = None
        while not self._stop_event.is_set():
            now = time.localtime()
            current_minute = (now.tm_hour, now.tm_min)
            current_hhmm   = f"{now.tm_hour:02d}:{now.tm_min:02d}"

            if current_minute != last_fired_minute:
                for item in self._schedule:
                    if item.get("time") == current_hhmm:
                        log.info(f"Schedule {current_hhmm}: firing")
                        self._fire_osc_items([item], ())

                pending = self._pending_start_timer is not None and self._pending_start_timer.is_alive()
                if self._auto_refresh_interval and not self._experiment_active and not pending:
                    elapsed = (time.time() - self._last_refresh_time) / 60.0
                    if elapsed >= self._auto_refresh_interval:
                        log.info(f"Auto-refresh: {elapsed:.0f} min since last refresh — sending /xeno/refresh.")
                        apparatus = self._targets.get("apparatus")
                        if apparatus:
                            apparatus.send_message("/xeno/refresh", [])
                            self._last_refresh_time = time.time()
                        else:
                            log.warning("Auto-refresh: 'apparatus' target not found.")

                last_fired_minute = current_minute

            self._stop_event.wait(60 - now.tm_sec)

    # -----------------------------------------------------------------------
    # Internals
    # -----------------------------------------------------------------------

    def _monitor_send(self, address, value):
        """Forward a state message to the monitor client if one is configured."""
        if self._monitor:
            self._monitor.send_message(address, value)

    def _trigger_start(self):
        log.info("Adapter: → /xeno/control/begin")
        self._last_experiment_start = time.time()
        self._last_refresh_time     = time.time()  # experiment start triggers a refresh
        self._session_experiment_count += 1
        self._xenopi_client.send_message("/xeno/control/begin", [])
        self._monitor_send("/xeno/adapter/pending", 0)

    def _cancel_pending_start(self):
        if self._pending_start_timer is not None and self._pending_start_timer.is_alive():
            self._pending_start_timer.cancel()
            log.info("Adapter: cancelled pending experiment start.")
            self._monitor_send("/xeno/adapter/pending", 0)
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
            "route":   self._handle_route,
        }
        fn = _handler_map.get(handler_type)
        if fn is None:
            log.error(f"Adapter: unknown handler type {handler_type!r}. Known: {list(_handler_map)}")
            return None

        def handler(addr, *args):
            log.debug(f"Adapter received {addr} {args}")
            try:
                fn(params, *args)
            except Exception as e:
                log.exception(f"Adapter error in handler for {addr}: {e}")

        return handler

    # -----------------------------------------------------------------------
    # Handler implementations
    # -----------------------------------------------------------------------

    def _handle_standby(self, params, *osc_args):
        """
        Record reservation timing, fire osc: side effects, notify XenoPi.
        Resets the session experiment counter for max_per_session enforcement.
        """
        self._cancel_pending_start()
        self._session_experiment_count = 0
        self._experiment_active = False  # new session — clear any stale active flag
        minutes_ahead = int(osc_args[0]) if osc_args else 0
        self._reservation_start_time = time.time() + minutes_ahead * 60.0
        log.info(
            f"Adapter: standby — reservation in {minutes_ahead} min "
            f"(at {time.strftime('%H:%M:%S', time.localtime(self._reservation_start_time))})."
        )
        self._fire_osc_items(params.get('osc', []), osc_args)
        self._xenopi_client.send_message("/xeno/control/standby", minutes_ahead)
        self._monitor_send("/xeno/adapter/standby", minutes_ahead)
        self._monitor_send("/xeno/adapter/pending", 0)
        self._monitor_send("/xeno/adapter/active", 0)

    def _handle_start(self, params, *osc_args):
        """
        Unified start trigger with optional guards.

        Guards (all default to off unless noted):
          require_on_time    — reject if visitors arrived too late into the reservation
            late_threshold_minutes  (default 30)
          require_inactive   — reject if an experiment is already running (default true)
            cooldown_minutes        (default 0, heuristic fallback if XenoPi state unknown)
          max_per_session    — reject once this many experiments have run since last /standby
                               (default unlimited)

        Scheduling:
          delay_minutes      — wait N minutes before firing (default 0 = immediate)
          allow_retrigger    — if a delayed start is already pending, cancel and rearm it
                               (default true; set false to ignore subsequent triggers)
        """
        # Guard: on-time check.
        if params.get("require_on_time", False):
            threshold = float(params.get("late_threshold_minutes", 30.0))
            elapsed   = self._minutes_since_reservation_start()
            if elapsed is None:
                log.warning("Adapter: require_on_time but no /standby seen — proceeding anyway.")
            elif elapsed > threshold:
                log.warning(
                    f"Adapter: {elapsed:.1f} min late (threshold: {threshold} min) — NOT starting."
                )
                return
            else:
                log.info(f"Adapter: on time ({elapsed:.1f}/{threshold} min elapsed).")

        # Guard: inactive check (default true — don't restart a running experiment).
        if params.get("require_inactive", True):
            if self._experiment_active:
                log.info("Adapter: experiment already active — ignoring.")
                return
            cooldown = float(params.get("cooldown_minutes", 0.0))
            if cooldown > 0 and self._last_experiment_start is not None:
                elapsed = (time.time() - self._last_experiment_start) / 60.0
                if elapsed < cooldown:
                    log.info(
                        f"Adapter: cooldown not elapsed ({elapsed:.0f}/{cooldown:.0f} min) — ignoring."
                    )
                    return

        # Guard: session experiment limit.
        max_per_session = params.get("max_per_session", None)
        if max_per_session is not None and self._session_experiment_count >= int(max_per_session):
            log.info(
                f"Adapter: session experiment limit reached "
                f"({self._session_experiment_count}/{max_per_session}) — ignoring."
            )
            return

        # Guard: retrigger — if a delayed start is already pending, honour allow_retrigger.
        if self._pending_start_timer is not None and self._pending_start_timer.is_alive():
            if not params.get("allow_retrigger", True):
                log.info("Adapter: start already pending and allow_retrigger=false — ignoring.")
                return
            # allow_retrigger=true (default): fall through, cancel and rearm below.

        # Fire osc side effects immediately (before any delay timer).
        self._fire_osc_items(params.get('osc', []), osc_args)

        # Schedule or fire.
        delay = float(params.get("delay_minutes", 0.0))
        self._cancel_pending_start()
        if delay > 0:
            log.info(f"Adapter: scheduling start in {delay:.0f} min.")
            self._pending_start_timer = threading.Timer(delay * 60.0, self._trigger_start)
            self._pending_start_timer.daemon = True
            self._pending_start_timer.start()
            self._monitor_send("/xeno/adapter/pending", 1)
        else:
            log.info("Adapter: starting immediately.")
            self._trigger_start()

    def _handle_stop(self, params, *osc_args):
        """Cancel any pending start, send stop to XenoPi, fire osc: side effects."""
        self._cancel_pending_start()
        log.info("Adapter: stop → /xeno/control/stop")
        self._xenopi_client.send_message("/xeno/control/stop", [])
        self._fire_osc_items(params.get('osc', []), osc_args)

    def _handle_route(self, params, *osc_args):
        """Forward incoming args to configured OSC targets."""
        self._fire_osc_items(params.get('osc', []), osc_args)

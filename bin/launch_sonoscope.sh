#!/usr/bin/env bash
# Launch (or restart) the Pd sonoscope patch.
# Safe to call while already running — kills the existing instance first.

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."

# Export the active session environment (DISPLAY, XDG_RUNTIME_DIR, etc.)
# so this script works when called from adapter, cron, or a bare terminal.
source "$bin_dir/xeno_session_env.sh"

if pkill -f 'xeno-sonoscope.pd' 2>/dev/null; then
    echo "[$(date)] Stopped existing Pd sonoscope."
    sleep 2
fi

bash "$bin_dir/xeno_audio.sh" "$xeno_dir/pd/xeno-sonoscope.pd" >> "$xeno_dir/logs/xeno_sonoscope.log" 2>&1 &
echo "[$(date)] Pd sonoscope launched (PID=$!)"

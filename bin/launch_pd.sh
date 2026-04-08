#!/usr/bin/env bash
# Launch (or restart) the Pd sonoscope patch.
# Safe to call while already running — kills the existing instance first.

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."

if pkill -f 'xeno-sonoscope.pd' 2>/dev/null; then
    echo "[$(date)] Stopped existing Pd sonoscope."
    sleep 2
fi

bash "$bin_dir/xeno_audio.sh" "$xeno_dir/pd/xeno-sonoscope.pd" >> "$xeno_dir/logs/xeno_sonoscope.log" 2>&1 &
echo "[$(date)] Pd sonoscope launched (PID=$!)"

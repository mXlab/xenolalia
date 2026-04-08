#!/usr/bin/env bash
# Launch (or restart) XenoProjection via run_sketch.sh (auto-restarts on crash).
# Safe to call while already running — kills the existing instance first.

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."

# pkill -f 'XenoProjection' matches both run_sketch.sh and processing-java.
if pkill -f 'XenoProjection' 2>/dev/null; then
    echo "[$(date)] Stopped existing XenoProjection."
    sleep 2
fi

bash "$bin_dir/run_sketch.sh" "$xeno_dir/processing/XenoProjection/XenoProjection.pde" >> "$xeno_dir/logs/xeno_projection.log" 2>&1 &
echo "[$(date)] XenoProjection launched (PID=$!)"

#!/usr/bin/env bash

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."
xeno_env_dir="$xeno_dir/xeno-env"
xeno_logs_dir="$xeno_dir/logs"

# Ensure logs directory exists.
mkdir -p $xeno_logs_dir

# Number of old log files to keep.
LOG_KEEP=5

# Rotate a log file, keeping the last LOG_KEEP copies as <log>.1, <log>.2, ...
rotate_log() {
    local log="$1"
    for i in $(seq $((LOG_KEEP-1)) -1 1); do
        [ -f "${log}.$i" ] && mv "${log}.$i" "${log}.$((i+1))"
    done
    [ -f "$log" ] && mv "$log" "${log}.1"
}

rotate_log $xeno_logs_dir/xeno_server.log
rotate_log $xeno_logs_dir/xeno_sonoscope.log
rotate_log $xeno_logs_dir/xeno_projection.log

# Cleanup: use pkill for restartable components so instances relaunched via
# launch_*.sh are also caught on shutdown (their PIDs differ from startup).
cleanup() {
    echo "Shutting down..."
    kill $prevent_sleep_pid $xeno_server_pid $open_stage_control_pid 2>/dev/null
    pkill -f 'xeno-sonoscope.pd' 2>/dev/null
    pkill -f 'XenoProjection' 2>/dev/null
}
trap 'cleanup; exit' SIGINT SIGTERM

# Prevent sleep.
/bin/bash $bin_dir/prevent_sleep.sh &
prevent_sleep_pid=$!
echo "Launching prevent_sleep (PID=$prevent_sleep_pid)"

# Launch xeno_server (cd first so relative paths like config/xenopc.yaml resolve correctly).
cd $xeno_dir && $xeno_env_dir/bin/python3 -u $xeno_dir/xeno_server.py --local-snapshots-dir $xeno_dir/contents > $xeno_logs_dir/xeno_server.log 2>&1 &
xeno_server_pid=$!
echo "Launching xeno_server (PID=$xeno_server_pid)"

# Launch Open Stage Control.
/usr/bin/open-stage-control &
open_stage_control_pid=$!
echo "Launching Open Stage Control (PID=$open_stage_control_pid)"

# Launch Pd sonoscope and XenoProjection via their launch scripts.
# These handle kill-if-running + start, so they can also be called to restart.
bash $bin_dir/launch_pd.sh
bash $bin_dir/launch_projection.sh

echo ""
echo "All components launched. To restart individual components:"
echo "  $bin_dir/launch_pd.sh"
echo "  $bin_dir/launch_projection.sh"
echo ""

# Keep alive until interrupted or xeno_server exits.
wait $xeno_server_pid
cleanup

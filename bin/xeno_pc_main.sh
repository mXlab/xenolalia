#!/usr/bin/env bash

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."
xeno_env_dir="$xeno_dir/xeno-env"
xeno_logs_dir="$xeno_dir/logs"

# Prevent sleep.
/bin/bash $bin_dir/prevent_sleep.sh &
prevent_sleep_pid=$!
echo "Launching prevent_sleep (PID=$prevent_sleep_pid)"

# Launch xeno_osc.
$xeno_env_dir/bin/python3 $xeno_dir/xeno_server.py --local-snapshots-dir $xeno_dir/contents > $xeno_logs_dir/xeno_server.log 2>&1 &
xeno_server_pid=$!
echo "Launching xeno_server (PID=$xeno_server_pid)"

# Launch Open Stage Control.
echo "Launching Open Stage Control..."
/usr/bin/open-stage-control &
open_stage_control_pid=$!
echo "Launching Open Stage Control (PID=$open_stage_control_pid)"

# Launch Pd sonoscope.
sudo /usr/bin/pd $xeno_dir/pd/xeno-sonoscope.pd > $xeno_logs_dir/xeno_sonoscope.log 2>&1 &
xeno_sonoscope_pid=$!
echo "Launching xeno-sonoscope (PID=$xeno_sonoscope_pid)"

cleanup="sudo kill $prevent_sleep_pid $xeno_server_pid $open_stage_control_pid $xeno_sonoscope_pid"

echo ""
echo "If the script does not terminate nicely you can kill all subprocesses by running:"
echo $cleanup
echo ""

trap "$cleanup; exit" SIGINT

# Launch processing sketch.
echo "Launching XenoPi"
/opt/processing/processing-java --sketch=$xeno_dir/processing/XenoProjection --run > $xeno_logs_dir/xeno_projection.log 2>&1

# Cleanup on exit.
eval $cleanup

#!/usr/bin/env bash

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."
xeno_logs_dir="$xeno_dir/logs"
cd $xeno_dir

# Prevent sleep.
/bin/bash $bin_dir/prevent_sleep.sh &
prevent_sleep_pid=$!
echo "Launching prevent_sleep (PID=$prevent_sleep_pid)"

# Launch xeno_osc.
/usr/bin/python3 $xeno_dir/xeno_osc.py > $xeno_logs_dir/xeno_osc.log 2>&1 </dev/null &
xeno_osc_pid=$!
echo "Launching xeno_osc (PID=$xeno_osc_pid)"

# Launch xeno_orbiter.
/usr/bin/python3 $xeno_dir/xeno_orbiter.py > $xeno_logs_dir/xeno_orbiter.log 2>&1 &
xeno_orbiter_pid=$!
echo "Launching xeno_orbiter (PID=$xeno_orbiter_pid)"

cleanup="sudo kill $prevent_sleep_pid $xeno_osc_pid $xeno_orbiter_pid"

echo ""
echo "If the script does not terminate nicely you can kill all subprocesses by running:"
echo $cleanup
echo ""

trap "$cleanup; exit" SIGINT

# Initialize log file.
> $xeno_logs_dir/xeno_pi.log

# Wait for xeno_osc.py to start before first launch.
echo "Waiting for xeno_osc.py to start..."
sleep 20

# Launch processing sketch, restarting on crash.
# On subsequent restarts xeno_osc.py is already running, so use a shorter delay.
while true; do
  echo "[$(date)] Launching XenoPi" >> $xeno_logs_dir/xeno_pi.log
  /usr/local/bin/processing-java --sketch=$xeno_dir/XenoPi --run >> $xeno_logs_dir/xeno_pi.log 2>&1
  EXIT_CODE=$?
  echo "[$(date)] XenoPi exited with code $EXIT_CODE. Restarting in 5s..." >> $xeno_logs_dir/xeno_pi.log
  sleep 5
done

# Cleanup on exit (reached only via trap above).
eval $cleanup

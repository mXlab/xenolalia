#!/usr/bin/env bash

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."

# Prevent sleep.
/bin/bash $bin_dir/prevent_sleep.sh &
prevent_sleep_pid=$!
echo "Launching prevent_sleep (PID=$prevent_sleep_pid)"

# Launch xeno_osc.
/usr/bin/python3 $xeno_dir/xeno_osc.py -c $xeno_dir/results/model_sparse_conv_enc20-40_dec40-20_k5_b128.hdf5 &
xeno_osc_pid=$!
echo "Launching xeno_osc (PID=$xeno_osc_pid)"

# Launch xeno_orbiter.
/usr/bin/python3 $xeno_dir/xeno_orbiter.py &
xeno_orbiter_pid=$!
echo "Launching xeno_orbiter (PID=$xeno_orbiter_pid)"

cleanup="sudo kill $prevent_sleep_pid $xeno_osc_pid $xeno_orbiter_pid"

echo ""
echo "If the script does not terminate nicely you can kill all subprocesses by running:"
echo $cleanup
echo ""

trap "$cleanup; exit" SIGINT

# Launch processing sketch.
echo "Launching XenoPi"
/usr/local/bin/processing-java --sketch=$xeno_dir/XenoPi --run

# Cleanup on exit.
eval $cleanup

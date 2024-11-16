#!/usr/bin/env bash

bin_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
xeno_dir="$bin_dir/.."

# Prevent sleep.
/bin/bash $bin_dir/prevent_sleep.sh &
prevent_sleep_pid=$!
echo "Launching prevent_sleep (PID=$prevent_sleep_pid)"

cleanup="sudo kill $prevent_sleep_pid"

echo ""
echo "If the script does not terminate nicely you can kill all subprocesses by running:"
echo $cleanup
echo ""

trap "$cleanup; exit" SIGINT

# Launch processing sketch.
echo "Launching XenoMicroscope"
/usr/local/bin/processing-java --sketch=$xeno_dir/processing/XenoMicroscope --run

# Cleanup on exit.
eval $cleanup

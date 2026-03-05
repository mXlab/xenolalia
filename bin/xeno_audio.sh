#!/bin/bash
# Launch Pd on XenoPC via pw-jack with HDMI output
# Usage: ./xenoaudio [patch.pd]

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PATCH="${1:-$SCRIPT_DIR/test_stereo.pd}"
SINK="alsa_output.pci-0000_00_1f.3.hdmi-stereo"

cleanup() {
    kill "$PD_PID" 2>/dev/null
    wait "$PD_PID" 2>/dev/null
    echo "pd stopped"
}
trap cleanup EXIT INT TERM

# start pd in background briefly so we can link it
pw-jack pd -noprefs -jack -noadc -r 48000 -outchannels 2 -audiobuf 200 -send '; pd dsp 1' "$PATCH" &
PD_PID=$!

sleep 3

# connect to HDMI
pw-link pure_data:output_1 "${SINK}:playback_FL" 2>/dev/null
pw-link pure_data:output_2 "${SINK}:playback_FR" 2>/dev/null
echo "pd connected to HDMI — ctrl-c to stop"

# wait on pd process
wait "$PD_PID"

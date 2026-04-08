#!/bin/bash
# Launch Pd on XenoPC via pw-jack with HDMI output
# Usage: xeno_audio.sh [--gui|--nogui] [patch.pd]
#   --nogui  Run Pd without the GUI window (default)
#   --gui    Run Pd with the GUI window (for debugging)

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

GUI=false
PATCH=""
for arg in "$@"; do
    case "$arg" in
        --gui)   GUI=true ;;
        --nogui) GUI=false ;;
        *)       PATCH="$arg" ;;
    esac
done
PATCH="${PATCH:-$SCRIPT_DIR/test_stereo.pd}"

SINK="alsa_output.pci-0000_00_1f.3.hdmi-stereo"

cleanup() {
    kill "$PD_PID" 2>/dev/null
    wait "$PD_PID" 2>/dev/null
    echo "pd stopped"
}
trap cleanup EXIT INT TERM

# Wait for PipeWire to be ready (up to 30s)
PW_SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipewire-0"
for i in $(seq 1 30); do
    [ -S "$PW_SOCKET" ] && break
    echo "Waiting for PipeWire... ($i/30)"
    sleep 1
done

if [ ! -S "$PW_SOCKET" ]; then
    echo "PipeWire socket not found, aborting"
    exit 1
fi

# Start pd via pw-jack
GUI_FLAG=$( [ "$GUI" = false ] && echo "-nogui" || echo "" )
pw-jack pd $GUI_FLAG -noprefs -jack -noadc -r 48000 -outchannels 2 -audiobuf 200 -send '; pd dsp 1' "$PATCH" &
PD_PID=$!

# Retry pw-link until HDMI sink is available (up to 15s)
for i in $(seq 1 15); do
    sleep 1
    pw-link pure_data:output_1 "${SINK}:playback_FL" 2>/dev/null && \
    pw-link pure_data:output_2 "${SINK}:playback_FR" 2>/dev/null && \
    { echo "pd connected to HDMI"; break; }
done

# Watchdog: re-establish pw-link if the connection drops (e.g. HDMI device cycles).
# pw-link is idempotent: silent no-op if the link already exists.
while kill -0 "$PD_PID" 2>/dev/null; do
    sleep 5
    pw-link pure_data:output_1 "${SINK}:playback_FL" 2>/dev/null
    pw-link pure_data:output_2 "${SINK}:playback_FR" 2>/dev/null
done &

# wait on pd process
wait "$PD_PID"

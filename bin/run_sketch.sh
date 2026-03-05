#!/usr/bin/env bash
# Run a Processing sketch from the command line, restarting on crash.
# Usage: bin/run_sketch.sh path/to/Sketch/Sketch.pde

PROCESSING_JAVA="/opt/processing-4.3/processing-java"
RESTART_DELAY=5  # seconds to wait between restarts

if [ -z "$1" ]; then
  echo "Usage: $0 path/to/Sketch/Sketch.pde" >&2
  exit 1
fi

SKETCH_FILE="$(realpath "$1")"
SKETCH_DIR="$(dirname "$SKETCH_FILE")"

while true; do
  echo "[$(date)] Starting sketch: $SKETCH_DIR"
  "$PROCESSING_JAVA" --sketch="$SKETCH_DIR" --run
  EXIT_CODE=$?
  echo "[$(date)] Sketch exited with code $EXIT_CODE. Restarting in ${RESTART_DELAY}s..."
  sleep "$RESTART_DELAY"
done

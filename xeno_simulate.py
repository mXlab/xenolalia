#!/usr/bin/env python3
"""Simulate xeno_osc.py for a past snapshot directory.

Sends OSC messages to XenoPi (and optionally to XenoProjection) as if
xeno_osc.py had processed the snapshots in real time.  Use this to test
the overlay, visibility tracking, gallery gating, and pipeline scene
without a camera or live model.

Usage:
    python xeno_simulate.py <snapshot_dir> [options]
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

from PIL import Image
from pythonosc import udp_client

import xeno_image

if __name__ == "__main__":
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("snapshot_dir", help="Experiment snapshot directory to replay")
    parser.add_argument("-C", "--configuration-file", default="XenoPi/settings.json")
    parser.add_argument("--xenopi-ip",   default="127.0.0.1")
    parser.add_argument("--xenopi-port", default=7001, type=int)
    parser.add_argument("--server-ip",   default="192.168.0.100")
    parser.add_argument("--server-port", default=7000, type=int)
    parser.add_argument("--delay",       default=2.0, type=float,
                        help="Seconds between steps")
    parser.add_argument("--vis-override", default=None, type=int, choices=[0, 1, 2],
                        help="Force this visibility class for all steps (skip recompute)")
    args = parser.parse_args()

    with open(args.configuration_file) as f:
        cfg = json.load(f)
    input_quad    = tuple(cfg["camera_quad"])
    squircle_mode = cfg.get("squircle_mode", "none")
    threshold_cv    = float(cfg.get("visibility_threshold_cv",    0.1))
    threshold_human = float(cfg.get("visibility_threshold_human", 0.3))

    xenopi = udp_client.SimpleUDPClient(args.xenopi_ip, args.xenopi_port)
    server = udp_client.SimpleUDPClient(args.server_ip, args.server_port)

    snap_dir = Path(args.snapshot_dir)
    uid = snap_dir.name

    # Find ANN images (new naming: *_raw_3ann.png; old: *_processed_nn.png).
    ann_files = sorted(snap_dir.glob("*_raw_3ann.png")) or \
                sorted(snap_dir.glob("*_processed_nn.png"))

    if not ann_files:
        print(f"No ANN images found in {snap_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Replaying {len(ann_files)} steps from {snap_dir}")

    # --- Start experiment ---
    server.send_message("/xeno/server/new", [uid])
    time.sleep(0.5)

    for i, ann_path in enumerate(ann_files):
        ann_path_str = str(ann_path.absolute())
        print(f"  Step {i+1}/{len(ann_files)}: {ann_path.name}")

        # Compute visibility from raw image if possible.
        raw_path = ann_path.with_name(
            ann_path.name.replace("_raw_3ann.png", "_raw.png").replace("_processed_nn.png", "_raw.png")
        )
        vis_class = args.vis_override
        if vis_class is None:
            if raw_path.exists():
                try:
                    # Projected glyph at this step = ann output from the previous step.
                    prev_ann = ann_files[i - 1] if i > 0 else None
                    projected = Image.open(str(prev_ann)) if prev_ann and prev_ann.exists() else None
                    resized, simplified, enhanced, masked, transformed, raw_transformed = \
                        xeno_image.load_image(str(raw_path), False, 28, input_quad, squircle_mode)
                    vis_class = xeno_image.compute_visibility(
                        resized,
                        raw_image=raw_transformed,
                        projected=projected,
                        threshold_cv=threshold_cv,
                        threshold_human=threshold_human,
                    )
                except Exception as e:
                    print(f"    (visibility compute failed: {e})")
                    vis_class = 0
            else:
                vis_class = 0

        # Send step messages.
        xenopi.send_message("/xeno/neurons/step", [ann_path_str])
        xenopi.send_message("/xeno/neurons/visibility", [vis_class])
        server.send_message("/xeno/server/step", [uid])
        print(f"    visibility={vis_class}")

        time.sleep(args.delay)

    # --- End experiment ---
    server.send_message("/xeno/server/end", [uid, 2])  # send as human-visible by default
    print("Done. Sent experiment end.")

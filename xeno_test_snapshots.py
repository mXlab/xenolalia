#!/usr/bin/env python3
"""Batch-test visibility classification on existing raw snapshots.

Usage:
    python xeno_test_snapshots.py XenoPi/snapshots/00_test/ -C XenoPi/settings.json
    python xeno_test_snapshots.py XenoPi/snapshots/ --recursive -C XenoPi/settings.json
"""
import argparse
import json
import sys
from pathlib import Path

import xeno_image

if __name__ == "__main__":

    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("directory", type=str, help="Directory to scan for _raw.png snapshots")
    parser.add_argument("-C", "--configuration-file", type=str, default="XenoPi/settings.json")
    parser.add_argument("--recursive", action="store_true", help="Scan subdirectories too")
    parser.add_argument("--threshold-cv",    type=float, default=None,
                        help="Override CV threshold from settings")
    parser.add_argument("--threshold-human", type=float, default=None,
                        help="Override human threshold from settings")
    args = parser.parse_args()

    # Load settings.
    with open(args.configuration_file) as f:
        cfg = json.load(f)
    input_quad    = tuple(cfg["camera_quad"])
    squircle_mode = cfg.get("squircle_mode", "none")
    threshold_cv    = args.threshold_cv    or cfg.get("visibility_threshold_cv",    0.02)
    threshold_human = args.threshold_human or cfg.get("visibility_threshold_human", 0.10)

    # Collect raw images.
    root = Path(args.directory)
    raw_files = sorted(
        [p for p in root.glob("**/*_raw.png")] if args.recursive
        else [p for p in root.glob("*_raw.png")]
    )

    if not raw_files:
        print(f"No *_raw.png files found in {root}", file=sys.stderr)
        sys.exit(1)

    labels = {0: "invisible ", 1: "cv-only   ", 2: "human-vis "}

    print(f"{'File':<55}  {'Density':>8}  Class")
    print("-" * 75)
    for raw_path in raw_files:
        try:
            resized, *_ = xeno_image.load_image(
                str(raw_path), False, image_side=28,
                input_quad=input_quad, squircle_mode=squircle_mode
            )
            vis = xeno_image.compute_visibility(resized, threshold_cv, threshold_human)
            density = xeno_image._image_density(resized)
            print(f"{str(raw_path.name):<55}  {density:8.4f}  {labels[vis]}")
        except Exception as e:
            print(f"{str(raw_path.name):<55}  ERROR: {e}")

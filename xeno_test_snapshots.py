#!/usr/bin/env python3
"""Batch-test reaction-visibility classification on existing raw snapshots.

For each *_raw.png snapshot the script loads the *_raw_3ann.png from the
PREVIOUS step (within the same experiment directory) as the projected glyph,
then computes the Pearson correlation between the biological signal and that
glyph — both from the CV perspective (processed image) and the human
perspective (raw perspective-corrected image, no base subtraction).

Usage:
    python xeno_test_snapshots.py XenoPi/snapshots/00_test/ -C XenoPi/settings.json
    python xeno_test_snapshots.py XenoPi/snapshots/ --recursive -C XenoPi/settings.json
"""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

import xeno_image

if __name__ == "__main__":

    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("directory", type=str, help="Directory to scan for _raw.png snapshots")
    parser.add_argument("-C", "--configuration-file", type=str, default="XenoPi/settings.json")
    parser.add_argument("--recursive", action="store_true", help="Scan subdirectories too")
    parser.add_argument("--threshold-cv",    type=float, default=None,
                        help="Override CV correlation threshold from settings")
    parser.add_argument("--threshold-human", type=float, default=None,
                        help="Override human correlation threshold from settings")
    args = parser.parse_args()

    # Load settings.
    with open(args.configuration_file) as f:
        cfg = json.load(f)
    input_quad    = tuple(cfg["camera_quad"])
    squircle_mode = cfg.get("squircle_mode", "none")
    threshold_cv    = args.threshold_cv    if args.threshold_cv    is not None else float(cfg.get("visibility_threshold_cv",    0.1))
    threshold_human = args.threshold_human if args.threshold_human is not None else float(cfg.get("visibility_threshold_human", 0.3))

    # Collect raw images.
    root = Path(args.directory)
    raw_files = sorted(
        [p for p in root.glob("**/*_raw.png")] if args.recursive
        else [p for p in root.glob("*_raw.png")]
    )

    if not raw_files:
        print(f"No *_raw.png files found in {root}", file=sys.stderr)
        sys.exit(1)

    # Group by parent directory so previous-step lookup respects experiment boundaries.
    by_dir = defaultdict(list)
    for p in raw_files:
        by_dir[p.parent].append(p)

    labels = {0: "invisible", 1: "cv-only  ", 2: "human-vis"}

    hdr = f"{'File':<55}  {'Density':>7}  {'|CV-r|':>7}  {'|Hum-r|':>8}  Class"
    print(hdr)
    print("-" * len(hdr))

    for dir_path in sorted(by_dir.keys()):
        dir_files = sorted(by_dir[dir_path])

        for i, raw_path in enumerate(dir_files):
            # Find the projected glyph: the _3ann.png from the previous step.
            projected = None
            if i > 0:
                prev_raw = dir_files[i - 1]
                prev_ann = prev_raw.with_name(prev_raw.stem + '_3ann.png')
                if prev_ann.exists():
                    try:
                        projected = Image.open(str(prev_ann))
                    except Exception:
                        projected = None

            try:
                resized, simplified, enhanced, masked, transformed, raw_transformed = \
                    xeno_image.load_image(
                        str(raw_path), False, image_side=28,
                        input_quad=input_quad, squircle_mode=squircle_mode
                    )

                vis = xeno_image.compute_visibility(
                    resized,
                    raw_image=raw_transformed,
                    projected=projected,
                    threshold_cv=threshold_cv,
                    threshold_human=threshold_human,
                )
                density = xeno_image._image_density(resized)

                # Compute correlations for display.
                if projected is not None:
                    proj_28 = projected.convert('L').resize((28, 28), Image.LANCZOS)
                    cv_corr    = abs(xeno_image._image_correlation(resized, proj_28))
                    raw_28     = raw_transformed.convert('L').resize((28, 28), Image.LANCZOS)
                    human_corr = abs(xeno_image._image_correlation(raw_28, proj_28))
                    cv_str    = f"{cv_corr:7.4f}"
                    human_str = f"{human_corr:8.4f}"
                else:
                    cv_str    = "     --"
                    human_str = "      --"

                print(f"{raw_path.name:<55}  {density:7.4f}  {cv_str}  {human_str}  {labels[vis]}")
            except Exception as e:
                print(f"{raw_path.name:<55}  ERROR: {e}")

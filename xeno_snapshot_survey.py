#!/usr/bin/env python3
"""Generate survey contact-sheet images for visibility-threshold calibration.

Scans all *_raw.png snapshots in a directory tree and produces three images:

  survey_density.png   – 'resized' (28×28 processed) sorted by pixel density
  survey_cv_corr.png   – 'transformed' (base-subtracted, not enhanced) sorted by |CV-r|
  survey_hum_corr.png  – raw image (full colour) sorted by |Hum-r|

Each image has 10 rows × 10 columns.  Rows span equal-width metric buckets
from the observed minimum to maximum; the range is printed on the left margin.
Use these sheets to visually identify good threshold values.

Speed notes:
  - Pre-computed intermediate files (*_raw_2res.png, *_raw_0trn.png) are used
    when available, avoiding the slow thinning step.
  - Set --workers to use multiple CPU cores (default: all available).

Usage:
    python xeno_snapshot_survey.py XenoPi/snapshots/ -C XenoPi/settings.json
    python xeno_snapshot_survey.py XenoPi/snapshots/ -C XenoPi/settings.json -o survey/
    python xeno_snapshot_survey.py XenoPi/snapshots/ -C XenoPi/settings.json --workers 4
"""

import argparse
import json
import multiprocessing
import os
import sys
from collections import defaultdict
from functools import partial
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import xeno_image

COLS       = 10
ROWS       = 10
THUMB      = 112
PAD        = 4
LEFT       = 155
TOP        = 30
FONT_SIZE  = 11
BG_COLOR   = (25, 25, 25)
LABEL_COLOR = (190, 190, 190)
EMPTY_COLOR = (45, 45, 45)


def _load_font(size):
    for path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/Library/Fonts/Arial.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


def _find_prev_ann(prev_raw):
    for suffix in ('_4prj.png', '_3ann.png'):
        candidate = prev_raw.with_name(prev_raw.stem + suffix)
        if candidate.exists():
            return candidate
    old = prev_raw.with_name(prev_raw.name.replace('_raw.png', '_processed_nn.png'))
    if old.exists():
        return old
    return None


def _process_one(args_tuple):
    """Worker function: process one raw snapshot and return metric data.

    Returns a dict with keys:
        density, resized_bytes   – always present on success
        cv_corr, transformed_bytes, human_corr, raw_bytes  – present if prev_ann exists
        error – set on failure
    """
    raw_path_str, prev_ann_str, input_quad, squircle_mode = args_tuple
    raw_path = Path(raw_path_str)

    result = {"path": raw_path_str, "exp_dir": str(raw_path.parent)}

    try:
        # ---- resized: use pre-computed *_2res.png if available ----
        precomp_resized = raw_path.with_name(raw_path.stem + '_2res.png')
        if precomp_resized.exists():
            resized = Image.open(str(precomp_resized)).convert('L')
            # Still need raw_transformed for human correlation (load separately below).
            need_pipeline = False
        else:
            resized, simplified, enhanced, masked, transformed, raw_transformed = \
                xeno_image.load_image(str(raw_path), False, image_side=28,
                                      input_quad=input_quad,
                                      squircle_mode=squircle_mode)
            need_pipeline = True

        result["density"] = xeno_image._image_density(resized)
        result["resized_bytes"] = _img_to_bytes(resized)

        # ---- transformed display: use *_0trn.png if available ----
        precomp_trn = raw_path.with_name(raw_path.stem + '_0trn.png')
        if precomp_trn.exists():
            transformed_disp = Image.open(str(precomp_trn)).convert('L')
        elif need_pipeline:
            transformed_disp = transformed
        else:
            # Run only perspective transform (fast).
            raw_img = Image.open(str(raw_path))
            transformed_disp = xeno_image.transform(raw_img.convert('L'), input_quad)

        # ---- correlations (need prev_ann) ----
        if prev_ann_str:
            prev_ann = Path(prev_ann_str)
            try:
                projected = Image.open(str(prev_ann))
                proj_28   = projected.convert('L').resize((28, 28), Image.LANCZOS)

                cv_corr = abs(xeno_image._image_correlation(resized, proj_28))
                result["cv_corr"] = cv_corr
                result["transformed_bytes"] = _img_to_bytes(transformed_disp)
                result["ann_bytes"] = _img_to_bytes(projected)

                # For human display: use perspective-corrected raw (no processing).
                if need_pipeline:
                    raw_for_display = raw_transformed
                else:
                    raw_img = Image.open(str(raw_path))
                    raw_for_display = xeno_image.transform(raw_img.convert('RGB'), input_quad)

                # For human correlation: use natural base subtraction (scale=1, no
                # amplification) to remove illumination gradient without artificial boost.
                base_img_path = raw_path.parent / "base_image.png"
                if base_img_path.exists():
                    base_img = Image.open(str(base_img_path))
                    base_transformed = xeno_image.transform(base_img.convert('L'), input_quad)
                    raw_for_corr = xeno_image.remove_base_natural(raw_for_display, base_transformed)
                else:
                    raw_for_corr = raw_for_display

                raw_28 = raw_for_corr.resize((28, 28), Image.LANCZOS)
                human_corr = abs(xeno_image._image_correlation(raw_28, proj_28))
                result["human_corr"] = human_corr
                result["raw_bytes"] = _img_to_bytes(raw_for_display)

            except Exception as e:
                pass  # correlation stays absent

    except Exception as e:
        result["error"] = str(e)

    return result


def _img_to_bytes(img):
    """Serialize a PIL Image to PNG bytes for cross-process passing."""
    import io
    buf = io.BytesIO()
    img.convert('RGB').save(buf, format='PNG')
    return buf.getvalue()


def _bytes_to_img(b):
    import io
    return Image.open(io.BytesIO(b)).convert('RGB')


def make_grid(entries, title, thumb=THUMB, nearest=False):
    """Build a ROWS×COLS contact-sheet PIL Image.

    entries: list of (metric_value, PIL_Image, exp_dir, path_str, ann_img_or_None)
    At most one image per experiment directory is shown in each row.
    When ann_img is present a thin inter-row of glyphs is drawn below each snapshot row.

    Returns (canvas, layout, lo, bucket_w) where layout is a list of rows,
    each row being a list of (val, path_str) for cells that were filled.
    """
    if not entries:
        return None, [], 0.0, 1.0

    resample = Image.NEAREST if nearest else Image.LANCZOS

    has_glyphs = any(e[4] is not None for e in entries)
    GLYPH_H    = thumb // 2

    values = [e[0] for e in entries]
    lo, hi = min(values), max(values)
    span = hi - lo if hi > lo else 1e-9
    bucket_w = span / ROWS

    buckets = [[] for _ in range(ROWS)]
    for val, img, exp_dir, path_str, ann_img in sorted(entries, key=lambda x: x[0]):
        b = min(int((val - lo) / bucket_w), ROWS - 1)
        buckets[b].append((val, img, exp_dir, path_str, ann_img))

    selected = []
    for bucket in buckets:
        # One image per experiment: pick the middle entry from each experiment group.
        by_exp = defaultdict(list)
        for val, img, exp_dir, path_str, ann_img in bucket:
            by_exp[exp_dir].append((val, img, path_str, ann_img))
        candidates = sorted(
            [exp_entries[len(exp_entries) // 2] for exp_entries in by_exp.values()],
            key=lambda x: x[0]
        )
        if len(candidates) <= COLS:
            selected.append(candidates)
        else:
            idxs = [round(i * (len(candidates) - 1) / (COLS - 1)) for i in range(COLS)]
            selected.append([candidates[i] for i in idxs])

    font       = _load_font(FONT_SIZE)
    font_small = _load_font(FONT_SIZE - 3)

    snap_h   = thumb + PAD
    inter_h  = (GLYPH_H + PAD) if has_glyphs else 0
    group_h  = snap_h + inter_h
    total_w  = LEFT + COLS * (thumb + PAD) + PAD
    total_h  = TOP  + ROWS * group_h + PAD

    GLYPH_BG = tuple(min(255, c + 15) for c in BG_COLOR)  # slightly lighter strip

    canvas = Image.new('RGB', (total_w, total_h), BG_COLOR)
    draw   = ImageDraw.Draw(canvas)

    draw.text((LEFT, 7), title, fill=(220, 220, 220), font=_load_font(FONT_SIZE))

    layout = []
    for row_idx, row_entries in enumerate(selected):
        y = TOP + row_idx * group_h

        row_lo = lo + row_idx * bucket_w
        row_hi = row_lo + bucket_w
        label  = f"{row_lo:.3f}–{row_hi:.3f}\n(n={len(row_entries)})"
        draw.multiline_text((PAD, y + thumb // 2 - 14), label,
                            fill=LABEL_COLOR, font=font_small, spacing=2)

        row_paths = []
        for col_idx, (val, img, path_str, ann_img) in enumerate(row_entries):
            x = LEFT + col_idx * (thumb + PAD)
            canvas.paste(img.convert('RGB').resize((thumb, thumb), resample), (x, y))
            row_paths.append((val, path_str))

        for col_idx in range(len(row_entries), COLS):
            x = LEFT + col_idx * (thumb + PAD)
            canvas.paste(Image.new('RGB', (thumb, thumb), EMPTY_COLOR), (x, y))

        # ---- glyph inter-row ----
        if has_glyphs:
            gy = y + snap_h
            # background strip
            canvas.paste(Image.new('RGB', (total_w, inter_h), GLYPH_BG), (0, gy))
            # label on the left margin
            draw.text((PAD, gy + GLYPH_H // 2 - 5), "glyph",
                      fill=LABEL_COLOR, font=font_small)
            for col_idx, (val, img, path_str, ann_img) in enumerate(row_entries):
                if ann_img is not None:
                    x = LEFT + col_idx * (thumb + PAD)
                    glyph_sq = ann_img.convert('RGB').resize((GLYPH_H, GLYPH_H), Image.LANCZOS)
                    # center the square glyph within the thumb-wide column cell
                    canvas.paste(glyph_sq, (x + (thumb - GLYPH_H) // 2, gy))

        layout.append((row_lo, row_hi, row_paths))

    return canvas, layout, lo, bucket_w


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("directory", help="Root directory to scan for *_raw.png snapshots")
    parser.add_argument("-C", "--configuration-file", default="XenoPi/settings.json")
    parser.add_argument("-o", "--output-dir", default=".",
                        help="Directory to write the three survey PNG files")
    parser.add_argument("--thumb", type=int, default=THUMB,
                        help="Thumbnail side length in pixels")
    parser.add_argument("--workers", type=int, default=os.cpu_count() or 4,
                        help="Parallel worker processes")
    parser.add_argument("--min-year", type=int, default=2023,
                        help="Exclude snapshot directories whose name starts with a year earlier than this")
    args = parser.parse_args()

    with open(args.configuration_file) as f:
        cfg = json.load(f)
    input_quad    = tuple(cfg["camera_quad"])
    squircle_mode = cfg.get("squircle_mode", "none")

    root      = Path(args.directory)
    raw_files = sorted([
        p for p in root.glob("**/*_raw.png")
        if p.parent.name[:4].isdigit() and int(p.parent.name[:4]) >= args.min_year
    ])
    if not raw_files:
        print(f"No *_raw.png files found in {root}", file=sys.stderr)
        sys.exit(1)

    # Group by directory and build (raw_path, prev_ann_path_or_None) pairs.
    by_dir = defaultdict(list)
    for p in raw_files:
        by_dir[p.parent].append(p)

    work_items = []
    for dir_path in sorted(by_dir.keys()):
        dir_files = sorted(by_dir[dir_path])
        for i, raw_path in enumerate(dir_files):
            prev_ann = None
            if i > 0:
                ann = _find_prev_ann(dir_files[i - 1])
                if ann:
                    prev_ann = str(ann)
            work_items.append((str(raw_path), prev_ann, input_quad, squircle_mode))

    print(f"Processing {len(work_items)} snapshots with {args.workers} workers…")

    density_entries = []
    cv_entries      = []
    hum_entries     = []
    errors = 0

    with multiprocessing.Pool(processes=args.workers) as pool:
        for done, res in enumerate(pool.imap_unordered(_process_one, work_items), 1):
            print(f"\r  {done}/{len(work_items)}", end="", flush=True)
            if "error" in res:
                errors += 1
                continue
            exp_dir  = res["exp_dir"]
            path_str = res["path"]
            ann_img  = _bytes_to_img(res["ann_bytes"]) if "ann_bytes" in res else None
            if "density" in res:
                density_entries.append((res["density"], _bytes_to_img(res["resized_bytes"]), exp_dir, path_str, None))
            if "cv_corr" in res:
                cv_entries.append((res["cv_corr"], _bytes_to_img(res["transformed_bytes"]), exp_dir, path_str, ann_img))
            if "human_corr" in res:
                hum_entries.append((res["human_corr"], _bytes_to_img(res["raw_bytes"]), exp_dir, path_str, ann_img))

    print(f"\n  Done. {len(density_entries)} snapshots loaded"
          f", {len(cv_entries)} with prior glyph"
          f", {errors} errors.")

    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    specs = [
        ("survey_density.png",
         density_entries,
         "Density  |  rows: equal-width buckets lo→hi  |  images: 'resized' 28×28 processed",
         True),
        ("survey_cv_corr.png",
         cv_entries,
         "|CV-r|  |  rows: equal-width buckets lo→hi  |  images: 'transformed' (base-subtracted)",
         False),
        ("survey_hum_corr.png",
         hum_entries,
         "|Hum-r|  |  rows: equal-width buckets lo→hi  |  images: raw_transformed (perspective-corrected)",
         False),
    ]

    for fname, entries, title, nearest in specs:
        print(f"Building {fname} ({len(entries)} entries) …")
        grid, layout, lo, bucket_w = make_grid(entries, title, thumb=args.thumb, nearest=nearest)
        if grid:
            img_path = out / fname
            grid.save(str(img_path))
            print(f"  → {img_path}  ({grid.width}×{grid.height} px)")

            txt_path = out / fname.replace(".png", "_files.txt")
            with open(str(txt_path), 'w') as f:
                f.write(f"# {fname}\n")
                f.write(f"# Grid positions (row, col) → source file\n\n")
                for row_idx, (row_lo, row_hi, row_paths) in enumerate(layout):
                    f.write(f"Row {row_idx:2d}  ({row_lo:.4f} – {row_hi:.4f}):\n")
                    for col_idx, (val, path_str) in enumerate(row_paths):
                        f.write(f"  [{row_idx},{col_idx:2d}]  {val:.4f}  {path_str}\n")
                    f.write("\n")
            print(f"  → {txt_path}")
        else:
            print(f"  (skipped — no entries)")

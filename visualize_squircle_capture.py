# visualize_squircle_capture.py
# Usage: source xeno-env/bin/activate && python visualize_squircle_capture.py
# Outputs: squircle_capture_comparison.png
#
# 3-row grid (rows: none / inside / outside) showing the 28x28 image sent to
# the autoencoder for a sample of raw snapshots from eisode-preparation-2026.
# The outside row shows corner content that inside/none modes discard.

import glob
import json
import sys
import numpy as np

sys.path.insert(0, '.')
import xeno_image
from PIL import Image, ImageDraw

SNAPSHOTS_BASE = 'XenoPi/snapshots'
SCALE = 6   # display 28x28 at 168x168
CELL = 28 * SCALE
PAD = 4
LABEL_H = 20
ROWS = 3  # none / inside / outside

sessions = sorted(glob.glob(f'{SNAPSHOTS_BASE}/*eisode-preparation-2026*'))
samples = []
for session in sessions[:4]:
    with open(f'{session}/settings.json') as f:
        settings = json.load(f)
    camera_quad = tuple(settings['camera_quad'])
    use_base_image = settings.get('use_base_image', False)
    base_image_path = f'{session}/base_image.png' if use_base_image else False
    raw_imgs = sorted(glob.glob(f'{session}/snapshot_0[1-9]_*_raw.png'))[:2]
    for raw_path in raw_imgs:
        samples.append((raw_path, camera_quad, base_image_path))

COLS = len(samples)
W = PAD + COLS * (CELL + PAD)
H = PAD + LABEL_H + PAD + ROWS * (CELL + PAD)

canvas = Image.new('L', (W, H), color=180)
draw = ImageDraw.Draw(canvas)

for col, (raw_path, camera_quad, base_image_path) in enumerate(samples):
    results = {}
    for mode in ('none', 'inside', 'outside'):
        resized, _, _, _, _, _ = xeno_image.load_image(
            raw_path, base_image_path,
            image_side=28, input_quad=camera_quad,
            squircle_mode=mode
        )
        results[mode] = resized.resize((CELL, CELL), Image.NEAREST)

    x = PAD + col * (CELL + PAD)
    y0 = PAD + LABEL_H + PAD
    canvas.paste(results['none'],    (x, y0))
    canvas.paste(results['inside'],  (x, y0 + CELL + PAD))
    canvas.paste(results['outside'], (x, y0 + 2 * (CELL + PAD)))

    session_time = raw_path.split('/')[-2].split('_')[1]
    snap_num = raw_path.split('/')[-1].split('_')[1]
    draw.text((x + 2, PAD + 4), f'{session_time} #{snap_num}', fill=30)

for r, label in enumerate(['none', 'inside', 'outside']):
    y = PAD + LABEL_H + PAD + r * (CELL + PAD) + CELL // 2 - 6
    draw.text((2, y), label, fill=30)

out_path = 'squircle_capture_comparison.png'
canvas.save(out_path)
print(f'Saved: {out_path}  size={canvas.size}')

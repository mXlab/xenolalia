# visualize_squircle_projection.py
# Usage: source xeno-env/bin/activate && python visualize_squircle_projection.py
# Outputs: squircle_projection_comparison.png
#
# 3-row grid (rows: square / inside / outside) for a sample of _3ann.png files
# from the eisode-preparation-2026 sessions. Shows what the autoencoder output
# looks like under each projection mode.

import glob
import sys
import numpy as np

sys.path.insert(0, '.')
import xeno_image
import squircle as _squircle
from PIL import Image, ImageDraw

SNAPSHOTS_BASE = 'XenoPi/snapshots'
CELL = 224
PAD = 6
LABEL_H = 22
ROWS = 3  # square / inside / outside

sessions = sorted(glob.glob(f'{SNAPSHOTS_BASE}/*eisode-preparation-2026*'))
samples = []
for session in sessions[:4]:
    imgs = sorted(glob.glob(f'{session}/*_3ann.png'))
    step = max(1, len(imgs) // 2)
    for img_path in imgs[::step][:2]:
        samples.append(img_path)

COLS = len(samples)
W = PAD + COLS * (CELL + PAD)
H = PAD + LABEL_H + PAD + ROWS * (CELL + PAD)

canvas = Image.new('L', (W, H), color=180)
draw = ImageDraw.Draw(canvas)

for col, path in enumerate(samples):
    raw = Image.open(path)
    post = xeno_image.postprocess_output(raw, output_size=CELL)
    inside_arr = _squircle.to_circle(np.array(post))
    inside = Image.fromarray(inside_arr, mode='L')
    outside = xeno_image.to_circle_outside(post)

    x = PAD + col * (CELL + PAD)
    y0 = PAD + LABEL_H + PAD
    canvas.paste(post,    (x, y0))
    canvas.paste(inside,  (x, y0 + CELL + PAD))
    canvas.paste(outside, (x, y0 + 2 * (CELL + PAD)))

    session_time = path.split('/')[-2].split('_')[1]
    snap_num = path.split('/')[-1].split('_')[1]
    draw.text((x + 2, PAD + 4), f'{session_time} #{snap_num}', fill=30)

for r, label in enumerate(['square (none)', 'inside', 'outside']):
    y = PAD + LABEL_H + PAD + r * (CELL + PAD) + CELL // 2 - 6
    draw.text((2, y), label, fill=30)

out_path = 'squircle_projection_comparison.png'
canvas.save(out_path)
print(f'Saved: {out_path}  size={canvas.size}')

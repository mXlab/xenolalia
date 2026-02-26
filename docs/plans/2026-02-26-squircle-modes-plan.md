# Squircle Modes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `squircle_mode` setting (`"none"/"inside"/"outside"`) replacing `use_squircle`, implement the circumscribed-disc "outside" mode, write a regression test, and add visual validation scripts.

**Architecture:** `squircle_mode` string flows from `settings.json` → `xeno_osc.py` → `xeno_image.py`. Two new vectorized functions (`to_circle_outside`, `to_square_outside`) implement the circumscribed mapping using `cv2.remap`. All existing behaviour is preserved when `squircle_mode="none"`.

**Tech Stack:** Python, numpy, cv2, PIL, squircle, unittest

---

### Task 1: Regression test

**Files:**
- Create: `tests/test_regression_pipeline.py`

Verifies that `use_squircle=False` (current API) reproduces the stored `_2res.png` files byte-for-byte.

**Step 1: Create the test file**

```python
# tests/test_regression_pipeline.py
import unittest
import glob
import json
import os
import numpy as np
from PIL import Image
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import xeno_image

SNAPSHOTS_BASE = os.path.join(os.path.dirname(__file__), '..', 'XenoPi', 'snapshots')


def _collect_cases():
    """Return list of (raw_path, ref_path, camera_quad, base_image_path) for all sessions."""
    cases = []
    pattern = os.path.join(SNAPSHOTS_BASE, '*eisode-preparation-2026*')
    for session_dir in sorted(glob.glob(pattern)):
        settings_path = os.path.join(session_dir, 'settings.json')
        if not os.path.exists(settings_path):
            continue
        with open(settings_path) as f:
            settings = json.load(f)
        camera_quad = tuple(settings['camera_quad'])
        use_base_image = settings.get('use_base_image', False)
        base_image_path = os.path.join(session_dir, 'base_image.png') if use_base_image else False
        if base_image_path and not os.path.exists(base_image_path):
            base_image_path = False
        for raw_path in sorted(glob.glob(os.path.join(session_dir, 'snapshot_*_raw.png'))):
            basename = os.path.splitext(os.path.basename(raw_path))[0]
            ref_path = os.path.join(session_dir, basename + '_2res.png')
            if os.path.exists(ref_path):
                cases.append((raw_path, ref_path, camera_quad, base_image_path))
    return cases


class TestRegressionPipeline(unittest.TestCase):

    def test_no_squircle_matches_stored_outputs(self):
        """use_squircle=False must reproduce stored _2res.png exactly for all sessions."""
        cases = _collect_cases()
        self.assertGreater(len(cases), 0, "No regression cases found — check SNAPSHOTS_BASE path")
        failures = []
        for raw_path, ref_path, camera_quad, base_image_path in cases:
            resized, _, _, _, _, _ = xeno_image.load_image(
                raw_path, base_image_path,
                image_side=28, input_quad=camera_quad,
                use_squircle=False
            )
            ref = Image.open(ref_path).convert('L')
            if not np.array_equal(np.array(resized), np.array(ref)):
                failures.append(os.path.relpath(raw_path))
        if failures:
            self.fail(f"Pipeline output differs from stored _2res.png:\n" + "\n".join(failures))


if __name__ == '__main__':
    unittest.main()
```

**Step 2: Run the test**

```bash
source xeno-env/bin/activate
python -m unittest tests/test_regression_pipeline.py -v
```

Expected: `test_no_squircle_matches_stored_outputs ... ok`

**Step 3: Commit**

```bash
git add tests/test_regression_pipeline.py
git commit -m "Added regression test for no-squircle pipeline against stored outputs"
```

---

### Task 2: `to_circle_outside` and `to_square_outside`

**Files:**
- Modify: `xeno_image.py` (add two functions after `add_mask`, around line 60)
- Modify: `tests/test_xeno_image.py` (add `TestSquircleOutside` class)

**Step 1: Write the failing tests**

Add this class at the end of `tests/test_xeno_image.py` (before `if __name__ == '__main__':`):

```python
class TestSquircleOutside(unittest.TestCase):

    def test_to_circle_outside_all_corners_populated(self):
        """to_circle_outside must populate all four canvas corners (circumscribed disc)."""
        arr = np.full((224, 224), 255, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')
        result = np.array(xeno_image.to_circle_outside(img))
        for corner in [(0, 0), (0, 223), (223, 0), (223, 223)]:
            self.assertGreater(result[corner], 0,
                f"Corner {corner} is black — disc is not circumscribing the square")

    def test_to_circle_outside_output_shape(self):
        """to_circle_outside must return an image of the same size as input."""
        img = Image.fromarray(np.full((112, 112), 200, dtype=np.uint8), mode='L')
        result = xeno_image.to_circle_outside(img)
        self.assertEqual(np.array(result).shape, (112, 112))

    def test_to_circle_outside_differs_from_inside(self):
        """to_circle_outside must produce a different result than squircle.to_circle."""
        import squircle
        arr = np.full((224, 224), 200, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')
        outside = np.array(xeno_image.to_circle_outside(img))
        inside = squircle.to_circle(arr)
        self.assertFalse(np.array_equal(outside, inside))

    def test_to_square_outside_output_shape(self):
        """to_square_outside must return an image of the same size as input."""
        img = Image.fromarray(np.full((112, 112), 200, dtype=np.uint8), mode='L')
        result = xeno_image.to_square_outside(img)
        self.assertEqual(np.array(result).shape, (112, 112))

    def test_to_square_outside_center_populated(self):
        """to_square_outside on a white image must populate the centre pixel."""
        arr = np.full((224, 224), 255, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')
        result = np.array(xeno_image.to_square_outside(img))
        self.assertGreater(result[112, 112], 0)
```

**Step 2: Run tests to verify they fail**

```bash
source xeno-env/bin/activate
python -m unittest tests/test_xeno_image.py TestSquircleOutside -v
```

Expected: `AttributeError: module 'xeno_image' has no attribute 'to_circle_outside'`

**Step 3: Implement the two functions in `xeno_image.py`**

Add after the `add_mask` function (around line 60), before `enhance`:

```python
def to_circle_outside(image):
    """Map a square image to its circumscribed disc (squircle outside mode).

    The output disc circumscribes the input square: its radius equals the
    half-diagonal (side * sqrt(2) / 2), so all four canvas corners are
    populated — no black corners. Uses inverse FGS mapping via cv2.remap.

    Args:
        image: Grayscale PIL Image (must be square).
    Returns:
        Grayscale PIL Image of the same size.
    """
    arr = np.array(image.convert('L'), dtype=np.uint8)
    n = arr.shape[0]
    # Destination coords in scaled-disc space: canvas spans [-1, 1],
    # disc radius = sqrt(2) so all canvas pixels lie within the disc.
    coords = (np.arange(n, dtype=np.float32) + 0.5) / n * 2.0 - 1.0
    uu, vv = np.meshgrid(coords, coords)
    # Scale to unit-disc space for FGS inverse
    u = uu / np.sqrt(2)
    v = vv / np.sqrt(2)
    u2, v2 = u * u, v * v
    r2 = u2 + v2
    uv = u * v
    fouru2v2 = 4.0 * uv * uv
    rad = np.maximum(r2 * (r2 - fouru2v2), 0.0)
    sgnuv = np.sign(uv)
    sqrto = np.sqrt(np.maximum(0.5 * (r2 - np.sqrt(rad)), 0.0))
    # Avoid division by zero: replace zero denominators with 1 (result overridden by where)
    safe_v = np.where(np.abs(v) > 1e-10, v, 1.0)
    safe_u = np.where(np.abs(u) > 1e-10, u, 1.0)
    x = np.where(np.abs(v) > 1e-10, sgnuv / safe_v * sqrto, uu / np.sqrt(2))
    y = np.where(np.abs(u) > 1e-10, sgnuv / safe_u * sqrto, vv / np.sqrt(2))
    x = np.clip(x, -1.0, 1.0)
    y = np.clip(y, -1.0, 1.0)
    map_x = ((x + 1.0) * 0.5 * n).astype(np.float32)
    map_y = ((y + 1.0) * 0.5 * n).astype(np.float32)
    result = cv2.remap(arr, map_x, map_y, cv2.INTER_LINEAR, borderValue=0)
    return Image.fromarray(result, mode='L')


def to_square_outside(image):
    """Map from a circumscribed disc back to a square (inverse of to_circle_outside).

    All canvas pixels lie within the circumscribed disc, so the full square
    is covered with no holes.

    Args:
        image: Grayscale PIL Image (must be square).
    Returns:
        Grayscale PIL Image of the same size.
    """
    arr = np.array(image.convert('L'), dtype=np.uint8)
    n = arr.shape[0]
    # Source coords in square space [-1, 1]
    coords = (np.arange(n, dtype=np.float32) + 0.5) / n * 2.0 - 1.0
    xx, yy = np.meshgrid(coords, coords)
    x2, y2 = xx * xx, yy * yy
    r2 = x2 + y2
    rad = np.sqrt(np.maximum(r2 - x2 * y2, 0.0))
    inv_sqrt_r2 = np.where(r2 > 1e-10, 1.0 / np.sqrt(r2), 0.0)
    # FGS square-to-disc, then scale output by sqrt(2) for circumscribed disc
    u = xx * rad * inv_sqrt_r2 * np.sqrt(2)
    v = yy * rad * inv_sqrt_r2 * np.sqrt(2)
    map_x = ((u + 1.0) * 0.5 * n).astype(np.float32)
    map_y = ((v + 1.0) * 0.5 * n).astype(np.float32)
    result = cv2.remap(arr, map_x, map_y, cv2.INTER_LINEAR, borderValue=0)
    return Image.fromarray(result, mode='L')
```

**Step 4: Run tests to verify they pass**

```bash
python -m unittest tests/test_xeno_image.py TestSquircleOutside -v
```

Expected: all 5 tests PASS

**Step 5: Commit**

```bash
git add xeno_image.py tests/test_xeno_image.py
git commit -m "Added to_circle_outside and to_square_outside (circumscribed squircle mode)"
```

---

### Task 3: Replace `use_squircle` with `squircle_mode` in `xeno_image.py`

**Files:**
- Modify: `xeno_image.py` (signatures of `process_image` and `load_image`)
- Modify: `tests/test_xeno_image.py` (update existing squircle tests)
- Modify: `tests/test_regression_pipeline.py` (update to new API)

**Step 1: Update `process_image` signature and body**

In `xeno_image.py`, find `process_image` (around line 178). Change its signature from:

```python
def process_image(image, base_image=False, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0], use_squircle=False):
```

to:

```python
def process_image(image, base_image=False, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0], squircle_mode="none"):
```

Replace the squircle block (currently):

```python
    # Squircle remapping: map circular disc content to fill the square.
    if use_squircle:
        import squircle
        masked = Image.fromarray(squircle.to_square(np.array(masked)))
```

with:

```python
    # Squircle remapping: map circular disc content to fill the square.
    if squircle_mode == "inside":
        import squircle as _squircle
        masked = Image.fromarray(_squircle.to_square(np.array(masked)))
    elif squircle_mode == "outside":
        masked = to_square_outside(masked)
```

**Step 2: Update `load_image` signature and body**

Change its signature from:

```python
def load_image(image_path, base_image_path=False, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0], use_squircle=False):
```

to:

```python
def load_image(image_path, base_image_path=False, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0], squircle_mode="none"):
```

Change the return line from:

```python
    return process_image(image, base_image, image_side, input_quad, use_squircle=use_squircle)
```

to:

```python
    return process_image(image, base_image, image_side, input_quad, squircle_mode=squircle_mode)
```

**Step 3: Update existing squircle tests in `tests/test_xeno_image.py`**

In `TestProcessImageSquircle`, change all occurrences of `use_squircle=True` to `squircle_mode="inside"` and `use_squircle=False` to `squircle_mode="none"`:

```python
class TestProcessImageSquircle(unittest.TestCase):

    def test_process_image_squircle_output_shape(self):
        """squircle_mode='inside' must not change the output shape."""
        img = _semicircle_image()
        resized, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="inside")
        self.assertEqual(resized.size, (28, 28))

    def test_process_image_squircle_changes_output(self):
        """squircle_mode='inside' must produce a different 28x28 result than 'none'."""
        img = _semicircle_image()
        sq, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="inside")
        no, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="none")
        self.assertFalse(
            np.array_equal(np.array(sq), np.array(no)),
            "squircle_mode='inside' should change the output image"
        )
```

Also add two new tests to `TestProcessImageSquircle`:

```python
    def test_process_image_outside_output_shape(self):
        """squircle_mode='outside' must not change the output shape."""
        img = _semicircle_image()
        resized, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="outside")
        self.assertEqual(resized.size, (28, 28))

    def test_process_image_outside_differs_from_inside(self):
        """squircle_mode='outside' must produce a different result than 'inside'."""
        img = _semicircle_image()
        out, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="outside")
        ins, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="inside")
        self.assertFalse(
            np.array_equal(np.array(out), np.array(ins)),
            "squircle_mode='outside' should differ from 'inside'"
        )
```

**Step 4: Update regression test to use new API**

In `tests/test_regression_pipeline.py`, change `use_squircle=False` to `squircle_mode="none"`:

```python
            resized, _, _, _, _, _ = xeno_image.load_image(
                raw_path, base_image_path,
                image_side=28, input_quad=camera_quad,
                squircle_mode="none"
            )
```

**Step 5: Run all tests**

```bash
source xeno-env/bin/activate
python -m unittest tests/test_xeno_image.py tests/test_regression_pipeline.py -v
```

Expected: all tests PASS (12 in test_xeno_image, 1 in test_regression_pipeline)

**Step 6: Commit**

```bash
git add xeno_image.py tests/test_xeno_image.py tests/test_regression_pipeline.py
git commit -m "Replaced use_squircle with squircle_mode (none/inside/outside) in xeno_image"
```

---

### Task 4: Replace `use_squircle` with `squircle_mode` in `xeno_osc.py`

**Files:**
- Modify: `xeno_osc.py`

No automated test (requires live model). Run all existing tests after to confirm nothing regressed.

**Step 1: Update module-level default**

Find (around line 84):

```python
use_squircle        = False
```

Replace with:

```python
squircle_mode       = "none"
```

**Step 2: Update `load_settings` global declaration**

Find in `load_settings()`:

```python
    global args, data, input_quad, n_feedback_steps, use_base_image, \
           use_convolutional, model_name, encoder_layer, \
           output_size, output_stroke_width, output_boundary_px, output_threshold, output_area_max, \
           use_squircle
```

Replace with:

```python
    global args, data, input_quad, n_feedback_steps, use_base_image, \
           use_convolutional, model_name, encoder_layer, \
           output_size, output_stroke_width, output_boundary_px, output_threshold, output_area_max, \
           squircle_mode
```

**Step 3: Update `load_settings` body**

Find:

```python
        use_squircle        = bool(data.get('use_squircle', False))
```

Replace with (includes backward-compat fallback for old `use_squircle` boolean):

```python
        if 'squircle_mode' in data:
            squircle_mode = str(data['squircle_mode'])
        elif data.get('use_squircle', False):
            squircle_mode = "inside"
        else:
            squircle_mode = "none"
```

**Step 4: Update `next_image` global declaration**

Find in `next_image()`:

```python
    global n_feedback_steps, input_quad, input_shape, image_side, use_base_image, prev_frame, \
           output_size, output_stroke_width, output_boundary_px, output_threshold, output_area_max, \
           use_squircle
```

Replace with:

```python
    global n_feedback_steps, input_quad, input_shape, image_side, use_base_image, prev_frame, \
           output_size, output_stroke_width, output_boundary_px, output_threshold, output_area_max, \
           squircle_mode
```

**Step 5: Update squircle block in `next_image`**

Find:

```python
    # Squircle remapping: map square output to circular disc for projection.
    if use_squircle:
        import squircle
        image = Image.fromarray(squircle.to_circle(np.array(image)), mode='L')
```

Replace with:

```python
    # Squircle remapping: map square output to circular disc for projection.
    if squircle_mode == "inside":
        import squircle as _squircle
        image = Image.fromarray(_squircle.to_circle(np.array(image)), mode='L')
    elif squircle_mode == "outside":
        image = xeno_image.to_circle_outside(image)
```

**Step 6: Update `load_image` call in `next_image`**

Find:

```python
        starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(
            image_path, base_image_path, image_side, input_quad, use_squircle=use_squircle)
```

Replace with:

```python
        starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(
            image_path, base_image_path, image_side, input_quad, squircle_mode=squircle_mode)
```

**Step 7: Update `handle_test_camera`**

Find in `handle_test_camera`:

```python
    global input_quad, image_side, use_squircle
```

Replace with:

```python
    global input_quad, image_side, squircle_mode
```

Find:

```python
    starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(image_path, False, image_side, input_quad, use_squircle=use_squircle)
```

Replace with:

```python
    starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(image_path, False, image_side, input_quad, squircle_mode=squircle_mode)
```

**Step 8: Run all tests to confirm nothing regressed**

```bash
source xeno-env/bin/activate
python -m unittest tests/test_xeno_image.py tests/test_regression_pipeline.py -v
```

Expected: all tests PASS

**Step 9: Commit**

```bash
git add xeno_osc.py
git commit -m "Replaced use_squircle with squircle_mode in xeno_osc"
```

---

### Task 5: Update `XenoPi/settings.json`

**Files:**
- Modify: `XenoPi/settings.json` (gitignored — do NOT commit)

**Step 1: Edit `XenoPi/settings.json`**

Find:

```json
"use_squircle": false,
```

Replace with:

```json
"squircle_mode": "none",
```

No commit needed (file is gitignored).

---

### Task 6: Projection visual validation script

**Files:**
- Create: `visualize_squircle_projection.py`

**Step 1: Create the script**

```python
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
```

**Step 2: Run the script**

```bash
source xeno-env/bin/activate
python visualize_squircle_projection.py
eog squircle_projection_comparison.png
```

Expected: 3-row grid saved, no errors.

**Step 3: Commit**

```bash
git add visualize_squircle_projection.py
git commit -m "Added projection squircle comparison visualisation script"
```

---

### Task 7: Capture visual validation script

**Files:**
- Create: `visualize_squircle_capture.py`

**Step 1: Create the script**

```python
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
```

**Step 2: Run the script**

```bash
source xeno-env/bin/activate
python visualize_squircle_capture.py
eog squircle_capture_comparison.png
```

Expected: 3-row grid saved. The "outside" row should show more content in the corners compared to "none" and "inside".

**Step 3: Commit**

```bash
git add visualize_squircle_capture.py
git commit -m "Added capture squircle comparison visualisation script"
```

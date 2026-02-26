# Squircle Modes Design

**Date:** 2026-02-26
**Status:** Approved

## Problem

The current squircle implementation supports only one mapping mode ("inside"): the projected
disc is inscribed in the `image_rect` square, illuminating only ~50% of the 45mm petri dish
area (radius ratio ≈ 70%). The physical setup positions the `image_rect` corners ON the 45mm
circle boundary, leaving the four corner-arc regions of the disc permanently dark.

Additionally, there is no automated regression test confirming that `squircle_mode="none"`
produces byte-identical output to the original pre-squircle pipeline.

## Goal

1. **Regression test**: verify `squircle_mode="none"` is pixel-perfect identical to the
   stored pipeline outputs from recorded sessions.

2. **Outside mode**: add a second squircle mapping where the disc circumscribes the
   `image_rect` square (disc radius = half-diagonal of square). Every projector pixel maps
   to the 45mm petri dish; the full disc is illuminated.

3. **Visual validation scripts**: two comparison grids — projection direction (what the
   autoencoder outputs look like under each mode) and capture direction (what the autoencoder
   receives as 28×28 input under each mode).

## Physical Geometry

```
      45mm disc (petri dish)
     ╱─────────────────────╲
    │   image_rect corners   │
    │   ┌─────────────┐      │
    │   │             │      │
    │   │  image_rect │      │
    │   │  (square)   │      │
    │   └─────────────┘      │
     ╲─────────────────────╱

image_rect corners lie ON the 45mm circle boundary.
  → image_rect side  = 45mm / √2 ≈ 31.8mm
  → inscribed disc r = 15.9mm  (inside mode)
  → circumscribed r  = 22.5mm  (outside mode = full dish)
```

**Inside mode**: disc inscribed in image_rect → projected circle ≈ 70% of dish radius.
**Outside mode**: disc circumscribed around image_rect → projected circle = full 45mm dish.

## Settings API Change

`use_squircle` (bool) is replaced by `squircle_mode` (string) everywhere.

| Value | Behaviour |
|---|---|
| `"none"` | No squircle — pipeline identical to pre-squircle code (default) |
| `"inside"` | Disc inscribed in square — current `use_squircle: true` behaviour |
| `"outside"` | Disc circumscribes square — new full-dish mode |

Backward-compat fallback in `load_settings()`: if `squircle_mode` key is absent but
`use_squircle` is present, map `true → "inside"`, `false → "none"`.

## Components Changed

### `xeno_image.py`

- `to_circle_outside(arr)` — new function. Vectorized FGS mapping scaled by √2 so the
  output disc circumscribes the input square. Uses `cv2.remap` for bilinear sampling.
  All canvas pixels are populated (no black corners).

- `to_square_outside(arr)` — inverse of `to_circle_outside`. Maps from the circumscribed
  disc back to the full square. Canvas pixels outside the disc are black.

- `process_image(... squircle_mode="none")` — replaces `use_squircle=False`. After
  `add_mask()`: applies `squircle.to_square()` for `"inside"`, `to_square_outside()` for
  `"outside"`, nothing for `"none"`.

- `load_image(... squircle_mode="none")` — forwards `squircle_mode` to `process_image()`.

### `xeno_osc.py`

- Module-level default: `squircle_mode = "none"` (replaces `use_squircle = False`).
- `load_settings()`: reads `squircle_mode` with backward-compat fallback.
- `next_image()`: applies `squircle.to_circle()` for `"inside"`,
  `to_circle_outside()` for `"outside"`, nothing for `"none"`. Passes `squircle_mode`
  to `load_image()`.
- `handle_test_camera()`: passes `squircle_mode` to `load_image()`.

### `XenoPi/settings.json`

- Replace `"use_squircle": false` with `"squircle_mode": "none"`.

### `tests/test_regression_pipeline.py` (new)

- Discovers all `eisode-preparation-2026` session folders under `XenoPi/snapshots/`.
- For each session reads `settings.json` (`camera_quad`, `use_base_image`).
- For each `snapshot_NN_*_raw.png` with a corresponding `_2res.png`, runs
  `xeno_image.load_image()` with `squircle_mode="none"` and the session's
  `base_image.png` (when `use_base_image` is true).
- Asserts pixel-perfect equality with the stored `_2res.png`.

### `tests/test_xeno_image.py` (updated)

- Replace `use_squircle` parameter with `squircle_mode` in existing squircle tests.
- New tests:
  - Outside mode has no black corners (all canvas pixels populated).
  - Outside mode disc touches all four corners.
  - Outside mode output differs from inside mode output.
  - `squircle_mode="none"` is byte-identical to default (no-squircle) call.

### Visual validation scripts (new)

- **`visualize_squircle_projection.py`**: 3-row comparison grid from session `_3ann.png`
  files — row 1 = original square, row 2 = inside, row 3 = outside. Shows projection
  direction.

- **`visualize_squircle_capture.py`**: 3-row comparison grid from session `*_raw.png`
  files using `process_image()` with each mode — shows the 28×28 result the autoencoder
  would receive under each mode. This is the key physical validation (corner content
  visible in outside mode).

## What Does Not Change

- `postprocess_output()` — operates in square space, unchanged.
- No changes to Processing sketches or Arduino firmware.
- When `squircle_mode="none"` the pipeline is byte-identical to the pre-squircle code.
- `xeno_mask.png` — still applied before the squircle capture transform.

## Trade-offs

**Outside mode — projection**: all projector pixels land on the petri dish. The mapping
has higher angular distortion near the corners (more stretching) than inside mode.

**Outside mode — capture**: `to_square_outside()` recovers corner-arc content that inside
mode discards, giving the autoencoder a richer 28×28 input. The inverse mapping is well-
defined everywhere but has the same corner-stretching characteristic.

**Regression test**: depends on real snapshot files in `XenoPi/snapshots/` being present,
so it is an integration-style test rather than a pure unit test. It cannot run in a clean
CI environment without the snapshot data.

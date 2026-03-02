# Xenolalia Architecture

## System Overview

Bio-digital installation: euglena microorganisms ↔ convolutional autoencoder feedback loop.
Camera captures euglenas → autoencoder generates new images → images projected onto euglenas → repeat.

## Five Core Components

### 1. XenoPi (Processing sketch, runs on Raspberry Pi)
- **Location**: `XenoPi/`
- **Entry point**: `XenoPi.pde`
- **Role**: System orchestrator — camera capture, state machine, OSC routing
- **Modes**: `CameraCalibrationMode` (startup) → `GenerativeMode` (operation)
- **OSC**: Receives on port 7001, sends to `127.0.0.1:7000` (xeno_osc.py), `192.168.0.102:7000` (ESP32), `192.168.0.100:7000` (xeno_server.py)
- **Key file**: `GenerativeMode.pde` — the state machine is the system heartbeat

### 2. xeno_osc.py (Python, neural network server)
- **Location**: `xeno_osc.py` + `xeno_image.py`
- **Role**: Loads Keras autoencoder, processes images, returns generated images
- **OSC**: Listens on port 7000, sends to `127.0.0.1:7001` (XenoPi) and `127.0.0.1:7002` (Orbiter)
- **Start command**: `python xeno_osc.py -C XenoPi/settings.json -M results/`
- **Key pipeline**: raw image → perspective transform → remove base → mask → squircle → enhance → simplify → 28×28 → autoencoder (×5) → postprocess → 224×224 binary image → path returned via OSC

### 3. ESP32 Apparatus (PlatformIO firmware)
- **Location**: `arduino/Xenolalia_platformio/src/`
- **Role**: Physical hardware — pumps, servo mixer, LED ring, liquid sensor
- **WiFi**: SSID "Xenolalia", static IP `192.168.0.102`
- **OSC**: Listens on port 7000, responds to port 7001
- **Key commands received**: `/xeno/refresh` (full liquid cycle), `/xeno/glow` (LED pulse)
- **Key responses**: `/xeno/apparatus/refreshed` (cycle complete), `/xeno/handshake`

### 4. Orbiter (Python, OLED display on mesoscope)
- **Location**: `xeno_orbiter.py`
- **Role**: SSD1351 OLED screen mounted on the mesoscope; animates the sequence of autoencoder output images accumulated during the current experiment
- **OSC**: Listens on port 7002, sends `/xeno/orbiter/begin` and `/xeno/orbiter/end` back to xeno_osc.py
- **Start command**: `python xeno_orbiter.py --fps 1`
- **Hardware**: SSD1351 OLED via SPI (device=0, port=0); uses `luma.oled` library
- **Behavior**: Accumulates frames as `/xeno/neurons/step` messages arrive; loops through them; 2.5× longer pause on the first frame of each cycle
- **Image prep**: Each frame rotated 90°, black border added (35% of width), resized to device resolution
- **Fed by**: `xeno_osc.py` fans out `/xeno/neurons/new`, `/xeno/neurons/step`, `/xeno/neurons/end` to both XenoPi (7001) and Orbiter (7002)

### 5. XenoProjection (Processing sketch, display node)
- **Location**: `processing/XenoProjection/`
- **Role**: Visualization — shows experiment progress, morphing vignettes of bio/artificial images
- **OSC**: Listens on port 7001, fed by `xeno_server.py` (not `xeno_osc.py`)
- **Scenes**: 5 display scenes (single glyph, side-by-side, alternating, step-by-step, recent grid)

---

## Communication Map

```
XenoPi (7001) ←──→ xeno_osc.py (7000)        [neural net, localhost]
xeno_osc.py   ───→ Orbiter (7002)             [OLED display, localhost]
XenoPi        ───→ ESP32 (192.168.0.102:7000) [apparatus, LAN]
ESP32         ───→ XenoPi (:7001)             [apparatus responses]
XenoPi        ───→ xeno_server.py (192.168.0.100:7000)  [experiment log]
xeno_server   ───→ XenoProjection (:7001)     [visualization display]
```

---

## Key OSC Addresses

| Address | Direction | Purpose |
|---------|-----------|---------|
| `/xeno/euglenas/handshake` | XenoPi → xeno_osc.py | Init ping |
| `/xeno/neurons/handshake` | xeno_osc.py → XenoPi | Ready confirmation |
| `/xeno/euglenas/new` | XenoPi → xeno_osc.py | New experiment started |
| `/xeno/euglenas/begin` | XenoPi → xeno_osc.py | First image of experiment |
| `/xeno/euglenas/step` | XenoPi → xeno_osc.py | Subsequent images |
| `/xeno/neurons/new` | xeno_osc.py → Orbiter | New experiment (clear display) |
| `/xeno/neurons/step` | xeno_osc.py → XenoPi + Orbiter | Generated image path (fan-out) |
| `/xeno/neurons/end` | xeno_osc.py → XenoPi + Orbiter | Shutdown signal |
| `/xeno/orbiter/begin` | Orbiter → xeno_osc.py | Orbiter ready |
| `/xeno/refresh` | XenoPi → ESP32 | Trigger full liquid cycle |
| `/xeno/apparatus/refreshed` | ESP32 → XenoPi | Cycle complete |
| `/xeno/glow` | XenoPi → ESP32 | LED ring toggle |
| `/xeno/exp/new` | XenoPi → xeno_server.py | New experiment |
| `/xeno/exp/step` | XenoPi → xeno_server.py | Image step |
| `/xeno/exp/end` | XenoPi → xeno_server.py | Experiment complete |

---

## State Machine (GenerativeMode.pde)

```
INIT → NEW → (REFRESH → POST_REFRESH →) FLASH → SNAPSHOT → WAIT_FOR_GLYPH → MAIN → PRESENTATION → NEW
```

| State | Duration | What happens |
|-------|----------|-------------|
| INIT | Until handshake | Pings xeno_osc.py repeatedly; waits for `/xeno/neurons/handshake` |
| NEW | Instant | Creates experiment directory, increments counter |
| REFRESH | Until confirmed | Sends `/xeno/refresh` to ESP32; waits for `/xeno/apparatus/refreshed` |
| POST_REFRESH | 2 minutes | Waits for euglenas to settle after mixing |
| FLASH | 8 seconds | White background; stops LED glow 3s before end |
| SNAPSHOT | Until clean frame | Captures camera image; rejects scan-line artifacts |
| WAIT_FOR_GLYPH | Until OSC reply | Blocks until xeno_osc.py returns generated image path |
| MAIN | 12 × exposure_time | Displays projected glyph; collects snapshots at intervals |
| PRESENTATION | 5 minutes | Final display; LED glow on; then loops back to NEW |

---

## Image Processing Pipeline (xeno_osc.py / xeno_image.py)

```
Raw PNG (640×480)
  → Perspective warp using camera_quad (4 corners, normalized coords)
  → Subtract base reference image (if use_base_image=true)
  → Apply circular mask (xeno_mask.png)
  → Squircle mapping: disc→square (if squircle_mode="inside")
  → Invert + median filter + histogram equalization
  → Adaptive threshold + morphological thinning + erosion
  → Resize to 28×28
  → Autoencoder forward pass × n_feedback_steps (default 5)
  → Upscale 28×28 → output_size (default 224×224) via Lanczos
  → Binarize at output_threshold (default 0.5)
  → Morphological analysis: classify components as thin vs thick
  → Thick components: draw inward contour of output_boundary_px width
  → Save as *_3ann.png; return path via OSC
```

Intermediate files saved alongside each snapshot:
- `*_0trn.png` — perspective transformed
- `*_1fil.png` — filtered/enhanced
- `*_2res.png` — resized 28×28 (autoencoder input)
- `*_3ann.png` — autoencoder output (projected glyph)
- `*_code.json` — encoder layer activations

Frame validation: mean pixel value must be 10%–90% (rejects all-black or all-white frames).

---

## Configuration (`XenoPi/settings.json`)

Single source of truth for all components. Key parameters:

| Parameter | Description |
|-----------|-------------|
| `camera_quad` | 8 floats (normalized 0–1), perspective transform corners |
| `image_rect` | 4 floats (normalized), display rectangle for projected image |
| `model_name` | Autoencoder filename in `results/` (without `.hdf5`) |
| `use_convolutional` | `true` = CNN autoencoder, `false` = dense |
| `n_feedback_steps` | Autoencoder iteration count (default 5) |
| `exposure_time` | Seconds between snapshots in MAIN state (default 300) |
| `squircle_mode` | `"none"`, `"inside"` (disc→square), or `"outside"` (square→disc) |
| `use_apparatus` | Whether to include REFRESH/POST_REFRESH states |
| `use_base_image` | Whether to subtract background reference |
| `output_size` | Post-processed output resolution (default 224) |
| `output_threshold` | Binarization threshold (default 0.5) |
| `output_stroke_width` | Morphological opening radius (default 20) |
| `output_boundary_px` | Contour width for thick components (default 22) |
| `encoder_layer` | Index of layer to extract activations from |
| `osc_apparatus_remote_ip` | ESP32 IP (default 192.168.0.102) |

---

## Experiment Data Structure

```
snapshots/<experiment_uid>/
├── info.json                      # Experiment metadata
├── settings.json                  # Settings snapshot at experiment start
├── base_image.png                 # Reference background image
├── snapshot_NN_MMMMMM_raw.png     # Raw camera capture
├── snapshot_NN_MMMMMM_0trn.png    # Perspective transformed
├── snapshot_NN_MMMMMM_1fil.png    # Filtered/enhanced
├── snapshot_NN_MMMMMM_2res.png    # 28×28 autoencoder input
├── snapshot_NN_MMMMMM_3ann.png    # Autoencoder output (projected glyph)
└── snapshot_NN_MMMMMM_code.json   # Encoder layer activations
```

---

## ESP32 Hardware Pinout

| Pin | Role |
|-----|------|
| 19 | Servo motor (euglena mixer) |
| 23 | NeoPixel LED ring (data) |
| 33 | Liquid level sensor (analog) |
| 21 | Pump 1 — drain/inlet |
| 22 | Pump 2 — fill/outlet |

Refresh cycle sequence: drain (15s) → mix ×2 → fill (until sensor threshold) → drain briefly → refill to 100%.

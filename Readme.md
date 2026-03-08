# Xenolalia

Bio-digital art installation creating a feedback loop between living microorganisms (euglenas) and a convolutional autoencoder. The camera captures euglenas → the autoencoder generates new images → the images are projected onto the euglenas → repeat.

For a full technical description of the system architecture, see [`docs/architecture.md`](docs/architecture.md).

---

## Table of Contents

1. [Machines & Network](#machines--network)
2. [Running Xenolalia](#running-xenolalia)
3. [Configuration Reference](#configuration-reference)
   - [XenoPi/settings.json](#xenopisettingsjson)
   - [config/xenopc.yaml](#configxenopcyaml)
   - [config/adapters/](#configadapters)
4. [Development & Testing Tools](#development--testing-tools)
5. [Glyph Alphabet & Font Generation](#glyph-alphabet--font-generation)
6. [Installation](#installation)
   - [XenoPC](#xenopc-installation)
   - [XenoPi (Raspberry Pi)](#xenopi-installation)
7. [OSC Message Reference](#osc-message-reference)
8. [Troubleshooting](#troubleshooting)

---

## Machines & Network

| IP | Machine | Programs (OSC receive port) |
|---|---|---|
| 192.168.0.**100** | **xenopc** | `xeno_server.py` (7000), `XenoProjection` (7001), `xeno-sonoscope.pd` (7002) |
| 192.168.0.**101** | **xenopi** (RPi) | `xeno_osc.py` (7000), `XenoPi` (7001), `xeno_orbiter.py` (7002) |
| 192.168.0.**102** | **Apparatus** (ESP32) | `XenolaliaApparatus` (7000) |
| 192.168.0.**103** | **Xenoscope** (RPi, microscope) | — |

Named OSC targets used in adapter configs (defined in `config/xenopc.yaml`):

| Name | Machine | Port |
|------|---------|------|
| `server` | xenopc (self) | 7000 |
| `macroscope` | XenoProjection | 7001 |
| `sonoscope` | xeno-sonoscope.pd | 7002 |
| `neurons` | xeno_osc.py (RPi) | 7000 |
| `mesoscope` | XenoPi (RPi) | 7001 |
| `orbiter` | xeno_orbiter.py (RPi) | 7002 |
| `apparatus` | ESP32 | 7000 |

---

## Running Xenolalia

### Definitions

- **Experiment**: one generation cycle starting from a seed image, producing a sequence of projected images.
- **Session**: an event during which the piece was run (e.g. a residency, an exhibition).
- **Node**: a specific mesoscope module running experiments.

### Programs

**On the xenopi (mesoscope / Raspberry Pi):**

| Program | Command / Script | Notes |
|---------|-----------------|-------|
| `xeno_osc.py` | started by `xeno_pi_main.sh` | Neural network server — must start before XenoPi |
| `XenoPi` | Processing sketch | Main controller — calibration + generative state machine |
| `xeno_orbiter.py` | started by `xeno_pi_main.sh` | Optional OLED display on the mesoscope |
| `prevent_sleep.sh` | started by `xeno_pi_main.sh` | Prevents monitor sleep |

**On the xenopc (macroscope):**

| Program | Command / Script | Notes |
|---------|-----------------|-------|
| `xeno_server.py` | started by `xeno_pc_main.sh` | Syncs snapshots, drives XenoProjection, runs adapter |
| `XenoProjection` | Processing sketch | Large-scale projection display |
| `xeno-sonoscope.pd` | started by `xeno_pc_main.sh` | Pd sonification patch (optional) |
| Open Stage Control | started by `xeno_pc_main.sh` | Optional OSC control interface |

### Launching

The easiest way is to use the launcher scripts.

**On the xenopi:**
```bash
cd ~/xenolalia
./bin/xeno_pi_main.sh
```

This starts `xeno_osc.py`, `xeno_orbiter.py`, `prevent_sleep.sh`, then launches `XenoPi` in a restart loop (auto-restarts on crash). Logs go to `logs/`.

**On the xenopc:**
```bash
cd ~/xenolalia
./bin/xeno_pc_main.sh
```

This starts `xeno_server.py`, `xeno-sonoscope.pd`, Open Stage Control, and `XenoProjection`. Logs go to `logs/`.

**Starting programs individually (xenopi):**
```bash
source xeno-env/bin/activate
python xeno_osc.py                          # reads settings.json for model
python xeno_orbiter.py --fps 1             # optional, requires SSD1351 OLED hardware
/bin/bash bin/prevent_sleep.sh &
# then open XenoPi in Processing IDE
```

**Starting programs individually (xenopc):**
```bash
source xeno-env/bin/activate
python xeno_server.py                       # reads config/xenopc.yaml
# then open XenoProjection in Processing IDE
```

### Startup Procedure

#### Step 1 — Calibration mode

On startup, `XenoPi` enters **calibration mode** (unless `startup_mode` is set to `"generative"` in `settings.json`).

**A. Reference image calibration** — defines the display rectangle:
1. Click the first corner to place the first control point.
2. Press TAB to select the next control point; click to place it.
3. Use arrow keys for fine adjustment.
4. Press ENTER to save, then SPACEBAR to proceed to the next step.

**B. Input quad calibration** — defines the camera perspective transform:
1. Adjust the four corners to match the field of view picked up by the camera.
2. Select a control point by pressing its number (1–4).
3. Use arrow keys for fine adjustment.
4. Press ENTER to save `settings.json`.

#### Step 2 — Set conditions

Before starting generation, set up the experimental conditions (light sources, lids, curtains, etc.) exactly as they will be during the experiment.

#### Step 3 — Start generative mode

Press **g** to start. Or set `startup_mode = "generative"` in `settings.json` to skip calibration entirely on next launch.

#### Step 4 — Managing experiments

- Press **n** to manually start a new experiment at any time.
- Press **ESC** to exit XenoPi. If started via `xeno_pi_main.sh`, the other programs are cleaned up automatically.

### Key Bindings

#### Calibration mode

| Key | Description |
|:---:|-------------|
| SPACEBAR | Toggle between reference image and input quad |
| ENTER | Save calibration to `settings.json` |
| ←↑→↓ | Move selected control point by one pixel |
| TAB | Select next control point |
| 1 2 3 4 | Select specific control point |
| m | Toggle mouse crosshair |
| p | Toggle control point crosshair |
| + − | Adjust control point line size |
| g | Start generative mode |

#### Generative mode

| Key | Description |
|:---:|-------------|
| SPACEBAR | Manually take a snapshot |
| f | Toggle flash screen (white frame — useful to inspect the petri dish) |
| v | Toggle camera view (live feed in corner) |
| a | Toggle auto mode (*) |
| n | Start new experiment |
| t | Test overlay: load the most recent snapshot and briefly show the CV-detected shape |

(*) In auto mode (default), snapshots are taken at intervals defined by `exposure_time`. In manual mode, press SPACEBAR to take each snapshot.

---

## Configuration Reference

### XenoPi/settings.json

Single source of truth for all components. A default file is located at `XenoPi/settings.json.default`.

#### Identification

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `node_name` | string | `"nodepi-01"` | Unique name for this mesoscope module |
| `session_name` | string | `"default"` | Name identifying the current session/event |

#### Camera

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `camera_id` | int | `0` | Camera device index |
| `camera_width` | int | `640` | Capture width in pixels (0 = use camera default) |
| `camera_height` | int | `480` | Capture height in pixels (0 = use camera default) |
| `camera_quad` | float[8] | identity | Perspective transform corners (normalized 0–1), in order: TL, BL, BR, TR (x,y pairs) |
| `image_rect` | float[4] | `[0.25, 0.25, 0.75, 0.75]` | Display rectangle for projected image on screen (x_min, y_min, x_max, y_max, normalized) |

#### Neural network / model

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model_name` | string | `"model"` | Autoencoder filename in `results/` directory, without `.hdf5` extension |
| `use_convolutional` | bool | `true` | If true, CNN autoencoder; if false, dense autoencoder |
| `n_feedback_steps` | int | `4` | Number of autoencoder self-loop iterations per step |
| `encoder_layer` | int | `5` | Index of the layer to extract activations from (for sonoscope and analysis) |
| `seed_image` | string | `"random"` | Seed type for the first step of each experiment: `"random"` or `"euglenas"` |
| `use_base_image` | bool | `true` | If true, subtract a background reference image before processing |

#### Image post-processing / output

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `squircle_mode` | string | `"none"` | Remapping applied before the autoencoder: `"none"`, `"inside"` (disc → square), or `"outside"` (square → disc) |
| `output_size` | int | `224` | Resolution of the generated output image in pixels (square) |
| `output_threshold` | float | `0.5` | Binarization threshold applied to autoencoder output |
| `output_stroke_width` | int | `20` | Morphological opening radius applied to output |
| `output_boundary_px` | int | `22` | Contour width (in pixels) drawn for thick components |
| `output_area_max` | float\|null | `null` | Maximum blob area; blobs larger than this are discarded (null = no limit) |

#### Visibility thresholds

Used by `xeno_osc.py` to classify each snapshot, and by `xeno_test_snapshots.py` for batch analysis.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `visibility_threshold_cv` | float | `0.1` | Pixel density below which the image is classified as invisible to CV (class 0) |
| `visibility_threshold_human` | float | `0.3` | Pixel density above which the image is classified as human-visible (class 2); between thresholds = cv-only (class 1) |

#### Experiment timing & control

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `exposure_time` | float | `60.0` | Seconds between snapshots during MAIN state |
| `experiment_duration_minutes` | float | `0` | Total experiment duration in minutes. Derives snapshot count as `round(duration × 60 / exposure_time)`. If 0, defaults to 12 snapshots. |
| `presentation_duration_minutes` | float | `0` | Duration of PRESENTATION state in minutes. If 0, defaults to 5 minutes. |
| `startup_mode` | string | `"calibration"` | `"calibration"` — start in calibration mode (default); `"generative"` — skip calibration and go straight to generative mode |
| `auto_restart` | bool | `false` | If true, automatically start a new experiment after PRESENTATION ends. If false, system goes to IDLE and waits. |
| `use_apparatus` | bool | `false` | If true, include the REFRESH and POST_REFRESH states to cycle liquid through the apparatus between experiments |

#### Network / OSC

Only change these if your network setup differs from defaults.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `osc_receive_port` | int | `7001` | Port on which XenoPi listens for incoming OSC |
| `osc_remote_ip` | string | `"127.0.0.1"` | IP of xeno_osc.py (neural network server) |
| `osc_send_port` | int | `7000` | Port of xeno_osc.py |
| `osc_server_remote_ip` | string | `"192.168.0.100"` | IP of xeno_server.py (xenopc) |
| `osc_server_send_port` | int | `7000` | Port of xeno_server.py |
| `osc_apparatus_remote_ip` | string | `"192.168.0.102"` | IP of the ESP32 apparatus |
| `osc_apparatus_send_port` | int | `7000` | Port of the ESP32 apparatus |

---

### config/xenopc.yaml

**Location**: `config/xenopc.yaml` — this file is **gitignored** (machine-specific). Copy from `config/xenopc.yaml.example` and fill in your values.

This file is read by `xeno_server.py` at startup. It defines the adapter to use, connection parameters, and named OSC targets for adapter configs.

```yaml
# Adapter name: maps to config/adapters/<adapter>.yaml
adapter: default

# XenoPi connection (used for rsync).
xenopi_ip: 192.168.0.101
xenopi_send_port: 7001
xenopi_username: pi
xenopi_password: xenolalia
xenopi_snapshots_dir: /home/pi/xenolalia/XenoPi/snapshots

# Macroscope (XenoProjection) connection.
macroscope_ip: 127.0.0.1
macroscope_send_port: 7001

# Local server.
receive_port: 7000
local_snapshots_dir: /home/xeno/xenolalia/contents

# Named OSC targets — referenced by adapter handler configs.
# 'xenopi' is always built-in.
targets:
  server:
    host: 127.0.0.1
    port: 7000
  macroscope:
    host: 127.0.0.1
    port: 7001
  sonoscope:
    host: 127.0.0.1
    port: 7002
  neurons:
    host: 192.168.0.101
    port: 7000
  mesoscope:
    host: 192.168.0.101
    port: 7001
  orbiter:
    host: 192.168.0.101
    port: 7002
  apparatus:
    host: 192.168.0.102
    port: 7000
```

---

### config/adapters/

Adapter configs decouple venue-specific trigger logic from the core code. Each installation can use a different adapter — e.g. proximity sensor trigger, time-slot schedule, manual control only — without touching `xeno_server.py`.

**Committed configs** (safe to use as-is or as a starting point):
- `config/adapters/default.yaml` — manual control only; no automatic triggers
- `config/adapters/proximity_example.yaml` — PIR/proximity sensor triggers a new experiment

**Venue-specific configs** (e.g. `eisode2026.yaml`) are gitignored. Use the examples as templates.

**Selecting an adapter**: set `adapter: <name>` in `config/xenopc.yaml`. The file `config/adapters/<name>.yaml` is loaded.

#### Adapter config format

```yaml
adapter: "My Installation"   # Display name (informational only)
receive_port: 8001           # Port the adapter listens on (separate from xeno_server's port)

handlers:

  /start:                    # OSC address that triggers this handler
    type: start              # Handler type: start | stop | route

  /presence:
    type: start
    require_inactive: true   # Only trigger if no experiment is currently running
    cooldown_minutes: 90     # Minimum time between triggers (safety net)

  /stop:
    type: stop

  /some/relay:
    type: route
    osc:
      - target: apparatus    # Named target from xenopc.yaml targets:
        address: /xeno/ring/grow
        type: i
        value: 1

# Timed daily OSC messages (fired once per day at HH:MM local time).
schedule:
  - time: "22:30"
    target: apparatus
    address: /xeno/ring/dark
    type: i
    value: 1
  - time: "09:00"
    target: apparatus
    address: /xeno/ring/grow
    type: i
    value: 1
```

**Handler types:**

| Type | Description |
|------|-------------|
| `start` | Sends a start command to XenoPi (begins a new experiment) |
| `stop` | Sends a stop command to XenoPi (ends the current experiment) |
| `route` | Forwards an OSC message to one or more named targets |

**Guard keys** (optional, on `start` handlers):

| Key | Description |
|-----|-------------|
| `require_inactive` | Only trigger if no experiment is currently running |
| `cooldown_minutes` | Minimum minutes between successive triggers |
| `delay_minutes` | Delay before the start command is actually sent |
| `require_on_time` | Only trigger during scheduled hours |

---

## Development & Testing Tools

These scripts allow testing individual features offline without a camera, live euglenas, or a full experiment cycle.

### `xeno_test_snapshots.py` — Batch Visibility Tester

Scans a directory of raw snapshots, runs each through the full image processing pipeline, and prints a table of pixel density and visibility class. Use this to calibrate `visibility_threshold_cv` and `visibility_threshold_human` in `settings.json`.

**Visibility classes:**

| Class | Label | Meaning |
|:-----:|-------|---------|
| 0 | `invisible` | No signal detected |
| 1 | `cv-only` | Machine detects it; not perceptible to humans |
| 2 | `human-vis` | Strong enough for humans to perceive |

**Usage:**

```bash
source xeno-env/bin/activate

# Scan a single experiment directory
python xeno_test_snapshots.py XenoPi/snapshots/00_test/ -C XenoPi/settings.json

# Scan all snapshot subdirectories recursively
python xeno_test_snapshots.py XenoPi/snapshots/ --recursive -C XenoPi/settings.json

# Try different thresholds
python xeno_test_snapshots.py XenoPi/snapshots/ --recursive \
    --threshold-cv 0.03 --threshold-human 0.15
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `directory` | *(required)* | Directory to scan for `*_raw.png` files |
| `-C` | `XenoPi/settings.json` | Config file |
| `--recursive` | off | Also scan subdirectories |
| `--threshold-cv` | from settings or `0.1` | Override CV-visible density threshold |
| `--threshold-human` | from settings or `0.3` | Override human-visible density threshold |

Once you have settled on good values, write them to `settings.json`:
```json
"visibility_threshold_cv": 0.03,
"visibility_threshold_human": 0.15
```

---

### `xeno_simulate.py` — OSC Simulation / Replay

Replays a past experiment snapshot directory by sending OSC messages to XenoPi and XenoProjection exactly as `xeno_osc.py` would — without a camera, live euglenas, or a running model. Use to test the shape overlay, visibility tracking, and display pipeline in isolation.

XenoPi and/or XenoProjection must be running before starting the script.

**Usage:**

```bash
source xeno-env/bin/activate

# Replay an experiment with a 2-second delay between steps (default)
python xeno_simulate.py XenoPi/snapshots/2021-09-03_17:16:07_emery-2021_nodepi-02/

# Fast replay with no delay
python xeno_simulate.py XenoPi/snapshots/2021-09-03_17:16:07_emery-2021_nodepi-02/ --delay 0

# Force a specific visibility class for all steps
python xeno_simulate.py XenoPi/snapshots/2021-09-03_17:16:07_emery-2021_nodepi-02/ --vis-override 2

# Multi-machine setup (XenoPi on RPi, XenoProjection on xenopc)
python xeno_simulate.py XenoPi/snapshots/2021-09-03_17:16:07_emery-2021_nodepi-02/ \
    --xenopi-ip 192.168.0.101 \
    --server-ip  192.168.0.100 \
    --delay 3
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `snapshot_dir` | *(required)* | Experiment directory to replay |
| `-C` | `XenoPi/settings.json` | Config file |
| `--xenopi-ip` | `127.0.0.1` | IP of machine running XenoPi |
| `--xenopi-port` | `7001` | OSC receive port of XenoPi |
| `--server-ip` | `192.168.0.100` | IP of machine running XenoProjection |
| `--server-port` | `7000` | OSC receive port of xeno_server.py |
| `--delay` | `2.0` | Seconds between steps |
| `--vis-override` | *(recomputed)* | Force visibility class for all steps: `0`, `1`, or `2` |

---

### `analyze_encoder.py` — Encoder Activation Analysis

Runs the autoencoder N times in feedback-loop mode (each from a different random seed), collects per-channel statistics (min, max, avg) from the encoder bottleneck layer, then analyses sparsity, amplitude, diversity, and inter/intra-run variation. Saves plots and a text report to the output directory.

Useful for verifying that the vectors sent to the sonoscope Pd patch carry meaningful, diverse information.

**Usage:**

```bash
source xeno-env/bin/activate

python analyze_encoder.py                          # uses settings.json defaults
python analyze_encoder.py -n 100 -s 8             # 100 runs, 8 feedback steps each
python analyze_encoder.py --vector max -o out/    # analyse the 'max' stat vector
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-C` | `XenoPi/settings.json` | Config file (model, encoder_layer, etc.) |
| `-M` | `results` | Directory containing `.hdf5` model files |
| `-n` | `50` | Number of independent feedback runs |
| `-s` | from settings | Feedback steps per run |
| `--vector` | `avg` | Stat vector to analyse: `min`, `max`, or `avg` |
| `-o` | `analysis` | Output directory for plots and report |
| `--sparsity-threshold` | `0.05` | Values below this are considered near-zero |

---

## Glyph Alphabet & Font Generation

These scripts generate a full xenolalia glyph alphabet and package it as a TrueType font. They use the autoencoder only — no camera or euglenas required.

### Environment setup

```bash
python -m venv xeno-env
source xeno-env/bin/activate
pip install -r requirements_alphabet.txt
```

### Step 1 — Generate glyph images (`xeno_alphabet.py`)

For each character (a–z, A–Z, 0–9, punctuation) the script renders it as a 28×28 seed image, blends it with noise, and feeds it through the autoencoder.

```bash
python xeno_alphabet.py -m <model_name> -C XenoPi/settings.json -o alphabet/
```

Settings used to generate the official `xenolalia.ttf` font:

```bash
python xeno_alphabet.py -m model_sparse_conv_enc20-40_dec40-20_k5_b128 \
    -c -n 5 -N 0.8 -s 28 --squircle-mode inside --threshold 0.2 \
    -o alphabet --seed 23 --fit --fit-max 2
```

**Key options:**

| Option | Default | Description |
|--------|---------|-------------|
| `-m`, `--model-name` | *(required)* | Model filename without `.hdf5` |
| `-M`, `--model-directory` | `results` | Directory containing `.hdf5` model files |
| `-C`, `--configuration-file` | — | Load post-processing params from `settings.json` |
| `-n`, `--n-steps` | `10` | Autoencoder feedback iterations per glyph |
| `-N`, `--noise` | `0.3` | Noise blend weight (0 = pure character, 1 = pure random) |
| `-o`, `--output-dir` | `alphabet` | Output directory for glyph images |
| `--fit` | off | Auto-scale each glyph to fill the 28×28 canvas |
| `--fit-max` | unlimited | Maximum expansion factor in `--fit` mode |
| `--uppercase` | off | Render letters as uppercase |
| `--seed` | — | Integer random seed for reproducibility |
| `--save-seeds` | off | Also save intermediate seed and raw autoencoder images |
| `--output-size` | `224` | Side length of saved output images in pixels |
| `--squircle-mode` | `none` | Squircle remapping: `none`, `inside`, or `outside` |

### Step 2 — Convert to TrueType font (`xeno_font.py`)

Traces binary glyph PNGs into vector contours and assembles a `.ttf` file.

```bash
python xeno_font.py alphabet/ xenolalia.ttf --family Xenolalia
```

**Key options:**

| Option | Default | Description |
|--------|---------|-------------|
| `glyph_dir` | *(required)* | Directory of glyph PNGs |
| `output_font` | *(required)* | Output `.ttf` file path |
| `--family` | `Xenolalia` | Font family name embedded in the TTF |
| `--style` | `Regular` | Font style name |
| `--upm` | `1000` | Units per em |
| `--advance` | UPM | Advance width for all glyphs |
| `--simplify` | `1.0` | Contour simplification tolerance in pixels (0 to disable) |

---

## Installation

### XenoPC Installation

**OS:** Ubuntu 24.04

#### Install system packages

```bash
sudo apt update && sudo apt upgrade

sudo apt install -y git git-gui \
    python3-dev python3-setuptools python3-h5py \
    libblas-dev liblapack-dev libatlas-base-dev gfortran \
    xdotool \
    python3-venv \
    software-properties-common dirmngr apt-transport-https lsb-release ca-certificates \
    liblo-tools liblo7 \
    rsync sshpass
```

#### Install Python libraries

```bash
python3 -m venv xeno-env
source xeno-env/bin/activate
pip install -r requirements_pc.txt
```

#### Configure

Copy and edit the xenopc config:
```bash
cp config/xenopc.yaml.example config/xenopc.yaml
nano config/xenopc.yaml        # fill in xenopi credentials and adapter name
```

Choose or create an adapter config in `config/adapters/`. The `default.yaml` (manual control) is ready to use with no changes.

#### Configure auto-launch

Create `~/.config/autostart/xenolalia.desktop` with:
```ini
[Desktop Entry]
Type=Application
Exec=/bin/bash /home/xeno/xenolalia/bin/xeno_pc_main.sh
```

Or use the provided `bin/xeno_pc_main.desktop` file.

---

### XenoPi Installation

**Last tested:** Raspberry Pi 3 B+ v1.3, Raspbian Stretch. The GL Video Processing library was not compatible with RPi 4 / Raspbian Buster at the time of writing.

#### Install system packages

```bash
sudo apt update && sudo apt upgrade

sudo apt install -y git git-gui \
    python3-dev python3-setuptools python3-h5py \
    libblas-dev liblapack-dev libatlas-base-dev gfortran \
    xdotool python3-venv \
    software-properties-common dirmngr apt-transport-https lsb-release ca-certificates \
    liblo-tools liblo7 \
    lftp
```

#### Install Python libraries

```bash
python3 -m venv xeno-env
source xeno-env/bin/activate
pip install -r requirements_xenopi.txt
```

#### Install Processing

```bash
wget https://github.com/processing/processing/releases/download/processing-0269-3.5.3/processing-3.5.3-linux-armv6hf.tgz
tar xzvf processing-3.5.3-linux-armv6hf.tgz
cd processing-3.5.3/
sudo ./install.sh
```

Add the following Processing libraries via Sketch → Import Library → Add Library:
- Video
- GL Video
- OpenCV
- OscP5

#### Configure auto-launch

Edit the autostart file:
```bash
nano ~/.config/lxsession/LXDE-pi/autostart
```

Add:
```bash
# Wait for Wifi before startup
sleep 10
/bin/bash /home/pi/xenolalia/bin/xeno_pi_main.sh > /home/pi/startuplog 2>&1
```

#### GPU memory (if Processing crashes with OpenGL errors)

Add to `/boot/config.txt`:
```
gpu_mem=320
```

#### LCD screen (optional 3.5" TFT)

Follow the official instructions at http://www.lcdwiki.com/MHS-3.5inch_RPi_Display — run `sudo ./MHS35-show` (not `LCD35-show`). After reboot, fix the resolution by editing `/boot/config.txt`:
```
hdmi_cvt 1920 1080 60 6 0 0 0
```

---

## OSC Message Reference

### XenoPi ↔ xeno_osc.py

| Receiver | Sender | Address | Params | Purpose |
|----------|--------|---------|--------|---------|
| `xeno_osc.py` | XenoPi | `/xeno/euglenas/handshake` | — | Request readiness confirmation from neural network |
| `xeno_osc.py` | XenoPi | `/xeno/euglenas/new` | — | Signal start of new experiment |
| `xeno_osc.py` | XenoPi | `/xeno/euglenas/begin` | `ss` | First snapshot: `raw_image_path`, `base_image_path`; uses random seed |
| `xeno_osc.py` | XenoPi | `/xeno/euglenas/step` | `ss` | Subsequent snapshot: `raw_image_path`, `base_image_path`; uses captured image as seed |
| `xeno_osc.py` | XenoPi | `/xeno/euglenas/settings-updated` | — | Reload `settings.json` |
| `xeno_osc.py` | XenoPi | `/xeno/euglenas/test-camera` | `s` | Request perspective-corrected preview: `raw_image_path` |
| XenoPi | `xeno_osc.py` | `/xeno/neurons/handshake` | — | Confirm neural network is ready |
| XenoPi | `xeno_osc.py` | `/xeno/neurons/begin` | — | Neural network server has started |
| XenoPi | `xeno_osc.py` | `/xeno/neurons/end` | — | Neural network server is shutting down |
| XenoPi | `xeno_osc.py` | `/xeno/neurons/new` | — | Neural network acknowledged new experiment |
| XenoPi | `xeno_osc.py` | `/xeno/neurons/step` | `s` | `nn_image_path` — path to the autoencoder-generated image |
| XenoPi | `xeno_osc.py` | `/xeno/neurons/visibility` | `i` | Visibility class: `0`=invisible, `1`=cv-only, `2`=human-visible |
| XenoPi | `xeno_osc.py` | `/xeno/neurons/test-camera` | `s` | `transformed_image_path` — perspective-corrected preview |

### XenoPi ↔ Apparatus (ESP32)

| Receiver | Sender | Address | Params | Purpose |
|----------|--------|---------|--------|---------|
| Apparatus | XenoPi | `/xeno/refresh` | `i` | Trigger full liquid refresh cycle (always `1`) |
| Apparatus | XenoPi | `/xeno/ring/dark` | — | LED ring off |
| Apparatus | XenoPi | `/xeno/ring/idle` | — | LED ring idle animation |
| Apparatus | XenoPi | `/xeno/ring/glow` | — | LED ring glow mode |
| Apparatus | XenoPi | `/xeno/ring/grow` | — | LED ring grow animation |
| Apparatus | any | `/xeno/color` | `iii` | Set NeoPixel ring color: R, G, B (0–255) |
| Apparatus | any | `/xeno/test_hardware` | — | Test all hardware components |
| Apparatus | any | `/xeno/mix` | — | Activate mixing pump |
| Apparatus | any | `/xeno/drain` | `i` | Drain pump; integer controls duration |
| Apparatus | any | `/xeno/fill` | `i` | Fill pump; integer controls duration |
| XenoPi | Apparatus | `/xeno/apparatus/refreshed` | — | Liquid refresh cycle complete |
| XenoPi | Apparatus | `/xeno/handshake` | — | Apparatus acknowledged a command |

### XenoPi ↔ xeno_server.py (xenopc)

| Receiver | Sender | Address | Params | Purpose |
|----------|--------|---------|--------|---------|
| `xeno_server.py` | XenoPi | `/xeno/exp/new` | `s` | New experiment: `uid` — triggers rsync |
| `xeno_server.py` | XenoPi | `/xeno/exp/step` | `s` | New image added: `uid` — triggers rsync |
| `xeno_server.py` | XenoPi | `/xeno/exp/end` | `si` | Experiment ended: `uid`, visibility class — triggers final rsync |
| `xeno_server.py` | XenoPi | `/xeno/exp/state` | `s` | Current FSM state name (used internally to derive downstream messages) |
| XenoPi | any | `/xeno/control/begin` | — | Start generative mode (external trigger) |

### xeno_server.py → XenoProjection

| Receiver | Sender | Address | Params | Purpose |
|----------|--------|---------|--------|---------|
| XenoProjection | `xeno_server.py` | `/xeno/server/new` | `s` | New experiment: `uid` |
| XenoProjection | `xeno_server.py` | `/xeno/server/step` | `s` | New image added: `uid` |
| XenoProjection | `xeno_server.py` | `/xeno/server/end` | `s` or `si` | Experiment ended: `uid`, optional visibility class |
| XenoProjection | `xeno_server.py` | `/xeno/server/snapshot` | — | Snapshot visual effect (fired when FSM state = `FLASH`) |

### xeno_osc.py → Orbiter / Sonoscope

| Receiver | Sender | Address | Params | Purpose |
|----------|--------|---------|--------|---------|
| `xeno_orbiter.py` | `xeno_osc.py` | `/xeno/neurons/new` | — | Reset OLED display for new experiment |
| `xeno_orbiter.py` | `xeno_osc.py` | `/xeno/neurons/step` | `s` | Display the image at `nn_image_path` on OLED |
| `xeno_orbiter.py` | `xeno_osc.py` | `/xeno/neurons/end` | — | Stop OLED animation |
| Pd sonoscope | `xeno_osc.py` | `/xeno/sonoscope/activations` | `fff…` | Flattened, normalized encoder activations (float array) — sent after each step |

### XenoProjection → Pd sonoscope (code signature)

| Receiver | Sender | Address | Params | Purpose |
|----------|--------|---------|--------|---------|
| Pd sonoscope | XenoProjection | `/xeno/sonoscope/activations/start` | `fff…` | Per-channel min/max/avg vectors at scene start |
| Pd sonoscope | XenoProjection | `/xeno/sonoscope/activations/end` | `fff…` | Per-channel min/max/avg vectors at scene end |

**Notes:**

- `/xeno/handshake` is sent by the Apparatus as acknowledgment on every incoming command.
- `/xeno/server/snapshot` is not sent by XenoPi directly — `xeno_server.py` fires it whenever it receives `/xeno/exp/state` = `FLASH`.
- `xeno_server.py` broadcasts `/xeno/server/*` to both XenoProjection and XenoPi. XenoPi has no handlers for those addresses and ignores them silently.
- `/xeno/neurons/begin` is broadcast by `xeno_osc.py` to both XenoPi and `xeno_orbiter.py`, but the orbiter only handles `new`, `step`, and `end`.

---

## Troubleshooting

### Processing crashes with OpenGL errors

Add to `/boot/config.txt` on the RPi:
```
gpu_mem=320
```

### Pure Data priority / sound problems

If Pd shows scheduling errors or ALSA errors ("Device or resource busy"), run it as superuser. To allow this without a password prompt:

```bash
sudo visudo
```

Add:
```
# Allow running pd as superuser without password.
xeno    ALL=NOPASSWD: /usr/bin/pd
```

### xeno_server.py can't find xenopc.yaml

Make sure you have copied the example and are running from the `xenolalia` directory:
```bash
cp config/xenopc.yaml.example config/xenopc.yaml
cd ~/xenolalia
python xeno_server.py
```

`xeno_pc_main.sh` handles the `cd` automatically.

### XenoPi doesn't connect to xeno_osc.py

`xeno_osc.py` must be running before XenoPi completes its first handshake attempt. When using `xeno_pi_main.sh`, the script waits 20 seconds after starting `xeno_osc.py` before launching XenoPi. If starting manually, start `xeno_osc.py` first and wait until you see the "Serving on..." message before opening XenoPi.

### Snapshots are not syncing to xenopc

Check that:
1. `xenopi_username`, `xenopi_password`, and `xenopi_snapshots_dir` in `config/xenopc.yaml` are correct.
2. `rsync` and `sshpass` are installed on the xenopc (`sudo apt install rsync sshpass`).
3. The xenopc can reach the RPi: `ping 192.168.0.101`.

### Experiment ends in IDLE and doesn't restart

This is the default behavior when `auto_restart` is `false` in `settings.json`. Either set `auto_restart: true`, or press **n** in XenoPi to start a new experiment manually.

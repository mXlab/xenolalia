# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Xenolalia is a bio-digital art installation that creates a feedback loop between living microorganisms (euglenas) and a neural network (autoencoder). The system captures images of euglenas, processes them through an autoencoder that generates new images, which are then projected onto the euglenas to influence their movement, creating an evolving visual dialogue.

## Architecture

The system consists of four interconnected components communicating via OSC (Open Sound Control):

```
XenoPi (Processing) <--OSC--> xeno_osc.py (Python/Keras) <--OSC--> XenoProjection (Processing)
       |
       +--OSC--> ESP32 Apparatus (Arduino/PlatformIO)
```

### Component Details

**XenoPi** (`XenoPi/*.pde`): Main Processing sketch running on Raspberry Pi
- Handles camera calibration and capture via GL Video library
- Manages the generative process state machine (INIT → NEW → REFRESH → POST_REFRESH → FLASH → SNAPSHOT → WAIT_FOR_GLYPH → MAIN → PRESENTATION)
- Communicates with neural network and ESP32 apparatus via OSC
- Configuration stored in `XenoPi/settings.json`

**xeno_osc.py**: Neural network OSC server (Python)
- Loads Keras autoencoder models from `results/` directory
- Receives images from XenoPi, processes through autoencoder, returns generated images
- Uses `xeno_image.py` for image preprocessing (transform, filter, mask, enhance, simplify)
- OSC addresses: `/xeno/euglenas/begin`, `/xeno/euglenas/step`, `/xeno/neurons/step`

**XenoProjection** (`processing/XenoProjection/*.pde`): Visualization display
- Shows morphing vignettes of biological and artificial images
- Manages scene transitions and experiment data display
- Receives updates via OSC at port 7001

**ESP32 Apparatus** (`arduino/Xenolalia_platformio/`): Physical hardware control
- Controls pumps, servo motor, liquid sensor, NeoPixel ring
- Receives OSC commands for refresh/glow operations
- Target: WEMOS D1 Mini ESP32

## Key Files

| File | Purpose |
|------|---------|
| `xeno_osc.py` | Main neural network server |
| `xeno_image.py` | Image processing library (transform, filter, mask) |
| `xeno_camera.py` | Camera capture abstraction (RPi/PC) |
| `xeno_video.py` | GIF/APNG generation from experiment snapshots |
| `deep_autoencoder.py` | Autoencoder training script |
| `XenoPi/XenoPi.pde` | Main Processing sketch |
| `XenoPi/GenerativeMode.pde` | State machine for generative process |
| `XenoPi/Settings.pde` | Configuration management |

## Commands

### Python Environment
```bash
# Activate virtual environment
source xeno-env/bin/activate

# Install dependencies (Raspberry Pi)
pip install -r requirements_xenopi.txt

# Install dependencies (PC)
pip install -r requirements_pc.txt
```

### Running the System
```bash
# Start neural network server (run first)
python xeno_osc.py -C XenoPi/settings.json -M results

# Process an image through the pipeline
python xeno_image.py input.png output.png -C XenoPi/settings.json

# Generate animation from experiment
python xeno_video.py <experiment_folder> output.gif -m bio
```

### Training Autoencoders
```bash
# Train convolutional autoencoder
python deep_autoencoder.py "16,8,8" model.hdf5 -c -e 100

# Train dense autoencoder
python deep_autoencoder.py "128,64,32" model.hdf5 -e 100
```

### ESP32 Firmware
```bash
# Build and upload via USB
cd arduino/Xenolalia_platformio
pio run -e wemos_d1_mini32 -t upload

# Upload via OTA (WiFi)
pio run -e wemos_d1_mini32_ota -t upload
```

### Processing Sketches
Open in Processing IDE:
- `XenoPi/XenoPi.pde` - requires GL Video library
- `processing/XenoProjection/XenoProjection.pde`
- `processing/CameraPerspectiveConfig/CameraPerspectiveConfig.pde`

## OSC Communication

Default ports:
- XenoPi receives: 7001
- xeno_osc.py receives: 7000
- XenoProjection receives: 7001
- ESP32 apparatus: 7000

Key addresses:
- `/xeno/euglenas/handshake` - Initialize connection
- `/xeno/euglenas/begin` - Start new image with random seed
- `/xeno/euglenas/step` - Process next image
- `/xeno/neurons/step` - Neural network response with image path
- `/xeno/refresh` - Trigger apparatus liquid refresh
- `/xeno/glow` - Control LED ring

## Image Processing Pipeline

1. **Capture**: Raw camera image
2. **Transform**: Perspective correction via `input_quad` (4 corner points)
3. **Remove base**: Subtract background reference image
4. **Mask**: Apply circular mask to remove border artifacts
5. **Enhance**: Invert, median filter, histogram equalization
6. **Simplify**: Adaptive threshold, morphological thinning, erosion
7. **Resize**: Scale to 28x28 for autoencoder input

## Configuration

`XenoPi/settings.json` contains:
- `camera_quad`: 8 floats defining perspective transform corners
- `image_rect`: Display rectangle for projected image
- OSC network settings (IPs and ports)
- `model_name`: Autoencoder model file (without .hdf5)
- `use_convolutional`: Whether model uses convolutional layers
- `n_feedback_steps`: Autoencoder iteration count
- `exposure_time`: Seconds between snapshots

# Xenolalia

## Components

Xenolalia consists mainly of 4 different components:
 1. **Mesoscope** Device / machine / apparatus where the experiments happen
    * xenopi (RPi) which runs the display and experiment control (XenoPi), the neural network generator (xeno_osc.py) and the orbiter (xeno_orbiter.py)
    * Apparatus controller (ESP32) which controls the pumps and motors
 2. **Macroscope** Large-scale projection showing the experiments in real time
    * xenopc (PC) running projection (XenoProjection) and python server operating file transfers (xeno_server.py)
 3. **Microscope** Microscope ("xenoscope") showing the live cells
 4. **Sonoscope** (Optional) Sonification of the neural network

## Default IP Addresses & Ports

| IP              | Machine                     | Programs & OSC input ports                              |
|-----------------|-----------------------------|---------------------------------------------------------|
|192.168.0.**100**|xenopc                       |xeno_server.py (7000), XenoProjection (7001)             |
|192.168.0.**101**|xenopi (RPi)                 |xeno_osc.py (7000), XenoPi (7001), xeno_orbiter.py (7002)|
|192.168.0.**102**|Apparatus (ESP32)            |XenolaliaApparatus (7000)                                |
|192.168.0.**103**|Xenoscope (microscope) (RPi) |Xenoscope (n/a)                                          |

## Running Xenolalia

### Introduction

Several programs are needed to run Xenolalia.

On the xenopi (mesoscope):
 1. Front-end: ```XenoPi``` Processing sketch. Manages the interaction between the camera and the screen.
 2. Back-end: ```xeno_osc.py``` Python script. Manages the image filtering and the autoencoder image generation.
 3. (Optional) Orbiter control: ```xeno_orbiter.py``` Python script. Manages control of the "orbiter" secondary OLED device.
 4. (Recommended) Sleep prevent: ```bin/prevent_sleep.sh``` Shell script. Prevents the Pi monitor for going to sleep due to lack of mouse activity.

Alternatively, a single script will automatically start all these programs: ```bin/xeno_main.sh```

On the xenopc:
 1. Macroscope: ```XenoProjection``` Processing sketch. Displays the different images of current and previous experiments.
 2. Server: ```xeno_server.py``` Python script. Receives messages about current experiment from XenoPi, syncs image files, and calls XenoProjection.

### Definitions

 * **Experiment** : one specific generation, starting from a seed image and generating a sequence of images
 * **Session** : an event during which the piece was run (eg. a residency, an exhibition, etc.)
 * **Node** : a specific instance or module on which the experiments are being performed

### Settings

The ```XenoPi/settings.json``` file contains parameters that can be set by the user to control the experiments. A sample file is located in ```XenoPi/settings.json.default```.

Description of the core parameters:

| Parameter        | Description | Example |
|------------------|-------------|---------|
| node_name        | Unique name to identify the module running the experiment | "nodepi-01" |
| session_name     | Unique name to identify the session/event during which the experiment took place | "isea-2020" |
| exposure_time    | Time during which each image is left on the petri dish before taking a new snapshot (seconds) | 300 |
| seed_image       | Type of image used as a seed (choices: random, euglenas) | "random" |
| n_feedback_steps | Number of self-loops the neural net does at each step | 4 |

### Launching

#### Step 1 : Start the program(s)

The easiest way to start the program is to use the ```xeno_main.sh``` bash script.

```
cd ~/xenolalia
./bin/xeno_main.sh
```

Alternatively you can start the programs separately.
 1. Start the ```XenoPi``` program. It will start in calibration mode.
 2. Start the ```xeno_osc.py``` script with the appropriate parameters. Example: ```python3 xeno_osc.py -c results/model_sparse_conv_enc20-40_dec40-20_k5_b128.hdf5 -n 5```
 3. (Optional) Start the ```xeno_orbiter.py``` and the ```bin/prevent_sleep.sh``` programs.

#### Step 2 : Calibration mode

Upon startup ```XenoPi``` will being in **calibration mode**. Here is how to proceed:
 1. Adjust the reference image.
     1. Click on the first corner to place the first control point.
     2. Press TAB to select the next control point; then click on the 2nd corner to place it.
     3. You can use the arrow keys to make small adjustments.
     4. Once you are satisfied, press ENTER: it will save the settings.json file.
     5. Then press the SPACEBAR.
 2. Adjust the input quad.
     1. Using the mouse and the same keys as for the previous step, adjust the four corners of the input quad to match the corners of the image picked by the camera, directly on the screen.
     2. You can select one of the four control points by pressing its number (1, 2, 3, 4).
     3. Once you are satisfied, press ENTER: it will save the settings.json file.

#### Step 3 : Check the conditions

**IMPORTANT** At this point you need to make sure to put the experimental setup in the same set of conditions as they will be running. Adjust light sources, close lids and curtains, etc. whatever you want your setup to be.

#### Step 4 : Begin generation

Press the 'g' key to start the generative process.

### Switch to next experiment

While the script is running you can manually start a new experiment by pressing the 'n' key.

### Exiting

You can exit ```XenoPi``` with the ESC key. If you started the programs using ```xeno_main.sh``` you don't need to do anything else as the script will take care of killing the other programs.

### Key bindings

#### Calibration mode

| Key | Description | 
|:---:|-------------|
| SPACEBAR | Toggle mode from reference image to input quad |
| ENTER | Save calibration settings |
| ←↑→↓ | Moves selected control point by one pixel |
| TAB | Select next control point |
| 1234 | Select specific control point |
| m | Toggle the mouse crosshair |
| p | Toggle the control point crosshair |
| +- | Adjust the size of the control point lines |
| g | Start generative mode |

#### Generative mode

| Key | Description | 
|:---:|-------------|
| SPACEBAR | Manually take a snapshot |
| f | Toggle flash screen (useful to look at what is happening on the petri dish) |
| v | Toggle camera view (live camera feed appears in the corner) |
| a | Toggle auto mode (\*) |
| n | Start new experiment |

(\*) In auto mode (default) snapshots will be taken at a regular pace as specified by the "exposure_time" setting. In manual mode (ie. non-auto mode) the user has the responsibility to manually take snapshots using the SPACEBAR.

## XenoPC Configuration

### Installation

OS: Ubuntu 24.04

#### Install Packages

```
# Update/upgrade Debian packages
sudo apt update
sudo apt upgrade

# Install debian packages.
sudo apt install -y git git-gui \
                      python3-dev python3-setuptools python3-h5py \
                      libblas-dev liblapack-dev libatlas-base-dev gfortran \
                      xdotool \
                      python-virtualenv \
                      software-properties-common dirmngr apt-transport-https lsb-release ca-certificates \
                      liblo-tools liblo7 \
                      rsync sshpass

```

#### Install Python libraries in Virtual Environment

From main directory:

```
python -m venv xeno-env
source xeno-env/bin/activate
```

```
pip install numpy
pip install -r requirements_pc.txt
pip install -U six wheel mock
```

## Xenopi Configuration

Follow these instructions in order to install everything on a Raspberry Pi.

### Specs

 * Board: Raspberry Pi Model 3 B+ Version 1.3
 * OS: Raspbian Stretch

Note: I was unable to get the Processing video libraries to work appropriately on a Raspberry Pi 4 (2G) w/ Rasbian Buster. I was also never able to boot the Pi 4 on Raspbian Stretch so I had to downgrade to a Pi 3.

### Installation

IMPORTANT: Do *not* install MiniConda as the Python3 version it installs (3.4) is incompatible with Keras. Use the default Python 3 version instead.

Troubleshooting: When running ```pip3 install``` if you get error "http.client.RemoteDisconnected: Remote end closed connection without response" just re-run the command until it works.

```
# Update/upgrade Debian packages
sudo apt update
sudo apt upgrade

# Install debian packages.
sudo apt install -y git git-gui \
                      python3-dev python3-setuptools python3-h5py \
                      libblas-dev liblapack-dev libatlas-base-dev gfortran \
                      xdotool \
                      python-virtualenv \
                      software-properties-common dirmngr apt-transport-https lsb-release ca-certificates \
                      liblo-tools liblo7 \
                      libjasper1 libqtgui4 libqt4-test \
                      lftp

# Install python libraries.
pip3 install numpy # This is important otherwise it will trigger a bug on next line
pip3 install -r requirements.txt
pip3 install -U six wheel mock
wget https://github.com/lhelontra/tensorflow-on-arm/releases/download/v2.0.0/tensorflow-2.0.0-cp37-none-linux_armv7l.whl
sudo pip3 uninstall tensorflow
pip3 install tensorflow-2.0.0-cp37-none-linux_armv7l.whl
# pip3 install keras tensorflow scipy numpy python-osc opencv-python scikit-image
```

To install Processing:
```
wget https://github.com/processing/processing/releases/download/processing-0269-3.5.3/processing-3.5.3-linux-armv6hf.tgz
tar czvf processing-3.5.3-linux-armv6hf.tgz
cd processing-3.5.3/
sudo ./install.sh
```

#### Xenolalia installation script

From the ```~/xenolalia``` directory the following script once with the login information for the FTP server:

```
sudo bash bin/xeno_pi_install.sh
```

#### Configure auto-launch

Edit the autostart file:
```
nano ~/.config/lxsession/LXDE-pi/autostart
```

Paste the following script and save:
```
# Wait to make sure Wifi is running before startup
sleep 10
# Launch script
/bin/bash /home/pi/xenolalia/bin/xeno_pi_main.sh > /home/pi/startuplog 2>&1
```

#### Processing libraries

Add the following libraries:
 * Video
 * GL VIdeo
 * OpenCV
 * OscP5

### LCD Screen

Follow the official instructions: http://www.lcdwiki.com/MHS-3.5inch_RPi_Display
IMPORTANT: run ```sudo ./MHS35-show``` and *not* ```LCD35-show```

After rebooting your main screen will have a 480x320 resolution. To fix this edit the ```/boot/config.txt``` by replacing the ```hdmi_cvt``` directive with your choice resolution eg. ```hdmi_cvt 1920 1080 60 6 0 0 0```

To restore the system in case of a mistake you can run the ```system_restore.sh``` script provided with the LCD-Show library.

### Notes

 * Dual monitor: I could never get my second monitor to work on the Pi4, it kept displaying the rainbow colorwheel splash screen. Did not find a solution.


## Xenodata

Xenodata provides an online interface to the generated contents.

The installation script will setup a hourly cron that will automatically upload all new generated contents.

To sync the contents manually:
```
sudo /etc/cron.hourly/xeno_sync_snapshots
```
The web-app can be access here: http://xenodata.sofianaudry.com/



## Troubleshooting

### Processing crashes with OpenGL errors

Make sure you have enough GPU memory by adding the following line to ```/boot/config.txt```:

```gpu_mem=320```

### Pure data priority and sound problems

It looks like there are problems when running Pd without admin rights:

```
priority 6 scheduling failed; running at normal priority
priority 8 scheduling failed.
```

and/or :

```
ALSA output error (snd_pcm_open): Device or resource busy
```

The solution is to run as superuser (sudo). To allow this without having to type a password, type:

```sudo visudo```

Add the following lines to the file:

```
# Allow to run pd as superuser.
xeno    ALL=NOPASSWD: /usr/bin/pd
```

Then save (CTRL-X). You should now be able to run Pd as sudo without having to type a password.

## OSC Message Reference

| Receiver Program | Sender Program(s) | Address | Param Types | Purpose |
|---|---|---|---|---|
| `xeno_osc.py` | XenoPi.pde | `/xeno/euglenas/handshake` | — | Request readiness confirmation from neural network |
| `xeno_osc.py` | XenoPi.pde | `/xeno/euglenas/new` | — | Signal start of new experiment |
| `xeno_osc.py` | XenoPi.pde | `/xeno/euglenas/begin` | `ss` | First snapshot of an experiment: provide `raw_image_path` and `base_image_path`; neural network uses a random seed for generation |
| `xeno_osc.py` | XenoPi.pde | `/xeno/euglenas/step` | `ss` | Subsequent snapshot: provide `raw_image_path` and `base_image_path`; neural network uses the captured image as seed |
| `xeno_osc.py` | XenoPi.pde | `/xeno/euglenas/settings-updated` | — | Notify neural network to reload `settings.json` |
| `xeno_osc.py` | XenoPi.pde | `/xeno/euglenas/test-camera` | `s` | Request a perspective-corrected preview; provides `raw_image_path` of the test capture |
| XenoPi.pde | `xeno_osc.py` | `/xeno/neurons/handshake` | — | Confirm neural network is ready |
| XenoPi.pde | `xeno_osc.py` | `/xeno/neurons/begin` | — | Neural network server has started |
| XenoPi.pde | `xeno_osc.py` | `/xeno/neurons/end` | — | Neural network server is shutting down |
| XenoPi.pde | `xeno_osc.py` | `/xeno/neurons/new` | — | Neural network acknowledged new experiment |
| XenoPi.pde | `xeno_osc.py` | `/xeno/neurons/step` | `s` | Delivers `nn_image_path`, the path to the autoencoder-generated image for this step |
| XenoPi.pde | `xeno_osc.py` | `/xeno/neurons/test-camera` | `s` | Returns `transformed_image_path`, the perspective-corrected version of the test capture |
| XenoPi.pde | XenolaliaApparatus | `/xeno/apparatus/refreshed` | — | Liquid refresh cycle completed |
| XenoPi.pde | XenolaliaApparatus | `/xeno/handshake` | — | Apparatus acknowledged a command |
| XenoPi.pde | any | `/xeno/control/begin` | — | Start generative mode |
| `xeno_orbiter.py` | `xeno_osc.py` | `/xeno/neurons/new` | — | Reset OLED display for new experiment |
| `xeno_orbiter.py` | `xeno_osc.py` | `/xeno/neurons/step` | `s` | Display the image at `nn_image_path` on the OLED screen |
| `xeno_orbiter.py` | `xeno_osc.py` | `/xeno/neurons/end` | — | Stop OLED display animation |
| `xeno_server.py` | XenoPi.pde | `/xeno/exp/new` | `s` | New experiment started; `uid` identifies the experiment; triggers rsync and data preparation |
| `xeno_server.py` | XenoPi.pde | `/xeno/exp/step` | `s` | New image added to the experiment identified by `uid`; triggers rsync and data preparation |
| `xeno_server.py` | XenoPi.pde | `/xeno/exp/end` | `s` | Experiment identified by `uid` has ended; triggers final rsync and data preparation |
| `xeno_server.py` | XenoPi.pde | `/xeno/exp/state` | `s` | Current FSM state name (e.g. `FLASH`, `SNAPSHOT`); used internally to derive downstream messages |
| XenoProjection | `xeno_server.py` | `/xeno/server/new` | `s` | New experiment identified by `uid` has started |
| XenoProjection | `xeno_server.py` | `/xeno/server/step` | `s` | New image added to experiment identified by `uid` |
| XenoProjection | `xeno_server.py` | `/xeno/server/end` | `s` | Experiment identified by `uid` has ended |
| XenoProjection | `xeno_server.py` | `/xeno/server/snapshot` | — | Trigger snapshot visual effect (fired when state = `FLASH`) |
| XenolaliaApparatus | XenoPi.pde | `/xeno/refresh` | `i` | Trigger a full liquid refresh cycle (always sent with value `1`) |
| XenolaliaApparatus | XenoPi.pde | `/xeno/glow` | `i` | Turn LED ring on (`1`) or off (`0`) |
| XenolaliaApparatus | any | `/xeno/test_hardware` | — | Test all hardware components |
| XenolaliaApparatus | any | `/xeno/mix` | — | Activate mixing pump |
| XenolaliaApparatus | any | `/xeno/drain` | `i` | Drain tube; integer value controls duration or amount |
| XenolaliaApparatus | any | `/xeno/fill` | `i` | Fill tube; integer value controls duration or amount |
| XenolaliaApparatus | any | `/xeno/color` | `iii` | Set NeoPixel ring color; three integers for red, green, blue (0–255) |

**Notes:**

- `/xeno/handshake` is sent by XenolaliaApparatus as an acknowledgment on every incoming command.
- `/xeno/server/snapshot` is not sent directly by XenoPi.pde: `xeno_server.py` fires it whenever it receives `/xeno/exp/state` with value `FLASH`.
- `xeno_server.py` broadcasts `/xeno/server/*` messages to both XenoProjection and XenoPi.pde as a side effect of its internal broadcast logic. XenoPi.pde has no handlers for those addresses and silently ignores them.
- `/xeno/neurons/begin` and `/xeno/neurons/end` are broadcast by `xeno_osc.py` to both XenoPi.pde and `xeno_orbiter.py`, but the orbiter only registers handlers for `new`, `step`, and `end` — `begin` arrives unhandled there.

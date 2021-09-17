# Raspberry Pi Configuration

## Specs

 * Board: Raspberry Pi Model 3 B+ Version 1.3
 * OS: Raspbian Stretch

Note: I was unable to get the Processing video libraries to work appropriately on a Raspberry Pi 4 (2G) w/ Rasbian Buster. I was also never able to boot the Pi 4 on Raspbian Stretch so I had to downgrade to a Pi 3.

## Installation

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
# pip3 install pip3 --upgrade # DO NOT DO THIS
pip3 install keras tensorflow scipy numpy
pip3 install python-osc
pip3 install opencv-python scikit-image

# Install Processing
curl https://processing.org/download/install-arm.sh | sudo sh
```

### Xenolalia installation script

From the ```~/xenolalia``` directory the following script once with the login information for the FTP server:

```
sudo bash bin/xeno_pi_install.sh
```

### Processing libraries

Add the following libraries:
 * Video
 * GL VIdeo
 * OpenCV
 * OscP5

## LCD Screen

Follow the official instructions: http://www.lcdwiki.com/MHS-3.5inch_RPi_Display
IMPORTANT: run ```sudo ./MHS35-show``` and *not* ```LCD35-show```

After rebooting your main screen will have a 480x320 resolution. To fix this edit the ```/boot/config.txt``` by replacing the ```hdmi_cvt``` directive with your choice resolution eg. ```hdmi_cvt 1920 1080 60 6 0 0 0```

To restore the system in case of a mistake you can run the ```system_restore.sh``` script provided with the LCD-Show library.

## Notes

 * Dual monitor: I could never get my second monitor to work on the Pi4, it kept displaying the rainbow colorwheel splash screen. Did not find a solution.



# Running Xenolalia

## Introduction

Several programs are needed to run Xenolalia:
 1. Front-end: ```XenoPi``` Processing sketch. Manages the interaction between the camera and the screen.
 2. Back-end: ```xeno_osc.py``` Python script. Manages the image filtering and the autoencoder image generation.
 3. (Optional) Orbiter control: ```xeno_orbiter.py``` Python script. Manages control of the "orbiter" secondary OLED device.
 4. (Recommended) Sleep prevent: ```bin/prevent_sleep.sh``` Shell script. Prevents the Pi monitor for going to sleep due to lack of mouse activity.

Alternatively, a single script will automatically start all these programs: ```bin/xeno_main.sh```

## Definitions

 * **Experiment** : one specific generation, starting from a seed image and generating a sequence of images
 * **Session** : an event during which the piece was run (eg. a residency, an exhibition, etc.)
 * **Node** : a specific instance or module on which the experiments are being performed

## Settings

The ```XenoPi/settings.json``` file contains parameters that can be set by the user to control the experiments. A sample file is located in ```XenoPi/settings.json.default```.

Description of the core parameters:

| Parameter        | Description | Example |
|------------------|-------------|---------|
| node_name        | Unique name to identify the module running the experiment | "nodepi-01" |
| session_name     | Unique name to identify the session/event during which the experiment took place | "isea-2020" |
| exposure_time    | Time during which each image is left on the petri dish before taking a new snapshot (seconds) | 300 |
| seed_image       | Type of image used as a seed (choices: random, euglenas) | "random" |
| n_feedback_steps | Number of self-loops the neural net does at each step | 4 |

## Launching

### Step 1 : Start the program(s)

The easiest way to start the program is to use the ```xeno_main.sh``` bash script.

```
cd ~/xenolalia
./bin/xeno_main.sh
```

Alternatively you can start the programs separately.
 1. Start the ```XenoPi``` program. It will start in calibration mode.
 2. Start the ```xeno_osc.py``` script with the appropriate parameters. Example: ```python3 xeno_osc.py -c results/model_sparse_conv_enc20-40_dec40-20_k5_b128.hdf5 -n 5```
 3. (Optional) Start the ```xeno_orbiter.py``` and the ```bin/prevent_sleep.sh``` programs.

### Step 2 : Calibration mode

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

### Step 3 : Check the conditions

**IMPORTANT** At this point you need to make sure to put the experimental setup in the same set of conditions as they will be running. Adjust light sources, close lids and curtains, etc. whatever you want your setup to be.

### Step 4 : Begin generation

Press the 'g' key to start the generative process.

## Switch to next experiment

While the script is running you can manually start a new experiment by pressing the 'n' key.

## Exiting

You can exit ```XenoPi``` with the ESC key. If you started the programs using ```xeno_main.sh``` you don't need to do anything else as the script will take care of killing the other programs.

## Key bindings

### Calibration mode

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

### Generative mode

| Key | Description | 
|:---:|-------------|
| SPACEBAR | Manually take a snapshot |
| f | Toggle flash screen (useful to look at what is happening on the petri dish) |
| v | Toggle camera view (live camera feed appears in the corner) |
| a | Toggle auto mode (\*) |
| n | Start new experiment |

(\*) In auto mode (default) snapshots will be taken at a regular pace as specified by the "exposure_time" setting. In manual mode (ie. non-auto mode) the user has the responsibility to manually take snapshots using the SPACEBAR.


# Xenodata

Xenodata provides an online interface to the generated contents.

The installation script will setup a hourly cron that will automatically upload all new generated contents.

To sync the contents manually:
```
sudo /etc/cron.hourly/xeno_sync_snapshots
```
The web-app can be access here: http://xenodata.sofianaudry.com/

# Troubleshooting

## Processing crashes with OpenGL errors

Make sure you have enough GPU memory by adding the following line to ```/boot/config.txt```:

```gpu_mem=320```

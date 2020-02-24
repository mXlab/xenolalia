# Raspberry Pi Configuration

## Specs

 * Board: Raspberry Pi Model 3 B+ Version 1.3
 * OS: Raspbian Stretch

Note: I was unable to get the Processing video libraries to work appropriately on a Raspberry Pi 4 (2G) w/ Rasbian Buster. I was also never able to boot the Pi 4 on Raspbian Stretch so I had to downgrade to a Pi 3.

## Installs

IMPORTANT: Do *not* install MiniConda as the Python3 version it installs (3.4) is incompatible with Keras. Use the default Python 3 version instead.

Troubleshooting: When running ```pip3 install``` if you get error "http.client.RemoteDisconnected: Remote end closed connection without response" just re-run the command until it works.

```
# Update/upgrade Debian packages
sudo apt update
sudo apt upgrade

# Install debian packages.
sudo apt install -y git git-gui
sudo apt install -y python3-dev python3-setuptools python3-h5py
sudo apt install -y libblas-dev liblapack-dev libatlas-base-dev gfortran
sudo apt install -y xdotool
sudo apt install -y python-virtualenv
sudo apt install -y software-properties-common dirmngr apt-transport-https lsb-release ca-certificates
sudo apt install -y liblo-tools liblo7
sudo apt install -y libjasper1 libqtgui4 libqt4-test # OpenCV

# Install python libraries.
# pip3 install pip3 --upgrade # DO NOT DO THIS
pip3 install keras tensorflow scipy numpy
pip3 install python-osc
pip3 install opencv-python scikit-image

# Install Processing
curl https://processing.org/download/install-arm.sh | sudo sh
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

Two programs are needed to run Xenolalia:
 1. Front-end: ```XenoPi``` Processing sketch. Manages the interaction between the camera and the screen.
 2. Back-end: ```xeno_osc.py``` Python script. Manages the image filtering and the autoencoder image generation.

To launch the process:
 1. Start the XenoPi program. It will start in calibration mode.
 2. Adjust the reference image.
     1. Click on the first corner to place the first control point.
     2. Press TAB to select the next control point; then click on the 2nd corner to place it.
     3. You can use the arrow keys to make small adjustments.
     4. Once you are satisfied, press ENTER: it will save the settings.json file.
     5. Then press the SPACEBAR.
 3. Adjust the input quad.
     1. Using the mouse and the same keys as for the previous step, adjust the four corners of the input quad to match the corners of the image picked by the camera, directly on the screen.
     2. You can select one of the four control points by pressing its number (1, 2, 3, 4).
     3. Once you are satisfied, press ENTER: it will save the settings.json file.
 4. Start the xeno_osc.py script with the appropriate parameters. Example: ```python3 xeno_osc.py -c results/model_sparse_conv_enc20-40_dec40-20_k5_b128.hdf5 -n 5```
 5. Once the xeno_osc.py script has launched and is initialized, press the 'g' key to start the generative process.

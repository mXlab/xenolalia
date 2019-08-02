# Raspberry Pi Raspbian configuration

## Specs

 * Board: Raspberry Pi Model 3 B+ Version 1.3
 * OS: Raspbian Stretch

Note: I was unable to get the Processing video libraries to work appropriately on a Raspberry Pi 4 (2G) w/ Rasbian Buster. I was also never able to boot the Pi 4 on Raspbian Stretch so I had to downgrade to a Pi 3.

## Installs

IMPORTANT: Do *not* install MiniConda as the Python3 version it installs (3.4) is incompatible with Keras. Use the default Python 3 version instead.

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

# Install python libraries.
# pip3 install pip3 --upgrade # DO NOT DO THIS
pip3 install keras tensorflow scipy numpy

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
IMPORTANT: run ```./MHS35-show``` and *not* ```./LCD35-show```

After rebooting your main screen will have a 480x320 resolution. To fix this edit the ```/boot/config.txt``` by replacing the ```hdmi_cvt``` directive with your choice resolution eg. ```hdmi_cvt 1920 1080 60 6 0 0 0```

To restore the system in case of a mistake you can run the ```system_restore.sh``` script provided with the LCD-Show library.

## Notes

 * Dual monitor: I could never get my second monitor to work on the Pi4, it kept displaying the rainbow colorwheel splash screen. Did not find a solution.

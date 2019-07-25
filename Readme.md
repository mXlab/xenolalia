# Raspberry Pi Raspbian configuration

## Specs
Raspberry Pi 4 (2G) w/ Rasbian Buster

## Packages

IMPORTANT: Do *not* install MiniConda as the Python3 version it installs (3.4) is incompatible with Keras. Use the default Python 3 version instead.

```
# Update/upgrade Debian packages
sudo apt update
sudo apt upgrade

# Install debian packages.
sudo apt install -y git git-gui
sudo apt install -y python3-dev python3-setuptools python3-h5py
sudo apt install -y libblas-dev liblapack-dev libatlas-base-dev gfortran
sudo apt install -y python-virtualenv

# Install python libraries.
pip install pip --upgrade
pip install keras tensorflow scipy numpy
```

## Notes

 * LCD screen: it seems impossible to rotate the screen with option "lcd_rotate=2" unless you are using specifically the RPi official touchscreen
 * Dual monitor: I could never get my second monitor to work, it kept displaying the rainbow colorwheel splash screen. Did not find a solution.

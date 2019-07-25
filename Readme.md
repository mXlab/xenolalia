# Raspberry Pi Raspbian configuration

## Specs
Raspberry Pi 4 (2G) w/ Rasbian Buster

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
sudo apt install -y python-virtualenv
sudo apt install -y software-properties-common dirmngr apt-transport-https lsb-release ca-certificates

# Install python libraries.
pip install pip --upgrade
pip install keras tensorflow scipy numpy
```

### Install FFMEG support for Gstreamer v4l

(WORK IN PROGRESS)

```
# Install packages for Debian multimedia
echo "deb http://www.deb-multimedia.org buster main non-free" >> /etc/apt/sources.list
wet http://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2016.8.1_all.deb
sudo dpkg -i deb-multimedia-keyring_2016.8.1_all.deb
sha256sum deb-multimedia-keyring_2016.8.1_all.deb
# Should return: 9faa6f6cba80aeb69c9bac139b74a3d61596d4486e2458c2c65efe9e21ff3c7d deb-multimedia-keyring_2016.8.1_all.deb
```

http://deb-multimedia.org/

### Processing libraries

Add the following libraries:
 * Video
 * GL VIdeo
 * OpenCV

## Notes

 * LCD screen: it seems impossible to rotate the screen with option "lcd_rotate=2" unless you are using specifically the RPi official touchscreen
 * Dual monitor: I could never get my second monitor to work, it kept displaying the rainbow colorwheel splash screen. Did not find a solution.

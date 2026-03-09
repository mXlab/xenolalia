#!/usr/bin/python

# Warning: This will display the perspective image on an RGB Matrix

import Image
import ImageDraw
import time
from rgbmatrix import Adafruit_RGBmatrix
import signal

PWM_BIT_DEPTH = 4

# This is the size of our encoded representations.
image_side = 28
image_dim = image_side*image_side

# Rows and chain length are both required parameters:
matrix = Adafruit_RGBmatrix(32, 1)
matrix.SetPWMBits(PWM_BIT_DEPTH)

image = Image.open("camera_perspective_reference.png")
image.load()
matrix.SetImage(image.im.id, 0, 0)
signal.pause()
matrix.Clear()

#!/usr/bin/python

import Image
import ImageDraw
import time
import os.path
from rgbmatrix import Adafruit_RGBmatrix

filename = "RgbMatrixDrawingTool/matrix.png"

# Rows and chain length are both required parameters:
matrix = Adafruit_RGBmatrix(32, 1)

# Bitmap example w/graphics prims
image = Image.new("1", (32, 32)) # Can be larger than matrix if wanted!!
draw  = ImageDraw.Draw(image)    # Declare Draw instance before prims

while True:
	print "Loading image"
	if os.path.isfile(filename):
		image = Image.open(filename)
		image.load()
		matrix.Clear();
		matrix.SetImage(image.im.id, 0, 0)
	time.sleep(5)

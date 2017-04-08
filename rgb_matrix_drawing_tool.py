#!/usr/bin/python

import Image
import ImageDraw
import time
from rgbmatrix import Adafruit_RGBmatrix

# Rows and chain length are both required parameters:
matrix = Adafruit_RGBmatrix(32, 1)

# Bitmap example w/graphics prims
image = Image.new("1", (32, 32)) # Can be larger than matrix if wanted!!
draw  = ImageDraw.Draw(image)    # Declare Draw instance before prims

while True:
	print "Loading image"
	image = Image.open("RgbMatrixDrawingTool/matrix.png")
	image.load()
	matrix.Clear();
	matrix.SetImage(image.im.id, 0, 0)
	time.sleep(5)

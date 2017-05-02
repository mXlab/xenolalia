#!/usr/bin/python

import Image
import ImageDraw
import time
import os
import os.path
from rgbmatrix import Adafruit_RGBmatrix

filename = "RgbMatrixDrawingTool/matrix.png"

# Rows and chain length are both required parameters:
matrix = Adafruit_RGBmatrix(32, 1)

# Bitmap example w/graphics prims
image = Image.new("1", (32, 32)) # Can be larger than matrix if wanted!!
draw  = ImageDraw.Draw(image)    # Declare Draw instance before prims

def modification_date(file):
	if os.path.isfile(filename):
		return time.ctime(os.stat(file)[8])
	else:
		return 0

last_moddate = 0

while True:
	moddate = modification_date(filename)
	if (moddate != last_moddate):
		print "Image updated: " + str(moddate)
		image = Image.open(filename)
		image.load()
		matrix.Clear();
		matrix.SetImage(image.im.id, 0, 0)
		last_moddate = moddate
	time.sleep(0.1)

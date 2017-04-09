import numpy as np
from keras.models import Model, load_model

import time
import math

from rgbmatrix import Adafruit_RGBmatrix
import Image
import ImageDraw

from xeno_camera import XenoCamera

USE_CAMERA = True

if (USE_CAMERA):
    FPS = 1
else:
    FPS = 10
INTERVAL = 1./FPS

MATRIX_PWM_BIT_DEPTH = 6
#MATRIX_WRITE_CYCLES =  1

MAX_RED   = 200
MAX_GREEN = 200
MAX_BLUE  = 200

PERSPECTIVE_CONF = "CameraPerspectiveConfig/camera_perspective.conf"

# This is the size of our encoded representations.
image_side = 28
image_dim = image_side*image_side

# create xeno camera
#input_quad = ( 0.35, 0.495, 0.65, 0.2675, 0.78125, 0.3525, 0.3421875, 0.6975 )
#input_quad = ( 0.4390625, 0.4525, 0.7640625, 0.2025, 0.8828125, 0.3325, 0.378125, 0.7075 )
with open(PERSPECTIVE_CONF, "rb") as f:
    input_quad = tuple([ float(v) for v in f.readlines() ])
print input_quad
cam = XenoCamera(input_quad, image_side=image_side)

# Adjust cam
cam.iso = 100
cam.constrast = 100
cam.sharpen = 100
time.sleep(2)
cam.exposure_mode = "off"

# Rows and chain length are both required parameters:
matrix = Adafruit_RGBmatrix(32, 1)
matrix.SetPWMBits(MATRIX_PWM_BIT_DEPTH)
#matrix.SetWriteCycles(MATRIX_WRITE_CYCLES)
matrix.Clear()

def channel(v, max):
    return int(round(v * max))

def calibrate():
    median = np.median(sample_frame(0))

def sample_frame(t):
    # take picture sample
    output = cam.sample()
    #output.save("img/output_{frame:03d}.png".format(frame=t))
    #cam.raw_sample().save("img/raw_output_{frame:03d}.png".format(frame=t))
    
    return np.asarray(output).reshape((1,image_dim))

def autoencoder_generate(n_steps, use_camera=False):
    
    # Iterate.
    for t in range(n_steps):

        print "t={t} ======".format(t=t)

        # special case for first frame (init)
        if (t == 0):
            if (use_camera):
                # take picture sample
                frame = sample_frame(t)
            else:
                # Generate first image as random.
                frame = np.random.random((1,image_dim))

        # non-starting frames (update)
        else:
            if (use_camera):
                # take picture sample
                frame = sample_frame(t)
            
            # generate next frame.
            frame = model.predict(frame)

        # display frame on led matrix
        f = frame.reshape(image_side, image_side)
        for x in range(image_side):
            for y in range(image_side):
                intensity = f[x, y]
                matrix.SetPixel(x+2, y+2, channel(intensity, MAX_RED), channel(intensity, MAX_GREEN), channel(intensity, MAX_BLUE))

        # wait
	time.sleep(INTERVAL)

filename = "autoencoder.hdf5"
#filename = "autoencoder.h5"
model = load_model(filename)

#cam.start()
autoencoder_generate(20, True)
#cam.stop()

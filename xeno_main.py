import numpy as np
from keras.models import Model, load_model

import time
import math

from rgbmatrix import Adafruit_RGBmatrix
import Image
import ImageDraw

from xeno_camera import XenoCamera

fps = 10
interval = 1./fps

PWM_BIT_DEPTH = 6

MAX_RED = 200
MAX_GREEN = 200
MAX_BLUE = 200

# This is the size of our encoded representations.
image_side = 28
image_dim = image_side*image_side

# create xeno camera
#input_quad = ( 0.35, 0.495, 0.65, 0.2675, 0.78125, 0.3525, 0.3421875, 0.6975 )
input_quad = ( 0.4390625, 0.4525, 0.7640625, 0.2025, 0.8828125, 0.3325, 0.378125, 0.7075 )
cam = XenoCamera(input_quad, image_side=image_side)

# Rows and chain length are both required parameters:
matrix = Adafruit_RGBmatrix(32, 1)
matrix.SetPWMBits(PWM_BIT_DEPTH)
matrix.Clear()

def channel(v, max):
    return int(round(v * max))

def sample_frame(t):
    # take picture sample
    output = cam.sample()
    output.save("img/output_{frame:03d}.png".format(frame=t))
    return np.asarray(output).reshape((1,image_dim))

def autoencoder_generate(n_steps, use_camera=False):
    
    # Iterate.
    for t in range(n_steps):

        if (t == 0):
            if (use_camera):
                # take picture sample
                frame = sample_frame(t)
            else:
                # Generate first image as random.
                frame = np.random.random((1,image_dim))
        else:
            if (use_camera):
                # take picture sample
                frame = sample_frame(t)
            
                # TODO: wait a little for organisms to settle
                time.sleep(1)

            # denerate next frame.
            frame = model.predict(frame)

        print "t={t} ======".format(t=t)
        # display frame on led matrix
        f = frame.reshape(image_side, image_side)
        for x in range(image_side):
            for y in range(image_side):
                intensity = f[x, y]
                matrix.SetPixel(x+2, y+2, channel(intensity, MAX_RED), channel(intensity, MAX_GREEN), channel(intensity, MAX_BLUE))
        
	time.sleep(interval)

filename = "autoencoder.hdf5"
#filename = "autoencoder.h5"
model = load_model(filename)

#cam.start()
autoencoder_generate(20, True)
#cam.stop()

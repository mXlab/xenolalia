import argparse

parser = argparse.ArgumentParser()
parser.add_argument("model_file", type=str, help="The file containing the trained model")

parser.add_argument("-f", "--fps", type=float, default=10, help="Frames per second")
parser.add_argument("-d", "--duration", type=float, default=10, help="Duration (in seconds)")

args = parser.parse_args()
import numpy as np
from keras.models import Model, load_model

import time
import math

from rgbmatrix import Adafruit_RGBmatrix
import Image
import ImageDraw

fps = args.fps
interval = 1./fps
n_frames = int(args.duration * fps)

PWM_BIT_DEPTH = 6

MAX_RED = 200
MAX_GREEN = 200
MAX_BLUE = 200

# This is the size of our encoded representations.
image_side = 28
image_dim = image_side*image_side

# Rows and chain length are both required parameters:
matrix = Adafruit_RGBmatrix(32, 1)
matrix.SetPWMBits(PWM_BIT_DEPTH)
matrix.Clear()

def channel(v, max):
    return int(round(v * max))

def autoencoder_generate(n_steps):
    # Generate first image as random.
    frame = np.random.random((1,image_dim))

    # Iterate.
    for t in range(n_steps):

        f = frame.reshape(image_side, image_side)
        for x in range(image_side):
            for y in range(image_side):
                intensity = f[x, y]
                matrix.SetPixel(x+2, y+2, channel(intensity, MAX_RED), channel(intensity, MAX_GREEN), channel(intensity, MAX_BLUE))

        # Generate next frame.
        frame = model.predict(frame)

	time.sleep(interval)

model = load_model(args.model_file)

autoencoder_generate(n_frames)

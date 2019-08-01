import numpy as np
from keras.models import Model, load_model

import os
import time
import math
import argparse

from xeno_camera import XenoCamera

USE_RPI = os.uname()[4].startswith('arm')

parser = argparse.ArgumentParser()
parser.add_argument("-o", "--output-file", type=str, default="snapshot.png", help="Output file name for camera snapshot")
parser.add_argument("-c", "--configuration-file", type=str, default="CameraPerspectiveConfig/camera_perspective.conf", help="Configuration file containing input quad")
parser.add_argument("-q", "--input-quad", type=str, default=None, help="Comma-separated list of numbers defining input quad (overrides configuration file)")
parser.add_argument("-b", "--bypass-camera", default=False, action='store_true', help="Bypass camera")

# Platform-specific options
if USE_RPI:
    parser.add_argument("-m", "--use-led-matrix", default=False, action='store_true', help="Use LED matrix for display")
else:
    parser.add_argument("-d", "--device-id", type=int, default=0, help="The video device ID")

args = parser.parse_args()

# Load input quad
if (args.input_quad != None):
    input_quad = tuple([ float(x) for x in args.input_quad.split(',') ])
else:
    with open(args.configuration_file, "rb") as f:
        input_quad = tuple([ float(v) for v in f.readlines() ])

OUTPUT = "screen" # or "matrix" to use LED matrix

FLASH_INTENSITY = 0.25

INTERACTIVE = False

OUTPUT_SCREEN_RESOLUTION = (480, 640)
OUTPUT_SCREEN_CHANNELS = (480, 640, 3)
#OUTPUT_SCREEN_RESOLUTION = (640, 480)
#OUTPUT_SCREEN_CHANNELS = (640, 480, 3)
OUTPUT_RESOLUTION = (320, 320)

USE_LED_MATRIX = False
if USE_RPI:
    if args.use_led_matrix:
        USE_LED_MATRIX = True

if USE_LED_MATRIX:
    from rgbmatrix import Adafruit_RGBmatrix
    import Image
    import ImageDraw
else:
    import cv2

if (args.bypass_camera):
    INTERVAL = 0.1 # 10 fps
else:
    INTERVAL = 30
    FLASH = 1

MATRIX_PWM_BIT_DEPTH = 6
#MATRIX_WRITE_CYCLES =  1

MAX_RED   = 200
MAX_GREEN = 200
MAX_BLUE  = 200

# This is the size of our encoded representations.
image_side = 28
image_dim = image_side*image_side

# Create camera object
if USE_RPI:
	cam = XenoCamera(input_quad=input_quad)
else:
	cam = XenoCamera(input_quad=input_quad, device_id=args.device_id)

if USE_LED_MATRIX:
    # Rows and chain length are both required parameters:
    matrix = Adafruit_RGBmatrix(32, 1)
    matrix.SetPWMBits(MATRIX_PWM_BIT_DEPTH)
    #matrix.SetWriteCycles(MATRIX_WRITE_CYCLES)
    matrix.Clear()
else:
    #pass
    #cv2.startWindowThread()
    #cv2.namedWindow("output", cv2.WINDOW_AUTOSIZE)
    cv2.namedWindow("output", cv2.WND_PROP_FULLSCREEN)
    #cv2.moveWindow("output", 0, -3000)
    #cv2.setWindowProperty("output", cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

def channel(v, max):
    return int(round(v * max))

def calibrate():
    median = np.median(sample_frame(0))

def sample_frame(t):
    if (not USE_LED_MATRIX):
        # Flash
        print("FLASH!")
        display_image(np.ones((image_side,image_side,3), np.uint8)*FLASH_INTENSITY*255)
        time.sleep(FLASH)

    # take picture sample
    output = cam.sample()
    output.resize(OUTPUT_RESOLUTION).save("img/output_{frame:03d}.png".format(frame=t))
    #cam.raw_sample().save("img/raw_output_{frame:03d}.png".format(frame=t))

    return np.asarray(output).reshape((1,image_dim))

def display_image(img, waitForKey=False):
    # Resize image.
    img = cv2.resize(img, dsize=OUTPUT_RESOLUTION, interpolation=cv2.INTER_CUBIC)

    # Create larger black-background and fit image inside.
    display_img = np.zeros(OUTPUT_SCREEN_CHANNELS, np.uint8)
    i = int(0.5 * (OUTPUT_SCREEN_RESOLUTION[0] - OUTPUT_RESOLUTION[0]))
    j = int(0.5 * (OUTPUT_SCREEN_RESOLUTION[1] - OUTPUT_RESOLUTION[1]))
    display_img[i:i+OUTPUT_RESOLUTION[0], j:j+OUTPUT_RESOLUTION[1]] = img

    # Display.
    cv2.imshow("output", display_img)
    if (waitForKey):
        cv2.waitKey(0)
    else:
        cv2.waitKey(10)

def autoencoder_generate(n_steps, use_camera=False):

    # Iterate.
    for t in range(n_steps):

        print("t={t} ======".format(t=t))

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
        if USE_LED_MATRIX:
            for x in range(image_side):
                for y in range(image_side):
                    intensity = f[x, y]
                    matrix.SetPixel(x+2, y+2, channel(intensity, MAX_RED), channel(intensity, MAX_GREEN), channel(intensity, MAX_BLUE))
            # wait
            time.sleep(INTERVAL)
        else:
            img = np.zeros((image_side,image_side,3), np.uint8)
            for x in range(image_side):
                for y in range(image_side):
                    intensity = f[x, y]
                    if (intensity > 0.5):
                        img[x, y] = (255, 255, 255)
                    else:
                        img[x, y] = (0, 0, 255) # Red background
            #print(img)
            #img = cv2.imread("test.png")
            print("OUTPUT!")
            display_image(img, INTERACTIVE)
            time.sleep(INTERVAL)

filename = "autoencoder.hdf5"
#filename = "autoencoder.h5"
model = load_model(filename)

INIT = False

# First send a reference image
img = np.ones((image_side,image_side, 3), np.uint8)*255
imgIn = np.zeros((image_side-2,image_side-2, 3), np.uint8)
img[1:image_side-1,1:image_side-1] = imgIn
display_image(img, True)

if (not INIT):
    cam.start()
    autoencoder_generate(10, not args.bypass_camera)
    cam.stop()

import numpy as np

import os
import os.path
import sys
import signal
import time
import math
import argparse

from pythonosc import dispatcher
from pythonosc import osc_server

from pythonosc import osc_message_builder
from pythonosc import udp_client

from PIL import Image, ImageOps

import xeno_image

USE_RPI = os.uname()[4].startswith('arm')

parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument("model_file", type=str, help="Model filename (hdf5)")

parser.add_argument("-c", "--convolutional", default=False, action='store_true', help="Use convolutional autoencoder")
parser.add_argument("-C", "--configuration-file", type=str, default="XenoPi/camera_perspective.conf", help="Configuration file containing input quad")
parser.add_argument("-q", "--input-quad", type=str, default=None, help="Comma-separated list of numbers defining input quad (overrides configuration file)")
parser.add_argument("-n", "--n-steps", type=int, default=1, help="Number of self-loop steps for each image")
parser.add_argument("-D", "--output-directory", type=str, default=".", help="Output directory for generative images")

parser.add_argument("-i", "--ip", default="127.0.0.1",
                    help="Specify the ip address to send data to.")
parser.add_argument("-s", "--send-port", default="7001",
                    type=int, help="Specify the port number to send data to.")
parser.add_argument("-r", "--receive-port", default="7000",
                    type=int, help="Specify the port number to listen on.")

args = parser.parse_args()

from keras.models import Model, load_model

# Load input quad
if (args.input_quad != None):
    input_quad = tuple([ float(x) for x in args.input_quad.split(',') ])
else:
    print("open config file")
    with open(args.configuration_file, "rb") as f:
        input_quad = tuple([ float(v) for v in f.readlines() ])

print(input_quad)

# This is the size of our encoded representations.
image_side = 28
image_dim = image_side*image_side

if args.convolutional:
    input_shape = (1, image_side, image_side, 1)
else:
    input_shape = (1, image_dim)

n_steps = args.n_steps

# Generates frame from starting frame.
def generate(n_steps, starting_frame=None):
    global input_shape

    # Iterate.
    for t in range(n_steps):

        print("t={t} ======".format(t=t))

        # special case for first frame (init)
        if t == 0:
            if starting_frame is None:
                # Generate first image as random.
                frame = np.random.random(input_shape)
            else:
                frame = starting_frame

        # generate next frame.
        frame = model.predict(frame)

    return frame

def next_image(image_path, starting_frame_random):
    global n_steps, input_quad, input_shape, image_side

    dirname = os.path.dirname(image_path)
    basename = os.path.splitext(os.path.basename(image_path))[0]

    if starting_frame_random:
        starting_frame = None
    else:
        starting_image, filtered_image, transformed_image = xeno_image.load_image(image_path, image_side, input_quad)
        starting_frame = xeno_image.image_to_array(starting_image, input_shape)
        transformed_image.save("{}/{}_0trn.png".format(dirname, basename))
        filtered_image.save("{}/{}_1fil.png".format(dirname, basename))
        starting_image.save("{}/{}_2res.png".format(dirname, basename))
    # Generate new image.
    frame = generate(n_steps, starting_frame)
    image = xeno_image.array_to_image(frame, image_side, image_side)
#    image = Image.fromarray(frame.reshape((image_side, image_side)) * 255.0).convert('L')
    # Save image to path.
    nn_image_path = "{}/{}_3ann.png".format(dirname, basename)
    image.save(nn_image_path)
    # Return back OSC message.
    client.send_message("/xeno/neurons/step", [nn_image_path])

def handle_step(addr, image_path):
    next_image(image_path, False)

def handle_begin(addr, image_path):
    next_image(image_path, True)

# Load model.
model = load_model(args.model_file)

# Create OSC dispatcher.
dispatcher = dispatcher.Dispatcher()
dispatcher.map("/xeno/euglenas/step", handle_step)
dispatcher.map("/xeno/euglenas/begin", handle_begin)

# Launch OSC server & client.

server = osc_server.BlockingOSCUDPServer(("0.0.0.0", args.receive_port), dispatcher)
client = udp_client.SimpleUDPClient(args.ip, args.send_port)

def interrupt(signup, frame):
    global client, server
    print("Exiting program... {np.mean(perf_measurements)}")
    client.send_message("/xeno/neurons/end", [])
    server.server_close()
    sys.exit()

signal.signal(signal.SIGINT, interrupt)

print("Serving on {server.server_address}. Program ready.")
#client.send_message("/xeno/neurons/begin", [])
#if args.use_robot:
#    time.sleep(10) # Give time to the robot to do its starting sequence
#print("Go!")

server.serve_forever()

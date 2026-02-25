import numpy as np

import os
import os.path
import sys
import signal
import time
import math
import argparse
import json

from pythonosc import dispatcher
from pythonosc import osc_server

from pythonosc import osc_message_builder
from pythonosc import udp_client

from PIL import Image, ImageOps

import xeno_image

USE_RPI = os.uname()[4].startswith('arm')

parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument("-C", "--configuration-file", type=str, default="XenoPi/settings.json", help="Configuration file containing camera input quad")
parser.add_argument("-M", "--model-directory", type=str, default="results", help="Directory where to find model files")

parser.add_argument("-ix", "--xenopi-ip", default="127.0.0.1",
                    help="The IP address where the XenoPi program runs.")
parser.add_argument("-sx", "--xenopi-send-port", default="7001",
                    type=int, help="The port number used to send data to XenoPi.")

parser.add_argument("-ie", "--orbiter-ip", default="127.0.0.1",
                    help="The IP address where the orbiter program runs.")
parser.add_argument("-se", "--orbiter-send-port", default="7002",
                    type=int, help="The port number used to send data to the orbiter.")

parser.add_argument("-is", "---server-ip", default="192.168.0.100",
                    help="The IP address where the server program runs.")
parser.add_argument("-ss", "--server-send-port", default="7000",
                    type=int, help="The port number used to send data to the server.")

parser.add_argument("-r", "--receive-port", default="7000",
                    type=int, help="The port number to listen on.")

args = parser.parse_args()

from keras.models import Model, load_model

# Load calibration settings from .json file.
def load_settings():
    import json
    global args, data, input_quad, n_feedback_steps, use_base_image, \
           use_convolutional, model_name, encoder_layer, \
           output_size, output_line_width, output_threshold, output_area_max
    print("Loading settings")
    with open(args.configuration_file, "r") as f:
        data = json.load(f)
        print(data)

        input_quad = tuple( data['camera_quad'] )
        n_feedback_steps = data['n_feedback_steps']
        use_base_image = data['use_base_image']
        use_convolutional = data['use_convolutional']
        encoder_layer = data['encoder_layer']
        model_name = data['model_name']
        # Post-processing settings (all optional, with safe defaults).
        output_size       = int(data.get('output_size',       224))
        output_line_width = int(data.get('output_line_width', 2))
        output_threshold  = float(data.get('output_threshold', 0.5))
        output_area_max   = data.get('output_area_max', None)
        if output_area_max is not None:
            output_area_max = float(output_area_max)

# Defaults — overwritten by load_settings().
output_size       = 224
output_line_width = 2
output_threshold  = 0.5
output_area_max   = None

# Load settings.
load_settings()

# This is the size of our encoded representations.
image_side = 28
image_dim = image_side*image_side

# Adjust input shape if suing convolutional network.
if use_convolutional:
    input_shape = (1, image_side, image_side, 1)
else:
    input_shape = (1, image_dim)

# Returns true iff frame contains enough pixels but not too much
def validate(frame, min=0.1, max=0.9):
    # Compute average.
    return min <= np.average(frame) <= max

def generate_random():
    global input_shape, image_side

    # Generate random frame.
    frame = np.random.random(input_shape)

    # Convert to image.
    image = xeno_image.array_to_image(frame, image_side, image_side)

    # Add mask.
    image = xeno_image.add_mask(image, True) # mask is inverted

    # Convert back to frame.
    return xeno_image.image_to_array(image, input_shape)

# Generates frame from starting frame mixed with previous frame.
def generate_merge(n_steps, starting_frame, prev_frame):
    if n_steps <= 0:
        return prev_frame
    else:
        frame = np.maximum(starting_frame, prev_frame)
        for t in range(n_steps-1):
            encoded, frame = model.predict(frame)
        return encoded, frame

# Generates frame from starting frame.
def generate(n_steps, starting_frame, prev_frame):
    global input_shape, seed_image

    while True:
        # Iterate.
        for t in range(n_steps):

            print("t={t} ======".format(t=t))

            # special case for first frame (init)
            if t == 0:
                if starting_frame is None:
                    # Generate first image as random.
                    frame = generate_random()
                else:
                    frame = starting_frame

            # generate next frame.
            encoded, frame = model.predict(frame)

        # See if frame validates.
        if validate(frame):
            print("Validated")
            break
        # Needs more time, just keep projecting.
        elif starting_frame is not None:
            print("Not validated : trying merge")
            encoded, frame = generate_merge(n_steps, starting_frame, prev_frame)
            if validate(frame):
                print("Validated")
            else:
                print("Not validated : resend")
                frame = prev_frame
            break

    return encoded, frame

# Broadcast message.
def send_message(addr, data=[], client=False):
    if client:
        client.send_message(addr, data)
    else:
        xenopi_client.send_message(addr, data)
        orbiter_client.send_message(addr, data)

def save_encoded_json(
    activations,
    filepath,
    normalize=True,
    precision=6
):
    """
    Save convolutional encoder activations to a minimal JSON format:
    {
      "shape": [H, W, C],
      "channels": [ HxW arrays, one per channel ]
    }
    """

    # Remove batch dimension if present
    if activations.ndim == 4:
        activations = activations[0]

    # activations: (H, W, C)
    H, W, C = activations.shape

    if normalize:
        # Normalize per channel using vectorized operations
        mins = activations.min(axis=(0, 1), keepdims=True)
        maxs = activations.max(axis=(0, 1), keepdims=True)
        activations = (activations - mins) / (maxs - mins + 1e-8)

    # Reorder to (C, H, W) for channel-major export
    channels = np.transpose(activations, (2, 0, 1))

    # Round and convert to native Python lists
    channels = np.round(channels, precision).tolist()

    with open(filepath, "w") as f:
        json.dump(channels, f, indent=2)
    
# Processes next image based on image path and sends an OSC message back to the XenoPi program.
# At each step, this function will save the following images:
# - (basename)_0trn.png : transformed image
# - (basename)_1fil.png : filtered image
# - (basename)_2res.png : original starting point image
# - (basename)_3ann.png : image generated by the autoencoder
# - (basename)_code.png : features generated by the encoder (encoded as json array)
def next_image(image_path, base_image_path, starting_frame_random):
    global n_feedback_steps, input_quad, input_shape, image_side, use_base_image, prev_frame, \
           output_size, output_line_width, output_threshold, output_area_max

    dirname = os.path.dirname(image_path)
    basename = os.path.splitext(os.path.basename(image_path))[0]

    if starting_frame_random:
        starting_frame = None
        prev_frame = None
    else:
        if not use_base_image:
            base_image_path = False

        starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(image_path, base_image_path, image_side, input_quad)
        starting_frame = xeno_image.image_to_array(starting_image, input_shape)
        transformed_image.save("{}/{}_0trn.png".format(dirname, basename))
        filtered_image.save("{}/{}_1fil.png".format(dirname, basename))
        starting_image.save("{}/{}_2res.png".format(dirname, basename))
    # Generate new image.
    encoded, frame = generate(n_feedback_steps, starting_frame, prev_frame)
    prev_frame = np.copy(frame)
    image = xeno_image.array_to_image(frame, image_side, image_side)
    image = xeno_image.postprocess_output(
        image,
        output_size=output_size,
        threshold=output_threshold,
        line_width=output_line_width,
        area_max=output_area_max,
    )
    # Save image to path.
    nn_image_path = "{}/{}_3ann.png".format(dirname, basename)
    image.save(nn_image_path)
    # Save encoded data.
    save_encoded_json(encoded, "{}/{}_code.json".format(dirname, basename))
    # Return back OSC message.
    send_message("/xeno/neurons/step", [nn_image_path])

# Handler for new experiment..
def handle_new(addr):
    send_message("/xeno/neurons/new")

# Handler for first image step.
def handle_begin(addr, image_path, base_image_path):
    next_image(image_path, base_image_path, True)

# Handler for one image step.
def handle_step(addr, image_path, base_image_path):
    next_image(image_path, base_image_path, False)

# Handler for XenoPi handshake.
def handle_handshake(addr):
    send_message("/xeno/neurons/handshake",client=xenopi_client)

# Handler for settings updated.
def handle_settings_updated(addr):
    load_settings()

# Handler for camera test.
def handle_test_camera(addr, image_path):
    global input_quad, image_side
    dirname = os.path.dirname(image_path)
    basename = os.path.splitext(os.path.basename(image_path))[0]
    starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(image_path, False, image_side, input_quad)
    transformed_image_path = "{}/{}_0trn.png".format(dirname, basename)
    transformed_image.save(transformed_image_path.format(dirname, basename))
    filtered_image.save("{}/{}_1fil.png".format(dirname, basename))
    starting_image.save("{}/{}_2res.png".format(dirname, basename))
    send_message("/xeno/neurons/test-camera", [transformed_image_path], client=xenopi_client)

# Load model.
model_file = "{}/{}.hdf5".format(args.model_directory, model_name)
autoencoder_model = load_model(model_file)
model = Model(
    inputs = autoencoder_model.input,
    outputs = [
        autoencoder_model.layers[encoder_layer].output, # encoder activations
        autoencoder_model.output # decoder activations
    ]
)

# Create OSC dispatcher.
dispatcher = dispatcher.Dispatcher()
dispatcher.map("/xeno/euglenas/new", handle_new)
dispatcher.map("/xeno/euglenas/begin", handle_begin)
dispatcher.map("/xeno/euglenas/step", handle_step)
dispatcher.map("/xeno/euglenas/handshake", handle_handshake)
dispatcher.map("/xeno/euglenas/settings-updated", handle_settings_updated)
dispatcher.map("/xeno/euglenas/test-camera", handle_test_camera)

# Launch OSC server & client.
server = osc_server.BlockingOSCUDPServer(("0.0.0.0", args.receive_port), dispatcher)
xenopi_client = udp_client.SimpleUDPClient(args.xenopi_ip, args.xenopi_send_port)
orbiter_client = udp_client.SimpleUDPClient(args.orbiter_ip, args.orbiter_send_port)

# Allows program to end cleanly on a CTRL-C command.
def interrupt(signup, frame):
    global xenopi_client, orbiter_client, server
    # print("Exiting program... {}".format(np.mean(perf_measurements)))
    send_message("/xeno/neurons/end")
    server.server_close()
    sys.exit()

signal.signal(signal.SIGINT, interrupt)

# Indicates that server is ready.
print("Serving on {}. Program ready. You can now start XenoPi generative mode.".format(server.server_address))
send_message("/xeno/neurons/begin")

server.serve_forever()

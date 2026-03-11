import numpy as np

import logging
import os
import os.path
import sys
import signal
import time
import math
import argparse
import traceback
import json

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S',
)
log = logging.getLogger(__name__)

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
    global args, data, input_quad, n_feedback_steps, use_base_image, \
           use_convolutional, model_name, encoder_layer, \
           output_size, output_stroke_width, output_boundary_px, output_threshold, output_area_max, \
           squircle_mode, visibility_threshold_cv, visibility_threshold_human
    log.info("Loading settings")
    with open(args.configuration_file, "r") as f:
        data = json.load(f)
        log.debug(str(data))

        input_quad = tuple( data['camera_quad'] )
        n_feedback_steps = data['n_feedback_steps']
        use_base_image = data['use_base_image']
        use_convolutional = data['use_convolutional']
        encoder_layer = data['encoder_layer']
        model_name = data['model_name']
        # Post-processing settings (all optional, with safe defaults).
        output_size         = int(data.get('output_size',         224))
        output_stroke_width = int(data.get('output_stroke_width', 20))
        output_boundary_px  = int(data.get('output_boundary_px',  22))
        output_threshold    = float(data.get('output_threshold',  0.5))
        output_area_max     = data.get('output_area_max', None)
        if output_area_max is not None:
            output_area_max = float(output_area_max)
        if 'squircle_mode' in data:
            squircle_mode = str(data['squircle_mode'])
        elif data.get('use_squircle', False):
            squircle_mode = "inside"
        else:
            squircle_mode = "none"
        visibility_threshold_cv    = float(data.get('visibility_threshold_cv',    0.1))
        visibility_threshold_human = float(data.get('visibility_threshold_human', 0.3))

# Defaults — overwritten by load_settings().
output_size                = 224
output_stroke_width        = 20
output_boundary_px         = 22
output_threshold           = 0.5
output_area_max            = None
squircle_mode              = "none"
visibility_threshold_cv    = 0.1
visibility_threshold_human = 0.3

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
        return None, prev_frame
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

            log.debug("t={t} ======".format(t=t))

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
            log.info("Validated")
            break
        # Needs more time, just keep projecting.
        elif starting_frame is not None:
            log.info("Not validated : trying merge")
            encoded, frame = generate_merge(n_steps, starting_frame, prev_frame)
            if validate(frame):
                log.info("Validated")
            else:
                log.info("Not validated : resend")
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

    # Reorder to (C, H, W) for channel-major export
    channels = np.transpose(activations, (2, 0, 1))

    # Round and convert to native Python lists
    channels = np.round(channels, precision).tolist()

    with open(filepath, "w") as f:
        json.dump(channels, f, indent=2)
    
def save_code_signature(encoded, filepath, n_bins=40, precision=4):
    """Save a compact code signature of encoder activations to a JSON file.

    For convolutional encoders (3-D output H×W×C): one bin per channel,
    summarising the H×W spatial values with per-channel min/max/avg.
    For dense encoders (1-D output): splits the flattened vector into n_bins
    equal-sized bins and computes per-bin min/max/avg.
    The format is intentionally open-ended: vector length and structure may
    vary across signature types.
    """
    if encoded is None:
        return
    # Remove batch dim if present.
    arr = (encoded[0] if encoded.ndim == 4 else encoded).astype(np.float32)
    # Normalize globally to [0, 1].
    vmin, vmax = arr.min(), arr.max()
    if vmax > vmin:
        arr = (arr - vmin) / (vmax - vmin)
    def _r(v): return round(float(v), precision)
    if arr.ndim == 3:
        # Convolutional: shape (H, W, C) — one bin per channel.
        H, W, C = arr.shape
        spatial = arr.reshape(H * W, C)  # (H*W, C)
        def _peak(ch_map):
            vmax = ch_map.max()
            rows, cols = np.where(ch_map == vmax)
            return [int(round(rows.mean())), int(round(cols.mean()))]
        peak_rc = [_peak(arr[:, :, c]) for c in range(C)]
        data = {
            "model": model_name,
            "encoder_layer": encoder_layer,
            "encoder_shape": list(arr.shape),
            "n_values": int(arr.size),
            "min":  [_r(v) for v in spatial.min(axis=0)],
            "max":  [_r(v) for v in spatial.max(axis=0)],
            "avg":  [_r(v) for v in spatial.mean(axis=0)],
            "std":  [_r(v) for v in spatial.std(axis=0)],
            "q25":  [_r(v) for v in np.percentile(spatial, 25, axis=0)],
            "q50":  [_r(v) for v in np.percentile(spatial, 50, axis=0)],
            "q75":  [_r(v) for v in np.percentile(spatial, 75, axis=0)],
            "peak": peak_rc,
        }
    else:
        # Dense: split flat vector into n_bins equal-sized bins.
        flat = arr.flatten()
        bins = np.array_split(flat, n_bins)
        data = {
            "model": model_name,
            "encoder_layer": encoder_layer,
            "encoder_shape": list(arr.shape),
            "n_values": int(flat.size),
            "min":  [_r(b.min())  for b in bins],
            "max":  [_r(b.max())  for b in bins],
            "avg":  [_r(b.mean()) for b in bins],
            "std":  [_r(b.std())  for b in bins],
            "q25":  [_r(np.percentile(b, 25)) for b in bins],
            "q50":  [_r(np.percentile(b, 50)) for b in bins],
            "q75":  [_r(np.percentile(b, 75)) for b in bins],
        }
    with open(filepath, "w") as f:
        json.dump(data, f, indent=2)

# Processes next image based on image path and sends an OSC message back to the XenoPi program.
# At each step, this function will save the following images:
# - (basename)_0trn.png : transformed image
# - (basename)_1fil.png : filtered image
# - (basename)_2res.png : original starting point image
# - (basename)_3ann.png : image generated by the autoencoder
# - (basename)_code.png : features generated by the encoder (encoded as json array)
def next_image(image_path, base_image_path, starting_frame_random):
    global n_feedback_steps, input_quad, input_shape, image_side, use_base_image, prev_frame, \
           output_size, output_stroke_width, output_boundary_px, output_threshold, output_area_max, \
           squircle_mode, visibility_threshold_cv, visibility_threshold_human

    dirname = os.path.dirname(image_path)
    basename = os.path.splitext(os.path.basename(image_path))[0]

    if starting_frame_random:
        starting_frame = None
        prev_frame = None
    else:
        if not use_base_image:
            base_image_path = False

        starting_image, filtered_image, ___, ___, transformed_image, raw_transformed = xeno_image.load_image(image_path, base_image_path, image_side, input_quad, squircle_mode=squircle_mode)
        starting_frame = xeno_image.image_to_array(starting_image, input_shape)
        raw_transformed.save("{}/{}_col.png".format(dirname, basename))
        if base_image_path:
            base_img = Image.open(base_image_path)
            base_tf  = xeno_image.transform(base_img.convert('L'), input_quad)
            xeno_image.remove_base_natural(raw_transformed, base_tf).save("{}/{}_bsb.png".format(dirname, basename))
        transformed_image.save("{}/{}_0trn.png".format(dirname, basename))
        filtered_image.save("{}/{}_1fil.png".format(dirname, basename))
        starting_image.save("{}/{}_2res.png".format(dirname, basename))
        # Compute and broadcast visibility class (correlation with previous projected glyph).
        vis_class = xeno_image.compute_visibility(
            starting_image,
            raw_image=raw_transformed,
            projected=prev_frame,
            threshold_cv=visibility_threshold_cv,
            threshold_human=visibility_threshold_human,
        )
        send_message("/xeno/neurons/visibility", [vis_class], client=xenopi_client)
    # Generate new image.
    encoded, frame = generate(n_feedback_steps, starting_frame, prev_frame)
    prev_frame = np.copy(frame)
    # Save raw AE output (before postprocessing).
    image = xeno_image.array_to_image(frame, image_side, image_side)
    image.save("{}/{}_3ann.png".format(dirname, basename))
    # Postprocess: distance transform, threshold, stroke widening.
    image = xeno_image.postprocess_output(
        image,
        output_size=output_size,
        threshold=output_threshold,
        stroke_width=output_stroke_width,
        boundary_px=output_boundary_px,
        area_max=output_area_max,
    )
    # Squircle remapping: map square output to circular disc for projection.
    if squircle_mode == "inside":
        image = xeno_image.to_circle_inside(image)
    elif squircle_mode == "outside":
        image = xeno_image.to_circle_outside(image)
    # Save postprocessed projected image.
    nn_image_path = "{}/{}_4prj.png".format(dirname, basename)
    image.save(nn_image_path)
    # Save encoded data (only when encoder output is available).
    if encoded is not None:
        save_encoded_json(encoded, "{}/{}_code.json".format(dirname, basename))
        save_code_signature(encoded, "{}/{}_code_signature.json".format(dirname, basename))
    # Return back OSC message.
    send_message("/xeno/neurons/step", [nn_image_path])

# Handler for new experiment..
def handle_new(addr):
    send_message("/xeno/neurons/new")

# Handler for first image step.
def handle_begin(addr, image_path, base_image_path):
    try:
        next_image(image_path, base_image_path, True)
    except Exception as e:
        traceback.print_exc()

# Handler for one image step.
def handle_step(addr, image_path, base_image_path):
    try:
        next_image(image_path, base_image_path, False)
    except Exception as e:
        traceback.print_exc()

# Handler for XenoPi handshake.
def handle_handshake(addr):
    send_message("/xeno/neurons/handshake",client=xenopi_client)

# Handler for settings updated.
def handle_settings_updated(addr):
    load_settings()

# Handler for camera test.
def handle_test_camera(addr, image_path):
    global input_quad, image_side, squircle_mode
    dirname = os.path.dirname(image_path)
    basename = os.path.splitext(os.path.basename(image_path))[0]
    starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(image_path, False, image_side, input_quad, squircle_mode=squircle_mode)
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
log.info("Serving on {}. Program ready. You can now start XenoPi generative mode.".format(server.server_address))
send_message("/xeno/neurons/begin")

server.serve_forever()

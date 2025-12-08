import numpy as np

import os
import os.path
import sys
import signal
import argparse

from subprocess import Popen, PIPE

from pythonosc import dispatcher
from pythonosc import osc_server

from pythonosc import osc_message_builder
from pythonosc import udp_client

from xeno_video import experiment_to_gif

parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument("-u", "--xenopi-username", default="pi",
                    help="The username for the xeno Pi.")
parser.add_argument("-p", "--xenopi-password", default="xenolalia",
                    help="The password for the xeno Pi.")
parser.add_argument("-dx", "--xenopi-snapshots-dir", default="/home/pi/xenolalia/XenoPi/snapshots",
                    help="Path to XenoPi snapshots folder.")

parser.add_argument("-dl", "--local-snapshots-dir", default="./contents",
                    help="Path to local snapshots folder.")

parser.add_argument("-ix", "--xenopi-ip", default="192.168.0.101",
                    help="The IP address where the XenoPi program runs.")
parser.add_argument("-sx", "--xenopi-send-port", default="7001",
                    type=int, help="The port number used to send data to XenoPi.")

parser.add_argument("-im", "---macroscope-ip", default="127.0.0.1",
                    help="The IP address where the macroscope program runs.")
parser.add_argument("-sm", "--macroscope-send-port", default="7001",
                    type=int, help="The port number used to send data to the macroscope.")

parser.add_argument("-r", "--receive-port", default="7000",
                    type=int, help="The port number to listen on.")

args = parser.parse_args()

# Broadcast message.
def send_message(addr, data=[], client=False):
    if client:
        client.send_message(addr, data)
    else:
        xenopi_client.send_message(addr, data)
        macroscope_client.send_message(addr, data)

def xenopi_experiment_path(uid):
    return "{}/{}".format(args.xenopi_snapshots_dir, uid)

def local_experiment_path(uid):
    return "{}/{}".format(args.local_snapshots_dir, uid)

# Performs a recursive rsync from source (on XenoPi) to destination (on local host)
def rsync(src_dir, dst_dir):
    # Build commandline.
    cmd = "/usr/bin/rsync -ratlz\
        --rsh=\"/usr/bin/sshpass -p {password} \
        ssh -o StrictHostKeyChecking=no -l {username}\" \
        {xenopi_ip}:{src_dir} {dst_dir}".format(
            password=args.xenopi_password, username=args.xenopi_username, 
            xenopi_ip=args.xenopi_ip, src_dir=src_dir.rstrip("/") + "/", dst_dir=dst_dir)

    # Execute command
    p = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
    stdout, stderr = p.communicate()  # block until finished
    
    # Check return code
    if p.returncode != 0:
        print("rsync failed with return code:", p.returncode)
        print("Error output:", stderr.decode())

    return p.returncode
    
def fetch_experiment(uid, update_images=True):
    # First create directory.
    local_path = local_experiment_path(uid)
    if not os.path.exists(local_path):
        os.mkdir(local_path)
        
    # Then fetch all data using rsync.
    rsync(xenopi_experiment_path(uid), local_path)
    
    if (update_images):
        update_experiment_images(uid)
    
def update_experiment_images(uid):
    experiment_path = local_experiment_path(uid)
    experiment_to_gif(experiment_path, "{}/{}_ann_%d.png".format(experiment_path, uid), "ann_all", fit_in_circle=True, ann_background=(0,0,0), ann_foreground=(255,255,255))
    experiment_to_gif(experiment_path, "{}/{}_bio_%d.png".format(experiment_path, uid), "bio_all", fit_in_circle=True)


# Handler for new experiment..
def handle_new(addr, uid):
    print("** Received NEW {}".format(uid))
    fetch_experiment(uid)
    send_message("/xeno/server/new", uid)

# # Handler for first image step.
# def handle_begin(addr, uid):
#     print("Received begin {}".format(uid))
#     fetch_experiment(uid)
#     send_message("/xeno/server/begin", uid)

# # Handler for first image step.
def handle_step(addr, uid):
    print("** Received STEP {}".format(uid))
    fetch_experiment(uid)
    send_message("/xeno/server/step", uid)

def handle_end(addr, uid):
    print("** Received END {}".format(uid))
    fetch_experiment(uid)
    send_message("/xeno/server/end", uid)

def handle_state(addr, state):
    print("** Received STATE {}".format(state))
    if (state == "FLASH"):
        send_message("/xeno/server/snapshot")

# # Handler for one image step.
# def handle_step(addr, image_path, base_image_path):
#     next_image(image_path, base_image_path, False)

# # Handler for XenoPi handshake.
# def handle_handshake(addr):
#     send_message("/xeno/neurons/handshake",client=xenopi_client)

# # Handler for settings updated.
# def handle_settings_updated(addr):
#     load_settings()

# # Handler for camera test.
# def handle_test_camera(addr, image_path):
#     global input_quad, image_side
#     dirname = os.path.dirname(image_path)
#     basename = os.path.splitext(os.path.basename(image_path))[0]
#     starting_image, filtered_image, ___, ___, transformed_image, ___ = xeno_image.load_image(image_path, False, image_side, input_quad)
#     transformed_image_path = "{}/{}_0trn.png".format(dirname, basename)
#     transformed_image.save(transformed_image_path.format(dirname, basename))
#     filtered_image.save("{}/{}_1fil.png".format(dirname, basename))
#     starting_image.save("{}/{}_2res.png".format(dirname, basename))
#     send_message("/xeno/neurons/test-camera", [transformed_image_path], client=xenopi_client)

# Create OSC dispatcher.
dispatcher = dispatcher.Dispatcher()
dispatcher.map("/xeno/exp/new", handle_new)
# dispatcher.map("/xeno/exp/begin", handle_begin)
dispatcher.map("/xeno/exp/step", handle_step)
dispatcher.map("/xeno/exp/end", handle_end)
dispatcher.map("/xeno/exp/state", handle_state)
# dispatcher.map("/xeno/exp/handshake", handle_handshake)

# Launch OSC server & client.
server = osc_server.BlockingOSCUDPServer(("0.0.0.0", args.receive_port), dispatcher)
xenopi_client = udp_client.SimpleUDPClient(args.xenopi_ip, args.xenopi_send_port)
macroscope_client = udp_client.SimpleUDPClient(args.macroscope_ip, args.macroscope_send_port)

# Allows program to end cleanly on a CTRL-C command.
def interrupt(signup, frame):
    global xenopi_client, macroscope_client, server
    # print("Exiting program... {}".format(np.mean(perf_measurements)))
    send_message("/xeno/server/end")
    server.server_close()
    sys.exit()

signal.signal(signal.SIGINT, interrupt)

# Indicates that server is ready.
print("Serving on {}. Program ready.".format(server.server_address))
# send_message("/xeno/neurons/begin")

server.serve_forever()

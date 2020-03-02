import os
import os.path
import sys
import signal
import time
import argparse

from pythonosc import dispatcher
from pythonosc import osc_server

from pythonosc import osc_message_builder
from pythonosc import udp_client

import asyncio

from luma.core.interface.serial import i2c, spi
from luma.core.render import canvas
from luma.oled.device import ssd1327

from PIL import Image

parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

parser.add_argument("-f", "--fps", type=float, default=1, help="Frames per second.")
parser.add_argument("-i", "--ip", default="127.0.0.1",
                    help="Specify the ip address to send data to.")
parser.add_argument("-s", "--send-port", default="7000",
                    type=int, help="Specify the port number to send data to.")
parser.add_argument("-r", "--receive-port", default="8001",
                    type=int, help="Specify the port number to listen on.")

args = parser.parse_args()

# Initialize OLED control.
serial = spi(device=0, port=0)
device = ssd1327(serial)

# Initialization.
frame_interval = 1.0/args.fps
images = []
current_frame = 0
running = True

# Handler for first image step.
def handle_begin(addr):
	print("Orbiter: begin")
	images = []
	current_frame = 0
	device.clear()

# Handler for one image step.
def handle_step(addr, image_path):
	print("Orbiter: step {}".format(image_path))
	img = Image.open(image_path).convert(device.mode).resize((device.width, device.height), Image.ANTIALIAS)
	images.append(img)

# Handler for first image step.
def handle_end(addr):
	print("Orbiter: end")
	running = False

# Create OSC dispatcher.
dispatcher = dispatcher.Dispatcher()
dispatcher.map("/xeno/neurons/begin", handle_begin)
dispatcher.map("/xeno/neurons/step", handle_step)
dispatcher.map("/xeno/neurons/end", handle_end)
#dispatcher.map("/xeno/euglenas/settings-updated", handle_settings_updated)

# Launch OSC server & client.
client = udp_client.SimpleUDPClient(args.ip, args.send_port)

# Allows program to end cleanly on a CTRL-C command.
def interrupt(signup, frame):
    global client, server
    print("Exiting program... {}".format(np.mean(perf_measurements)))
    client.send_message("/xeno/orbiter/end", [])
    server.server_close()
    sys.exit()

signal.signal(signal.SIGINT, interrupt)

async def loop():
	global current_frame
	print("current_frame = {} images = {}", current_frame, images)
	while (running):
		# Get next frame and display it.
		if (images):
			device.display(images[current_frame])
			current_frame = (current_frame + 1) % len(images)
		
		# Wait.
		await asyncio.sleep(frame_interval)
		
		print("Looping");
	
async def init():
	server = osc_server.AsyncIOOSCUDPServer(("0.0.0.0", args.receive_port), dispatcher, asyncio.get_event_loop())
	transport, protocol = await server.create_serve_endpoint()  # Create datagram endpoint and start serving
	
	# Indicates that server is ready.
	print("Orbiter server ready.")
	client.send_message("/xeno/orbiter/begin", [])
	
	await loop()  # Enter main loop of program
	
	transport.close()  # Clean up serve endpoint

asyncio.get_event_loop().run_until_complete(init())
#asyncio.run(init())

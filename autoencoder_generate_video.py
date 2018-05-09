import argparse

parser = argparse.ArgumentParser()
parser.add_argument("model_file", type=str, help="The file containing the trained model")

parser.add_argument("-f", "--fps", type=float, default=30, help="Frames per second")
parser.add_argument("-d", "--duration", type=float, default=10, help="Duration (in seconds)")
parser.add_argument("-n", "--n-clips", type=int, default=10, help="Number of video clips to generate")
parser.add_argument("-D", "--output-directory", type=str, default=".", help="The directory where video clips will be saved")

args = parser.parse_args()

import os
import numpy as np
import matplotlib.animation as animation

from keras.models import Model, load_model
from pylab import *

# this is the size of our encoded representations
image_side = 28
image_dim = image_side*image_side

fps = args.fps
n_seconds = args.duration
n_frames = fps * n_seconds
interval = 1000.0 / fps

frame = np.random.random((1, image_dim))

def autoencoder_generate(video_filename):
    global frame, model
    # Generate first image as random
    frame = np.random.random((1, image_dim))

    fig = plt.figure()
    ax = fig.add_subplot(111)
    ax.set_aspect('equal')
#    ax.set_axis_off()
    ax.get_xaxis().set_visible(False)
    ax.get_yaxis().set_visible(False)

    im = ax.imshow(frame.reshape(image_side, image_side),cmap='gray',interpolation='nearest')
    im.set_clim([0,1])
    fig.set_size_inches([5,5])

    tight_layout()

    def update_img(n):
        global frame, model
        im.set_data(frame.reshape(image_side, image_side))
        frame = model.predict(frame)
        return im

    #legend(loc=0)
    ani = animation.FuncAnimation(fig, update_img, n_frames, interval=interval)
    writer = animation.writers['ffmpeg'](fps=fps)

    ani.save(video_filename, writer=writer, dpi=100)#,savefig_kwargs={ 'bbox_inches': 'tight', 'pad_inches': 0 })

# load the model
model = load_model(args.model_file)

# create models directory if needed
if not os.path.exists(args.output_directory):
	os.makedirs(args.output_directory)

for i in range(0, args.n_clips):
  print("Generating movie # {0:02d}".format(i))
  autoencoder_generate(args.output_directory + "/output_{0:02d}.mp4".format(i))

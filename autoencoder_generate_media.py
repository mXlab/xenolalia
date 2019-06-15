import argparse

parser = argparse.ArgumentParser()
parser.add_argument("model_file", type=str, help="The file containing the trained model")

parser.add_argument("-I", "--still-images", default=False, action='store_true', help="Generate still images instead of videos")
parser.add_argument("-c", "--convolutional", default=False, action='store_true', help="Use convolutional autoencoder")
parser.add_argument("-i", "--n-iterations", type=int, default=300, help="Number of iterations (for generating still images)")
parser.add_argument("-f", "--fps", type=float, default=30, help="Frames per second")
parser.add_argument("-d", "--duration", type=float, default=10, help="Duration (in seconds)")
parser.add_argument("-n", "--n-clips", type=int, default=10, help="Number of video clips to generate")
parser.add_argument("-D", "--output-directory", type=str, default=".", help="The directory where video clips will be saved")
parser.add_argument("-s", "--starting-image", type=str, default=None, help="(optional) Starting image (instead of noise)")

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
interval = 1000.0 / fps

convolutional = args.convolutional
still_images = args.still_images
if still_images:
    n_frames = args.n_iterations
else:
    n_frames = int(fps * n_seconds)

if convolutional:
    input_shape = (1, image_side, image_side, 1)
else:
    input_shape = (1, image_dim)

def autoencoder_generate(filename):
    global frame, model, still_images

    if still_images:
        filename = filename + ".jpg"
    else:
        filename = filename + ".mp4"

    # Generate first image as random
    if args.starting_image == None:
        frame = np.random.random(input_shape)
    else:
        from PIL import Image
        img = Image.open(args.starting_image).resize((image_side, image_side)).convert('L')
        frame = np.array(img).reshape(input_shape)
        frame = frame / np.max(frame)

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
    if still_images:
        for i in range(n_frames):
            im = update_img(i)
        # Save image
        fig.savefig(filename)
#        print(im.make_image(None))
#        .imsave(filename)
    else:
        ani = animation.FuncAnimation(fig, update_img, n_frames, interval=interval)
        writer = animation.writers['ffmpeg'](fps=fps)

        ani.save(filename, writer=writer, dpi=100)#,savefig_kwargs={ 'bbox_inches': 'tight', 'pad_inches': 0 })

# load the model
model = load_model(args.model_file)
print(model.summary())

# create models directory if needed
if not os.path.exists(args.output_directory):
	os.makedirs(args.output_directory)

for i in range(0, args.n_clips):
  print("Generating # {0:02d}".format(i))
  autoencoder_generate(args.output_directory + "/output_{0:02d}".format(i))

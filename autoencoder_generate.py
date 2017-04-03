import numpy as np
import matplotlib.animation as animation

from keras.models import Model, load_model
from pylab import *

# this is the size of our encoded representations
image_side = 28
image_dim = image_side*image_side

folder = "saved_images"

fps = 30
n_seconds = 10
n_steps = fps * n_seconds

frame = np.random.random((1,image_dim))

def autoencoder_generate(video_filename):
    global frame, model
    # Generate first image as random
    frame = np.random.random((1,image_dim))
    
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
    ani = animation.FuncAnimation(fig,update_img,300,interval=30)
    writer = animation.writers['ffmpeg'](fps=30)

    ani.save(video_filename,writer=writer,dpi=100)#,savefig_kwargs={ 'bbox_inches': 'tight', 'pad_inches': 0 })
    return ani

filename = "saved_models_deep/autoencoder.h5"
#filename = "autoencoder.h5"
model = load_model(filename)

for i in range(0, 20):
  print "Generating movie # {0:02d}".format(i)
  autoencoder_generate("output_{0:02d}.mp4".format(i))

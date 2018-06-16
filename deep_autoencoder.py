# Source: https://blog.keras.io/building-autoencoders-in-keras.html

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("encoder", type=str, help="A comma-separated list of numbers representing the number of neurons in each hidden layer of the encoder")
parser.add_argument("model_file", type=str, help="The file where to save the model (in HDF5 format)")

parser.add_argument("-c", "--convolutional", default=False, action='store_true', help="Use convolutional autoencoder")
parser.add_argument("-s", "--sparse", default=False, action='store_true', help="User sparse autoencoder")
parser.add_argument("--dropout", type=float, default=0.25, help="Dropout value (if using sparse mode with convolutional net)")
parser.add_argument("--last-padding-valid", default=False, help="Set last layer's padding to 'valid' instead of 'same'")
parser.add_argument("-k", "--kernel-size", type=int, default=3, help="Convolutional kernel size")
parser.add_argument("-ds", "--down-sampling-size", type=int, default=2, help="Downsampling size (for encoder)")
parser.add_argument("-us", "--up-sampling-size", type=int, default=2, help="Unsampling size (for decoder)")
parser.add_argument("-d", "--decoder", type=str, default=None, help="A comma-separated list of numbers representing the number of neurons in each hidden layer of the decoder")
parser.add_argument("-e", "--n-epochs", type=int, default=100, help="Number of epochs")
parser.add_argument("-b", "--batch-size", type=int, default=256, help="The batch size")
parser.add_argument("-F", "--show-figure", default=True, action='store_true', help="Show example reconstruction after training")
parser.add_argument("-D", "--model-directory", type=str, default=".", help="The directory where models will be saved")

args = parser.parse_args()

from keras.layers import Input, Dense, Conv2D, MaxPooling2D, UpSampling2D, Dropout
from keras.models import Model, load_model
from keras.regularizers import l1

# this is the size of our encoded representations
image_side = 28
image_dim = image_side*image_side

encoding_dim = 32  # 32 floats -> compression of factor 24.5, assuming the input is 784 floats

convolutional = args.convolutional

# this is our input placeholder
if convolutional:
    input = Input(shape=(image_side,image_side,1))
else:
    input = Input(shape=(image_dim,))

# build encoder
encoder_layers = args.encoder.split(',')

is_sparse = args.sparse
kernel_size = args.kernel_size
kernel = (kernel_size, kernel_size)
down_sampling = (args.down_sampling_size, args.down_sampling_size)
up_sampling = (args.up_sampling_size, args.up_sampling_size)

encoder = input

if convolutional:
    for n_hidden in encoder_layers:
        encoder = Conv2D(int(n_hidden), kernel, activation='relu', padding='same')(encoder)
        encoder = MaxPooling2D(down_sampling, padding='same')(encoder)
        if is_sparse:
            encoder = Dropout(args.dropout)(encoder)
else:
    for i in range(len(encoder_layers)-1):
        n_hidden = encoder_layers[i]
        encoder = Dense(int(n_hidden), activation='relu')(encoder)
    if is_sparse:
        encoder = Dense(int(encoder_layers[-1]), activation='relu', activity_regularizer=l1(1e-5))(encoder)
    else:
        encoder = Dense(int(encoder_layers[-1]), activation='relu')(encoder)

# build decoder
decoder = encoder
if (args.decoder != None):
    decoder_layers = args.decoder.split(',')
    if convolutional:
        for i in range(len(decoder_layers)-1):
            n_hidden = decoder_layers[i]
            decoder = Conv2D(int(n_hidden), kernel, activation='relu', padding='same')(decoder)
            decoder = UpSampling2D(up_sampling)(decoder)
        decoder = Conv2D(int(encoder_layers[-1]), kernel, activation='relu', padding='same')(decoder)
        decoder = UpSampling2D(up_sampling)(decoder)
    else:
        for n_hidden in decoder_layers:
            decoder = Dense(int(n_hidden), activation='relu')(decoder)

if convolutional:
    if args.last_padding_valid:
        padding = 'valid'
    else:
        padding = 'same'
    decoder = Conv2D(1, kernel, activation='sigmoid', padding=padding)(decoder)
else:
    decoder = Dense(image_dim, activation='sigmoid')(decoder)

output = decoder

# maps an input to its reconstruction
autoencoder = Model(inputs=input, outputs=output)

print(autoencoder.summary())

# compile autoencoder
autoencoder.compile(optimizer='adadelta', loss='binary_crossentropy')

# Make image of model
from keras.utils import plot_model
plot_model(autoencoder, to_file='model.png')

# create training and test sets
from keras.datasets import mnist
import numpy as np
(x_train, _), (x_test, _) = mnist.load_data()

x_train = x_train.astype('float32') / 255.
x_test = x_test.astype('float32') / 255.

if convolutional:
    x_train = x_train.reshape((len(x_train), image_side, image_side, 1))
    x_test = x_test.reshape((len(x_test), image_side, image_side, 1))
else:
    x_train = x_train.reshape((len(x_train), np.prod(x_train.shape[1:])))
    x_test = x_test.reshape((len(x_test), np.prod(x_test.shape[1:])))

import os.path
from keras.callbacks import ModelCheckpoint

# create models directory if needed
#if not os.path.exists(args.model_directory):
#	os.makedirs(args.model_directory)

print("Training autoencoder")
autoencoder.fit(x_train, x_train,
                epochs=args.n_epochs,
                batch_size=args.batch_size,
                shuffle=True,
#                callbacks=[ModelCheckpoint(args.model_directory + "/autoencoder.{epoch:02d}.hdf5")],
                validation_data=(x_test, x_test))
autoencoder.save(args.model_file)

# encode and decode some digits
# note that we take them from the *test* set
decoded_imgs = autoencoder.predict(x_test)

# use Matplotlib (don't ask)
import matplotlib.pyplot as plt

if (args.show_figure):
    n = 10  # how many digits we will display
    plt.figure(figsize=(20, 4))
    for i in range(n):
        # display original
        ax = plt.subplot(2, n, i + 1)
        plt.imshow(x_test[i].reshape(28, 28))
        plt.gray()
        ax.get_xaxis().set_visible(False)
        ax.get_yaxis().set_visible(False)

        # display reconstruction
        ax = plt.subplot(2, n, i + 1 + n)
        plt.imshow(decoded_imgs[i].reshape(28, 28))
        plt.gray()
        ax.get_xaxis().set_visible(False)
        ax.get_yaxis().set_visible(False)
    plt.show()

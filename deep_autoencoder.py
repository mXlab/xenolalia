# Source: https://blog.keras.io/building-autoencoders-in-keras.html

from keras.layers import Input, Dense
from keras.models import Model, load_model

# this is the size of our encoded representations
image_side = 28
image_dim = image_side*image_side

encoding_dim = 32  # 32 floats -> compression of factor 24.5, assuming the input is 784 floats

# this is our input placeholder
input_img = Input(shape=(image_dim,))

# "encoded" is the encoded representation of the input
encoded = Dense(encoding_dim*4, activation='relu')(input_img)
encoded = Dense(encoding_dim*2, activation='relu')(encoded)
encoded = Dense(encoding_dim,   activation='relu')(encoded)

# "decoded" is the lossy reconstruction of the input
decoded = Dense(encoding_dim*2, activation='relu')(encoded)
decoded = Dense(encoding_dim*4, activation='relu')(decoded)
decoded = Dense(image_dim,      activation='sigmoid')(decoded)

# this model maps an input to its reconstruction
autoencoder = Model(input=input_img, output=decoded)

autoencoder.compile(optimizer='adadelta', loss='binary_crossentropy')

from keras.datasets import mnist
import numpy as np
(x_train, _), (x_test, _) = mnist.load_data()

x_train = x_train.astype('float32') / 255.
x_test = x_test.astype('float32') / 255.
x_train = x_train.reshape((len(x_train), np.prod(x_train.shape[1:])))
x_test = x_test.reshape((len(x_test), np.prod(x_test.shape[1:])))
print(x_train.shape)
print(x_test.shape)

import os.path
from keras.callbacks import ModelCheckpoint
filename = "autoencoder.h5"
if os.path.isfile(filename):
  print("Loading autoencoder from file")
  autoencoder = load_model(filename)
else:
  print("Training autoencoder")
  autoencoder.fit(x_train, x_train,
                  nb_epoch=100,
                  batch_size=256,
                  shuffle=True,
                  callbacks=[ModelCheckpoint("autoencoder.{epoch:02d}.hdf5")],
                  validation_data=(x_test, x_test))
  autoencoder.save(filename)

# encode and decode some digits
# note that we take them from the *test* set
decoded_imgs = autoencoder.predict(x_test)

# use Matplotlib (don't ask)
import matplotlib.pyplot as plt

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

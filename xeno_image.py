# Library that provides different kinds of image filtering and conversion tools. Can also be used as a script to
# filter an image.

import numpy as np

import os
import os.path
import time
import math
import argparse

from PIL import Image, ImageOps, ImageFilter, ImageEnhance

# equalizes levels to a certain average accross points
def equalize(arr, average=0.5):
    return arr * (average * arr.size) / arr.sum()

def round_up_to_odd(f):
    return int(np.ceil(f) // 2 * 2 + 1)

# Converts a PIL grayscale image to a numpy array in [0,1] with given shape.
def image_to_array(img, input_shape):
    return np.asarray(img).reshape(input_shape) / 255.0

# Converts a numpy array received from the neural network with all values in [0,1] to PIL grayscale image.
def array_to_image(arr, width, height):
    return Image.fromarray(arr.reshape((width, height)) * 255.0).convert('L')

# Processes raw grayscale image. Returns a tuple containing:
# - transformed + filtered + resized image
# - transformed + filtered image
# - transformed image
def process_image(image, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0]):
    w = image.size[0]
    h = image.size[1]

    median_filter_size = round_up_to_odd(min(w, h) * 0.015) # this is approximated on a size of 5 for a 320x320 image
#    median_filter_size = round_up_to_odd(min(w, h) * 0.1) # this is approximated on a size of 5 for a 320x320 image
    contrast_factor = 2
#    brightness_factor = 0.1

    # Adjust image perspective based on input quad.
    input_quad_abs = (input_quad[0] * w, input_quad[1] * h, input_quad[2] * w, input_quad[3] * h, input_quad[4] * w, input_quad[5] * h, input_quad[6] * w, input_quad[7] * h)
    transformed = image.transform(image.size, Image.QUAD, input_quad_abs)

    # Apply image filters to image. The goal is to provide a balanced and highly contrasted grayscale image
    #    image = ImageOps.autocontrast(image)

    # Apply mask to alleviate border flares / artefacts.
    filtered = transformed.convert('RGBA')
    image_mask = Image.open("xeno_mask.png").convert('RGBA').resize(transformed.size)
    filtered = Image.alpha_composite(filtered, image_mask)
    filtered = filtered.convert('L')

    # Image filters to enhance contrasts.
    filtered = ImageOps.invert(filtered)
    filtered = filtered.filter(ImageFilter.MedianFilter(median_filter_size))
    filtered = ImageOps.equalize(filtered)
#    filtered = ImageEnhance.Brightness(filtered).enhance(brightness_factor)
    filtered = ImageEnhance.Contrast(filtered).enhance(contrast_factor)

    ##################################################################
    import cv2
    from skimage.morphology import skeletonize, thin
    from skimage import img_as_bool, img_as_float, img_as_ubyte
    # Erode/thin using opencv (NOTE: This part is still experimental).
    img = np.array(filtered)
    ret, img = cv2.threshold(img, 191, 255, cv2.THRESH_BINARY)
    # kernel = np.ones((5, 5), np.uint8)
    # opencv_image = cv2.erode(opencv_image, kernel, iterations=5)
    img = img_as_bool(img)
    img = thin(img, max_iter=5)
    img = img_as_ubyte(img)
    filtered = Image.fromarray(img)
    ##################################################################

    resized = filtered.resize((image_side, image_side))

    return resized, filtered, transformed


# Loads image_path file, applies perspective transforms and returns it as
# a numpy array formatted for the autoencoder.
def load_image(image_path, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0]):
    # Open image as grayscale.
    image = Image.open(image_path).convert('L')
    return process_image(image, image_side, input_quad)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument("input_image", type=str, help="Input image file")
    parser.add_argument("output_image", type=str, help="Output image file")

    parser.add_argument("-C", "--configuration-file", type=str, default="XenoPi/camera_perspective.conf", help="Configuration file containing input quad")
    parser.add_argument("-q", "--input-quad", type=str, default=None, help="Comma-separated list of numbers defining input quad (overrides configuration file)")
    parser.add_argument("-i", "--image-side", type=int, default=28, help="Image side value")

    parser.add_argument("-r", "--raw-image", default=False, action='store_true', help="Use raw image (ie. do not apply any transformations, just filterings)")
    parser.add_argument("-c", "--enable-color", default=False, action='store_true', help="Enable color when taking snapshot")
    parser.add_argument("-s", "--show", default=False, action='store_true', help="Show image on screen before saving")

    args = parser.parse_args()

    if args.raw_image:
        input_quad = (0, 0, 0, 1, 1, 1, 1, 1, 0)  # dummy
    elif (args.input_quad != None):
        input_quad = tuple([float(x) for x in args.input_quad.split(',')])
    else:
        with open(args.configuration_file, "rb") as f:
            input_quad = tuple([float(v) for v in f.readlines()])

    img = load_image(args.input_image, input_quad=input_quad, apply_transforms=not args.raw_image)
    if args.show:
        img.show()

    img.save(args.output_image)

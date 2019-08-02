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

# Process raw grayscale image.
def process_image(image, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0], apply_transforms=True):
    median_filter_size = 25
    contrast_factor = 2

    # Invert image.
    image = ImageOps.invert(image)

    if apply_transforms:
        # Apply transforms on image.
        w = image.size[0]
        h = image.size[1]
        input_quad_abs = (input_quad[0] * w, input_quad[1] * h, input_quad[2] * w, input_quad[3] * h, input_quad[4] * w, input_quad[5] * h, input_quad[6] * w, input_quad[7] * h)
        image = image.transform(image.size, Image.QUAD, input_quad_abs)

    # Equalize and denoise image.
    #    image = ImageOps.autocontrast(image)
    image = ImageOps.equalize(image)
    image = ImageEnhance.Contrast(image).enhance(contrast_factor)
    image = image.filter(ImageFilter.MedianFilter(median_filter_size))

    if apply_transforms:
        image = image.resize((image_side, image_side))
    return image


# Loads image_path file, applies perspective transforms and returns it as
# a numpy array formatted for the autoencoder.
def load_image(image_path, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0], apply_transforms=True):
    # Open image as grayscale.
    image = Image.open(image_path).convert('L')
    return process_image(image, image_side, input_quad, median_filter_size, apply_transforms)


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

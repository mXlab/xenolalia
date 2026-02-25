# Library that provides different kinds of image filtering and conversion tools. Can also be used as a script to
# filter an image.

import numpy as np

import argparse

import os

from PIL import Image, ImageOps, ImageFilter, ImageChops

import cv2
from skimage.morphology import thin
from skimage import img_as_bool, img_as_ubyte

from collections import namedtuple

from skimage import __version__ as skimage_version
from skimage.morphology import thin
from packaging import version

# equalizes levels to a certain average accross points
def equalize(arr, average=0.5):
    return arr * (average * arr.size) / arr.sum()

def round_up_to_odd(f):
    return int(np.ceil(f) // 2 * 2 + 1)

# Converts a PIL grayscale image to a numpy array in [0,1] with given shape.
def image_to_array(img, input_shape):
    return np.asarray(img.convert('L')).reshape(input_shape) / 255.0

# Converts a numpy array received from the neural network with all values in [0,1] to PIL grayscale image.
def array_to_image(arr, width, height):
    return Image.fromarray(arr.reshape((width, height)) * 255.0).convert('L')

def create_mask(image, invert=False):
    script_path = os.path.abspath(__file__) # i.e. /path/to/dir/xeno_image.py
    script_dir = os.path.split(script_path)[0] #i.e. /path/to/dir/
    absolute_file_mask_path = os.path.join(script_dir, "xeno_mask.png")
    return Image.open(absolute_file_mask_path).convert('RGBA').resize(image.size)

# Returns image resulting from subtraction of image from base_image.
def remove_base(image, base_image):
    return ImageChops.subtract(image.convert('RGB'), base_image.convert('RGB'), scale=0.1, offset=127)

# Returns square image picked from area in image defined by input_quad.
def transform(image, input_quad):
    w, h = image.size
    input_quad_abs = (input_quad[0] * w, input_quad[1] * h, input_quad[2] * w, input_quad[3] * h, input_quad[4] * w, input_quad[5] * h, input_quad[6] * w, input_quad[7] * h)
    square_side = max(w, h)
    return image.transform((square_side, square_side), Image.QUAD, input_quad_abs)

# Apply mask to alleviate border flares / artefacts.
def add_mask(image, invert=False):
    if invert:
        return ImageOps.invert(add_mask(ImageOps.invert(image)))
    else:
        return Image.alpha_composite(image.convert('RGBA'), create_mask(image)).convert('RGB')

# Apply different kinds of filterings to image in order to enhance its shape.
def enhance(image):
    w, h = image.size
    median_filter_size = round_up_to_odd(min(w, h) * 0.009375) # this is approximated on a size of 5 for a 320x320 image

    # Convert to grayscale.
    filtered = image.convert('L')
    image_mask = ImageOps.invert(create_mask(image).convert('L'))

    # Image filters to enhance contrasts.

    # Invert image: dark/green zones should show up as light zones.
    filtered = ImageOps.invert(filtered) 

    # Apply median filter - this will reduce noise in the image.
    filtered = filtered.filter(ImageFilter.MedianFilter(median_filter_size))

    # Equalize the image histogram - creates a uniform distribution of grayscale values in the output image.
    filtered = ImageOps.equalize(filtered, image_mask)

    #    filtered = ImageEnhance.Brightness(filtered).enhance(brightness_factor)
    # filtered = ImageEnhance.Contrast(filtered).enhance(2)
    return filtered

# Simplifies image by removing noise through thinning.
def simplify(image):
    # Convert to numpy array in order to apply OpenCV operations.
    img = np.array(image)

    # Apply adaptive thresholding of image to turn it to black & white.
    ___, img = cv2.threshold(img, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Thin image: this will turn small "speckles" into single-pixel lines.
    img = img_as_bool(img)
    # Deal with different versions of scikit-image.
    if version.parse(skimage_version) >= version.parse("0.20.0"):
        img = thin(img, max_num_iter=5)
    else:
        img = thin(img, max_iter=5)
    img = img_as_ubyte(img)

    # Erode image: further reduce speckles to obtain more pure image.
    kernel = np.ones((3, 3), np.uint8)
    img = cv2.erode(img, kernel, iterations=5)

    # Reconvert from numpy array back to PIL image.
    img = Image.fromarray(img)

    return img

# Resize to square image using Lanczos algorithm (which is better for reducing image size).
def resize(image, image_side):
    return image.resize((image_side, image_side), resample=Image.LANCZOS)

def postprocess_output(image, output_size=224, threshold=0.5, line_width=2, area_max=None):
    """Post-process an autoencoder output image for projection.

    Transforms the raw 28x28 (or any size) grayscale PIL image into a
    higher-resolution binary image suitable for projection:
      1. Upscale to output_size x output_size.
      2. Threshold to binary (using area_max or fixed threshold).
      3. Extract boundary: filled regions become hollow loops.
      4. Dilate to control stroke width.

    Args:
        image:       Grayscale PIL Image (autoencoder output).
        output_size: Side length of the returned image in pixels.
        threshold:   Binary threshold in [0, 1), used when area_max is None.
                     Values ≥ 1.0 produce all-black output (no pixel can exceed 255).
        line_width:  Dilation radius in pixels. 0 = no dilation (raw boundary).
        area_max:    If set (0–1), overrides threshold: keeps at most this
                     fraction of pixels lit before boundary extraction.

    Returns:
        Grayscale PIL Image of size output_size x output_size.
    """
    # 1. Upscale.
    img = image.convert('L').resize((output_size, output_size), resample=Image.LANCZOS)
    arr = np.array(img, dtype=np.uint8)

    # 2. Threshold to binary.
    if area_max is not None:
        # Percentile threshold: keep at most area_max fraction of pixels "on".
        thresh_val = np.percentile(arr, (1.0 - float(area_max)) * 100.0)
        thresh_val = max(1, int(thresh_val))  # avoid all-white on flat images
        _, binary = cv2.threshold(arr, thresh_val, 255, cv2.THRESH_BINARY)
    else:
        thresh_val = int(float(threshold) * 255)
        _, binary = cv2.threshold(arr, thresh_val, 255, cv2.THRESH_BINARY)

    # 3. Boundary extraction: boundary = image - erosion(image).
    #    Filled regions become outlines (loops); thin lines have no interior
    #    to subtract so they are preserved as-is.
    #    BORDER_CONSTANT with value 0 ensures image-edge pixels are treated as
    #    having black neighbours, so the boundary ring at the image border is
    #    correctly extracted even for images that fill the entire canvas.
    kernel_3x3 = np.ones((3, 3), np.uint8)
    eroded = cv2.erode(binary, kernel_3x3, iterations=1,
                       borderType=cv2.BORDER_CONSTANT, borderValue=0)
    boundary = cv2.subtract(binary, eroded)

    # 4. Dilate to desired line width.
    if line_width > 0:
        k = line_width * 2 + 1
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
        boundary = cv2.dilate(boundary, kernel, iterations=1)

    return Image.fromarray(boundary, mode='L')

# Processes raw image.
def process_image(image, base_image=False, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0]):
    # Transform image using input quad.
    raw_transformed = transform(image.convert('RGB'), input_quad)

    # Remove averaged background file from image.
    if base_image:
        prefiltered = remove_base(image, base_image)
    else:
        prefiltered = image.convert('RGB')

    # Transform image using input quad.
    transformed = transform(prefiltered, input_quad).convert('L')

    # Apply mask to alleviate border flares / artefacts.
    masked = add_mask(transformed)

    # Image filters to enhance contrasts.
    enhanced = enhance(masked)

    # Apply morphology enhancement.
    simplified = simplify(enhanced)

    # Resize to smaller image.
    resized = resize(simplified, image_side)

    return resized, simplified, enhanced, masked, transformed, raw_transformed

# Loads image_path file, applies perspective transforms and returns it as
# a numpy array formatted for the autoencoder.
def load_image(image_path, base_image_path=False, image_side=28, input_quad=[0, 0, 0, 1, 1, 1, 1, 0]):
    # Open image as grayscale.
    image = Image.open(image_path)
    if base_image_path:
        base_image = Image.open(base_image_path)
    else:
        base_image = False
    return process_image(image, base_image, image_side, input_quad)

if __name__ == "__main__":

    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument("input_image", type=str, help="Input image file")
    parser.add_argument("output_image", type=str, help="Output image file")

    parser.add_argument("-b", "--base-image", type=str, default=False, help="Base image from which to subtract image")
    parser.add_argument("-C", "--configuration-file", type=str, default="XenoPi/settings.json", help="Configuration file containing camera input quad")
    parser.add_argument("-q", "--input-quad", type=str, default=None, help="Comma-separated list of numbers defining input quad (overrides configuration file)")
    parser.add_argument("-i", "--image-side", type=int, default=28, help="Image side value")

    parser.add_argument("-r", "--raw-image", default=False, action='store_true', help="Use raw image (ie. do not apply any transformations, just filterings)")
    parser.add_argument("-c", "--enable-color", default=False, action='store_true', help="Enable color when taking snapshot")
    parser.add_argument("-s", "--show", default=False, action='store_true', help="Show image on screen before saving")

    args = parser.parse_args()

    # Load calibration settings from .json file.
    def load_settings():
        import json
        global args, data, input_quad, n_steps
        print("Loading settings")
        with open(args.configuration_file, "r") as f:
            data = json.load(f)
            input_quad = tuple( data['camera_quad'] )

    # Load input quad
    if args.raw_image:
        input_quad = (0, 0, 0, 1, 1, 1, 1, 1, 0)  # dummy
    elif (args.input_quad != None):
        input_quad = tuple([float(x) for x in args.input_quad.split(',')])
    else:
        load_settings()

    resized, simplified, enhanced, masked, transformed, raw_transformed = load_image(args.input_image, args.base_image, input_quad=input_quad)#, apply_transforms=(not args.raw_image))
    if args.show:
        single_image_side = transformed.size[0]
        print(single_image_side)
        composition = Image.new('RGBA', (3*single_image_side, 2*single_image_side))
        composition.paste(raw_transformed, (0, 0))
        composition.paste(transformed, (  single_image_side, 0))
        composition.paste(masked,      (2*single_image_side, 0))
        composition.paste(enhanced,    (0,                   single_image_side))
        composition.paste(simplified,  (  single_image_side, single_image_side))
        composition.paste(resized.resize(transformed.size), (2*single_image_side, single_image_side))
        composition.show()

    resized.save(args.output_image)

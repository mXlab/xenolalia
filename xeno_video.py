import glob
import argparse
import os.path

import numpy as np
import math

from PIL import Image, ImageOps
from apng import APNG
import xeno_image as xi

# Load calibration settings from .json file.
def load_settings(settings_file):
    import json
    with open(settings_file, "r") as f:
        data = json.load(f)
        input_quad = tuple(data['camera_quad'])
    return input_quad

# Approximates and returns a new input quad that will result in a large enough border to fit
# inside a circular mask.
def input_quad_fit_in_circle(input_quad):
    # Gather all corners.
    p1 = np.array( input_quad[0:2] )
    p2 = np.array( input_quad[2:4] )
    p3 = np.array( input_quad[4:6] )
    p4 = np.array( input_quad[6:8] )
    all_points = np.array([p1, p2, p3, p4])

    # Find center point.
    p_center = (np.mean(all_points[:,0]), np.mean(all_points[:,1]))

    # Resize factor estimated using trigonometry.
    resize_factor = 1 + math.sqrt(2) * (1 - math.sin(math.pi/4.0))

    # Project points according to resize factor (clamp to range [0, 1]).
    p1 = np.clip(p_center + (p1 - p_center)*resize_factor, 0, 1)
    p2 = np.clip(p_center + (p2 - p_center)*resize_factor, 0, 1)
    p3 = np.clip(p_center + (p3 - p_center)*resize_factor, 0, 1)
    p4 = np.clip(p_center + (p4 - p_center)*resize_factor, 0, 1)

    # Return new input quad.
    return list( np.concatenate( [p1, p2, p3, p4] ) )

# Expand ANN (neural net) image to fit inside circle, adding a border with specific background color.
def ann_image_fit_in_circle(img, background=(0,0,0)):
    size = (img.width, img.height)
    img = img.resize((img.width*2, img.height*2))
    border_size = int( img.width * (1 - math.sin(math.pi/4.0)) * 0.5 )
    img = ImageOps.expand(img, border=border_size, fill="rgb({},{},{})".format(int(background[0]), int(background[1]), int(background[2])))
    return img.resize(size)

# Horizontally concatenate two images.
def concatenate_horizontal(img1, img2):
    dst = Image.new('RGB', (img1.width + img2.width, img1.height))
    dst.paste(img1, (0, 0))
    dst.paste(img2, (img1.width, 0))
    return dst

# Generate animated GIF or APNG from list of same-size images.
def save_images_as_animation(image_list, animation_file_name, fps=5):
    delay = int(1.0 / fps * 1000)
    type = os.path.splitext(animation_file_name)[1][1:]
    if type == "gif":
        image_list[0].save(animation_file_name, format="GIF", append_images=image_list[1:],
                           save_all=True, duration=delay, loop=0)
    elif type == "png":
        file = APNG()
        for img in image_list:
            tmp_file_name = "/tmp/temp_file.png"
            img.save(tmp_file_name, format="png")
            file.append_file(tmp_file_name, delay=delay)
        file.save(animation_file_name)

# Batch-resize list of images to a square image of image_side x image_side.
def resize_square_images(image_list, image_side=480):
    size = (image_side, image_side)
    return [img.resize(size, resample=Image.LANCZOS) for img in image_list]

# Extract timestamp from snapshot file.
# Example: snapshot_file_get_timestamp("/path/to/2019-08-02_17:23:28_604889_pro.png") returns "604889"
def snapshot_file_get_timestamp(path):
    return path.split('/')[1].split('_')[2]

# Returns list of images in folder that correspond to a certain pattern, ordered according to timestamp.
def get_ordered_snapshot_images(folder, pattern):
    return [Image.open(filename) for filename in sorted(glob.glob(f"{folder}/{pattern}"), key=snapshot_file_get_timestamp)]

# Get all "ann" images in experiment folder, with optional background and foreground RGB colors.
def get_ann_images(experiment_folder, gif_file_side, background=(0, 0, 0), foreground=(255, 255, 255), fit_in_circle=False):
    images = get_ordered_snapshot_images(experiment_folder, "*_3ann.png")
    images = [ImageOps.colorize(img, background, foreground) for img in images]
    images = resize_square_images(images, gif_file_side)
    if fit_in_circle:
        images = [ann_image_fit_in_circle(img, background=background) for img in images]
    return images

# Get all "raw" images in experiment folder.
def get_raw_images(experiment_folder, gif_file_side, input_quad, fit_in_circle=False):
    raw_images = get_ordered_snapshot_images(experiment_folder, "*_raw.png")
    base_image = Image.open(f"{experiment_folder}/base_image.png")

    if fit_in_circle:
        input_quad = input_quad_fit_in_circle(input_quad)
    raw_transformed_images = []
    for img in raw_images:
        __, __, __, __, __, rt = xi.process_image(img, base_image, image_side=28, input_quad=input_quad)
        if fit_in_circle:
            rt = xi.add_mask(rt)
        raw_transformed_images.append(rt)
    return resize_square_images(raw_images, gif_file_side), resize_square_images(raw_transformed_images, gif_file_side)

# Returns a new image list from source image list with crossfade between images.
def crossfade(image_list, crossfade_steps=10):
    new_image_list = []
    for i in range(len(image_list) - 1):
        img_from = image_list[i].convert('RGBA')
        img_to = image_list[i + 1].convert('RGBA')
        for j in range(crossfade_steps):
            mixing_factor = float(j) / crossfade_steps
            new_image_list.append(Image.blend(img_from, img_to, mixing_factor))
    return new_image_list

# Generates an animated GIF from a single experiment. Several modes and options available.
# "ann" : animated sequence of ANN-only generated images
# "raw" : animated sequence of raw-only generated images
# "raw_transformed" : animated sequence of raw images, transformed according to input quad
# "ann_raw_transformed_concatenated" : animated sequence intermixing ANN and raw transformed images side by side
# "ann_raw_transformed_sequence" : animated sequence intermixing ANN and raw transformed images one after the other
def experiment_to_gif(experiment_folder, gif_file_name, mode, gif_file_side=480, fps=5.0, ann_background=(0, 0, 0),
                      ann_foreground=(255, 255, 255), input_quad=None, fit_in_circle=False):
    # Get input quad.
    if input_quad is None:
        import json
        settings_file = f"{experiment_folder}/settings.json"
        data = json.load(open(settings_file, "r"))
        input_quad = tuple(data['camera_quad'])

    # Get image frames.
    ann_frames = get_ann_images(experiment_folder, gif_file_side, ann_background, ann_foreground, fit_in_circle=fit_in_circle)
    raw_frames, raw_transformed_frames = get_raw_images(experiment_folder, gif_file_side, input_quad, fit_in_circle=fit_in_circle)

    if mode == "ann":
        image_list = ann_frames
    elif mode == "raw":
        image_list = raw_frames
    elif mode == "raw_transformed":
        image_list = raw_transformed_frames
    elif mode == "ann_raw_transformed_concatenated":
        image_list = []
        for i in range(len(ann_frames) - 1):
            image_list.append(concatenate_horizontal(ann_frames[i], raw_transformed_frames[i]))
    elif mode == "ann_raw_transformed_sequence":
        image_list = []
        for i in range(len(ann_frames) - 1):
            image_list.append(ann_frames[i])
            image_list.append(raw_transformed_frames[i])
        image_list = crossfade(image_list, 20)
        fps *= 20

    save_images_as_animation(image_list, gif_file_name, fps=fps)


if __name__ == "__main__":

    # Create parser.
    def tuple_type(str):
        return tuple(map(float, str.split(",")))

    def list_type(str):
        return list(map(float, str.split(",")))

    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument("experiment_folder", type=str, help="Root folder of experiment")
    parser.add_argument("output_gif_file", type=str, help="Output GIF file")

    parser.add_argument("-m", "--mode", type=str, default="raw_transformed", help="Animation mode")
    parser.add_argument("-i", "--image-side", type=int, default=480, help="Pixel dimension of side (square image)")
    parser.add_argument("-fps", "--frames-per-second", type=float, default=5.0, help="Number of frames/images per second")
    parser.add_argument("-b", "--ann-background", type=tuple_type, default="0,0,0", help="RGB color of background (ANN images)")
    parser.add_argument("-f", "--ann-foreground", type=tuple_type, default="255,255,255", help="RGB color of foreground (ANN images)")

    parser.add_argument("-q", "--input-quad", type=list_type, default=None, help="Comma-separated list of numbers defining input quad (overrides configuration file)")

    parser.add_argument("-c", "--fit-in-circle", default=False, action='store_true', help="Append border to generated images so that they fit inside a circular mask")

    args = parser.parse_args()

    # Load input quad
    if (args.input_quad != None):
        input_quad = args.input_quad
    else:
        input_quad = load_settings("{}/settings.json".format(args.experiment_folder))

    # Create GIF.
    experiment_to_gif(args.experiment_folder, args.output_gif_file, args.mode, gif_file_side=args.image_side, fps=args.frames_per_second, ann_background=args.ann_background, ann_foreground=args.ann_foreground, input_quad=input_quad, fit_in_circle=args.fit_in_circle)
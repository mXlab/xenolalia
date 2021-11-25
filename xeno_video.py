import glob
import argparse

from PIL import Image, ImageOps

import xeno_image as xi

# Load calibration settings from .json file.
def load_settings(settings_file):
    import json
    with open(settings_file, "r") as f:
        data = json.load(f)
        input_quad = tuple(data['camera_quad'])
    return input_quad

# Horizontally concatenate two images.
def concatenate_horizontal(img1, img2):
    dst = Image.new('RGB', (img1.width + img2.width, img1.height))
    dst.paste(img1, (0, 0))
    dst.paste(img2, (img1.width, 0))
    return dst

# Generate animated GIF from list of same-size images.
def save_image_list_as_gif(image_list, gif_file_name, duration=200):
    image_list[0].save(gif_file_name, format="GIF", append_images=image_list[1:],
                       save_all=True, duration=duration, loop=0)

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
def get_ann_images(experiment_folder, background=(0, 0, 0), foreground=(255, 255, 255)):
    images = get_ordered_snapshot_images(experiment_folder, "*_3ann.png")
    return [ImageOps.colorize(img, background, foreground) for img in images]

# Get all "raw" images in experiment folder.
def get_raw_images(experiment_folder):
    return get_ordered_snapshot_images(experiment_folder, "*_raw.png")

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
def experiment_to_gif(experiment_folder, gif_file_name, mode, gif_file_side=480, duration=200, ann_background=(0, 0, 0),
                      ann_foreground=(255, 255, 255), input_quad=None):
    # Get input quad.
    if input_quad is None:
        import json
        settings_file = f"{experiment_folder}/settings.json"
        data = json.load(open(settings_file, "r"))
        input_quad = tuple(data['camera_quad'])

    # Get image frames.
    ann_frames = get_ann_images(experiment_folder, ann_background, ann_foreground)
    raw_frames = get_raw_images(experiment_folder)

    base_image = Image.open(f"{experiment_folder}/base_image.png")
    raw_transformed_frames = []
    for img in raw_frames:
        __, __, __, __, __, rt = xi.process_image(img, base_image, image_side=28, input_quad=input_quad)
        raw_transformed_frames.append(rt)

    if mode == "ann":
        image_list = resize_square_images(ann_frames, gif_file_side)
    elif mode == "raw":
        image_list = resize_square_images(raw_frames, gif_file_side)
    elif mode == "raw_transformed":
        image_list = resize_square_images(raw_transformed_frames, gif_file_side)
    elif mode == "ann_raw_transformed_concatenated":
        image_list = []
        ann_frames = resize_square_images(ann_frames, gif_file_side)
        raw_transformed_frames = resize_square_images(raw_transformed_frames, gif_file_side)
        for i in range(len(ann_frames) - 1):
            image_list.append(concatenate_horizontal(ann_frames[i], raw_transformed_frames[i]))
    elif mode == "ann_raw_transformed_sequence":
        image_list = []
        ann_frames = resize_square_images(ann_frames, gif_file_side)
        raw_transformed_frames = resize_square_images(raw_transformed_frames, gif_file_side)
        for i in range(len(ann_frames) - 1):
            image_list.append(ann_frames[i])
            image_list.append(raw_transformed_frames[i])
        image_list = crossfade(image_list, 20)
        duration /= 20

    save_image_list_as_gif(image_list, gif_file_name, duration=duration)


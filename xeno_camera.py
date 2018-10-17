import os

import io
from PIL import Image, ImageEnhance, ImageFilter, ImageOps
import time
import numpy

from scipy import stats

# Normalize across RGB channels.
def normalize_rgb(arr):
    """
    Linear normalization
    http://en.wikipedia.org/wiki/Normalization_%28image_processing%29
    """
    arr = arr.astype('float')
    # Do not touch the alpha channel
    for i in range(3):
        minval = arr[...,i].min()
        maxval = arr[...,i].max()
        if minval != maxval:
            arr[...,i] -= minval
            arr[...,i] *= (255.0/(maxval-minval))
    return arr

# Normalize across single channel (grayscale).
def normalize_l(arr):
    """
    Linear normalization
    http://en.wikipedia.org/wiki/Normalization_%28image_processing%29
    """
    arr = arr.astype('float')
    # Do not touch the alpha channel
    minval = arr.min()
    maxval = arr.max()
    if (minval != maxval):
        arr -= minval
        arr *= (255.0/(maxval-minval))
    return arr

# Raspberry Pi camera
if os.uname()[4].startswith('arm'):

    USE_RPI = True

    import picamera
    import picamera.array

    class XenoCamera(picamera.PiCamera):
	    def __init__(self, input_quad=(0, 0, 0, 1, 1, 1, 1, 0), image_side=28):
		    picamera.PiCamera.__init__(self)
		    self.stream = io.BytesIO()
		    self.input_quad = input_quad
		    self.image_side = image_side

	    def start(self):
		    self.start_preview()
		    time.sleep(2) # allow the camera to initialize nicely
		    # Adjust cam
		    cam.iso = 100
		    cam.constrast = 100
		    cam.sharpen = 100
		    time.sleep(2) # not sure if we need to redo this
		    cam.exposure_mode = "off"

	    def stop(self):
		    self.stop_preview()

	    def raw_sample(self, color=False):
		    self.stream.seek(0)
		    self.capture(self.stream, format="png")
		    self.stream.seek(0)
		    if color:
		        return Image.open(self.stream)
		    else:
		        return Image.open(self.stream).convert("L")

	    def sample(self):
		    image = self.raw_sample()
		    # Apply filters on image.
		    image = ImageOps.invert(image)
		    image = ImageOps.autocontrast(image)
		    image = ImageOps.equalize(image)
		    image = image.convert('L')
		    # Apply transforms on image.
		    w = image.size[0]
		    h = image.size[1]
		    input_quad_abs = ( self.input_quad[0]*w, self.input_quad[1]*h, self.input_quad[2]*w, self.input_quad[3]*h, self.input_quad[4]*w, self.input_quad[5]*h, self.input_quad[6]*w, self.input_quad[7]*h )
		    output = image.transform(image.size, Image.QUAD, input_quad_abs).resize((self.image_side, self.image_side))
		    return output

# PC camera
else:

    USE_RPI = False

    import cv2

    class XenoCamera():
	    def __init__(self, input_quad=(0, 0, 0, 1, 1, 1, 1, 0), image_side=28, device_id=0):
		    self.cam = cv2.VideoCapture(device_id)
		    self.input_quad = input_quad
		    self.image_side = image_side

	    def start(self):
		    pass

	    def stop(self):
		    pass

	    def raw_sample(self, color=False):
		    s, im = self.cam.read() # captures image
		    if s:
		        cv2_im = cv2.cvtColor(im, cv2.COLOR_BGR2RGB)
		        if color:
		            pil_im = Image.fromarray(cv2_im)
		        else:
		            pil_im = Image.fromarray(cv2_im).convert("L")
			    #pil_im.show
		        return pil_im
		    else:
			    return None

	    def sample(self):
		    image = self.raw_sample(True)
		    # Apply filters on image.
		    image = ImageOps.invert(image)
		    image = ImageOps.autocontrast(image)
		    image = ImageOps.equalize(image)
		    image = image.convert('L')
		    # Apply transforms on image.
		    w = image.size[0]
		    h = image.size[1]
		    input_quad_abs = ( self.input_quad[0]*w, self.input_quad[1]*h, self.input_quad[2]*w, self.input_quad[3]*h, self.input_quad[4]*w, self.input_quad[5]*h, self.input_quad[6]*w, self.input_quad[7]*h )
		    output = image.transform(image.size, Image.QUAD, input_quad_abs).resize((self.image_side, self.image_side))
		    return output


# Commandline script
import argparse

if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output-file", type=str, default="snapshot.png", help="Output file name for camera snapshot")
    parser.add_argument("-C", "--configuration-file", type=str, default="CameraPerspectiveConfig/camera_perspective.conf", help="Configuration file containing input quad")
    parser.add_argument("-r", "--raw-image", default=False, action='store_true', help="Use raw image")
    parser.add_argument("-c", "--enable-color", default=False, action='store_true', help="Enable color when taking snapshot")
    parser.add_argument("-s", "--show", default=False, action='store_true', help="Show image on screen before saving")
    parser.add_argument("-q", "--input-quad", type=str, default=None, help="Comma-separated list of numbers defining input quad (overrides configuration file)")
    
    if not USE_RPI:
        parser.add_argument("-d", "--device-id", type=int, default=0, help="The video device ID")
    
    args = parser.parse_args()
    
    if args.raw_image:
        input_quad = (0, 0, 0, 1, 1, 1, 1, 1, 0) # dummy
    elif (args.input_quad != None):
        input_quad = tuple([ float(x) for x in args.input_quad.split(',') ])
    else:
    	with open(args.configuration_file, "rb") as f:
	        input_quad = tuple([ float(v) for v in f.readlines() ])

    # Create camera object
    if USE_RPI:
    	cam = XenoCamera(input_quad=input_quad)
    else:
    	cam = XenoCamera(input_quad=input_quad, device_id=args.device_id)
    
    # Sample one image.
    cam.start()
    if args.raw_image:
        output = cam.raw_sample(True)
    else:
        output = cam.sample()
    cam.stop()

    output.show()

    output.save(args.output_file)

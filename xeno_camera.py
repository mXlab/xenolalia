import picamera
import picamera.array
import io
from PIL import Image
import time
import numpy

class XenoCamera(picamera.PiCamera):
	def __init__(self, input_quad, image_side=28):
		picamera.PiCamera.__init__(self)
		self.stream = io.BytesIO()
		self.input_quad = input_quad
		self.image_side = image_side

	def start(self):
		self.start_preview()
		time.sleep(2) # allow the camera to initialize nicely

	def stop(self):
		self.stop_preview()

	def sample(self):
		self.stream.seek(0)
		self.capture(self.stream, format="png")
		self.stream.seek(0)
		image = Image.open(self.stream)
		print "Image created"
		w = image.size[0]
		h = image.size[1]
		#print "Image size: {w}x{h}".format(w=w, h=h)
		input_quad_abs = ( self.input_quad[0]*w, self.input_quad[1]*h, self.input_quad[2]*w, self.input_quad[3]*h, self.input_quad[4]*w, self.input_quad[5]*h, self.input_quad[6]*w, self.input_quad[7]*h )
		output = image.transform(image.size, Image.QUAD, input_quad_abs).convert('L').resize((self.image_side, self.image_side))
		return output

if __name__ == "__main__":
	input_quad = ( 0.35, 0.495, 0.65, 0.2675, 0.78125, 0.3525, 0.3421875, 0.6975 )

	cam = XenoCamera(input_quad)
	cam.start()
	output = cam.sample()
	cam.stop()

	output.save("test.png")

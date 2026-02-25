# tests/test_xeno_image.py
import unittest
import numpy as np
from PIL import Image

# xeno_image imports cv2, skimage etc — these are available in xeno-env on laptop.
import xeno_image


def _filled_circle_image(size=28, radius_frac=0.4):
    """Return a grayscale PIL Image with a white filled circle on black."""
    arr = np.zeros((size, size), dtype=np.uint8)
    cx, cy = size // 2, size // 2
    radius = int(size * radius_frac)
    for y in range(size):
        for x in range(size):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2:
                arr[y, x] = 255
    return Image.fromarray(arr, mode='L')


def _solid_white_image(size=28):
    """Return a grayscale PIL Image filled entirely with white (255)."""
    return Image.fromarray(np.full((size, size), 255, dtype=np.uint8), mode='L')


def _solid_black_image(size=28):
    """Return a grayscale PIL Image filled entirely with black (0)."""
    return Image.fromarray(np.zeros((size, size), dtype=np.uint8), mode='L')


class TestPostprocessOutput(unittest.TestCase):

    def test_output_size_matches_parameter(self):
        """postprocess_output() must return an image of exactly output_size × output_size."""
        img = _filled_circle_image()
        result = xeno_image.postprocess_output(img, output_size=112)
        self.assertEqual(result.size, (112, 112))

    def test_filled_circle_becomes_hollow(self):
        """Centre pixel of a large filled circle must be black after postprocessing
        (boundary extraction hollows out filled shapes)."""
        img = _filled_circle_image(size=28, radius_frac=0.45)
        result = xeno_image.postprocess_output(img, output_size=224, line_width=1)
        arr = np.array(result)
        cx, cy = 112, 112  # centre of 224×224
        self.assertEqual(arr[cy, cx], 0,
            "Centre of a filled circle should be black (hollow) after boundary extraction.")

    def test_solid_black_stays_black(self):
        """An all-black input must produce an all-black output (no boundary to extract)."""
        img = _solid_black_image()
        result = xeno_image.postprocess_output(img, output_size=112)
        arr = np.array(result)
        self.assertEqual(arr.max(), 0,
            "All-black input should produce all-black output.")

    def test_solid_white_becomes_border_only(self):
        """An all-white input: after boundary extraction, interior pixels are black."""
        img = _solid_white_image()
        result = xeno_image.postprocess_output(img, output_size=65, line_width=1)
        arr = np.array(result)
        # The very centre must be black (65 is odd, so centre is unambiguous at index 32)
        cx, cy = 32, 32
        self.assertEqual(arr[cy, cx], 0,
            "Centre of all-white input must be black after boundary extraction.")

    def test_area_max_constrains_lit_pixels(self):
        """With output_area_max=0.1, at most ~10 % of pixels should be non-zero."""
        img = _filled_circle_image()
        result = xeno_image.postprocess_output(img, output_size=112, area_max=0.1)
        arr = np.array(result)
        lit_fraction = np.count_nonzero(arr) / arr.size
        self.assertLessEqual(lit_fraction, 0.15,
            "output_area_max=0.1 should keep lit pixels well below 15 %.")

    def test_line_width_zero_produces_thinner_result_than_line_width_four(self):
        """Larger line_width must produce more lit pixels than line_width=0."""
        img = _filled_circle_image()
        r0 = xeno_image.postprocess_output(img, output_size=112, line_width=0)
        r4 = xeno_image.postprocess_output(img, output_size=112, line_width=4)
        lit0 = np.count_nonzero(np.array(r0))
        lit4 = np.count_nonzero(np.array(r4))
        self.assertLess(lit0, lit4,
            "line_width=4 must produce more lit pixels than line_width=0.")

    def test_threshold_controls_binarisation(self):
        """A lower threshold value should produce more lit pixels than a higher one.

        Given a mid-grey image (pixel value ~128, normalised ~0.5), a threshold
        of 0.4 is below the pixel intensity so more pixels pass as 'on', whereas
        a threshold of 0.6 is above it so fewer (or none) pass.
        """
        # Build a uniform mid-grey image (value 128 out of 255, ~0.502 normalised)
        arr = np.full((28, 28), 128, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')

        result_low = xeno_image.postprocess_output(img, output_size=112, threshold=0.4)
        result_high = xeno_image.postprocess_output(img, output_size=112, threshold=0.6)

        lit_low = np.count_nonzero(np.array(result_low))
        lit_high = np.count_nonzero(np.array(result_high))

        self.assertGreater(lit_low, lit_high,
            "threshold=0.4 should produce more lit pixels than threshold=0.6 "
            "on a mid-grey image.")

    def test_returns_pil_image(self):
        """postprocess_output() must return a PIL Image."""
        img = _filled_circle_image()
        result = xeno_image.postprocess_output(img)
        self.assertIsInstance(result, Image.Image)


if __name__ == '__main__':
    unittest.main()

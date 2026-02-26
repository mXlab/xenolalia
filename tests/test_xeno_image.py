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
        (thick components are hollowed out)."""
        img = _filled_circle_image(size=28, radius_frac=0.45)
        result = xeno_image.postprocess_output(img, output_size=224)
        arr = np.array(result)
        cx, cy = 112, 112  # centre of 224×224
        self.assertEqual(arr[cy, cx], 0,
            "Centre of a filled circle should be black (hollow) after postprocessing.")

    def test_solid_black_stays_black(self):
        """An all-black input must produce an all-black output (no boundary to extract)."""
        img = _solid_black_image()
        result = xeno_image.postprocess_output(img, output_size=112)
        arr = np.array(result)
        self.assertEqual(arr.max(), 0,
            "All-black input should produce all-black output.")

    def test_solid_white_becomes_border_only(self):
        """An all-white input: thick component hollowed out, so interior is black."""
        img = _solid_white_image()
        result = xeno_image.postprocess_output(img, output_size=65)
        arr = np.array(result)
        # The very centre must be black (65 is odd, so centre is unambiguous at index 32)
        cx, cy = 32, 32
        self.assertEqual(arr[cy, cx], 0,
            "Centre of all-white input must be black after postprocessing.")

    def test_area_max_constrains_lit_pixels(self):
        """area_max limits the fraction of pixels that pass binarisation.

        Uses a gradient image so the percentile threshold must reason over a
        real distribution, not a degenerate binary one.
        """
        # Horizontal gradient 0–255: a genuine spread of values for percentile threshold.
        arr = np.tile(np.linspace(0, 255, 28, dtype=np.uint8), (28, 1))
        img = Image.fromarray(arr, mode='L')
        # With area_max=0.1 only the top 10 % of pixel values should pass before
        # boundary extraction, so final lit fraction must be well below that.
        result = xeno_image.postprocess_output(img, output_size=112, area_max=0.1)
        out_arr = np.array(result)
        lit_fraction = np.count_nonzero(out_arr) / out_arr.size
        self.assertLessEqual(lit_fraction, 0.10,
            "area_max=0.1 should keep final lit fraction at or below 10 %.")

    def test_larger_boundary_px_produces_more_lit_pixels(self):
        """A larger boundary_px must produce more lit pixels for a thick shape."""
        img = _filled_circle_image(size=28, radius_frac=0.45)
        r_small = xeno_image.postprocess_output(img, output_size=224, boundary_px=5)
        r_large = xeno_image.postprocess_output(img, output_size=224, boundary_px=20)
        lit_small = np.count_nonzero(np.array(r_small))
        lit_large = np.count_nonzero(np.array(r_large))
        self.assertLess(lit_small, lit_large,
            "boundary_px=20 must produce more lit pixels than boundary_px=5.")

    def test_threshold_controls_binarisation(self):
        """A lower threshold value should produce more lit pixels than a higher one.

        Given a mid-grey image (pixel value ~128, normalised ~0.5), a threshold
        of 0.4 is below the pixel intensity so more pixels pass as 'on', whereas
        a threshold of 0.6 is above it so fewer (or none) pass.
        """
        # Build a uniform mid-grey image (value 128 out of 255, ~0.502 normalised)
        arr = np.full((28, 28), 128, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')

        result_low = xeno_image.postprocess_output(img, output_size=112, threshold=0.4, stroke_width=5)
        result_high = xeno_image.postprocess_output(img, output_size=112, threshold=0.6, stroke_width=5)

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


def _semicircle_image(size=224):
    """White top-half disc on black background, simulating petri dish content."""
    arr = np.zeros((size, size, 3), dtype=np.uint8)
    y_idx, x_idx = np.ogrid[:size, :size]
    disc = (x_idx - size//2)**2 + (y_idx - size//2)**2 <= (size//2 - 2)**2
    top = y_idx < size // 2
    arr[disc & top] = 255
    return Image.fromarray(arr, 'RGB')


class TestProcessImageSquircle(unittest.TestCase):

    def test_process_image_squircle_output_shape(self):
        """use_squircle=True must not change the output shape."""
        img = _semicircle_image()
        resized, _, _, _, _, _ = xeno_image.process_image(img, use_squircle=True)
        self.assertEqual(resized.size, (28, 28))

    def test_process_image_squircle_changes_output(self):
        """use_squircle=True must produce a different 28x28 result than False."""
        img = _semicircle_image()
        sq, _, _, _, _, _ = xeno_image.process_image(img, use_squircle=True)
        no, _, _, _, _, _ = xeno_image.process_image(img, use_squircle=False)
        self.assertFalse(
            np.array_equal(np.array(sq), np.array(no)),
            "squircle remapping should change the output image"
        )


if __name__ == '__main__':
    unittest.main()

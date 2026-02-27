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
        """squircle_mode='inside' must not change the output shape."""
        img = _semicircle_image()
        resized, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="inside")
        self.assertEqual(resized.size, (28, 28))

    def test_process_image_squircle_changes_output(self):
        """squircle_mode='inside' must produce a different 28x28 result than 'none'."""
        img = _semicircle_image()
        sq, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="inside")
        no, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="none")
        self.assertFalse(
            np.array_equal(np.array(sq), np.array(no)),
            "squircle remapping should change the output image"
        )

    def test_process_image_outside_output_shape(self):
        """squircle_mode='outside' must not change the output shape."""
        img = _semicircle_image()
        resized, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="outside")
        self.assertEqual(resized.size, (28, 28))

    def test_process_image_outside_differs_from_inside(self):
        """squircle_mode='outside' must produce a different result than 'inside'."""
        img = _semicircle_image()
        out, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="outside")
        ins, _, _, _, _, _ = xeno_image.process_image(img, squircle_mode="inside")
        self.assertFalse(
            np.array_equal(np.array(out), np.array(ins)),
            "squircle_mode='outside' should differ from 'inside'"
        )

    def test_process_image_outside_preserves_corner_content(self):
        """squircle_mode='outside' should skip add_mask, preserving outer annulus content.

        The xeno_mask.png is a white radial vignette: it whitens (makes near-255)
        the outer border of the image.  When add_mask IS applied before
        to_square_outside, the annulus content is whitened, so output corners end
        up near 255 regardless of the original pixel value.  When add_mask is
        SKIPPED, the output corners reflect the original source content.

        Test strategy: use a mid-gray source (100) and assert that the near-corner
        pixels of the output are NOT near-white (i.e., < 200). This can only hold
        if the mask was skipped; if the mask ran first, the annulus would be
        near-white and the corners would be > 200.
        """
        arr = np.full((224, 224, 3), 100, dtype=np.uint8)
        img = Image.fromarray(arr, mode='RGB')
        _, _, _, masked, _, _ = xeno_image.process_image(img, squircle_mode="outside")
        result = np.array(masked)
        inset = 5
        n = result.shape[0]
        for r, c in [(inset, inset), (inset, n-1-inset), (n-1-inset, inset), (n-1-inset, n-1-inset)]:
            self.assertLess(result[r, c], 200,
                f"Corner ({r},{c})={result[r,c]} is near-white — mask was applied before "
                f"to_square_outside, whitening the annulus. Expected original content (~100).")

    def test_process_image_none_still_masks_corners(self):
        """squircle_mode='none' should still apply add_mask, whitening outer corners.

        The xeno_mask.png is a white radial vignette with near-opaque alpha at the
        border, so corners are whitened (near 255) after compositing.
        """
        arr = np.full((224, 224, 3), 100, dtype=np.uint8)
        img = Image.fromarray(arr, mode='RGB')
        _, _, _, masked, _, _ = xeno_image.process_image(img, squircle_mode="none")
        result = np.array(masked)
        # masked is RGB; sample the red channel for each corner pixel
        for r, c in [(0, 0), (0, 223), (223, 0), (223, 223)]:
            self.assertGreater(result[r, c, 0], 200,
                f"Corner ({r},{c}) R={result[r,c,0]} should be near-white after add_mask vignette")


class TestSquircleOutside(unittest.TestCase):

    def test_to_circle_outside_all_corners_populated(self):
        """to_circle_outside must populate all four canvas corners (circumscribed disc)."""
        arr = np.full((224, 224), 255, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')
        result = np.array(xeno_image.to_circle_outside(img))
        for corner in [(0, 0), (0, 223), (223, 0), (223, 223)]:
            self.assertGreater(result[corner], 0,
                f"Corner {corner} is black — disc is not circumscribing the square")

    def test_to_circle_outside_output_shape(self):
        """to_circle_outside must return an image of the same size as input."""
        img = Image.fromarray(np.full((112, 112), 200, dtype=np.uint8), mode='L')
        result = xeno_image.to_circle_outside(img)
        self.assertEqual(np.array(result).shape, (112, 112))

    def test_to_circle_outside_differs_from_inside(self):
        """to_circle_outside must produce a different result than squircle.to_circle."""
        import squircle
        ramp = np.tile(np.arange(224, dtype=np.uint8), (224, 1))
        img = Image.fromarray(ramp, mode='L')
        outside = np.array(xeno_image.to_circle_outside(img))
        inside = squircle.to_circle(ramp)
        self.assertFalse(np.array_equal(outside, inside))

    def test_to_square_outside_output_shape(self):
        """to_square_outside must return an image of the same size as input."""
        img = Image.fromarray(np.full((112, 112), 200, dtype=np.uint8), mode='L')
        result = xeno_image.to_square_outside(img)
        self.assertEqual(np.array(result).shape, (112, 112))

    def test_to_square_outside_full_square_covered(self):
        """to_square_outside maps the full circumscribed disc into the square — corners included.

        Pixels 5 inset from each corner are checked rather than the exact corner
        pixels: the FGS inverse maps output corners to source coords at the very
        edge of the image (map_x ~ n-1 + epsilon), which cv2.remap bilinearly
        blends with borderValue=0 to near-zero. Five pixels inset, all four
        near-corner regions are solidly populated.
        """
        n = 224
        inset = 5
        arr = np.full((n, n), 100, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')
        result = np.array(xeno_image.to_square_outside(img))
        for r, c in [(inset, inset), (inset, n-1-inset), (n-1-inset, inset), (n-1-inset, n-1-inset)]:
            self.assertGreater(result[r, c], 0, f"Near-corner ({r},{c}) is black — square not fully covered")


    def test_to_square_outside_all_corners_not_zero(self):
        """to_square_outside must not produce near-zero exact corner pixels.
        Before clamping, the FGS mapping sends 3 of 4 corners to source coords
        at pixel n (out of bounds), blending with borderValue=0 to near-zero.
        After clamping, all corners use the nearest valid source pixel.
        """
        arr = np.full((224, 224), 255, dtype=np.uint8)
        img = Image.fromarray(arr, mode='L')
        result = np.array(xeno_image.to_square_outside(img))
        n = result.shape[0]
        threshold = 200  # well above near-zero (~0.8) from unclamped OOB blending
        for r, c in [(0, 0), (0, n-1), (n-1, 0), (n-1, n-1)]:
            self.assertGreater(result[r, c], threshold,
                f"Corner ({r},{c})={result[r,c]} is near-zero — source coords not clamped")


if __name__ == '__main__':
    unittest.main()

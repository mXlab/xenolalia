# tests/test_regression_pipeline.py
import glob
import json
import os
import unittest

import numpy as np
from PIL import Image

import xeno_image

SNAPSHOTS_BASE = os.path.join(os.path.dirname(__file__), '..', 'XenoPi', 'snapshots')


def _collect_cases():
    """Return list of (raw_path, ref_path, camera_quad, base_image_path) for all sessions."""
    cases = []
    # NOTE: "eisode" is the actual spelling used in data directory names (typo in session names).
    pattern = os.path.join(SNAPSHOTS_BASE, '*eisode-preparation-2026*')
    for session_dir in sorted(glob.glob(pattern)):
        settings_path = os.path.join(session_dir, 'settings.json')
        if not os.path.exists(settings_path):
            continue
        with open(settings_path) as f:
            settings = json.load(f)
        camera_quad = tuple(settings['camera_quad'])
        use_base_image = settings.get('use_base_image', False)
        base_image_path = os.path.join(session_dir, 'base_image.png') if use_base_image else False
        if base_image_path and not os.path.exists(base_image_path):
            base_image_path = False
        for raw_path in sorted(glob.glob(os.path.join(session_dir, 'snapshot_*_raw.png'))):
            basename = os.path.splitext(os.path.basename(raw_path))[0]
            ref_path = os.path.join(session_dir, basename + '_2res.png')
            if os.path.exists(ref_path):
                cases.append((raw_path, ref_path, camera_quad, base_image_path))
    return cases


class TestRegressionPipeline(unittest.TestCase):

    def test_no_squircle_matches_stored_outputs(self):
        """use_squircle=False must reproduce stored _2res.png exactly for all sessions."""
        cases = _collect_cases()
        self.assertGreater(len(cases), 0, "No regression cases found — check SNAPSHOTS_BASE path")
        failures = []
        for raw_path, ref_path, camera_quad, base_image_path in cases:
            resized, _, _, _, _, _ = xeno_image.load_image(
                raw_path, base_image_path,
                image_side=28, input_quad=camera_quad,
                use_squircle=False
            )
            ref = Image.open(ref_path).convert('L')
            if not np.array_equal(np.array(resized), np.array(ref)):
                failures.append(os.path.relpath(raw_path))
        if failures:
            self.fail(f"Pipeline output differs from stored _2res.png:\n" + "\n".join(failures))


if __name__ == '__main__':
    unittest.main()

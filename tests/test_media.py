import unittest
from scripts.media import validate_clips


class ManifestTests(unittest.TestCase):
    def test_valid(self):
        data = [{"name": "auto-layout", "start": "00:05:20", "duration": "00:01:25"}]
        self.assertEqual(validate_clips(data), data)

    def test_path_traversal(self):
        with self.assertRaises(ValueError):
            validate_clips([{"name": "../evil", "start": "00:01:00", "duration": "00:00:05"}])

    def test_duplicates(self):
        clip = {"name": "one", "start": "00:01:00", "duration": "00:00:05"}
        with self.assertRaises(ValueError):
            validate_clips([clip, clip])

    def test_bad_timestamp(self):
        with self.assertRaises(ValueError):
            validate_clips([{"name": "one", "start": "wrong", "duration": "00:00:05"}])

    def test_zero_duration(self):
        with self.assertRaises(ValueError):
            validate_clips([{"name": "one", "start": "00:00:10", "duration": "00:00:00"}])

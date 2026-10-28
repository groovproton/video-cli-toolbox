import unittest
import tempfile
from pathlib import Path
from scripts.media import validate_clips, safe_clean


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


class CleanTests(unittest.TestCase):
    def test_reject_root(self):
        root = Path(__file__).resolve().parent.parent
        with self.assertRaises(ValueError):
            safe_clean(str(root))

    def test_reject_parent(self):
        root = Path(__file__).resolve().parent.parent
        with self.assertRaises(ValueError):
            safe_clean(str(root / ".."))

    def test_reject_source(self):
        root = Path(__file__).resolve().parent.parent
        with self.assertRaises(ValueError):
            safe_clean(str(root / "scripts"))

    def test_clean_safe_directory(self):
        root = Path(__file__).resolve().parent.parent
        with tempfile.TemporaryDirectory(dir=root, prefix=".test-output-") as td:
            target = Path(td) / "generated"
            target.mkdir()
            (target / "video.txt").write_text("test")
            safe_clean(str(target))
            self.assertFalse(target.exists())

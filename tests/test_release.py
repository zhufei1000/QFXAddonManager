import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import release


class ReleaseTests(unittest.TestCase):
    def test_tag_must_match_all_packages(self):
        info = release.release_info()
        self.assertEqual(info["project_id"], 1773703)
        self.assertEqual(release.release_info(info["tag"]), info)
        for invalid in ("v0.0.0", info["version"], "main", "v1.1.11;echo bad"):
            with self.assertRaises(ValueError):
                release.release_info(invalid)

    def test_upload_contains_the_verified_zip_and_metadata(self):
        info = release.release_info()
        info["sha256"] = "fixture-checksum"
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / info["asset"]
            path.write_bytes(b"PK-test-archive")
            response = io.BytesIO(b'{"id": 12345}')
            with mock.patch("urllib.request.urlopen", return_value=response) as request:
                receipt = release.upload_curseforge(path, info, "Release notes", "test-key")
            sent = request.call_args.args[0]
            self.assertEqual(sent.full_url, "https://wow.curseforge.com/api/projects/1773703/upload-file")
            self.assertEqual(sent.get_method(), "POST")
            self.assertNotIn("test-key", sent.full_url)
            self.assertEqual(sent.get_header("X-api-token"), "test-key")
            self.assertIn(b'PK-test-archive', sent.data)
            self.assertIn(b'"changelogType": "markdown"', sent.data)
            self.assertIn(b'"gameVersionNames"', sent.data)
            self.assertEqual(receipt["file_id"], 12345)
            self.assertEqual(receipt["project_id"], 1773703)

    def test_missing_key_sends_no_upload(self):
        with mock.patch("urllib.request.urlopen") as request:
            with self.assertRaises(ValueError):
                release.upload_curseforge(Path("not-read.zip"), {}, "", " ")
            request.assert_not_called()

    def test_missing_key_cannot_create_a_github_release(self):
        info = release.release_info()
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            package = directory / info["asset"]
            package.write_bytes(b"PK-test")
            saved = {**info, "sha256": release.digest(package)}
            (directory / "release-manifest.json").write_text(json.dumps(saved), encoding="utf-8")
            (directory / (info["asset"] + ".sha256")).write_text(
                saved["sha256"] + "  " + info["asset"] + "\n", encoding="ascii")
            with mock.patch.dict("os.environ", {"CF_API_KEY": "", "GITHUB_REF": "refs/tags/" + info["tag"]}), \
                    mock.patch.object(release.build_addon, "validate_archive"), \
                    mock.patch.object(release, "gh") as github:
                with self.assertRaisesRegex(ValueError, "CF_API_KEY"):
                    release.publish(directory, info["tag"])
                github.assert_not_called()

    def test_failed_upload_is_not_automatically_retried(self):
        info = release.release_info()
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / info["asset"]
            path.write_bytes(b"PK-test")
            failure = urllib.error.HTTPError("https://wow.curseforge.com/api", 403, "Forbidden", {}, None)
            with mock.patch("urllib.request.urlopen", side_effect=failure) as request:
                with self.assertRaisesRegex(ValueError, "HTTP 403"):
                    release.upload_curseforge(path, info, "notes", "test-key")
                self.assertEqual(request.call_count, 1)

    def test_bad_upload_response_is_not_reported_as_success(self):
        info = release.release_info()
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / info["asset"]
            path.write_bytes(b"PK-test")
            for payload in ({}, {"id": False}, {"id": -1}):
                with mock.patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps(payload).encode())):
                    with self.assertRaisesRegex(ValueError, "valid file ID"):
                        release.upload_curseforge(path, info, "notes", "test-key")


if __name__ == "__main__":
    unittest.main()

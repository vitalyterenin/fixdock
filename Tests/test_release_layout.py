import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Scripts'))
import release

class Response:
    def __init__(self, body): self.body = body
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def read(self): return self.body

class PreviousFeedTests(unittest.TestCase):
    def test_first_publication_has_no_prior_feed(self):
        with tempfile.TemporaryDirectory() as d, patch.object(release.urllib.request, 'urlopen', side_effect=HTTPError('url',404,'missing',{},None)):
            path = Path(d) / 'previous.xml'
            release.previous(path)
            self.assertFalse(path.exists())
            self.assertIsNone(json.loads(path.with_suffix('.state.json').read_text())['previousFeedSHA256'])

    def test_existing_app_cannot_silently_become_a_first_release(self):
        data = release.config()
        data['legacyFeedURLs'] = ['https://teren.in/apps/feeds/fixdock.xml']
        with tempfile.TemporaryDirectory() as d, patch.object(release, 'config', return_value=data), patch.object(release.urllib.request, 'urlopen', side_effect=HTTPError('url',404,'missing',{},None)):
            with self.assertRaisesRegex(ValueError,'established'):
                release.previous(Path(d) / 'previous.xml')

    def test_previous_feed_records_exact_hash(self):
        body = b'<rss><channel/></rss>'
        with tempfile.TemporaryDirectory() as d, patch.object(release.urllib.request, 'urlopen', return_value=Response(body)):
            path = Path(d) / 'previous.xml'
            release.previous(path)
            state = json.loads(path.with_suffix('.state.json').read_text())
            self.assertEqual(state['sourceURL'], release.config()['feedURL'])
            self.assertEqual(state['previousFeedSHA256'], hashlib.sha256(body).hexdigest())

    def test_download_must_belong_to_its_repository(self):
        data = release.config()
        data['downloadURL'] = 'https://github.com/other/repo/releases/latest/download/' + release.ARCHIVE_NAME
        with patch.object(release.json, 'loads', return_value=data), self.assertRaises(ValueError):
            release.config()

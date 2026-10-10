import json
import tempfile
import unittest
from pathlib import Path
from stage_roast_release import stage


class StageTests(unittest.TestCase):
    def test_content_only_stage_disable_and_rollback_preserve_site(self):
        with tempfile.TemporaryDirectory() as directory:
            public = Path(directory)
            (public / 'index.html').write_text('approved deployed app')
            first = stage('build/roast_release', public, 'https://example.invalid')
            self.assertEqual(first['status'], 'staged locally; not deployed')
            self.assertEqual((public / 'index.html').read_text(), 'approved deployed app')
            disabled = stage('build/roast_release', public, 'https://example.invalid',
                             ['karen_batch01_clear_001'], False)
            self.assertFalse(disabled['downloads_enabled'])
            self.assertEqual(disabled['disabled_ids'], ['karen_batch01_clear_001'])
            # Re-staging an archived known-good release is the rollback command.
            stage('build/roast_release', public, 'https://example.invalid')
            current = json.loads((public / 'content/roasts/manifest.json').read_text())
            self.assertTrue(current['downloads_enabled'])
            self.assertEqual(current['disabled_ids'], [])
            shard = next((public / 'content/roasts/packs').glob('*.json'))
            shard.write_text('corrupt existing immutable file')
            with self.assertRaisesRegex(ValueError, 'immutable'):
                stage('build/roast_release', public, 'https://example.invalid')

    def test_unverified_non_https_shape_rejected(self):
        for origin in ['http://example.invalid', 'https://u:p@example.invalid',
                       'https://example.invalid/content', 'https://example.invalid?key=x']:
            with self.assertRaises(ValueError):
                stage('build/roast_release', '/unused', origin)


if __name__ == '__main__':
    unittest.main()

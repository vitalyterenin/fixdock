import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Scripts'))
import signing


class SigningIdentityTests(unittest.TestCase):
    def test_changed_certificate_cannot_silently_replace_the_release_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Resources').mkdir()
            (root / 'Resources/ReleaseSigning.cer').write_bytes(b'different identity')
            (root / 'release.json').write_text(json.dumps({
                'codeSigningCertificateSHA256': hashlib.sha256(b'approved identity').hexdigest()}))
            with patch.object(signing, 'ROOT', root), self.assertRaisesRegex(ValueError, 'pinned'):
                signing.certificate()

    def test_content_hash_or_identifier_only_requirements_are_rejected(self):
        der = signing.certificate()
        for requirement in ['cdhash H"1234"', f'identifier "{signing.APP_ID}"',
                            f'identifier "{signing.APP_ID}" or true']:
            with self.assertRaises(ValueError):
                signing.check_requirement('designated => ' + requirement, signing.APP_ID, der)

    def test_a_different_certificate_or_bundle_identifier_is_rejected(self):
        der = signing.certificate()
        for identifier, cert in [('another.app', der), (signing.APP_ID, b'another certificate')]:
            requirement = f'designated => identifier "{identifier}" and certificate root = H"{hashlib.sha1(cert).hexdigest()}"'
            with self.assertRaises(ValueError):
                signing.check_requirement(requirement, signing.APP_ID, der)

    def test_release_build_cannot_fall_back_to_ad_hoc_without_a_keychain(self):
        with patch.dict(signing.os.environ, {'FIXDOCK_REQUIRE_RELEASE_SIGNING': '1', 'FIXDOCK_SIGN_KEYCHAIN': ''}):
            with patch.object(signing, 'run') as command, self.assertRaisesRegex(ValueError, 'required'):
                signing.sign(Path('Fixdock.app'))
            command.assert_not_called()

    def test_missing_ci_secrets_cannot_create_a_keychain(self):
        with patch.dict(signing.os.environ, {'FIXDOCK_SIGNING_P12': '', 'FIXDOCK_SIGNING_PASSWORD': ''}):
            with patch.object(signing, 'run') as command, self.assertRaisesRegex(ValueError, 'secrets'):
                signing.import_ci('unused.keychain-db')
            command.assert_not_called()


    def test_ci_restores_exact_search_list_after_success_or_signing_failure(self):
        for failing in [False, True]:
            calls = []
            def command(*args):
                calls.append(args)
                if args == ('security', 'list-keychains', '-d', 'user'):
                    return '"/runner/login keychain"\n"/runner/system.keychain"'
                if args[0] == 'codesign' and failing:
                    raise ValueError('codesign failed')
                return ''
            with patch.dict(signing.os.environ, {'GITHUB_ACTIONS':'true', 'FIXDOCK_SIGN_KEYCHAIN':'/runner/isolated.keychain', 'FIXDOCK_REQUIRE_RELEASE_SIGNING':'1'}), patch.object(signing,'run',side_effect=command), patch.object(signing,'components',return_value=[Path('Fixdock.app')]), patch.object(signing,'verify'):
                if failing:
                    with self.assertRaisesRegex(ValueError,'codesign failed'): signing.sign(Path('Fixdock.app'))
                else:
                    signing.sign(Path('Fixdock.app'))
            self.assertEqual(calls[-1], ('security','list-keychains','-d','user','-s','/runner/login keychain','/runner/system.keychain'))
            self.assertIn(('security','list-keychains','-d','user','-s','/runner/isolated.keychain','/runner/login keychain','/runner/system.keychain'),calls)

    def test_local_signing_does_not_touch_keychain_search_list(self):
        with patch.dict(signing.os.environ, {'GITHUB_ACTIONS':'', 'FIXDOCK_SIGN_KEYCHAIN':'/local/identity.keychain'}), patch.object(signing,'run',return_value='') as command, patch.object(signing,'components',return_value=[Path('Fixdock.app')]), patch.object(signing,'verify'):
            signing.sign(Path('Fixdock.app'))
        self.assertTrue(command.call_args_list)
        self.assertTrue(all(call.args[0]=='codesign' for call in command.call_args_list))


if __name__ == '__main__':
    unittest.main()

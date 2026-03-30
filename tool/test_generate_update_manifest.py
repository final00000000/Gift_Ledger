import importlib.util
import pathlib
import unittest

MODULE_PATH = pathlib.Path(__file__).with_name('generate_update_manifest.py')
SPEC = importlib.util.spec_from_file_location('generate_update_manifest', MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class GenerateUpdateManifestTest(unittest.TestCase):
    def test_android_variants_are_preserved_in_manifest(self) -> None:
        manifest = MODULE.build_manifest(
            {
                'schemaVersion': 1,
                'entries': [
                    {
                        'channel': 'stable',
                        'platform': 'android',
                        'version': '1.3.2',
                        'buildNumber': 1030299,
                        'packageType': 'apk',
                        'downloadUrl': 'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
                        'sha256': 'c' * 64,
                        'notes': 'Android stable',
                        'variants': {
                            'armeabi-v7a': {
                                'packageType': 'apk',
                                'downloadUrl': 'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-armeabi-v7a.apk',
                                'sha256': 'b' * 64,
                            },
                            'arm64-v8a': {
                                'packageType': 'apk',
                                'downloadUrl': 'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
                                'sha256': 'c' * 64,
                            },
                        },
                    },
                    {
                        'channel': 'stable',
                        'platform': 'windows',
                        'version': '1.3.2',
                        'buildNumber': 1030299,
                        'packageType': 'exe',
                        'downloadUrl': 'https://example.com/gift_ledger-stable-windows-v1.3.2-build1030299-setup.exe',
                        'sha256': 'd' * 64,
                        'notes': 'Windows stable',
                    },
                ],
            }
        )

        android_entry = manifest['channels']['stable']['android']
        self.assertEqual(
            android_entry['downloadUrl'],
            'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
        )
        self.assertEqual(
            android_entry['variants']['armeabi-v7a']['downloadUrl'],
            'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-armeabi-v7a.apk',
        )
        self.assertEqual(
            android_entry['variants']['arm64-v8a']['sha256'],
            'c' * 64,
        )

    def test_invalid_android_variant_abi_is_rejected(self) -> None:
        with self.assertRaisesRegex(MODULE.ManifestGenerationError, '仅支持'):
            MODULE.build_manifest(
                {
                    'entries': [
                        {
                            'channel': 'stable',
                            'platform': 'android',
                            'version': '1.3.2',
                            'buildNumber': 1030299,
                            'packageType': 'apk',
                            'downloadUrl': 'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
                            'sha256': 'a' * 64,
                            'notes': 'Android stable',
                            'variants': {
                                'x86_64': {
                                    'packageType': 'apk',
                                    'downloadUrl': 'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-x86_64.apk',
                                    'sha256': 'b' * 64,
                                },
                            },
                        },
                    ],
                }
            )


if __name__ == '__main__':
    unittest.main()

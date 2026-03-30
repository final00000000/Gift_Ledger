import importlib.util
import pathlib
import unittest

MODULE_PATH = pathlib.Path(__file__).with_name('resolve_release_metadata.py')
SPEC = importlib.util.spec_from_file_location('resolve_release_metadata', MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class ResolveReleaseMetadataTest(unittest.TestCase):
    def test_stable_build_number_uses_fixed_width_and_stable_suffix(self) -> None:
        self.assertEqual(MODULE.derive_build_number('1.3.1'), 1030199)

    def test_beta_build_number_is_lower_than_same_core_stable(self) -> None:
        self.assertEqual(MODULE.derive_build_number('1.3.1-beta.2'), 1030102)
        self.assertLess(
            MODULE.derive_build_number('1.3.1-beta.2'),
            MODULE.derive_build_number('1.3.1'),
        )

    def test_patch_double_digit_stays_lower_than_next_minor(self) -> None:
        self.assertLess(
            MODULE.derive_build_number('1.3.10'),
            MODULE.derive_build_number('1.4.0'),
        )

    def test_minor_or_patch_reaching_three_digits_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, 'must stay below 100'):
            MODULE.derive_build_number('1.100.0')

        with self.assertRaisesRegex(ValueError, 'must stay below 100'):
            MODULE.derive_build_number('1.3.100')

    def test_beta_requires_prerelease_semver(self) -> None:
        with self.assertRaisesRegex(ValueError, 'Beta releases require'):
            MODULE.resolve_channel_and_release_tag(
                event_name='workflow_dispatch',
                input_channel='beta',
                input_release_tag='',
                ref_name='',
                pubspec_semver='1.3.1',
            )

    def test_prerelease_release_tag_infers_beta_channel(self) -> None:
        semver, channel, release_tag = MODULE.resolve_channel_and_release_tag(
            event_name='workflow_dispatch',
            input_channel='',
            input_release_tag='v1.3.1-beta.2',
            ref_name='',
            pubspec_semver='1.3.1',
        )
        self.assertEqual(semver, '1.3.1-beta.2')
        self.assertEqual(channel, 'beta')
        self.assertEqual(release_tag, 'v1.3.1-beta.2')

    def test_android_asset_names_only_include_split_abis(self) -> None:
        names = MODULE.build_asset_names(
            app_name='gift_ledger',
            channel='stable',
            platform='android',
            semver='1.3.2',
            build_number=1030299,
        )
        self.assertEqual(
            names['asset_name'],
            'gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
        )
        self.assertEqual(
            names['asset_name_armeabi_v7a'],
            'gift_ledger-stable-android-v1.3.2-build1030299-armeabi-v7a.apk',
        )
        self.assertEqual(
            names['asset_name_arm64_v8a'],
            'gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
        )

    def test_unsupported_platform_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, 'Unsupported platform'):
            MODULE.build_asset_names(
                app_name='gift_ledger',
                channel='stable',
                platform='ios',
                semver='1.3.2',
                build_number=1030299,
            )


if __name__ == '__main__':
    unittest.main()

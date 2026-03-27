import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';

Map<String, dynamic> _manifestJsonWithStableWindowsOverrides(
  Map<String, dynamic> stableWindowsOverrides,
) {
  return {
    'stable': {
      'windows': {
        'version': '1.3.0',
        'buildNumber': 13,
        'downloadUrl': 'https://example.com/stable/GiftLedgerSetup.exe',
        'sha256':
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        'packageType': 'exe',
        ...stableWindowsOverrides,
      },
    },
    'beta': {
      'windows': {
        'version': '1.3.1-beta.2',
        'buildNumber': 14,
        'downloadUrl': 'https://example.com/beta/GiftLedgerSetup.exe',
        'sha256':
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        'packageType': 'exe',
      },
    },
  };
}

void main() {
  group('UpdateManifest', () {
    test('能解析 stable/beta 下的 android/windows 节点', () {
      const manifestJson = '''
{
  "stable": {
    "android": {
      "version": "1.3.0",
      "buildNumber": 13,
      "downloadUrl": "https://example.com/stable/app-release.apk",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "packageType": "apk"
    },
    "windows": {
      "version": "1.3.0",
      "buildNumber": 13,
      "downloadUrl": "https://example.com/stable/GiftLedgerSetup.exe",
      "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "packageType": "exe"
    }
  },
  "beta": {
    "android": {
      "version": "1.3.1-beta.2",
      "buildNumber": 14,
      "downloadUrl": "https://example.com/beta/app-release.apk",
      "sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      "packageType": "apk"
    },
    "windows": {
      "version": "1.3.1-beta.2",
      "buildNumber": 14,
      "downloadUrl": "https://example.com/beta/GiftLedgerSetup.exe",
      "sha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      "packageType": "exe"
    }
  }
}
''';

      final manifest = UpdateManifest.fromJson(
        jsonDecode(manifestJson) as Map<String, dynamic>,
      );

      expect(manifest.stable.windows?.packageType, 'exe');
      expect(manifest.beta.windows?.version, '1.3.1-beta.2');
      expect(manifest.stable.android?.buildNumber, 13);
      expect(manifest.beta.android?.packageType, 'apk');
      expect(
        manifest.stable.windows?.downloadUrl,
        'https://example.com/stable/GiftLedgerSetup.exe',
      );
      expect(
        manifest.beta.android?.sha256,
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );
    });

    test('支持按目标读取对应条目', () {
      final manifest = UpdateManifest.fromJson(
        _manifestJsonWithStableWindowsOverrides({}),
      );

      const stableWindowsTarget = UpdateTarget(
        channel: UpdateChannel.stable,
        platform: UpdatePlatform.windows,
      );
      const betaWindowsTarget = UpdateTarget(
        channel: UpdateChannel.beta,
        platform: UpdatePlatform.windows,
      );

      expect(manifest.getEntry(stableWindowsTarget)?.version, '1.3.0');
      expect(manifest.getEntry(betaWindowsTarget)?.version, '1.3.1-beta.2');
    });

    test('缺失关键字段时抛出清晰异常', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifestJsonWithStableWindowsOverrides({'sha256': null}),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('sha256'),
          ),
        ),
      );
    });

    test('非法字段值时抛出清晰异常', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifestJsonWithStableWindowsOverrides({
            'buildNumber': 'NaN',
            'downloadUrl': 'not-a-url',
            'sha256': 'short',
          }),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('buildNumber'),
          ),
        ),
      );
    });

    test('空 version 时抛出清晰异常', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifestJsonWithStableWindowsOverrides({'version': '   '}),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('version'),
          ),
        ),
      );
    });

    test('缺失 packageType 时抛出清晰异常', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifestJsonWithStableWindowsOverrides({'packageType': null}),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('packageType'),
          ),
        ),
      );
    });

    test('packageType 超出一期允许集合时抛出清晰异常', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifestJsonWithStableWindowsOverrides({'packageType': 'dmg'}),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('packageType'), contains('apk')),
          ),
        ),
      );
    });

    test('android 节点支持按 ABI 读取变体资源', () {
      final manifest = UpdateManifest.fromJson({
        'channels': {
          'stable': {
            'android': {
              'version': '1.3.2',
              'buildNumber': 1030299,
              'downloadUrl':
                  'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
              'sha256':
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'packageType': 'apk',
              'notes': 'Android stable',
              'variants': {
                'armeabi-v7a': {
                  'downloadUrl':
                      'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-armeabi-v7a.apk',
                  'sha256':
                      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                  'packageType': 'apk',
                },
                'arm64-v8a': {
                  'downloadUrl':
                      'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
                  'sha256':
                      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
                  'packageType': 'apk',
                },
              },
            },
          },
          'beta': {},
        },
      });

      final entry = manifest.stable.android;
      expect(entry, isNotNull);
      expect(
        entry?.resolveDownloadUrl(preferredAbi: 'armeabi-v7a'),
        'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-armeabi-v7a.apk',
      );
      expect(
        entry?.resolveSha256(preferredAbi: 'arm64-v8a'),
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );
      expect(entry?.resolveAbi(preferredAbi: 'arm64-v8a'), 'arm64-v8a');
      expect(
        entry?.resolveDownloadUrl(preferredAbi: 'x86_64'),
        'https://example.com/gift_ledger-stable-android-v1.3.2-build1030299-arm64-v8a.apk',
      );
    });

    test('非法 downloadUrl 时抛出清晰异常', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifestJsonWithStableWindowsOverrides({
            'downloadUrl': 'relative/path/to/file.exe',
          }),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('downloadUrl'),
          ),
        ),
      );
    });
  });
}

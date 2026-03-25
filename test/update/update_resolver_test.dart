import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/update/update_keys.dart';
import 'package:gift_ledger/services/update/update_resolver.dart';

UpdateManifest _buildManifest({
  required Map<String, dynamic>? stableWindows,
  required Map<String, dynamic>? betaWindows,
}) {
  return UpdateManifest.fromJson({
    'stable': {
      'windows': stableWindows,
    },
    'beta': {
      'windows': betaWindows,
    },
  });
}

Map<String, dynamic> _entry({
  required String version,
  required int buildNumber,
  required String url,
  required String sha256,
  required String packageType,
  String notes = '',
}) {
  return {
    'version': version,
    'buildNumber': buildNumber,
    'downloadUrl': url,
    'sha256': sha256,
    'packageType': packageType,
    'notes': notes,
  };
}

void main() {
  group('UpdateResolver', () {
    const resolver = UpdateResolver();

    test('beta 用户没有更高 beta 时回退 stable，并使用 stable 目标键', () {
      final manifest = _buildManifest(
        stableWindows: _entry(
          version: '1.3.1',
          buildNumber: 15,
          url: 'https://example.com/stable/GiftLedgerSetup.exe',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          packageType: 'exe',
          notes: '稳定版修复',
        ),
        betaWindows: _entry(
          version: '1.3.1-beta.2',
          buildNumber: 14,
          url: 'https://example.com/beta/GiftLedgerSetup.exe',
          sha256:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          packageType: 'exe',
          notes: '测试版说明',
        ),
      );

      final target = resolver.resolve(
        manifest: manifest,
        selectedChannel: UpdateChannel.beta,
        platform: UpdatePlatform.windows,
        currentVersion: '1.3.1-beta.2',
        currentBuildNumber: 14,
      );

      expect(target, isNotNull);
      expect(target?.channel, UpdateChannel.beta);
      expect(target?.resolvedTargetChannel, UpdateChannel.stable);
      expect(target?.version, '1.3.1');
      expect(target?.buildNumber, 15);
      expect(target?.packageType, 'exe');
      expect(target?.downloadUrl,
          'https://example.com/stable/GiftLedgerSetup.exe');
      expect(
        buildUpdateTargetKey(target!),
        'stable@windows@1.3.1@15',
      );
    });

    test('beta 用户有更高 beta 时优先 beta', () {
      final manifest = _buildManifest(
        stableWindows: _entry(
          version: '1.3.1',
          buildNumber: 15,
          url: 'https://example.com/stable/GiftLedgerSetup.exe',
          sha256:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          packageType: 'exe',
        ),
        betaWindows: _entry(
          version: '1.3.1-beta.3',
          buildNumber: 16,
          url: 'https://example.com/beta/GiftLedgerSetup.exe',
          sha256:
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          packageType: 'exe',
          notes: '测试版优先',
        ),
      );

      final target = resolver.resolve(
        manifest: manifest,
        selectedChannel: UpdateChannel.beta,
        platform: UpdatePlatform.windows,
        currentVersion: '1.3.0',
        currentBuildNumber: 13,
      );

      expect(target, isNotNull);
      expect(target?.resolvedTargetChannel, UpdateChannel.beta);
      expect(target?.version, '1.3.1-beta.3');
      expect(target?.buildNumber, 16);
      expect(target?.notes, '测试版优先');
    });

    test('stable 用户只看 stable', () {
      final manifest = _buildManifest(
        stableWindows: _entry(
          version: '1.3.1',
          buildNumber: 15,
          url: 'https://example.com/stable/GiftLedgerSetup.exe',
          sha256:
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          packageType: 'exe',
        ),
        betaWindows: _entry(
          version: '1.4.0-beta.1',
          buildNumber: 20,
          url: 'https://example.com/beta/GiftLedgerSetup.exe',
          sha256:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          packageType: 'exe',
        ),
      );

      final target = resolver.resolve(
        manifest: manifest,
        selectedChannel: UpdateChannel.stable,
        platform: UpdatePlatform.windows,
        currentVersion: '1.3.0',
        currentBuildNumber: 13,
      );

      expect(target, isNotNull);
      expect(target?.channel, UpdateChannel.stable);
      expect(target?.resolvedTargetChannel, UpdateChannel.stable);
      expect(target?.version, '1.3.1');
      expect(target?.buildNumber, 15);
    });

    test('当前版本已不低于目标版本时返回 null', () {
      final manifest = _buildManifest(
        stableWindows: _entry(
          version: '1.3.1',
          buildNumber: 15,
          url: 'https://example.com/stable/GiftLedgerSetup.exe',
          sha256:
              '1111111111111111111111111111111111111111111111111111111111111111',
          packageType: 'exe',
        ),
        betaWindows: _entry(
          version: '1.3.1-beta.3',
          buildNumber: 16,
          url: 'https://example.com/beta/GiftLedgerSetup.exe',
          sha256:
              '2222222222222222222222222222222222222222222222222222222222222222',
          packageType: 'exe',
        ),
      );

      final target = resolver.resolve(
        manifest: manifest,
        selectedChannel: UpdateChannel.stable,
        platform: UpdatePlatform.windows,
        currentVersion: '1.3.1',
        currentBuildNumber: 15,
      );

      expect(target, isNull);
    });
  });
}

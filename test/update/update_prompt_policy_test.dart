import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';

const _stableFallbackTarget = UpdateTarget(
  channel: UpdateChannel.beta,
  resolvedTargetChannel: UpdateChannel.stable,
  platform: UpdatePlatform.windows,
  version: '1.3.1',
  buildNumber: 15,
  packageType: 'exe',
  downloadUrl: 'https://example.com/stable/GiftLedgerSetup.exe',
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  notes: '稳定版修复',
);

const _betaTarget = UpdateTarget(
  channel: UpdateChannel.beta,
  resolvedTargetChannel: UpdateChannel.beta,
  platform: UpdatePlatform.windows,
  version: '1.3.2-beta.1',
  buildNumber: 16,
  packageType: 'exe',
  downloadUrl: 'https://example.com/beta/GiftLedgerSetup.exe',
  sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  notes: '测试版修复',
);

void main() {
  group('UpdatePromptPolicy', () {
    const policy = UpdatePromptPolicy();

    test('忽略当前目标后，不再弹窗但继续显示红点与 banner', () {
      final decision = policy.decide(
        source: UpdateCheckSource.startup,
        target: _stableFallbackTarget,
        ignoredTargetKeys: {'stable@windows@1.3.1@15'},
        promptedTargetKeys: const <String>{},
      );

      expect(decision.showDialog, isFalse);
      expect(decision.showRedDot, isTrue);
      expect(decision.showBanner, isTrue);
    });

    test('启动检查且首次发现时强弹', () {
      final decision = policy.decide(
        source: UpdateCheckSource.startup,
        target: _betaTarget,
        ignoredTargetKeys: const <String>{},
        promptedTargetKeys: const <String>{},
      );

      expect(decision.showDialog, isTrue);
      expect(decision.showRedDot, isTrue);
      expect(decision.showBanner, isFalse);
    });

    test('已提示过则不再强弹', () {
      final decision = policy.decide(
        source: UpdateCheckSource.startup,
        target: _betaTarget,
        ignoredTargetKeys: const <String>{},
        promptedTargetKeys: {'beta@windows@1.3.2-beta.1@16'},
      );

      expect(decision.showDialog, isFalse);
      expect(decision.showRedDot, isTrue);
      expect(decision.showBanner, isTrue);
    });

    test('手动检查不会被判成首次启动强弹逻辑', () {
      final decision = policy.decide(
        source: UpdateCheckSource.manual,
        target: _betaTarget,
        ignoredTargetKeys: const <String>{},
        promptedTargetKeys: const <String>{},
      );

      expect(decision.showDialog, isFalse);
      expect(decision.showRedDot, isTrue);
      expect(decision.showBanner, isTrue);
    });
  });
}

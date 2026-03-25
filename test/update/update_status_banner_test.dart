import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/widgets/update/update_status_banner.dart';

void main() {
  testWidgets('点击关闭只触发 onDismiss', (tester) async {
    var dismissed = 0;
    var installed = 0;

    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateStatusBanner(
            target: target,
            isInstalling: false,
            onInstall: () {
              installed += 1;
            },
            onDismiss: () {
              dismissed += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('关闭更新横幅'));
    await tester.pumpAndSettle();

    expect(dismissed, 1);
    expect(installed, 0);
  });

  testWidgets('安装进行中时禁用立即更新按钮并展示文案', (tester) async {
    var installCount = 0;

    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateStatusBanner(
            target: target,
            isInstalling: true,
            onInstall: () {
              installCount += 1;
            },
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.text('更新中...'), findsOneWidget);
    await tester.tap(find.text('更新中...'));
    await tester.pump();

    expect(installCount, 0);
  });
}

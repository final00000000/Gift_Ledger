import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_installer.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';
import 'package:gift_ledger/widgets/update/update_settings_section.dart';

Finder _buttonFinderByLabel(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
}

void main() {
  const target = UpdateTarget(
    channel: UpdateChannel.stable,
    resolvedTargetChannel: UpdateChannel.stable,
    platform: UpdatePlatform.android,
    version: '1.3.0',
    buildNumber: 13,
    notes: '稳定版更新说明',
  );

  testWidgets('发现新版本时展示目标版本、重新检查与立即更新按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpdateSettingsSection(
              currentVersion: '1.2.8',
              status: UpdateStateStatus.available,
              lastSource: UpdateCheckSource.manual,
              target: target,
              onCheckPressed: () {},
              onInstallPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('应用更新'), findsOneWidget);
    expect(find.text('可更新到 v1.3.0'), findsOneWidget);
    expect(find.text('目标版本 v1.3.0'), findsOneWidget);
    expect(find.textContaining('构建号'), findsNothing);
    expect(find.text('重新检查'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
  });

  testWidgets('手动检查失败且保留旧 target 时，不展示旧的立即更新按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpdateSettingsSection(
              currentVersion: '1.2.8',
              status: UpdateStateStatus.error,
              lastSource: UpdateCheckSource.manual,
              target: target,
              onCheckPressed: () {},
              onInstallPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('当前网络不可用，或暂时无法访问更新服务'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('立即更新'), findsNothing);
  });

  testWidgets('安装中时展示安装中状态，并禁用重新检查与安装按钮', (tester) async {
    var installPressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpdateSettingsSection(
              currentVersion: '1.2.8',
              status: UpdateStateStatus.installing,
              lastSource: UpdateCheckSource.manual,
              target: target,
              installResult: const InstallResult(
                didOpen: true,
                savePath: 'C:/temp/GiftLedgerSetup.exe',
                message: '安装器已启动',
              ),
              onCheckPressed: () {},
              onInstallPressed: () {
                installPressed += 1;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('正在打开系统安装器'), findsWidgets);
    expect(find.text('安装中...'), findsOneWidget);

    final checkButton = tester.widget<ButtonStyleButton>(
      _buttonFinderByLabel('重新检查'),
    );
    final installButton = tester.widget<ButtonStyleButton>(
      _buttonFinderByLabel('安装中...'),
    );
    expect(checkButton.onPressed, isNull);
    expect(installButton.onPressed, isNull);

    await tester.tap(find.text('安装中...'));
    await tester.pump();
    expect(installPressed, 0);
  });

  testWidgets('需要权限时展示去开启权限按钮，并禁用重新检查', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpdateSettingsSection(
              currentVersion: '1.2.8',
              status: UpdateStateStatus.permissionRequired,
              lastSource: UpdateCheckSource.manual,
              target: target,
              error: const UpdateInstallerException('尚未开启安装权限，请先授权后继续更新。'),
              onCheckPressed: () {},
              onInstallPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('需要先开启安装权限'), findsOneWidget);
    expect(find.text('去开启权限'), findsOneWidget);
    final checkButton = tester.widget<ButtonStyleButton>(
      _buttonFinderByLabel('重新检查'),
    );
    expect(checkButton.onPressed, isNull);
  });

  testWidgets('startup 检查失败时状态卡回退到默认提示，不展示失败文案', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpdateSettingsSection(
              currentVersion: '1.2.8',
              status: UpdateStateStatus.error,
              lastSource: UpdateCheckSource.startup,
              target: null,
              onCheckPressed: () {},
              onInstallPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('当前网络不可用，或暂时无法访问更新服务'), findsNothing);
    expect(find.text('检查最新版本与更新说明'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
  });
}

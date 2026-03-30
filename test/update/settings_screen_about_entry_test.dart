import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/screens/about_app_screen.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_installer.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService().init();
  });

  testWidgets('SettingsScreen 移除独立应用更新卡片，仅保留 About B2 入口并可跳转 AboutAppScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.available(version: '1.3.0');

    await tester.pumpWidget(
      buildSettingsTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text('应用更新'), findsNothing);
    expect(find.text('关于随礼记'), findsOneWidget);
    expect(find.text('当前版本 v1.2.8'), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-app-red-dot')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('关于随礼记'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final aboutTile = find.ancestor(
      of: find.text('关于随礼记'),
      matching: find.byType(ListTile),
    );
    await tester.tap(aboutTile);
    await tester.pumpAndSettle();

    expect(find.byType(AboutAppScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen 默认态只展示当前版本，不显示红点与发现新版本胶囊', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.idle();

    await tester.pumpWidget(
      buildSettingsTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text('关于随礼记'), findsOneWidget);
    expect(find.text('当前版本 v1.2.8'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-app-red-dot')), findsNothing);
    expect(find.text('发现新版本'), findsNothing);
  });

  testWidgets('SettingsScreen 在已有目标版本但未显式带红点时，About 入口仍展示更新状态', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController(
      state: const UpdateState(
        status: UpdateStateStatus.available,
        target: UpdateTarget(
          channel: UpdateChannel.stable,
          resolvedTargetChannel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: '1.3.0',
          buildNumber: 13,
          notes: '稳定版更新说明',
        ),
        showRedDot: false,
      ),
    );

    await tester.pumpWidget(
      buildSettingsTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about-app-red-dot')), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('SettingsScreen 在启动后收到更新状态时，About 入口立即同步展示', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.idle();

    await tester.pumpWidget(
      buildSettingsTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about-app-red-dot')), findsNothing);
    expect(find.text('发现新版本'), findsNothing);

    controller.emit(
      const UpdateState(
        status: UpdateStateStatus.available,
        target: UpdateTarget(
          channel: UpdateChannel.stable,
          resolvedTargetChannel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: '1.3.0',
          buildNumber: 13,
          notes: '稳定版更新说明',
        ),
        showRedDot: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about-app-red-dot')), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('SettingsScreen 在后台下载时 About 入口展示下载状态', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController(
      state: const UpdateState(
        status: UpdateStateStatus.downloading,
        target: UpdateTarget(
          channel: UpdateChannel.stable,
          resolvedTargetChannel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: '1.3.0',
          buildNumber: 13,
          notes: '稳定版更新说明',
        ),
        showRedDot: true,
        downloadProgress: DownloadProgress(
          receivedBytes: 64,
          totalBytes: 128,
        ),
      ),
    );

    await tester.pumpWidget(
      buildSettingsTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text('下载中 50%'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-app-red-dot')), findsOneWidget);
  });
}

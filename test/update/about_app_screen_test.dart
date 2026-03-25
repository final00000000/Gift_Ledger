import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';
import 'package:gift_ledger/widgets/update/update_channel_section.dart';
import 'package:gift_ledger/widgets/update/update_release_notes_section.dart';
import 'package:gift_ledger/widgets/update/update_settings_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_test_helpers.dart';

class RetainedTargetManualErrorController extends FakeUpdateController {
  RetainedTargetManualErrorController()
      : _retainedTarget = const UpdateTarget(
          channel: UpdateChannel.stable,
          resolvedTargetChannel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: '1.3.1',
          buildNumber: 13,
          notes: '保留的已知更新说明',
        ),
        super(
          state: const UpdateState(
            status: UpdateStateStatus.available,
            lastSource: UpdateCheckSource.startup,
            target: UpdateTarget(
              channel: UpdateChannel.stable,
              resolvedTargetChannel: UpdateChannel.stable,
              platform: UpdatePlatform.android,
              version: '1.3.1',
              buildNumber: 13,
              notes: '保留的已知更新说明',
            ),
            showRedDot: true,
            showBanner: true,
          ),
        );

  final UpdateTarget _retainedTarget;

  @override
  Future<void> checkForUpdates({required UpdateCheckSource source}) async {
    checkCalls += 1;
    emit(
      UpdateState(
        status: UpdateStateStatus.error,
        lastSource: source,
        target: _retainedTarget,
        showRedDot: true,
        error: StateError('network unavailable'),
      ),
    );
  }
}

Finder _buttonFinderByLabel(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService().init();
  });

  testWidgets('AboutAppScreen 会展示顶部信息、更新区块和 GitHub 入口', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.available(version: '1.3.0');

    await tester.pumpWidget(
      buildAboutTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text('随礼记'), findsOneWidget);
    expect(find.textContaining('当前版本 v1.2.8'), findsWidgets);
    expect(find.byType(UpdateSettingsSection), findsOneWidget);
    expect(find.byType(UpdateChannelSection), findsOneWidget);
    expect(find.byType(UpdateReleaseNotesSection), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-red-dot')), findsNothing);
  });

  testWidgets('AboutAppScreen 在 ignored 版本场景仍展示版本与更新说明，但页内不显示红点',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.ignoredAvailable(
      version: '1.3.1',
      notes: '忽略版本后也应可见的更新说明',
    );

    await tester.pumpWidget(
      buildAboutTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1.3.1'), findsWidgets);
    expect(find.text('忽略版本后也应可见的更新说明'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-red-dot')), findsNothing);
  });

  testWidgets('AboutAppScreen 在 installing 状态会同时禁用检查、安装与 Beta 开关',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.installing(version: '1.3.1');

    await tester.pumpWidget(
      buildAboutTestApp(updateController: controller),
    );
    await tester.pump();

    final checkButton = tester.widget<ButtonStyleButton>(
      _buttonFinderByLabel('重新检查'),
    );
    final installButton = tester.widget<ButtonStyleButton>(
      _buttonFinderByLabel('更新中...'),
    );
    final betaSwitch = tester.widget<Switch>(find.byType(Switch));

    expect(checkButton.onPressed, isNull);
    expect(installButton.onPressed, isNull);
    expect(betaSwitch.onChanged, isNull);
  });

  testWidgets('AboutAppScreen 在 installing 状态下仍允许展开更新说明并保留 GitHub 入口可见',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.installing(
      version: '1.3.1',
      notes: '第一行\n第二行\n第三行\n第四行',
    );

    await tester.pumpWidget(
      buildAboutTestApp(updateController: controller),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('展开'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('展开'));
    await tester.pump();

    expect(find.text('收起'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('AboutAppScreen 在安装失败后回落到可更新态，并重新开放重试相关交互', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = FakeUpdateController.installFailed(version: '1.3.1');

    await tester.pumpWidget(
      buildAboutTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    final retryButton = tester.widget<ButtonStyleButton>(
      _buttonFinderByLabel('重新检查'),
    );
    final installButton = tester.widget<ButtonStyleButton>(
      _buttonFinderByLabel('立即更新'),
    );
    final betaSwitch = tester.widget<Switch>(find.byType(Switch));

    expect(retryButton.onPressed, isNotNull);
    expect(installButton.onPressed, isNotNull);
    expect(betaSwitch.onChanged, isNotNull);
  });

  testWidgets(
      'AboutAppScreen 手动检查失败且 controller 保留旧 target 时，应优先展示网络错误而不是误报新版本',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = RetainedTargetManualErrorController();

    await tester.pumpWidget(
      buildAboutTestApp(updateController: controller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新检查'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.checkCalls, 1);
    expect(controller.markCalls, 0);
    expect(find.text('当前网络不可用，或暂时无法访问更新服务'), findsWidgets);
    expect(find.textContaining('发现新版本'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}

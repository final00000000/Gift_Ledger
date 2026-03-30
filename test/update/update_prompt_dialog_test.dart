import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_installer.dart';
import 'package:gift_ledger/widgets/update/update_prompt_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService().init();
  });

  testWidgets('勾选不再提示后提交回调结果为 true', (tester) async {
    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    final controller = FakeUpdateController.available();
    UpdatePromptDialogResult? result;

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<UpdatePromptDialogResult>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const UpdatePromptDialog(target: target),
                    );
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('这个版本不再提示'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.ignoreCurrentVersion, isTrue);
    expect(result!.action, UpdatePromptDialogAction.later);
  });

  testWidgets('仅在弹窗真正显示后触发 onShown 回调', (tester) async {
    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    final controller = FakeUpdateController.available();
    var shownCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => UpdatePromptDialog(
                        target: target,
                        onShown: () {
                          shownCount += 1;
                        },
                      ),
                    );
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(shownCount, 0);

    await tester.tap(find.text('open'));
    expect(shownCount, 0);

    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('v1.3.0'), findsOneWidget);
    expect(find.textContaining('构建'), findsNothing);
    expect(shownCount, 1);
  });

  testWidgets('下载中会展示进度文案并禁用主按钮', (tester) async {
    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    final controller = FakeUpdateController(
      state: const UpdateState(
        status: UpdateStateStatus.downloading,
        target: target,
        showRedDot: true,
        downloadProgress: DownloadProgress(
          receivedBytes: 64,
          totalBytes: 128,
        ),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(
            body: UpdatePromptDialog(target: target),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('正在下载更新 50%'), findsOneWidget);
    expect(find.text('64 B / 128 B'), findsOneWidget);
    expect(find.text('下载中 50%'), findsOneWidget);
    expect(find.text('后台继续'), findsOneWidget);
    final downloadingButton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('下载中 50%'),
        matching:
            find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      ),
    );
    final backgroundButton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('后台继续'),
        matching:
            find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      ),
    );
    expect(downloadingButton.onPressed, isNull);
    expect(backgroundButton.onPressed, isNotNull);
  });

  testWidgets('下载中可关闭弹窗并继续后台继续', (tester) async {
    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    final controller = FakeUpdateController(
      state: const UpdateState(
        status: UpdateStateStatus.downloading,
        target: target,
        showRedDot: true,
        downloadProgress: DownloadProgress(
          receivedBytes: 64,
          totalBytes: 128,
        ),
      ),
    );
    UpdatePromptDialogResult? result;

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<UpdatePromptDialogResult>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const UpdatePromptDialog(target: target),
                    );
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('后台继续'), findsOneWidget);
    await tester.tap(find.text('后台继续'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.action, UpdatePromptDialogAction.later);
    expect(result!.ignoreCurrentVersion, isFalse);
  });
}

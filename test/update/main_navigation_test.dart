import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/main.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/app_build_info_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:gift_ledger/widgets/update/update_prompt_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MainNavigationTestController extends UpdateController {
  _MainNavigationTestController()
      : super(
          repository: _NoopUpdateRepository(),
          appBuildInfoService: const _NoopBuildInfoService(),
          configService: ConfigService(),
        );

  UpdateState _fakeState = const UpdateState();
  int checkCalls = 0;
  int markCalls = 0;

  @override
  UpdateState get state => _fakeState;

  @override
  Future<void> checkForUpdates({required UpdateCheckSource source}) async {
    checkCalls += 1;
  }

  @override
  Future<void> markCurrentTargetPresented() async {
    markCalls += 1;
  }

  void emit(UpdateState state) {
    _fakeState = state;
    notifyListeners();
  }
}

class _NoopUpdateRepository implements UpdateRepository {
  @override
  String? get cachedManifestJson => null;

  @override
  Future<UpdateManifest> fetchManifest() {
    throw UnimplementedError();
  }
}

class _NoopBuildInfoService implements AppBuildInfoService {
  const _NoopBuildInfoService();

  @override
  Future<AppBuildInfo> getCurrentBuildInfo() {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService().init();
  });

  testWidgets('启动后仅调度一次检查，并对同一目标弹窗去重', (tester) async {
    final controller = _MainNavigationTestController();
    final promptCompleter = Completer<UpdatePromptDialogResult?>();
    var presenterCount = 0;
    var onShownCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: MaterialApp(
          home: MainNavigation(
            screens: const [
              SizedBox.shrink(),
              SizedBox.shrink(),
              SizedBox.shrink(),
            ],
            promptPresenter: (context, target, onShown) {
              presenterCount += 1;
              onShown();
              onShownCount += 1;
              return promptCompleter.future;
            },
          ),
        ),
      ),
    );

    await tester.pump();

    expect(controller.checkCalls, 1);

    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
    );
    const state = UpdateState(
      status: UpdateStateStatus.available,
      target: target,
      showDialog: true,
    );

    controller.emit(state);
    await tester.pump();

    controller.emit(state);
    await tester.pump();

    expect(presenterCount, 1);
    expect(onShownCount, 1);
    expect(controller.markCalls, 1);

    promptCompleter.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('设置 Tab 在有更新时显示红点', (tester) async {
    final controller = _MainNavigationTestController();

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: const MaterialApp(
          home: MainNavigation(
            screens: [
              SizedBox.shrink(),
              SizedBox.shrink(),
              SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('settings-tab-red-dot')), findsNothing);

    controller.emit(
      const UpdateState(
        status: UpdateStateStatus.available,
        target: UpdateTarget(
          channel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: '1.3.0',
        ),
        showRedDot: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('settings-tab-red-dot')), findsOneWidget);
  });
}

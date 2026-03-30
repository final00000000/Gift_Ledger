import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/app_build_info_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_installer.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:gift_ledger/services/update/update_ui_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _SpyUpdateController extends UpdateController {
  _SpyUpdateController()
      : super(
          repository: _NoopUpdateRepository(),
          appBuildInfoService: const _NoopBuildInfoService(),
          configService: ConfigService(),
        );

  UpdateState _fakeState = const UpdateState();
  int markCount = 0;
  int installCount = 0;

  @override
  UpdateState get state => _fakeState;

  void emit(UpdateState state) {
    _fakeState = state;
    notifyListeners();
  }

  @override
  Future<void> markCurrentTargetPresented() async {
    markCount += 1;
  }

  @override
  Future<void> installCurrentTarget() async {
    installCount += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService().init();
  });

  group('UpdatePromptCoordinator', () {
    test('同一目标在弹窗未关闭前只允许展示一次', () {
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

      final coordinator = UpdatePromptCoordinator();

      expect(coordinator.beginPresentation(state), 'stable@android@1.3.0@13');
      expect(coordinator.beginPresentation(state), isNull);

      coordinator.endPresentation();

      expect(coordinator.beginPresentation(state), 'stable@android@1.3.0@13');
    });
  });

  group('scheduleManualUpdatePresentation', () {
    test('目标未变化时会在下一帧标记已展示并反馈版本文案', () async {
      const target = UpdateTarget(
        channel: UpdateChannel.stable,
        platform: UpdatePlatform.android,
        version: '1.3.0',
        buildNumber: 13,
      );
      final controller = _SpyUpdateController()
        ..emit(
          const UpdateState(
            status: UpdateStateStatus.available,
            target: target,
          ),
        );
      final completer = Completer<void>();
      String? message;

      scheduleManualUpdatePresentation(
        controller: controller,
        target: target,
        isMounted: () => true,
        schedulePostFrame: (callback) async {
          callback(Duration.zero);
          completer.complete();
        },
        showMessage: (value) {
          message = value;
        },
      );

      await completer.future;

      expect(controller.markCount, 1);
      expect(message, '发现新版本 v1.3.0');
    });

    test('当前目标已变化时不再错误标记旧版本', () async {
      const originalTarget = UpdateTarget(
        channel: UpdateChannel.stable,
        platform: UpdatePlatform.android,
        version: '1.3.0',
        buildNumber: 13,
      );
      const newTarget = UpdateTarget(
        channel: UpdateChannel.stable,
        platform: UpdatePlatform.android,
        version: '1.3.1',
        buildNumber: 14,
      );
      final controller = _SpyUpdateController()
        ..emit(
          const UpdateState(
            status: UpdateStateStatus.available,
            target: newTarget,
          ),
        );

      scheduleManualUpdatePresentation(
        controller: controller,
        target: originalTarget,
        isMounted: () => true,
        schedulePostFrame: (FrameCallback callback) {
          callback(Duration.zero);
        },
        showMessage: (_) {},
      );

      expect(controller.markCount, 0);
    });
  });

  group('installCurrentUpdateAndCollectMessage', () {
    test('会透传安装提示文案', () async {
      final controller = _SpyUpdateController()
        ..emit(
          const UpdateState(
            status: UpdateStateStatus.available,
            target: UpdateTarget(
              channel: UpdateChannel.stable,
              platform: UpdatePlatform.windows,
              version: '1.3.0',
              buildNumber: 13,
            ),
            installResult: InstallResult(
              didOpen: true,
              savePath: 'C:/temp/GiftLedgerSetup.exe',
              message: '安装器已启动',
            ),
          ),
        );

      final message = await installCurrentUpdateAndCollectMessage(controller);

      expect(controller.installCount, 1);
      expect(message, '安装器已启动');
    });

    test('安装器异常时会优先透传明确错误文案', () async {
      final controller = _SpyUpdateController()
        ..emit(
          const UpdateState(
            status: UpdateStateStatus.available,
            target: UpdateTarget(
              channel: UpdateChannel.stable,
              platform: UpdatePlatform.android,
              version: '1.3.0',
              buildNumber: 13,
            ),
            error: UpdateInstallerException('下载更新包超时，请检查网络后重试。'),
          ),
        );

      final message = await installCurrentUpdateAndCollectMessage(controller);

      expect(controller.installCount, 1);
      expect(message, '下载更新包超时，请检查网络后重试。');
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/app_build_info_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_installer.dart';
import 'package:gift_ledger/services/update/update_keys.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _resolvedStableKey = 'stable@windows@1.3.1@15';

UpdateManifest _buildManifest() {
  return UpdateManifest.fromJson({
    'channels': {
      'stable': {
        'windows': {
          'version': '1.3.1',
          'buildNumber': 15,
          'downloadUrl': 'https://example.com/stable/GiftLedgerSetup.exe',
          'sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'packageType': 'exe',
          'notes': '稳定版更新',
        },
      },
      'beta': {
        'windows': {
          'version': '1.3.1-beta.2',
          'buildNumber': 14,
          'downloadUrl': 'https://example.com/beta/GiftLedgerSetup.exe',
          'sha256':
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'packageType': 'exe',
          'notes': '当前已安装版本',
        },
      },
    },
  });
}

class FakeUpdateRepository implements UpdateRepository {
  FakeUpdateRepository(this.manifest);

  final UpdateManifest manifest;

  @override
  String? get cachedManifestJson => null;

  @override
  Future<UpdateManifest> fetchManifest() async => manifest;
}

class SequencedUpdateRepository implements UpdateRepository {
  SequencedUpdateRepository(this.responses);

  final List<Object> responses;

  @override
  String? get cachedManifestJson => null;

  @override
  Future<UpdateManifest> fetchManifest() async {
    if (responses.isEmpty) {
      throw StateError('No response configured');
    }

    final next = responses.removeAt(0);
    if (next is UpdateManifest) {
      return next;
    }
    throw next;
  }
}

class DeferredUpdateRepository implements UpdateRepository {
  DeferredUpdateRepository(this.completers);

  final List<Completer<UpdateManifest>> completers;

  @override
  String? get cachedManifestJson => null;

  @override
  Future<UpdateManifest> fetchManifest() async {
    if (completers.isEmpty) {
      throw StateError('No completer configured');
    }

    return completers.removeAt(0).future;
  }
}

class FakeAppBuildInfoService implements AppBuildInfoService {
  FakeAppBuildInfoService(this.buildInfo);

  final AppBuildInfo buildInfo;

  @override
  Future<AppBuildInfo> getCurrentBuildInfo() async => buildInfo;
}

class FakeUpdateInstaller implements UpdateInstaller {
  FakeUpdateInstaller({
    InstallResult? result,
    this.completer,
  })  : result = result ??
            const InstallResult(
              didOpen: true,
              savePath: 'C:/temp/GiftLedgerSetup.exe',
              message: 'done',
            ),
        callCount = 0;

  final InstallResult result;
  final Completer<InstallResult>? completer;
  UpdateTarget? lastTarget;
  int callCount;

  @override
  Future<InstallResult> downloadAndOpen(UpdateTarget target) async {
    callCount += 1;
    lastTarget = target;
    if (completer != null) {
      return completer!.future;
    }

    return result;
  }
}

class FailingUpdateInstaller implements UpdateInstaller {
  FailingUpdateInstaller(this.error);

  final Object error;

  @override
  Future<InstallResult> downloadAndOpen(UpdateTarget target) async {
    throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final configService = ConfigService();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configService.init();
  });

  setUp(() async {
    await configService.clear();
  });

  UpdateController buildController({
    UpdateChannel selectedChannel = UpdateChannel.beta,
    UpdateInstaller? installer,
    UpdateRepository? repository,
  }) {
    return UpdateController(
      repository: repository ?? FakeUpdateRepository(_buildManifest()),
      appBuildInfoService: FakeAppBuildInfoService(
        const AppBuildInfo(
          version: '1.3.1-beta.2',
          buildNumber: 14,
          platform: UpdatePlatform.windows,
        ),
      ),
      installer: installer ?? FakeUpdateInstaller(),
      configService: configService,
      selectedChannel: selectedChannel,
    );
  }

  group('UpdateController', () {
    test('发现更新后，在未确认已展示前不写入 prompted key', () async {
      final controller = buildController();

      await controller.checkForUpdates(source: UpdateCheckSource.startup);

      expect(controller.state.target?.version, '1.3.1');
      expect(controller.state.showDialog, isTrue);
      expect(controller.promptedTargetKeys, isEmpty);
      expect(
        configService.getStringList(promptedTargetKeysConfigKey),
        anyOf(isNull, isEmpty),
      );
    });

    test('调用 markCurrentTargetPresented 后，prompted key 才落盘', () async {
      final controller = buildController();

      await controller.checkForUpdates(source: UpdateCheckSource.startup);
      await controller.markCurrentTargetPresented();

      expect(controller.promptedTargetKeys, contains(_resolvedStableKey));
      expect(
        configService.getStringList(promptedTargetKeysConfigKey),
        contains(_resolvedStableKey),
      );
      expect(controller.state.showDialog, isFalse);
      expect(controller.state.showBanner, isTrue);
    });

    test('手动检查并确认已展示后，下次启动同版本不再首次强弹', () async {
      final manualController = buildController();

      await manualController.checkForUpdates(source: UpdateCheckSource.manual);
      expect(manualController.state.showDialog, isFalse);

      await manualController.markCurrentTargetPresented();
      expect(manualController.promptedTargetKeys, contains(_resolvedStableKey));

      final startupController = buildController();
      await startupController.checkForUpdates(source: UpdateCheckSource.startup);

      expect(startupController.state.target?.version, '1.3.1');
      expect(startupController.state.showDialog, isFalse);
      expect(startupController.state.showBanner, isTrue);
    });

    test('切换通道后会清空旧 state，避免残留旧 target 与提示状态', () async {
      final controller = buildController();

      await controller.checkForUpdates(source: UpdateCheckSource.startup);
      expect(controller.state.target, isNotNull);
      expect(controller.state.showDialog, isTrue);

      controller.setSelectedChannel(UpdateChannel.stable);

      expect(controller.selectedChannel, UpdateChannel.stable);
      expect(controller.state.target, isNull);
      expect(controller.state.showDialog, isFalse);
      expect(controller.state.showBanner, isFalse);
      expect(controller.state.status, UpdateStateStatus.idle);
    });

    test('installCurrentTarget 通过 controller 调 installer，并把结果写回 state', () async {
      final installer = FakeUpdateInstaller();
      final controller = buildController(installer: installer);

      await controller.checkForUpdates(source: UpdateCheckSource.startup);
      await controller.installCurrentTarget();

      expect(installer.lastTarget?.version, '1.3.1');
      expect(controller.state.installResult?.didOpen, isTrue);
      expect(
        controller.state.installResult?.savePath,
        'C:/temp/GiftLedgerSetup.exe',
      );
      expect(controller.state.error, isNull);
    });

    test('installCurrentTarget 在进行中时阻止重入，并暴露 installing 状态', () async {
      final completer = Completer<InstallResult>();
      final installer = FakeUpdateInstaller(completer: completer);
      final controller = buildController(installer: installer);

      await controller.checkForUpdates(source: UpdateCheckSource.startup);

      final firstInstall = controller.installCurrentTarget();
      expect(controller.state.status, UpdateStateStatus.installing);

      await controller.installCurrentTarget();
      expect(installer.callCount, 1);

      completer.complete(
        const InstallResult(
          didOpen: true,
          savePath: 'C:/temp/GiftLedgerSetup.exe',
          message: 'started',
        ),
      );

      await firstInstall;

      expect(controller.state.status, UpdateStateStatus.available);
      expect(controller.state.installResult?.message, 'started');
    });

    test('未调用 markCurrentTargetPresented 时，ignoreCurrentTarget 不得写 prompted', () async {
      final controller = buildController();

      await controller.checkForUpdates(source: UpdateCheckSource.startup);
      await controller.ignoreCurrentTarget();

      expect(controller.promptedTargetKeys, isEmpty);
      expect(
        configService.getStringList(promptedTargetKeysConfigKey),
        anyOf(isNull, isEmpty),
      );
      expect(controller.ignoredTargetKeys, contains(_resolvedStableKey));
    });

    test('未调用 markCurrentTargetPresented 时，installCurrentTarget 不得写 prompted', () async {
      final installer = FakeUpdateInstaller();
      final controller = buildController(installer: installer);

      await controller.checkForUpdates(source: UpdateCheckSource.startup);
      await controller.installCurrentTarget();

      expect(installer.lastTarget?.version, '1.3.1');
      expect(controller.promptedTargetKeys, isEmpty);
      expect(
        configService.getStringList(promptedTargetKeysConfigKey),
        anyOf(isNull, isEmpty),
      );
    });

    test('ignoreCurrentTarget 后会写入 ignored key', () async {
      final controller = buildController();

      await controller.checkForUpdates(source: UpdateCheckSource.startup);
      await controller.ignoreCurrentTarget();

      expect(controller.ignoredTargetKeys, contains(_resolvedStableKey));
    });

    test('手动检查失败时若已有已知目标，则保留 target 与红点，但状态切到 error', () async {
      final controller = buildController(
        repository: SequencedUpdateRepository([
          _buildManifest(),
          StateError('network unavailable'),
        ]),
      );

      await controller.checkForUpdates(source: UpdateCheckSource.startup);
      expect(controller.state.target?.version, '1.3.1');
      expect(controller.state.showRedDot, isTrue);

      await controller.checkForUpdates(source: UpdateCheckSource.manual);

      expect(controller.state.status, UpdateStateStatus.error);
      expect(controller.state.target?.version, '1.3.1');
      expect(controller.state.showRedDot, isTrue);
      expect(controller.state.showBanner, isFalse);
    });

    test('ignoreCurrentTarget 后再次检查同版本：不再弹窗，但保留红点与目标信息', () async {
      final firstController = buildController();

      await firstController.checkForUpdates(source: UpdateCheckSource.startup);
      await firstController.ignoreCurrentTarget();

      final nextController = buildController();
      await nextController.checkForUpdates(source: UpdateCheckSource.startup);

      expect(nextController.state.target?.version, '1.3.1');
      expect(nextController.state.showDialog, isFalse);
      expect(nextController.state.showRedDot, isTrue);
    });

    test('并发检查时，旧请求晚返回不会覆盖较新的结果', () async {
      final startupCompleter = Completer<UpdateManifest>();
      final manualCompleter = Completer<UpdateManifest>();
      final controller = buildController(
        repository: DeferredUpdateRepository([
          startupCompleter,
          manualCompleter,
        ]),
      );

      final startupFuture =
          controller.checkForUpdates(source: UpdateCheckSource.startup);
      final manualFuture =
          controller.checkForUpdates(source: UpdateCheckSource.manual);

      manualCompleter.complete(_buildManifest());
      await manualFuture;

      expect(controller.state.target?.version, '1.3.1');
      expect(controller.state.lastSource, UpdateCheckSource.manual);
      expect(controller.state.showDialog, isFalse);
      expect(controller.state.showBanner, isTrue);

      startupCompleter.complete(_buildManifest());
      await startupFuture;

      expect(controller.state.target?.version, '1.3.1');
      expect(controller.state.lastSource, UpdateCheckSource.manual);
      expect(controller.state.showDialog, isFalse);
      expect(controller.state.showBanner, isTrue);
    });

    test('切换通道后，旧检查结果不会重新写回已清空的 state', () async {
      final completer = Completer<UpdateManifest>();
      final controller = buildController(
        repository: DeferredUpdateRepository([completer]),
      );

      final pendingCheck =
          controller.checkForUpdates(source: UpdateCheckSource.manual);

      controller.setSelectedChannel(UpdateChannel.stable);
      expect(controller.state.status, UpdateStateStatus.idle);
      expect(controller.state.target, isNull);

      completer.complete(_buildManifest());
      await pendingCheck;

      expect(controller.selectedChannel, UpdateChannel.stable);
      expect(controller.state.status, UpdateStateStatus.idle);
      expect(controller.state.target, isNull);
      expect(controller.state.showDialog, isFalse);
      expect(controller.state.showBanner, isFalse);
    });

    test('当前版本已等于远端 release 时，应回到 upToDate 而不是 error', () async {
      final manifest = UpdateManifest.fromJson({
        'channels': {
          'stable': {
            'android': {
              'version': '1.2.8',
              'buildNumber': 0,
              'downloadUrl':
                  'https://github.com/final00000000/Gift_Ledger/releases/download/v1.2.8/gift_ledger_v1.2.8_arm64.apk',
              'sha256':
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'packageType': 'apk',
              'notes': '当前已是最新版本',
            },
          },
          'beta': {},
        },
      });
      final controller = UpdateController(
        repository: FakeUpdateRepository(manifest),
        appBuildInfoService: FakeAppBuildInfoService(
          const AppBuildInfo(
            version: '1.2.8',
            buildNumber: 28,
            platform: UpdatePlatform.android,
          ),
        ),
        configService: configService,
        selectedChannel: UpdateChannel.stable,
      );

      await controller.checkForUpdates(source: UpdateCheckSource.manual);

      expect(controller.state.status, UpdateStateStatus.upToDate);
      expect(controller.state.target, isNull);
      expect(controller.state.error, isNull);
    });

    test('installCurrentTarget 失败后会回落到 available，并保留 target 以便再次重试', () async {
      final controller = buildController(
        installer: FailingUpdateInstaller(StateError('install failed')),
      );

      await controller.checkForUpdates(source: UpdateCheckSource.manual);
      await controller.installCurrentTarget();

      expect(controller.state.status, UpdateStateStatus.available);
      expect(controller.state.target?.version, '1.3.1');
      expect(controller.state.error, isNotNull);
    });
  });
}

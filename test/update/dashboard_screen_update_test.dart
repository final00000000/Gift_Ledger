import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/screens/dashboard_screen.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/app_build_info_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_installer.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:provider/provider.dart';
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

class _DashboardTestUpdateController extends UpdateController {
  _DashboardTestUpdateController({
    this.installResult = const InstallResult(
      didOpen: true,
      savePath: 'C:/temp/GiftLedgerSetup.exe',
      message: '安装器已启动',
    ),
    this.installError,
  })
      : super(
          repository: _NoopUpdateRepository(),
          appBuildInfoService: const _NoopBuildInfoService(),
          configService: ConfigService(),
        );

  final InstallResult? installResult;
  final Object? installError;
  UpdateState _fakeState = const UpdateState();
  int installCalls = 0;

  @override
  UpdateState get state => _fakeState;

  void emit(UpdateState state) {
    _fakeState = state;
    notifyListeners();
  }

  @override
  Future<void> installCurrentTarget() async {
    installCalls += 1;
    _fakeState = UpdateState(
      status: UpdateStateStatus.available,
      lastSource: _fakeState.lastSource,
      target: _fakeState.target,
      showDialog: _fakeState.showDialog,
      showRedDot: _fakeState.showRedDot,
      showBanner: _fakeState.showBanner,
      installResult: installResult,
      error: installError,
    );
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService().init();
  });

  testWidgets('首页横幅点击立即更新会触发安装并展示反馈', (tester) async {
    final controller = _DashboardTestUpdateController();
    controller.emit(
      const UpdateState(
        status: UpdateStateStatus.available,
        lastSource: UpdateCheckSource.startup,
        target: UpdateTarget(
          channel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: '1.3.0',
          buildNumber: 13,
          notes: '修复若干问题',
        ),
        showBanner: true,
        showRedDot: true,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: const MaterialApp(
          home: DashboardScreen(
            previewData: DashboardPreviewData(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('立即更新'), findsOneWidget);

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(controller.installCalls, 1);
    expect(find.text('安装器已启动'), findsOneWidget);
  });

  testWidgets('首页横幅安装失败时展示兜底错误提示', (tester) async {
    final controller = _DashboardTestUpdateController(
      installResult: null,
      installError: StateError('install failed'),
    );
    controller.emit(
      const UpdateState(
        status: UpdateStateStatus.available,
        lastSource: UpdateCheckSource.startup,
        target: UpdateTarget(
          channel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: '1.3.0',
          buildNumber: 13,
          notes: '修复若干问题',
        ),
        showBanner: true,
        showRedDot: true,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateController>.value(
        value: controller,
        child: const MaterialApp(
          home: DashboardScreen(
            previewData: DashboardPreviewData(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(controller.installCalls, 1);
    expect(find.text('启动更新失败'), findsOneWidget);
  });
}

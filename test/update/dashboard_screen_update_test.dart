import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/screens/dashboard_screen.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/app_build_info_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:gift_ledger/widgets/update/update_status_banner.dart';
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
  _DashboardTestUpdateController()
      : super(
          repository: _NoopUpdateRepository(),
          appBuildInfoService: const _NoopBuildInfoService(),
          configService: ConfigService(),
        );

  UpdateState _fakeState = const UpdateState();

  @override
  UpdateState get state => _fakeState;

  void emit(UpdateState state) {
    _fakeState = state;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService().init();
  });

  testWidgets('首页不再展示更新横幅与立即更新按钮', (tester) async {
    final controller = _DashboardTestUpdateController();
    controller.emit(
      const UpdateState(
        status: UpdateStateStatus.available,
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

    expect(find.byType(UpdateStatusBanner), findsNothing);
    expect(find.text('立即更新'), findsNothing);
    expect(find.text('修复若干问题'), findsNothing);
  });
}

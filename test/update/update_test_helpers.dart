import 'package:flutter/material.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/screens/about_app_screen.dart';
import 'package:gift_ledger/screens/settings_screen.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/security_service.dart';
import 'package:gift_ledger/services/update/app_build_info_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:provider/provider.dart';

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

class FakeUpdateController extends UpdateController {
  FakeUpdateController({
    UpdateState state = const UpdateState(),
    UpdateChannel selectedChannel = UpdateChannel.stable,
  })  : _fakeState = state,
        _fakeSelectedChannel = selectedChannel,
        super(
          repository: _NoopUpdateRepository(),
          appBuildInfoService: const _NoopBuildInfoService(),
          configService: ConfigService(),
        );

  factory FakeUpdateController.idle({
    UpdateChannel selectedChannel = UpdateChannel.stable,
  }) {
    return FakeUpdateController(
      state: const UpdateState(status: UpdateStateStatus.idle),
      selectedChannel: selectedChannel,
    );
  }

  factory FakeUpdateController.available({
    String version = '1.3.0',
    String notes = '修复若干问题',
    UpdateChannel selectedChannel = UpdateChannel.stable,
    UpdateChannel targetChannel = UpdateChannel.stable,
    UpdatePlatform platform = UpdatePlatform.android,
    bool showRedDot = true,
    bool showDialog = false,
    bool showBanner = true,
    UpdateCheckSource lastSource = UpdateCheckSource.manual,
  }) {
    return FakeUpdateController(
      selectedChannel: selectedChannel,
      state: UpdateState(
        status: UpdateStateStatus.available,
        lastSource: lastSource,
        target: UpdateTarget(
          channel: targetChannel,
          resolvedTargetChannel: targetChannel,
          platform: platform,
          version: version,
          buildNumber: 13,
          notes: notes,
        ),
        showRedDot: showRedDot,
        showDialog: showDialog,
        showBanner: showBanner,
      ),
    );
  }

  factory FakeUpdateController.ignoredAvailable({
    String version = '1.3.1',
    String notes = '忽略版本后也应可见的更新说明',
    UpdateChannel selectedChannel = UpdateChannel.stable,
  }) {
    return FakeUpdateController.available(
      version: version,
      notes: notes,
      selectedChannel: selectedChannel,
      showRedDot: true,
      showDialog: false,
      showBanner: true,
      lastSource: UpdateCheckSource.startup,
    );
  }

  factory FakeUpdateController.installing({
    String version = '1.3.1',
    String notes = '第一行\n第二行\n第三行\n第四行',
    UpdateChannel selectedChannel = UpdateChannel.stable,
    UpdateChannel targetChannel = UpdateChannel.stable,
  }) {
    return FakeUpdateController(
      selectedChannel: selectedChannel,
      state: UpdateState(
        status: UpdateStateStatus.installing,
        lastSource: UpdateCheckSource.manual,
        target: UpdateTarget(
          channel: targetChannel,
          resolvedTargetChannel: targetChannel,
          platform: UpdatePlatform.android,
          version: version,
          buildNumber: 13,
          notes: notes,
        ),
        showRedDot: true,
      ),
    );
  }

  factory FakeUpdateController.installFailed({
    String version = '1.3.1',
    String notes = '修复若干问题',
    UpdateChannel selectedChannel = UpdateChannel.stable,
  }) {
    return FakeUpdateController(
      selectedChannel: selectedChannel,
      state: UpdateState(
        status: UpdateStateStatus.available,
        lastSource: UpdateCheckSource.manual,
        target: UpdateTarget(
          channel: UpdateChannel.stable,
          resolvedTargetChannel: UpdateChannel.stable,
          platform: UpdatePlatform.android,
          version: version,
          buildNumber: 13,
          notes: notes,
        ),
        showRedDot: true,
        error: StateError('install failed'),
      ),
    );
  }

  UpdateState _fakeState;
  UpdateChannel _fakeSelectedChannel;
  int checkCalls = 0;
  int installCalls = 0;
  int markCalls = 0;
  int ignoreCalls = 0;

  @override
  UpdateState get state => _fakeState;

  @override
  UpdateChannel get selectedChannel => _fakeSelectedChannel;

  void emit(UpdateState state) {
    _fakeState = state;
    notifyListeners();
  }

  @override
  void setSelectedChannel(UpdateChannel channel) {
    _fakeSelectedChannel = channel;
    _fakeState = const UpdateState();
    notifyListeners();
  }

  @override
  Future<void> checkForUpdates({required UpdateCheckSource source}) async {
    checkCalls += 1;
  }

  @override
  Future<void> installCurrentTarget() async {
    installCalls += 1;
  }

  @override
  Future<void> markCurrentTargetPresented() async {
    markCalls += 1;
  }

  @override
  Future<void> ignoreCurrentTarget() async {
    ignoreCalls += 1;
  }
}

class FakeSettingsStorageService {
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  Future<bool> getStatsIncludeEventBooks() async => true;

  Future<bool> getEventBooksEnabled() async => true;

  Future<void> setShowHomeAmounts(bool value) async {}
}

class FakeTemplateService {
  Future<bool> getUseFuzzyAmount() async => false;

  Future<void> setUseFuzzyAmount(bool value) async {}
}

class FakeNotificationService {
  Future<bool> isEnabled() async => false;

  Future<void> setEnabled(bool value) async {}
}

class FakeSettingsSecurityService {
  Future<String> getSecurityMode() async => SecurityService.modeNone;

  Future<bool> hasPin() async => true;

  Future<void> setPin(String pin) async {}

  Future<void> setSecurityMode(String mode) async {}
}

Widget buildSettingsTestApp({
  required FakeUpdateController updateController,
  String currentVersion = '1.2.8',
}) {
  return ChangeNotifierProvider<UpdateController>.value(
    value: updateController,
    child: MaterialApp(
      home: SettingsScreen(
        initialAppVersion: currentVersion,
        storageService: FakeSettingsStorageService(),
        templateService: FakeTemplateService(),
        notificationService: FakeNotificationService(),
        securityService: FakeSettingsSecurityService(),
      ),
    ),
  );
}

Widget buildAboutTestApp({
  required FakeUpdateController updateController,
  String currentVersion = '1.2.8',
}) {
  return ChangeNotifierProvider<UpdateController>.value(
    value: updateController,
    child: MaterialApp(
      home: AboutAppScreen(currentVersion: currentVersion),
    ),
  );
}

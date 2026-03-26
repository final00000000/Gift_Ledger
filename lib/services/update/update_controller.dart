import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/update_target.dart';
import '../../utils/semver_utils.dart';
import '../config_service.dart';
import 'app_build_info_service.dart';
import 'update_installer.dart';
import 'update_keys.dart';
import 'update_prompt_policy.dart';
import 'update_repository.dart';
import 'update_resolver.dart';

enum UpdateStateStatus {
  idle,
  checking,
  permissionRequired,
  downloading,
  installing,
  available,
  upToDate,
  error,
}

class UpdateState {
  final UpdateStateStatus status;
  final UpdateCheckSource? lastSource;
  final UpdateTarget? target;
  final bool showDialog;
  final bool showRedDot;
  final bool showBanner;
  final DownloadProgress? downloadProgress;
  final InstallResult? installResult;
  final Object? error;
  final StackTrace? stackTrace;

  const UpdateState({
    this.status = UpdateStateStatus.idle,
    this.lastSource,
    this.target,
    this.showDialog = false,
    this.showRedDot = false,
    this.showBanner = false,
    this.downloadProgress,
    this.installResult,
    this.error,
    this.stackTrace,
  });
}

class UpdateController extends ChangeNotifier {
  UpdateController({
    required UpdateRepository repository,
    required AppBuildInfoService appBuildInfoService,
    ConfigService? configService,
    UpdateInstaller? installer,
    UpdateResolver resolver = const UpdateResolver(),
    UpdatePromptPolicy promptPolicy = const UpdatePromptPolicy(),
    UpdateChannel selectedChannel = UpdateChannel.stable,
  })  : _repository = repository,
        _appBuildInfoService = appBuildInfoService,
        _configService = configService ?? ConfigService(),
        _installer = installer ?? createUpdateInstaller(),
        _resolver = resolver,
        _promptPolicy = promptPolicy,
        _selectedChannel = selectedChannel {
    _selectedChannel = _restoreSelectedChannel(selectedChannel);
    _promptedTargetKeys.addAll(_readKeySet(promptedTargetKeysConfigKey));
    _ignoredTargetKeys.addAll(_readKeySet(ignoredTargetKeysConfigKey));
  }

  final UpdateRepository _repository;
  final AppBuildInfoService _appBuildInfoService;
  final ConfigService _configService;
  final UpdateInstaller _installer;
  final UpdateResolver _resolver;
  final UpdatePromptPolicy _promptPolicy;

  final Set<String> _promptedTargetKeys = <String>{};
  final Set<String> _ignoredTargetKeys = <String>{};

  UpdateChannel _selectedChannel;
  UpdateState _state = const UpdateState();
  int _checkRequestEpoch = 0;
  bool _isInstallFlowStarting = false;
  bool _awaitingInstallPermissionGrant = false;
  bool _awaitingInstallCompletion = false;
  bool _didAutoResumePendingInstall = false;

  UpdateState get state => _state;
  UpdateChannel get selectedChannel => _selectedChannel;
  Set<String> get promptedTargetKeys => Set.unmodifiable(_promptedTargetKeys);
  Set<String> get ignoredTargetKeys => Set.unmodifiable(_ignoredTargetKeys);

  void setSelectedChannel(UpdateChannel channel) {
    if (_selectedChannel == channel) {
      return;
    }

    _checkRequestEpoch += 1;
    _selectedChannel = channel;
    _clearPendingInstallTracking();
    _state = const UpdateState();
    notifyListeners();
    unawaited(
      _configService.setString(selectedUpdateChannelConfigKey, channel.name),
    );
  }

  Future<void> checkForUpdates({required UpdateCheckSource source}) async {
    final requestEpoch = ++_checkRequestEpoch;
    final previousState = _state;

    _state = UpdateState(
      status: UpdateStateStatus.checking,
      lastSource: source,
    );
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _repository.fetchManifest(),
        _appBuildInfoService.getCurrentBuildInfo(),
      ]);
      final manifest = results[0] as dynamic;
      final buildInfo = results[1] as AppBuildInfo;

      final target = _resolver.resolve(
        manifest: manifest,
        selectedChannel: _selectedChannel,
        platform: buildInfo.platform,
        currentVersion: buildInfo.version,
        currentBuildNumber: buildInfo.buildNumber,
      );

      if (target == null) {
        if (!_isActiveCheck(requestEpoch)) {
          return;
        }

        _clearPendingInstallTracking();
        _state = UpdateState(
          status: UpdateStateStatus.upToDate,
          lastSource: source,
        );
        notifyListeners();
        return;
      }

      final decision = _promptPolicy.decide(
        source: source,
        target: target,
        ignoredTargetKeys: _ignoredTargetKeys,
        promptedTargetKeys: _promptedTargetKeys,
      );

      if (!_isActiveCheck(requestEpoch)) {
        return;
      }

      _clearPendingInstallTracking();
      _state = _buildAvailableState(
        source: source,
        target: target,
        decision: decision,
      );
      notifyListeners();
    } catch (error, stackTrace) {
      if (!_isActiveCheck(requestEpoch)) {
        return;
      }

      final preserveVisibleTarget =
          source == UpdateCheckSource.manual && previousState.target != null;

      _clearPendingInstallTracking();
      _state = UpdateState(
        status: UpdateStateStatus.error,
        lastSource: source,
        target: preserveVisibleTarget ? previousState.target : null,
        showRedDot: preserveVisibleTarget ? previousState.showRedDot : false,
        showBanner: false,
        error: error,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  Future<void> markCurrentTargetPresented() async {
    final target = _state.target;
    if (target == null) {
      return;
    }

    await _persistPromptedTargetKey(target);

    _state = _buildAvailableState(
      source: _state.lastSource ?? UpdateCheckSource.manual,
      target: target,
      status: _state.status == UpdateStateStatus.error
          ? UpdateStateStatus.available
          : _state.status,
      decision: const UpdatePromptDecision(
        showDialog: false,
        showRedDot: true,
        showBanner: false,
      ),
      downloadProgress: _state.downloadProgress,
      installResult: _state.installResult,
      error: _state.error,
      stackTrace: _state.stackTrace,
    );
    notifyListeners();
  }

  Future<void> ignoreCurrentTarget() async {
    final target = _state.target;
    if (target == null) {
      return;
    }

    await _persistTargetKey(
      target: target,
      keySet: _ignoredTargetKeys,
      storageKey: ignoredTargetKeysConfigKey,
    );

    final source = _state.lastSource ?? UpdateCheckSource.manual;
    _clearPendingInstallTracking();
    _state = _buildAvailableState(
      source: source,
      target: target,
    );
    notifyListeners();
  }

  Future<void> installCurrentTarget() async {
    final target = _state.target;
    if (target == null || _isInstallFlowBusy()) {
      return;
    }

    await _runInstallFlow(
      target: target,
      source: _state.lastSource ?? UpdateCheckSource.manual,
    );
  }

  Future<void> handleAppResumed() async {
    final target = _state.target;
    if (target == null) {
      return;
    }

    final source = _state.lastSource ?? UpdateCheckSource.manual;

    if (_awaitingInstallPermissionGrant) {
      try {
        final hasPermission = await _installer.canInstallPackages();
        if (hasPermission) {
          _awaitingInstallPermissionGrant = false;
          await _runInstallFlow(
            target: target,
            source: source,
            skipPermissionCheck: true,
          );
          return;
        }

        _awaitingInstallPermissionGrant = false;
        _state = _buildAvailableState(
          source: source,
          target: target,
          status: UpdateStateStatus.permissionRequired,
          error: const UpdateInstallerException('尚未开启安装权限，请先授权后继续更新。'),
        );
        notifyListeners();
      } catch (error, stackTrace) {
        _awaitingInstallPermissionGrant = false;
        _state = _buildAvailableState(
          source: source,
          target: target,
          status: UpdateStateStatus.permissionRequired,
          error: error,
          stackTrace: stackTrace,
        );
        notifyListeners();
      }
      return;
    }

    if (!_awaitingInstallCompletion) {
      return;
    }

    final lastInstallResult = _state.installResult;

    try {
      final buildInfo = await _appBuildInfoService.getCurrentBuildInfo();
      if (_isBuildInfoAtLeastTarget(buildInfo, target)) {
        _clearPendingInstallTracking();
        _state = UpdateState(
          status: UpdateStateStatus.upToDate,
          lastSource: source,
        );
        notifyListeners();
        return;
      }
    } catch (_) {
      // 读取当前版本失败时保持安装恢复兜底，不阻断后续逻辑。
    }

    if (_didAutoResumePendingInstall ||
        lastInstallResult == null ||
        !_isLocalInstallPath(lastInstallResult.savePath)) {
      _clearPendingInstallTracking();
      _state = _buildAvailableState(
        source: source,
        target: target,
        installResult: lastInstallResult,
      );
      notifyListeners();
      return;
    }

    _didAutoResumePendingInstall = true;
    _state = _buildAvailableState(
      source: source,
      target: target,
      status: UpdateStateStatus.installing,
      installResult: lastInstallResult,
    );
    notifyListeners();

    try {
      final reopenedResult = await _installer.reopenDownloadedPackage(
        lastInstallResult.savePath,
      );
      _state = _buildAvailableState(
        source: source,
        target: target,
        status: UpdateStateStatus.installing,
        installResult: reopenedResult,
      );
    } catch (error, stackTrace) {
      _clearPendingInstallTracking();
      _state = _buildAvailableState(
        source: source,
        target: target,
        installResult: lastInstallResult,
        error: error,
        stackTrace: stackTrace,
      );
    }

    notifyListeners();
  }

  Future<void> _runInstallFlow({
    required UpdateTarget target,
    required UpdateCheckSource source,
    bool skipPermissionCheck = false,
  }) async {
    if (_isInstallFlowStarting) {
      return;
    }

    _isInstallFlowStarting = true;
    try {
      await _startInstallFlow(
        target: target,
        source: source,
        skipPermissionCheck: skipPermissionCheck,
      );
    } finally {
      _isInstallFlowStarting = false;
    }
  }

  Future<void> _startInstallFlow({
    required UpdateTarget target,
    required UpdateCheckSource source,
    bool skipPermissionCheck = false,
  }) async {
    try {
      if (!skipPermissionCheck) {
        final hasPermission = await _installer.canInstallPackages();
        if (!hasPermission) {
          _state = _buildAvailableState(
            source: source,
            target: target,
            status: UpdateStateStatus.permissionRequired,
          );
          _awaitingInstallPermissionGrant = true;
          notifyListeners();

          final opened = await _installer.requestInstallPermission();
          if (!opened) {
            throw const UpdateInstallerException('无法打开安装权限设置页，请稍后重试。');
          }
          return;
        }
      }

      _awaitingInstallPermissionGrant = false;
      _state = _buildAvailableState(
        source: source,
        target: target,
        status: UpdateStateStatus.downloading,
        downloadProgress: const DownloadProgress(
          receivedBytes: 0,
          totalBytes: 0,
        ),
      );
      notifyListeners();

      final installResult = await _installer.downloadAndOpen(
        target,
        onProgress: (progress) {
          _emitDownloadProgress(
            source: source,
            target: target,
            progress: progress,
          );
        },
      );

      _awaitingInstallCompletion = installResult.didOpen;
      _didAutoResumePendingInstall = false;
      _state = _buildAvailableState(
        source: source,
        target: target,
        status: UpdateStateStatus.installing,
        installResult: installResult,
      );
    } catch (error, stackTrace) {
      _clearPendingInstallTracking();
      final resolvedStatus =
          _state.status == UpdateStateStatus.permissionRequired
              ? UpdateStateStatus.permissionRequired
              : UpdateStateStatus.available;
      _state = _buildAvailableState(
        source: source,
        target: target,
        status: resolvedStatus,
        error: error,
        stackTrace: stackTrace,
      );
    }

    notifyListeners();
  }

  void _emitDownloadProgress({
    required UpdateCheckSource source,
    required UpdateTarget target,
    required DownloadProgress progress,
  }) {
    final currentProgress = _state.downloadProgress;
    final didChange =
        currentProgress?.receivedBytes != progress.receivedBytes ||
            currentProgress?.totalBytes != progress.totalBytes ||
            _state.status != UpdateStateStatus.downloading;
    if (!didChange) {
      return;
    }

    _state = _buildAvailableState(
      source: source,
      target: target,
      status: UpdateStateStatus.downloading,
      downloadProgress: progress,
    );
    notifyListeners();
  }

  bool _isInstallFlowBusy() {
    if (_isInstallFlowStarting || _awaitingInstallPermissionGrant) {
      return true;
    }

    return _state.status == UpdateStateStatus.checking ||
        _state.status == UpdateStateStatus.downloading ||
        _state.status == UpdateStateStatus.installing;
  }

  void _clearPendingInstallTracking() {
    _awaitingInstallPermissionGrant = false;
    _awaitingInstallCompletion = false;
    _didAutoResumePendingInstall = false;
  }

  bool _isBuildInfoAtLeastTarget(AppBuildInfo buildInfo, UpdateTarget target) {
    final targetVersion = target.version;
    if (targetVersion == null || targetVersion.isEmpty) {
      return false;
    }

    final versionComparison = compareSemver(buildInfo.version, targetVersion);
    if (versionComparison > 0) {
      return true;
    }
    if (versionComparison < 0) {
      return false;
    }

    final currentBuildNumber = buildInfo.buildNumber;
    final targetBuildNumber = target.buildNumber;
    if (targetBuildNumber == null) {
      return true;
    }

    return currentBuildNumber >= targetBuildNumber;
  }

  bool _isLocalInstallPath(String path) {
    final normalizedPath = path.trim().toLowerCase();
    if (normalizedPath.isEmpty) {
      return false;
    }

    return !normalizedPath.startsWith('http://') &&
        !normalizedPath.startsWith('https://');
  }

  UpdateState _buildAvailableState({
    required UpdateCheckSource source,
    required UpdateTarget target,
    UpdateStateStatus status = UpdateStateStatus.available,
    UpdatePromptDecision? decision,
    DownloadProgress? downloadProgress,
    InstallResult? installResult,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final resolvedDecision = decision ??
        _promptPolicy.decide(
          source: source,
          target: target,
          ignoredTargetKeys: _ignoredTargetKeys,
          promptedTargetKeys: _promptedTargetKeys,
        );

    return UpdateState(
      status: status,
      lastSource: source,
      target: target,
      showDialog: resolvedDecision.showDialog,
      showRedDot: resolvedDecision.showRedDot,
      showBanner: resolvedDecision.showBanner,
      downloadProgress: downloadProgress,
      installResult: installResult,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Set<String> _readKeySet(String storageKey) {
    return Set<String>.from(
      _configService.getStringList(storageKey) ?? const <String>[],
    );
  }

  UpdateChannel _restoreSelectedChannel(UpdateChannel fallback) {
    final savedChannel =
        _configService.getString(selectedUpdateChannelConfigKey);
    if (savedChannel == null || savedChannel.isEmpty) {
      return fallback;
    }

    for (final channel in UpdateChannel.values) {
      if (channel.name == savedChannel) {
        return channel;
      }
    }

    return fallback;
  }

  Future<void> _persistTargetKey({
    required UpdateTarget target,
    required Set<String> keySet,
    required String storageKey,
  }) async {
    final targetKey = buildUpdateTargetKey(target);
    if (!keySet.add(targetKey)) {
      return;
    }

    final orderedKeys = keySet.toList()..sort();
    await _configService.setStringList(storageKey, orderedKeys);
  }

  Future<void> _persistPromptedTargetKey(UpdateTarget target) {
    return _persistTargetKey(
      target: target,
      keySet: _promptedTargetKeys,
      storageKey: promptedTargetKeysConfigKey,
    );
  }

  bool _isActiveCheck(int requestEpoch) => requestEpoch == _checkRequestEpoch;
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/update_target.dart';
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
    _state = _buildAvailableState(
      source: source,
      target: target,
    );
    notifyListeners();
  }

  Future<void> installCurrentTarget() async {
    final target = _state.target;
    if (target == null || _state.status == UpdateStateStatus.installing) {
      return;
    }

    final source = _state.lastSource ?? UpdateCheckSource.manual;
    _state = _buildAvailableState(
      source: source,
      target: target,
      status: UpdateStateStatus.installing,
    );
    notifyListeners();

    try {
      final installResult = await _installer.downloadAndOpen(target);
      _state = _buildAvailableState(
        source: source,
        target: target,
        installResult: installResult,
      );
    } catch (error, stackTrace) {
      _state = _buildAvailableState(
        source: source,
        target: target,
        error: error,
        stackTrace: stackTrace,
      );
    }

    notifyListeners();
  }

  UpdateState _buildAvailableState({
    required UpdateCheckSource source,
    required UpdateTarget target,
    UpdateStateStatus status = UpdateStateStatus.available,
    UpdatePromptDecision? decision,
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


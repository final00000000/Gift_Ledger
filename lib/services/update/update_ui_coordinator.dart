import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../../models/update_target.dart';
import 'update_controller.dart';
import 'update_keys.dart';

typedef UpdateMessageHandler = void Function(String message);
typedef PostFrameScheduler = void Function(FrameCallback callback);

class UpdatePromptCoordinator {
  bool _isShowingDialog = false;
  String? _activeDialogKey;

  String? beginPresentation(UpdateState state) {
    final target = state.target;
    if (_isShowingDialog || !state.showDialog || target == null) {
      return null;
    }

    final dialogKey = buildSafeUpdateTargetKey(target);
    if (_activeDialogKey == dialogKey) {
      return null;
    }

    _isShowingDialog = true;
    _activeDialogKey = dialogKey;
    return dialogKey;
  }

  void endPresentation() {
    _isShowingDialog = false;
    _activeDialogKey = null;
  }
}

void scheduleManualUpdatePresentation({
  required UpdateController controller,
  required UpdateTarget target,
  required bool Function() isMounted,
  required PostFrameScheduler schedulePostFrame,
  required UpdateMessageHandler showMessage,
}) {
  final targetKey = buildSafeUpdateTargetKey(target);

  schedulePostFrame((_) async {
    if (!isMounted()) {
      return;
    }

    final currentTarget = controller.state.target;
    if (currentTarget == null) {
      return;
    }

    if (buildSafeUpdateTargetKey(currentTarget) != targetKey) {
      return;
    }

    await controller.markCurrentTargetPresented();
    if (!isMounted()) {
      return;
    }

    final version = currentTarget.version;
    showMessage(
      version == null || version.isEmpty ? '发现新版本' : '发现新版本 v$version',
    );
  });
}

String? buildInstallFeedbackMessage(
  UpdateState state, {
  String fallbackErrorMessage = '启动更新失败',
}) {
  if (state.error != null) {
    return fallbackErrorMessage;
  }

  final message = state.installResult?.message;
  if (message == null || message.isEmpty) {
    return null;
  }

  return message;
}

Future<String?> installCurrentUpdateAndCollectMessage(
  UpdateController controller, {
  String fallbackErrorMessage = '启动更新失败',
}) async {
  await controller.installCurrentTarget();
  return buildInstallFeedbackMessage(
    controller.state,
    fallbackErrorMessage: fallbackErrorMessage,
  );
}

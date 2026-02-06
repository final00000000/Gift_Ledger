import 'package:flutter/material.dart';

import '../services/security_service.dart';
import '../widgets/pin_code_dialog.dart';

/// UI 层的统一解锁入口：
/// - 先确保 SecurityService 完成 init（避免冷启动/页面首次进入的竞态）
/// - 无锁模式（modeNone）不应弹 PIN，直接解锁以恢复可见/可操作状态
/// - 有锁模式下，如未解锁则弹 PIN 验证
///
/// 说明：这里刻意放在 utils（UI 可引用）而不是 services，避免服务层依赖 UI 组件。
extension SecurityServiceUnlockUi on SecurityService {
  Future<bool> ensureUnlocked(BuildContext context) async {
    await init();

    final mode = await getSecurityMode();
    if (mode == SecurityService.modeNone) {
      // 无锁模式：isUnlocked 仍用于“隐私显示/隐藏”状态，但不应要求 PIN。
      if (!isUnlocked.value) {
        unlock();
      }
      return true;
    }

    // 有锁模式：已经解锁则直接放行，否则弹出 PIN 验证。
    if (isUnlocked.value) return true;
    return await PinCodeDialog.show(context);
  }
}


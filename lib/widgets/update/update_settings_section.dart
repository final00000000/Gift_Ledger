import 'package:flutter/material.dart';

import '../../models/update_target.dart';
import '../../services/update/update_controller.dart';
import '../../services/update/update_prompt_policy.dart';
import '../../theme/app_theme.dart';

class UpdateSettingsSection extends StatelessWidget {
  const UpdateSettingsSection({
    super.key,
    required this.currentVersion,
    required this.status,
    required this.lastSource,
    required this.target,
    required this.onCheckPressed,
    required this.onInstallPressed,
  });

  final String currentVersion;
  final UpdateStateStatus status;
  final UpdateCheckSource? lastSource;
  final UpdateTarget? target;
  final VoidCallback onCheckPressed;
  final VoidCallback onInstallPressed;

  bool get _isChecking => status == UpdateStateStatus.checking;
  bool get _isInstalling => status == UpdateStateStatus.installing;
  bool get _isBusy => _isChecking || _isInstalling;

  String get _currentVersionLabel {
    return currentVersion.trim().isEmpty ? '当前版本未知' : '当前版本 v$currentVersion';
  }

  String get _headline {
    switch (status) {
      case UpdateStateStatus.checking:
        return '正在检查更新...';
      case UpdateStateStatus.installing:
        return '正在准备安装更新...';
      case UpdateStateStatus.upToDate:
        return '当前已是最新版本';
      case UpdateStateStatus.available:
        final version = target?.version;
        if (version == null || version.isEmpty) {
          return '发现可更新版本';
        }
        return '可更新到 v$version';
      case UpdateStateStatus.error:
        if (lastSource == UpdateCheckSource.manual) {
          return '当前网络不可用，或暂时无法访问更新服务';
        }
        return '检查最新版本与更新说明';
      case UpdateStateStatus.idle:
        return '检查最新版本与更新说明';
    }
  }

  String get _checkButtonLabel {
    switch (status) {
      case UpdateStateStatus.checking:
        return '检查中...';
      case UpdateStateStatus.available:
      case UpdateStateStatus.installing:
      case UpdateStateStatus.upToDate:
        return '重新检查';
      case UpdateStateStatus.error:
        return lastSource == UpdateCheckSource.manual ? '重试' : '检查更新';
      case UpdateStateStatus.idle:
        return '检查更新';
    }
  }

  bool get _showInstallButton {
    return target != null && status != UpdateStateStatus.error;
  }

  bool get _isTargetBetaRelease {
    return target?.effectiveResolvedTargetChannel == UpdateChannel.beta;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '应用更新',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
            ),
            title: Text(
              _headline,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              _currentVersionLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            visualDensity: VisualDensity.compact,
          ),
          if (target != null && status != UpdateStateStatus.error) ...[
            const Divider(height: 1, indent: 52),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            target!.version == null || target!.version!.isEmpty
                                ? '发现可更新版本'
                                : '目标版本 v${target!.version}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_isTargetBetaRelease)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Beta',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (target!.buildNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '构建号 ${target!.buildNumber}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : onCheckPressed,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_checkButtonLabel),
                ),
                if (_showInstallButton)
                  FilledButton(
                    onPressed: _isBusy ? null : onInstallPressed,
                    child: Text(_isInstalling ? '更新中...' : '立即更新'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

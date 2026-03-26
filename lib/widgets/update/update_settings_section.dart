import 'package:flutter/material.dart';

import '../../models/update_target.dart';
import '../../services/update/update_controller.dart';
import '../../services/update/update_installer.dart';
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
    this.error,
    this.installResult,
    this.downloadProgress,
  });

  final String currentVersion;
  final UpdateStateStatus status;
  final UpdateCheckSource? lastSource;
  final UpdateTarget? target;
  final VoidCallback onCheckPressed;
  final VoidCallback onInstallPressed;
  final Object? error;
  final InstallResult? installResult;
  final DownloadProgress? downloadProgress;

  bool get _isChecking => status == UpdateStateStatus.checking;
  bool get _isPermissionRequired =>
      status == UpdateStateStatus.permissionRequired;
  bool get _isDownloading => status == UpdateStateStatus.downloading;
  bool get _isInstalling => status == UpdateStateStatus.installing;
  bool get _isCheckBusy =>
      _isChecking || _isPermissionRequired || _isDownloading || _isInstalling;
  bool get _isInstallBusy => _isDownloading || _isInstalling;
  bool get _hasInstallActionError => error is UpdateInstallerException;

  String get _currentVersionLabel {
    return currentVersion.trim().isEmpty ? '当前版本未知' : '当前版本 v$currentVersion';
  }

  String get _headline {
    switch (status) {
      case UpdateStateStatus.checking:
        return '正在检查更新...';
      case UpdateStateStatus.permissionRequired:
        return '需要先开启安装权限';
      case UpdateStateStatus.downloading:
        final percent = _downloadPercentLabel;
        return percent == null ? '正在下载更新...' : '正在下载更新 $percent';
      case UpdateStateStatus.installing:
        return '正在打开系统安装器';
      case UpdateStateStatus.upToDate:
        return '当前已是最新版本';
      case UpdateStateStatus.available:
        final version = target?.version;
        if (version == null || version.isEmpty) {
          return '发现可更新版本';
        }
        return '可更新到 v$version';
      case UpdateStateStatus.error:
        if (_hasInstallActionError) {
          return '本次更新未完成';
        }
        if (lastSource == UpdateCheckSource.manual) {
          return '当前网络不可用，或暂时无法访问更新服务';
        }
        return '检查最新版本与更新说明';
      case UpdateStateStatus.idle:
        return '检查最新版本与更新说明';
    }
  }

  String? get _downloadPercentLabel {
    final fraction = downloadProgress?.fraction;
    if (fraction == null) {
      return null;
    }
    final percent = (fraction * 100).clamp(0, 100).round();
    return '$percent%';
  }

  String get _checkButtonLabel {
    switch (status) {
      case UpdateStateStatus.checking:
        return '检查中...';
      case UpdateStateStatus.permissionRequired:
      case UpdateStateStatus.downloading:
      case UpdateStateStatus.installing:
      case UpdateStateStatus.available:
      case UpdateStateStatus.upToDate:
        return '重新检查';
      case UpdateStateStatus.error:
        return lastSource == UpdateCheckSource.manual ? '重试' : '检查更新';
      case UpdateStateStatus.idle:
        return '检查更新';
    }
  }

  String get _installButtonLabel {
    switch (status) {
      case UpdateStateStatus.permissionRequired:
        return '去开启权限';
      case UpdateStateStatus.downloading:
        return _downloadPercentLabel == null
            ? '下载中...'
            : '下载中 ${_downloadPercentLabel!}';
      case UpdateStateStatus.installing:
        return '安装中...';
      case UpdateStateStatus.error:
        return _hasInstallActionError ? '重新下载' : '立即更新';
      case UpdateStateStatus.available:
      case UpdateStateStatus.idle:
      case UpdateStateStatus.checking:
      case UpdateStateStatus.upToDate:
        return '立即更新';
    }
  }

  bool get _showInstallButton {
    if (target == null) {
      return false;
    }

    if (status == UpdateStateStatus.error && !_hasInstallActionError) {
      return false;
    }

    return true;
  }

  bool get _isTargetBetaRelease {
    return target?.effectiveResolvedTargetChannel == UpdateChannel.beta;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    final digits = unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }

  String? _resolveInstallerError() {
    if (error is UpdateInstallerException) {
      return (error as UpdateInstallerException).message;
    }
    return null;
  }

  Widget? _buildStatusBody() {
    final installerError = _resolveInstallerError();

    if (_isPermissionRequired) {
      return _buildInfoBanner(
        icon: Icons.verified_user_outlined,
        color: AppTheme.primaryColor,
        message: installerError ?? '请先允许“随礼记”安装应用，返回后会自动继续更新。',
      );
    }

    if (_isDownloading) {
      final progressText = downloadProgress == null
          ? '正在准备下载，请保持网络畅通'
          : downloadProgress!.hasTotalBytes
              ? '${_formatBytes(downloadProgress!.receivedBytes)} / ${_formatBytes(downloadProgress!.totalBytes)}'
              : '已下载 ${_formatBytes(downloadProgress!.receivedBytes)}';
      return Column(
        children: [
          _buildInfoBanner(
            icon: Icons.downloading_rounded,
            color: AppTheme.primaryColor,
            message: progressText,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: downloadProgress?.fraction,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ],
      );
    }

    if (_isInstalling) {
      return _buildInfoBanner(
        icon: Icons.install_mobile_rounded,
        color: AppTheme.primaryColor,
        message: installResult?.message ?? '安装器已启动，请按系统提示完成更新。',
      );
    }

    if (installerError != null && installerError.isNotEmpty) {
      return _buildInfoBanner(
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFDC2626),
        message: installerError,
      );
    }

    return null;
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBody = _buildStatusBody();

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
          if (target != null) ...[
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
                    if (statusBody != null) ...[
                      const SizedBox(height: 12),
                      statusBody,
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
                  onPressed: _isCheckBusy ? null : onCheckPressed,
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
                    onPressed: _isInstallBusy ? null : onInstallPressed,
                    child: Text(_installButtonLabel),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

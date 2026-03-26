import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/update_target.dart';
import '../../services/update/update_controller.dart';
import '../../services/update/update_installer.dart';
import '../../theme/app_theme.dart';

enum UpdatePromptDialogAction {
  later,
  install,
}

class UpdatePromptDialogResult {
  final UpdatePromptDialogAction action;
  final bool ignoreCurrentVersion;

  const UpdatePromptDialogResult({
    required this.action,
    required this.ignoreCurrentVersion,
  });
}

class UpdatePromptDialog extends StatefulWidget {
  const UpdatePromptDialog({
    super.key,
    required this.target,
    this.onShown,
  });

  final UpdateTarget target;
  final VoidCallback? onShown;

  @override
  State<UpdatePromptDialog> createState() => _UpdatePromptDialogState();
}

class _UpdatePromptDialogState extends State<UpdatePromptDialog> {
  bool _ignoreCurrentVersion = false;
  bool _didNotifyShown = false;
  bool _didScheduleAutoClose = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didNotifyShown) {
        return;
      }
      _didNotifyShown = true;
      widget.onShown?.call();
    });
  }

  bool get _isBetaRelease {
    return widget.target.effectiveResolvedTargetChannel == UpdateChannel.beta;
  }

  String get _versionLabel {
    final version = widget.target.version;
    return version == null || version.isEmpty ? '版本信息不可用' : 'v$version';
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

  String? _resolveErrorMessage(Object? error) {
    if (error is UpdateInstallerException) {
      return error.message;
    }
    return null;
  }

  void _closeWithAction(UpdatePromptDialogAction action) {
    Navigator.of(context).pop(
      UpdatePromptDialogResult(
        action: action,
        ignoreCurrentVersion: _ignoreCurrentVersion,
      ),
    );
  }

  void _maybeAutoClose(UpdateState state) {
    if (_didScheduleAutoClose) {
      return;
    }

    if (state.target != null && state.status != UpdateStateStatus.upToDate) {
      return;
    }

    _didScheduleAutoClose = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final updateState = context.watch<UpdateController>().state;
    _maybeAutoClose(updateState);
    final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.86;

    final effectiveTarget = updateState.target ?? widget.target;
    final errorMessage = _resolveErrorMessage(updateState.error);
    final notes = effectiveTarget.notes.trim().isEmpty
        ? '本次更新包含体验优化与问题修复。'
        : effectiveTarget.notes.trim();
    final progress = updateState.downloadProgress;
    final progressFraction = progress?.fraction;
    final percent = progressFraction == null
        ? null
        : (progressFraction * 100).clamp(0, 100).round();
    final isPermissionRequired =
        updateState.status == UpdateStateStatus.permissionRequired;
    final isDownloading = updateState.status == UpdateStateStatus.downloading;
    final isInstalling = updateState.status == UpdateStateStatus.installing;
    final showIgnoreOption =
        !isPermissionRequired && !isDownloading && !isInstalling;

    final primaryLabel = switch (updateState.status) {
      UpdateStateStatus.permissionRequired => '去授权',
      UpdateStateStatus.downloading =>
        percent == null ? '下载中…' : '下载中 $percent%',
      UpdateStateStatus.installing => '等待安装完成',
      UpdateStateStatus.error => '重新下载',
      _ => '立即更新',
    };

    final secondaryLabel = switch (updateState.status) {
      UpdateStateStatus.downloading => '后台继续',
      UpdateStateStatus.installing => '关闭',
      UpdateStateStatus.error => '关闭',
      _ => '稍后',
    };

    return PopScope(
      canPop: true,
      child: Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: maxDialogHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildStatusPanel(
                    isPermissionRequired: isPermissionRequired,
                    isDownloading: isDownloading,
                    isInstalling: isInstalling,
                    errorMessage: errorMessage,
                    progress: progress,
                    percent: percent,
                  ),
                  const SizedBox(height: 16),
                  _buildNotesCard(notes: notes),
                  if (showIgnoreOption) ...[
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _ignoreCurrentVersion,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        '这个版本不再提示',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _ignoreCurrentVersion = value ?? false;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _closeWithAction(
                            UpdatePromptDialogAction.later,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                            foregroundColor: AppTheme.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(secondaryLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isDownloading || isInstalling
                              ? null
                              : () {
                                  context
                                      .read<UpdateController>()
                                      .installCurrentTarget();
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: Icon(
                            isPermissionRequired
                                ? Icons.admin_panel_settings_outlined
                                : isDownloading
                                    ? Icons.downloading_rounded
                                    : Icons.download_rounded,
                          ),
                          label: Text(primaryLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
            ),
          ),
          child: const Icon(
            Icons.system_update_alt_rounded,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '发现新版本',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (_isBetaRelease)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Beta',
                        style: TextStyle(
                          color: Color(0xFFF97316),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _versionLabel,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard({required String notes}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 18,
                color: AppTheme.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                '更新说明',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 152),
            child: SingleChildScrollView(
              child: Text(
                notes,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel({
    required bool isPermissionRequired,
    required bool isDownloading,
    required bool isInstalling,
    required String? errorMessage,
    required DownloadProgress? progress,
    required int? percent,
  }) {
    if (isPermissionRequired) {
      return _UpdateStatusCard(
        icon: Icons.verified_user_outlined,
        accentColor: AppTheme.primaryColor,
        title: '需要先开启安装权限',
        description: errorMessage ?? '完成授权后返回应用，会自动继续这次更新。',
        footer: const Text(
          '点击“去授权”后按系统提示开启权限，再返回随礼记继续更新。',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      );
    }

    if (isDownloading) {
      final progressText = progress == null
          ? '正在准备下载，请保持网络畅通'
          : progress.hasTotalBytes
              ? '${_formatBytes(progress.receivedBytes)} / ${_formatBytes(progress.totalBytes)}'
              : '已下载 ${_formatBytes(progress.receivedBytes)}';
      return _UpdateStatusCard(
        icon: Icons.downloading_rounded,
        accentColor: AppTheme.primaryColor,
        title: percent == null ? '正在下载更新' : '正在下载更新 $percent%',
        description: '下载已开始，无需重复点击。关闭弹窗后也会继续下载。',
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progressText,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (percent != null)
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress?.fraction,
                minHeight: 8,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '可先关闭弹窗，稍后在设置 → 关于随礼记中查看进度。',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (isInstalling) {
      return _UpdateStatusCard(
        icon: Icons.install_mobile_rounded,
        accentColor: AppTheme.primaryColor,
        title: '准备安装更新',
        description: '下载已完成，请按系统提示继续安装。',
        footer: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '若安装页未立即出现，可稍候片刻或回到应用继续。',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null && errorMessage.isNotEmpty) {
      return _UpdateStatusCard(
        icon: Icons.error_outline_rounded,
        accentColor: const Color(0xFFDC2626),
        title: '本次更新未完成',
        description: errorMessage,
        footer: const Text(
          '你可以稍后重试，下载会重新开始。',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      );
    }

    return const _UpdateStatusCard(
      icon: Icons.auto_awesome_rounded,
      accentColor: AppTheme.primaryColor,
      title: '建议现在更新',
      description: '点击“立即更新”后会在这里显示下载进度，下载完成后自动拉起安装。',
    );
  }
}

class _UpdateStatusCard extends StatelessWidget {
  const _UpdateStatusCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    this.footer,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}

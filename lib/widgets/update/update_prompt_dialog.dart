import 'package:flutter/material.dart';

import '../../models/update_target.dart';
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
    final buildNumber = widget.target.buildNumber;

    final buffer = StringBuffer(
      version == null || version.isEmpty ? '版本信息不可用' : 'v$version',
    );
    if (buildNumber != null) {
      buffer.write(' · 构建 $buildNumber');
    }
    return buffer.toString();
  }

  void _closeWithAction(UpdatePromptDialogAction action) {
    Navigator.of(context).pop(
      UpdatePromptDialogResult(
        action: action,
        ignoreCurrentVersion: _ignoreCurrentVersion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              '发现新版本',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_isBetaRelease)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Beta',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _versionLabel,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.target.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.target.notes.trim(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _closeWithAction(UpdatePromptDialogAction.later),
          child: const Text('稍后再说'),
        ),
        FilledButton.icon(
          onPressed: () => _closeWithAction(UpdatePromptDialogAction.install),
          icon: const Icon(Icons.download_rounded),
          label: const Text('立即更新'),
        ),
      ],
    );
  }
}

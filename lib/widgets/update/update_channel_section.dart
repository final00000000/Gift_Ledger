import 'package:flutter/material.dart';

import '../../models/update_target.dart';
import '../../theme/app_theme.dart';

class UpdateChannelSection extends StatelessWidget {
  const UpdateChannelSection({
    super.key,
    required this.selectedChannel,
    required this.enabled,
    required this.onBetaChanged,
  });

  final UpdateChannel selectedChannel;
  final bool enabled;
  final ValueChanged<bool> onBetaChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.science_rounded,
            color: Colors.orange,
            size: 18,
          ),
        ),
        title: const Text(
          '接收 Beta 测试版',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          '开启后可提前体验测试中的新功能',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: Switch.adaptive(
          value: selectedChannel == UpdateChannel.beta,
          onChanged: enabled ? onBetaChanged : null,
          activeTrackColor: AppTheme.primaryColor,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

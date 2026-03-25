import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AboutAppEntryTile extends StatelessWidget {
  const AboutAppEntryTile({
    super.key,
    required this.currentVersion,
    required this.showRedDot,
    required this.showUpdateChip,
    required this.onTap,
  });

  final String currentVersion;
  final bool showRedDot;
  final bool showUpdateChip;
  final VoidCallback onTap;

  String get _versionLabel {
    return currentVersion.trim().isEmpty ? '当前版本未知' : '当前版本 v$currentVersion';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          color: AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          const Flexible(
            child: Text(
              '关于随礼记',
              style: TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showRedDot) ...[
            const SizedBox(width: 6),
            Container(
              key: const ValueKey('about-app-red-dot'),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _versionLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            if (showUpdateChip)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '发现新版本',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

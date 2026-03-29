import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../app_logo.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.isUnlocked,
    required this.onSecurityPressed,
  });

  final bool isUnlocked;
  final Future<void> Function() onSecurityPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingM,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      child: Row(
        children: [
          const AppLogo(size: 44),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '随礼记',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: onSecurityPressed,
              icon: Icon(
                isUnlocked
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: isUnlocked
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class DashboardFab extends StatelessWidget {
  const DashboardFab({
    super.key,
    required this.bottomPadding,
    required this.onPressed,
  });

  final double bottomPadding;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final fabBottom = 64.0 + (bottomPadding > 12 ? bottomPadding : 12.0) + 16.0;

    return Positioned(
      right: 16,
      bottom: fabBottom,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

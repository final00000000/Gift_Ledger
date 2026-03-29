import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({
    super.key,
    required this.onAddRecord,
  });

  final Future<void> Function() onAddRecord;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      data: EmptyStates.noRecords(onAction: onAddRecord),
    );
  }
}

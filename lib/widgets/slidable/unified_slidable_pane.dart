import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class UnifiedSlidableAction {
  const UnifiedSlidableAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.fontWeight = FontWeight.w700,
    this.foregroundColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.showIcon = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;
  final FontWeight fontWeight;
  final Color foregroundColor;
  final BorderRadius borderRadius;
  final bool showIcon;
}

class UnifiedSlidablePane extends StatelessWidget {
  const UnifiedSlidablePane({
    super.key,
    required this.child,
    required this.actions,
    this.enabled = true,
    this.extentRatio = 0.52,
    this.actionSpacing = 8,
    this.childEndPadding = 8,
  });

  final Widget child;
  final List<UnifiedSlidableAction> actions;
  final bool enabled;
  final double extentRatio;
  final double actionSpacing;
  final double childEndPadding;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      enabled: enabled,
      startActionPane: null,
      endActionPane: actions.isEmpty
          ? null
          : ActionPane(
              motion: const ScrollMotion(),
              extentRatio: extentRatio,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  Expanded(
                    child: UnifiedSlidableButton(action: actions[i]),
                  ),
                  if (i < actions.length - 1) SizedBox(width: actionSpacing),
                ],
              ],
            ),
      child: Padding(
        padding: EdgeInsets.only(right: childEndPadding),
        child: child,
      ),
    );
  }
}

class UnifiedSlidableButton extends StatelessWidget {
  const UnifiedSlidableButton({
    super.key,
    required this.action,
  });

  final UnifiedSlidableAction action;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: action.borderRadius,
      child: Material(
        color: action.color,
        child: InkWell(
          onTap: action.onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action.showIcon && action.icon != null) ...[
                  Icon(action.icon, color: action.foregroundColor, size: 20),
                  const SizedBox(height: 6),
                ],
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: action.fontWeight,
                    color: action.foregroundColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

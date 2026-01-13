import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../theme/app_theme.dart';

class GiftListItem extends StatelessWidget {
  final Gift gift;
  final Guest? guest;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GiftListItem({
    super.key,
    required this.gift,
    this.guest,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM月dd日');

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: Colors.black.withOpacity(0.04)), // Visibility Border
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  // 图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gift.isReceived
                            ? [
                                AppTheme.primaryColor.withOpacity(0.15),
                                AppTheme.primaryColor.withOpacity(0.05),
                              ]
                            : [
                                AppTheme.accentColor.withOpacity(0.25),
                                AppTheme.accentColor.withOpacity(0.10),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      _getEventIcon(gift.eventType),
                      color: gift.isReceived
                          ? AppTheme.primaryColor
                          : AppTheme.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              guest?.name ?? '未知',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingS,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                gift.eventType,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: gift.isReceived 
                                    ? AppTheme.primaryColor.withOpacity(0.12) 
                                    : AppTheme.accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                gift.isReceived ? "收礼" : "送礼",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: gift.isReceived 
                                      ? AppTheme.primaryColor 
                                      : AppTheme.accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(gift.date),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 金额
                  Text(
                    '${gift.isReceived ? "+" : "-"}¥${gift.amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: gift.isReceived
                          ? AppTheme.primaryColor
                          : AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case '婚礼':
        return Icons.favorite_rounded;
      case '满月':
        return Icons.child_care_rounded;
      case '乔迁':
        return Icons.home_rounded;
      case '生日':
        return Icons.cake_rounded;
      case '丧事':
        return Icons.local_florist_rounded;
      case '过年':
        return Icons.celebration_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }
}

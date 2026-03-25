import 'package:flutter/material.dart';

import '../../models/gift.dart';
import '../../models/guest.dart';
import '../../theme/app_theme.dart';
import '../gift_note_preview.dart';
import '../privacy_aware_text.dart';

class PendingGiftCard extends StatelessWidget {
  const PendingGiftCard({
    super.key,
    required this.gift,
    required this.guest,
    required this.lunarDate,
    required this.daysText,
    required this.statusColor,
  });

  final Gift gift;
  final Guest? guest;
  final String lunarDate;
  final String daysText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final solarDate =
        '${gift.date.month.toString().padLeft(2, '0')}月${gift.date.day.toString().padLeft(2, '0')}日';
    final dateLabel =
        lunarDate.isNotEmpty ? '$solarDate ($lunarDate)' : solarDate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        guest?.name ?? '未知',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 88),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        gift.eventType,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                GiftNotePreview(
                  note: gift.note,
                  maxLines: 1,
                  fontSize: 11,
                  topSpacing: 6,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PrivacyAwareText(
                '¥${gift.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: gift.isReceived
                      ? AppTheme.primaryColor
                      : AppTheme.accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                daysText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

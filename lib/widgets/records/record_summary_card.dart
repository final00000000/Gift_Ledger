import 'package:flutter/material.dart';

import '../../models/gift.dart';
import '../../models/guest.dart';
import '../../theme/app_theme.dart';
import '../gift_note_preview.dart';
import '../privacy_aware_text.dart';

class RecordSummaryCard extends StatelessWidget {
  const RecordSummaryCard({
    super.key,
    required this.gift,
    required this.guest,
    required this.solarDate,
    required this.lunarDate,
    required this.itemColor,
    this.onTap,
  });

  final Gift gift;
  final Guest? guest;
  final String solarDate;
  final String lunarDate;
  final Color itemColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        lunarDate.isNotEmpty ? '$solarDate · $lunarDate' : solarDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        itemColor.withValues(alpha: 0.12),
                        itemColor.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    gift.isReceived
                        ? Icons.move_to_inbox_rounded
                        : Icons.outbox_rounded,
                    color: itemColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guest?.name ?? '未知联系人',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 88),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              gift.eventType,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: itemColor.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
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
                      '${gift.isReceived ? "+" : "-"}¥${gift.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: itemColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

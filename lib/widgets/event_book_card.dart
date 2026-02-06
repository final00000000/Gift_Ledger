import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_book.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';

class EventBookCard extends StatelessWidget {
  final EventBook eventBook;
  final int giftCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EventBookCard({
    super.key,
    required this.eventBook,
    this.giftCount = 0,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
  });

  Color _getTypeColor(String type) {
    switch (type) {
      case '婚礼':
        return const Color(0xFFFF4D4F);
      case '生日':
      case '满月':
        return const Color(0xFFFAAD14);
      case '乔迁':
        return const Color(0xFF1890FF);
      case '丧事':
        return const Color(0xFF595959);
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(eventBook.type);
    final lunarDate = LunarUtils.getLunarDateString(eventBook.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.08),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                // Decorative background element
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Large Icon Container
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              typeColor.withValues(alpha: 0.15),
                              typeColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Icon(
                            _getEventIcon(eventBook.type),
                            color: typeColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Middle: Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventBook.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    eventBook.type,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: typeColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('yyyy.MM.dd').format(eventBook.date),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (eventBook.note != null && eventBook.note!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                eventBook.note!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Right: Stats & Menu
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  lunarDate,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (onEdit != null || onDelete != null)
                                _buildMenu(context),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '$giftCount',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' 笔',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        height: 24,
        width: 24,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_horiz_rounded, color: Colors.grey[400], size: 16),
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      offset: const Offset(0, 30),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit?.call();
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18, color: Colors.blue[400]),
              const SizedBox(width: 10),
              const Text('修改记录'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red[400]),
              const SizedBox(width: 10),
              Text('删除记录', style: TextStyle(color: Colors.red[400])),
            ],
          ),
        ),
      ],
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
        return Icons.spa_rounded;
      case '酒席':
        return Icons.celebration_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }
}

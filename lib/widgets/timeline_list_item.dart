import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import 'privacy_aware_text.dart';

/// 时间轴列表项组件
/// 左侧时间线 + 右侧卡片设计
class TimelineListItem extends StatefulWidget {
  final Gift gift;
  final Guest? guest;
  final bool isFirst;
  final bool isLast;
  final bool showDateHeader;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int index;
  final Duration animationDelay;

  const TimelineListItem({
    super.key,
    required this.gift,
    this.guest,
    this.isFirst = false,
    this.isLast = false,
    this.showDateHeader = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.index = 0,
    this.animationDelay = Duration.zero,
  });

  @override
  State<TimelineListItem> createState() => _TimelineListItemState();
}

class _TimelineListItemState extends State<TimelineListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // 延迟启动动画，实现交错效果
    Future.delayed(
      widget.animationDelay + Duration(milliseconds: widget.index * 80),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final itemColor = widget.gift.isReceived
        ? AppTheme.primaryColor
        : AppTheme.accentColor;

    return Dismissible(
      key: Key('gift_${widget.gift.id}'),
      background: _buildSwipeBackground(
        color: Colors.blue,
        icon: Icons.edit_rounded,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: Colors.red,
        icon: Icons.delete_rounded,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 右滑编辑
          widget.onEdit?.call();
          return false;
        } else {
          // 左滑删除
          return await _showDeleteConfirmation();
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          widget.onDelete?.call();
        }
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧时间轴
            _buildTimeline(itemColor),
            // 右侧卡片
            Expanded(
              child: _buildCard(itemColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(Color color) {
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          // 上方连接线
          if (!widget.isFirst)
            Container(
              width: 2,
              height: 12,
              color: color.withOpacity(0.2),
            )
          else
            const SizedBox(height: 12),
          // 时间点
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // 下方连接线
          Expanded(
            child: Container(
              width: 2,
              color: widget.isLast
                  ? Colors.transparent
                  : color.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Color itemColor) {
    final dateFormat = DateFormat('MM月dd日');

    return Container(
      margin: const EdgeInsets.only(
        right: AppTheme.spacingM,
        bottom: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: itemColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: itemColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日期头部（如果需要显示）
                if (widget.showDateHeader) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppTheme.textSecondary.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(widget.gift.date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        LunarUtils.getLunarDateString(widget.gift.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // 主要内容
                Row(
                  children: [
                    // 图标
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            itemColor.withOpacity(0.15),
                            itemColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getEventIcon(widget.gift.eventType),
                        color: itemColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.guest?.name ?? '未知',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: itemColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.gift.isReceived ? '收礼' : '送礼',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: itemColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.gift.eventType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary.withOpacity(0.8),
                                  ),
                                ),
                              ),
                              if (!widget.showDateHeader) ...[
                                const SizedBox(width: 8),
                                Text(
                                  dateFormat.format(widget.gift.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 金额
                    PrivacyAwareText(
                      '${widget.gift.isReceived ? "+" : "-"}¥${widget.gift.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: itemColor,
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

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        left: 60,
        right: AppTheme.spacingM,
        bottom: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Future<bool> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除这条记录吗？\n\n${widget.guest?.name ?? "未知"} · ${widget.gift.eventType}\n¥${widget.gift.amount.toStringAsFixed(0)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
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

/// 时间轴日期分组头部
class TimelineDateHeader extends StatelessWidget {
  final DateTime date;

  const TimelineDateHeader({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年MM月dd日');

    return Padding(
      padding: const EdgeInsets.only(
        left: 60,
        right: AppTheme.spacingM,
        top: AppTheme.spacingM,
        bottom: AppTheme.spacingS,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  dateFormat.format(date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            LunarUtils.getLunarDateString(date),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

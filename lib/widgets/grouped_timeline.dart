import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../theme/app_theme.dart';
import 'timeline_list_item.dart';

/// 日期分组类型
enum DateGroup {
  today,
  yesterday,
  thisWeek,
  earlier,
}

/// 分组数据模型
class GroupedGifts {
  final DateGroup group;
  final String title;
  final List<Gift> gifts;

  const GroupedGifts({
    required this.group,
    required this.title,
    required this.gifts,
  });
}

/// 分组时间轴组件
/// 按日期分组显示：今天、昨天、本周、更早
class GroupedTimeline extends StatelessWidget {
  final List<Gift> gifts;
  final Map<int, Guest> guestMap;
  final Function(Gift gift, Guest? guest)? onTap;
  final Function(Gift gift, Guest? guest)? onEdit;
  final Function(Gift gift)? onDelete;
  final Duration animationDelay;

  const GroupedTimeline({
    super.key,
    required this.gifts,
    required this.guestMap,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.animationDelay = Duration.zero,
  });

  /// 将礼物列表按日期分组
  List<GroupedGifts> _groupGifts() {
    if (gifts.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final todayGifts = <Gift>[];
    final yesterdayGifts = <Gift>[];
    final thisWeekGifts = <Gift>[];
    final earlierGifts = <Gift>[];

    for (final gift in gifts) {
      final giftDate = DateTime(gift.date.year, gift.date.month, gift.date.day);

      if (giftDate == today) {
        todayGifts.add(gift);
      } else if (giftDate == yesterday) {
        yesterdayGifts.add(gift);
      } else if (giftDate.isAfter(weekStart) || giftDate == weekStart) {
        thisWeekGifts.add(gift);
      } else {
        earlierGifts.add(gift);
      }
    }

    final groups = <GroupedGifts>[];

    if (todayGifts.isNotEmpty) {
      groups.add(GroupedGifts(
        group: DateGroup.today,
        title: '今天',
        gifts: todayGifts,
      ));
    }

    if (yesterdayGifts.isNotEmpty) {
      groups.add(GroupedGifts(
        group: DateGroup.yesterday,
        title: '昨天',
        gifts: yesterdayGifts,
      ));
    }

    if (thisWeekGifts.isNotEmpty) {
      groups.add(GroupedGifts(
        group: DateGroup.thisWeek,
        title: '本周',
        gifts: thisWeekGifts,
      ));
    }

    if (earlierGifts.isNotEmpty) {
      groups.add(GroupedGifts(
        group: DateGroup.earlier,
        title: '更早',
        gifts: earlierGifts,
      ));
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupGifts();

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
          _GroupHeader(
            group: groups[groupIndex],
            animationDelay: animationDelay +
                Duration(milliseconds: groupIndex * 100),
          ),
          ...List.generate(
            groups[groupIndex].gifts.length,
            (index) {
              final gift = groups[groupIndex].gifts[index];
              final guest = guestMap[gift.guestId];
              final globalIndex = _getGlobalIndex(groups, groupIndex, index);

              // 判断是否需要显示日期头部
              bool showDateHeader = false;
              if (index == 0) {
                showDateHeader = true;
              } else {
                final prevGift = groups[groupIndex].gifts[index - 1];
                final currentDate =
                    DateFormat('yyyy-MM-dd').format(gift.date);
                final prevDate =
                    DateFormat('yyyy-MM-dd').format(prevGift.date);
                showDateHeader = currentDate != prevDate;
              }

              return TimelineListItem(
                gift: gift,
                guest: guest,
                isFirst: groupIndex == 0 && index == 0,
                isLast: groupIndex == groups.length - 1 &&
                    index == groups[groupIndex].gifts.length - 1,
                showDateHeader: showDateHeader,
                index: globalIndex,
                animationDelay: animationDelay,
                onTap: onTap != null ? () => onTap!(gift, guest) : null,
                onEdit: onEdit != null ? () => onEdit!(gift, guest) : null,
                onDelete: onDelete != null ? () => onDelete!(gift) : null,
              );
            },
          ),
        ],
      ],
    );
  }

  int _getGlobalIndex(List<GroupedGifts> groups, int groupIndex, int index) {
    int globalIndex = index;
    for (int i = 0; i < groupIndex; i++) {
      globalIndex += groups[i].gifts.length;
    }
    return globalIndex;
  }
}

/// 分组标题组件
class _GroupHeader extends StatefulWidget {
  final GroupedGifts group;
  final Duration animationDelay;

  const _GroupHeader({
    required this.group,
    required this.animationDelay,
  });

  @override
  State<_GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<_GroupHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    Future.delayed(widget.animationDelay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getGroupIcon() {
    switch (widget.group.group) {
      case DateGroup.today:
        return Icons.today_rounded;
      case DateGroup.yesterday:
        return Icons.history_rounded;
      case DateGroup.thisWeek:
        return Icons.date_range_rounded;
      case DateGroup.earlier:
        return Icons.schedule_rounded;
    }
  }

  Color _getGroupColor() {
    switch (widget.group.group) {
      case DateGroup.today:
        return AppTheme.primaryColor;
      case DateGroup.yesterday:
        return AppTheme.accentColor;
      case DateGroup.thisWeek:
        return AppTheme.statisticsColor;
      case DateGroup.earlier:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getGroupColor();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-20 * (1 - _animation.value), 0),
          child: Opacity(
            opacity: _animation.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: 8,
        ),
        child: Row(
          children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getGroupIcon(),
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // 标题
            Text(
              widget.group.title,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            // 数量徽章
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.group.gifts.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            // 装饰线
            Expanded(
              flex: 2,
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.3),
                      color.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

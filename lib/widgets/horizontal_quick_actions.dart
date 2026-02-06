import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 横向快捷操作项数据模型
class HorizontalActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final int? badge;
  final VoidCallback? onTap;

  const HorizontalActionItem({
    required this.title,
    required this.icon,
    required this.color,
    this.badge,
    this.onTap,
  });
}

/// 胶囊标签风格横向快捷操作组件
/// 与HeroSection的标签风格统一
class HorizontalQuickActions extends StatelessWidget {
  final List<HorizontalActionItem> items;
  final Duration animationDelay;

  const HorizontalQuickActions({
    super.key,
    required this.items,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: items.map((item) => _CapsuleActionButton(item: item)).toList(),
      ),
    );
  }
}

/// 胶囊样式快捷操作按钮
class _CapsuleActionButton extends StatelessWidget {
  final HorizontalActionItem item;

  const _CapsuleActionButton({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Icon(
                item.icon,
                color: item.color,
                size: 16,
              ),
              const SizedBox(width: 6),
              // 标题
              Text(
                item.title,
                style: TextStyle(
                  color: item.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // 徽章
              if (item.badge != null && item.badge! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badge}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/gift.dart';
import 'privacy_aware_text.dart';

/// 分类数据模型
class CategoryData {
  final String name;
  final double received;
  final double given;
  
  CategoryData({
    required this.name,
    required this.received,
    required this.given,
  });
  
  double get balance => received - given;
}

/// 对称柱状图 - 类似 React 组件的设计
/// 收入向上显示，支出向下显示
class SymmetryBarChart extends StatefulWidget {
  final List<Gift> gifts;
  final String? selectedCategory;
  final ValueChanged<String?>? onCategorySelected;

  const SymmetryBarChart({
    super.key,
    required this.gifts,
    this.selectedCategory,
    this.onCategorySelected,
  });

  @override
  State<SymmetryBarChart> createState() => _SymmetryBarChartState();
}

class _SymmetryBarChartState extends State<SymmetryBarChart> {
  /// 按分类汇总数据
  List<CategoryData> get categoryData {
    final map = <String, CategoryData>{};
    for (var gift in widget.gifts) {
      final category = gift.eventType;
      if (!map.containsKey(category)) {
        map[category] = CategoryData(name: category, received: 0, given: 0);
      }
      final current = map[category]!;
      if (gift.isReceived) {
        map[category] = CategoryData(
          name: category,
          received: current.received + gift.amount,
          given: current.given,
        );
      } else {
        map[category] = CategoryData(
          name: category,
          received: current.received,
          given: current.given + gift.amount,
        );
      }
    }
    return map.values.toList();
  }

  /// 获取分类图标
  IconData getCategoryIcon(String category) {
    switch (category) {
      case '婚礼':
        return Icons.favorite_rounded;
      case '满月':
        return Icons.child_care_rounded;
      case '乔迁':
        return Icons.home_rounded;
      case '生日':
        return Icons.cake_rounded;
      case '丧事':
        return Icons.sentiment_dissatisfied_rounded;
      case '过年':
        return Icons.celebration_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  /// 获取分类颜色
  Color getCategoryColor(String category) {
    switch (category) {
      case '婚礼':
        return const Color(0xFFEC4899); // 粉色
      case '满月':
        return const Color(0xFF0EA5E9); // 天蓝色
      case '乔迁':
        return const Color(0xFFF97316); // 橙色
      case '生日':
        return const Color(0xFF8B5CF6); // 紫色
      case '丧事':
        return const Color(0xFF6B7280); // 灰色
      case '过年':
        return const Color(0xFFEF4444); // 红色
      default:
        return const Color(0xFF64748B); // 默认灰色
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = categoryData;
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算最大值用于比例（使用 fold 简化）
    final maxReceived = data.fold<double>(0, (max, d) => d.received > max ? d.received : max);
    final maxGiven = data.fold<double>(0, (max, d) => d.given > max ? d.given : max);
    final maxValue = maxReceived > maxGiven ? maxReceived : maxGiven;
    final safeMax = maxValue == 0 ? 1.0 : maxValue;

    // 使用 RepaintBoundary 隔离图表重绘
    return RepaintBoundary(
      child: Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        // Glassmorphism / Card effect
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // 标题区域
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '分类统计',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Category Overview',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              // 右侧：图例 或 重置按钮
              if (widget.selectedCategory != null)
                GestureDetector(
                  onTap: () => widget.onCategorySelected?.call(null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              else
                // 颜色图例
                Row(
                  children: [
                    _buildLegendItem('收礼 ↑', const Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    _buildLegendItem('送礼 ↓', const Color(0xFFF43F5E)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // 对称柱状图区域
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.elasticOut,
            builder: (context, animValue, child) {
              return SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    // 中间基准线
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 80,
                      child: Container(
                        height: 1,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                    ),
                    // 柱状图
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: data.map((item) {
                        final isSelected = widget.selectedCategory == item.name;
                        final isUnselected = widget.selectedCategory != null &&
                            widget.selectedCategory != item.name;

                        return GestureDetector(
                          onTap: () {
                            widget.onCategorySelected?.call(
                              widget.selectedCategory == item.name ? null : item.name,
                            );
                          },
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: isUnselected ? 0.25 : 1.0,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 300),
                              scale: isSelected ? 1.08 : 1.0,
                              child: _buildSymmetryBar(
                                item,
                                safeMax,
                                animValue,
                                isSelected,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // 分类图标按钮区域
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: data.map((item) {
                final isSelected = widget.selectedCategory == item.name;
                final isUnselected = widget.selectedCategory != null &&
                    widget.selectedCategory != item.name;

                return GestureDetector(
                  onTap: () {
                    widget.onCategorySelected?.call(
                      widget.selectedCategory == item.name ? null : item.name,
                    );
                  },
                  child: Transform.scale(
                    scale: isSelected ? 1.1 : 1.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isUnselected ? 0.3 : 1.0,
                          child: Icon(
                            getCategoryIcon(item.name),
                            size: 24,
                            color: getCategoryColor(item.name),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isUnselected ? 0.3 : 1.0,
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected 
                                  ? getCategoryColor(item.name) 
                                  : AppTheme.textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSymmetryBar(
    CategoryData item,
    double maxValue,
    double animationValue,
    bool isSelected,
  ) {
    final receivedRatio = (item.received / maxValue).clamp(0.0, 1.0);
    final givenRatio = (item.given / maxValue).clamp(0.0, 1.0);
    
    // 最大柱子高度
    const maxBarHeight = 70.0;
    const barWidth = 28.0;

    return SizedBox(
      width: 50,
      height: 160,
      child: Column(
        children: [
          // 收入柱 (向上)
          SizedBox(
            height: 80,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: barWidth,
                height: maxBarHeight * receivedRatio * animationValue,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.6),
                      const Color(0xFF818CF8),
                    ],
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, -4),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          // 支出柱 (向下)
          SizedBox(
            height: 80,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: barWidth,
                height: maxBarHeight * givenRatio * animationValue,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(6),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF43F5E).withValues(alpha: 0.6),
                      const Color(0xFFE11D48),
                    ],
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 保留原有的垂直柱状图 (收支对比)
class BalanceBarChart extends StatelessWidget {
  final double received;
  final double sent;

  const BalanceBarChart({
    super.key,
    required this.received,
    required this.sent,
  });

  @override
  Widget build(BuildContext context) {
    final total = received + sent;
    final maxAmount = (received > sent ? received : sent);
    final safeMax = maxAmount == 0 ? 1.0 : maxAmount;

    // 使用 RepaintBoundary 隔离图表重绘
    return RepaintBoundary(
      child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingL,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        // 多层软阴影，营造高级悬浮感
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    '收支对比',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最近数据概览',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, 
                        size: 14, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        '¥${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          // 带有基准线的图表区域
          Stack(
            children: [
              // 背景基准线
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (index) => 
                    Container(
                      height: 1,
                      color: Colors.grey.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar(
                      context,
                      label: '收入',
                      amount: received,
                      ratio: received / safeMax,
                      color: AppTheme.primaryColor,
                      topColor: const Color(0xFF67E8F9), // 亮青色
                    ),
                    _buildBar(
                      context,
                      label: '支出',
                      amount: sent,
                      ratio: sent / safeMax,
                      color: AppTheme.accentColor,
                      topColor: const Color(0xFFFDA4AF), // 亮粉色
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBar(
    BuildContext context, {
    required String label,
    required double amount,
    required double ratio,
    required Color color,
    required Color topColor,
  }) {
    final safeRatio = ratio < 0.05 && amount > 0 ? 0.05 : ratio;
    
    return Column(
      children: [
        // 金额显示
        PrivacyAwareText(
          amount == 0 ? '0' : '¥${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        // 柱子主体
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1200),
          curve: Curves.elasticOut,
          tween: Tween(begin: 0, end: safeRatio),
          builder: (context, value, child) {
            return Container(
              width: 54,
              height: 160.0 * (value == 0 && amount > 0 ? 0.05 : value),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27), // 全圆角胶囊
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    color.withValues(alpha: 0.8),
                    color,
                    topColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 内部高光 (Inner Shine)
                  Positioned(
                    top: 10,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        // 标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// 统计列表项 (背景进度条风格)
class StatListItem extends StatelessWidget {
  final String label;
  final double amount;
  final double totalAmount;
  final Color color;
  final IconData icon;

  const StatListItem({
    super.key,
    required this.label,
    required this.amount,
    required this.totalAmount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalAmount == 0 ? 0.0 : amount / totalAmount;
    final displayRatio = ratio.isNaN ? 0.0 : ratio;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // 极其轻微的底部阴影或边框
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // 深度感图标容器
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    PrivacyAwareText(
                      '¥${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 高级感丝绸进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // 背景轨道
                      Container(
                        height: 12,
                        width: double.infinity,
                        color: Colors.grey.withAlpha(15),
                      ),
                      // 进度填充
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutQuart,
                        tween: Tween(begin: 0, end: displayRatio),
                        builder: (context, value, child) {
                          return FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withValues(alpha: 0.5),
                                    color,
                                    color.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: value > 0.05 ? Stack(
                                children: [
                                  // 末端亮点 (Glowing Spot)
                                  Positioned(
                                    right: 2,
                                    top: 3,
                                    bottom: 3,
                                    child: Container(
                                      width: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ) : null,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

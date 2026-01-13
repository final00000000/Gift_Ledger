import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 基础骨架容器（带 Shimmer 效果）
class SkeletonContainer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonContainer._({
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  /// 矩形骨架
  const SkeletonContainer.square({
    required double width,
    required double height,
    double borderRadius = 8,
  }) : this._(width: width, height: height, borderRadius: borderRadius);

  /// 圆形骨架
  const SkeletonContainer.circle({
    required double size,
  }) : this._(width: size, height: size, shape: BoxShape.circle);

  @override
  State<SkeletonContainer> createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Base colors based on brightness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius)
                : null,
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// 首页骨架屏
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部 Bar 占位
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingL,
            ),
            child: Row(
              children: [
                const SkeletonContainer.square(width: 40, height: 40, borderRadius: 12),
                const SizedBox(width: 12),
                SkeletonContainer.square(width: 120, height: 24, borderRadius: 4),
              ],
            ),
          ),

          // 收支卡片占位
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: SkeletonContainer.square(
              width: double.infinity,
              height: 180,
              borderRadius: AppTheme.radiusLarge,
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // 列表标题占位
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 SkeletonContainer.square(width: 80, height: 24, borderRadius: 4),
                 SkeletonContainer.square(width: 60, height: 20, borderRadius: 4),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingM),

          // 列表项占位 (生成 5 个)
          ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            itemCount: 5,
            separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingM),
            itemBuilder: (context, index) => const _ListItemSkeleton(),
          ),
        ],
      ),
    );
  }
}

class _ListItemSkeleton extends StatelessWidget {
  const _ListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // 头像
          const SkeletonContainer.circle(size: 48),
          const SizedBox(width: AppTheme.spacingM),
          // 文本区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonContainer.square(width: 100, height: 16, borderRadius: 4),
                const SizedBox(height: 8),
                SkeletonContainer.square(width: 60, height: 12, borderRadius: 4),
              ],
            ),
          ),
          // 金额
          SkeletonContainer.square(width: 80, height: 20, borderRadius: 4),
        ],
      ),
    );
  }
}

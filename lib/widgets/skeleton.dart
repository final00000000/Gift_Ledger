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

/// 首页骨架屏 - 适配新的视觉革命布局
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
                const SkeletonContainer.square(width: 48, height: 48, borderRadius: 12),
                const SizedBox(width: 12),
                SkeletonContainer.square(width: 80, height: 24, borderRadius: 4),
                const Spacer(),
                const SkeletonContainer.circle(size: 40),
                const SizedBox(width: 8),
                const SkeletonContainer.circle(size: 40),
              ],
            ),
          ),

          // Hero Section 占位 - 全屏渐变英雄区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: SkeletonContainer.square(
              width: double.infinity,
              height: 220,
              borderRadius: 28,
            ),
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Quick Action Grid 占位 - 2x2 网格
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: List.generate(
                4,
                (index) => SkeletonContainer.square(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 20,
                ),
              ),
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

          // 时间轴列表项占位 (生成 4 个)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 4,
            itemBuilder: (context, index) => const _TimelineItemSkeleton(),
          ),
        ],
      ),
    );
  }
}

/// 时间轴列表项骨架
class _TimelineItemSkeleton extends StatelessWidget {
  const _TimelineItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间轴
          SizedBox(
            width: 60,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const SkeletonContainer.circle(size: 12),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
          // 右侧卡片
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(
                right: AppTheme.spacingM,
                bottom: AppTheme.spacingS,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  // 图标
                  SkeletonContainer.square(width: 44, height: 44, borderRadius: 12),
                  const SizedBox(width: 12),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SkeletonContainer.square(width: 60, height: 16, borderRadius: 4),
                            const SizedBox(width: 8),
                            SkeletonContainer.square(width: 40, height: 16, borderRadius: 6),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SkeletonContainer.square(width: 80, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  // 金额
                  SkeletonContainer.square(width: 70, height: 20, borderRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

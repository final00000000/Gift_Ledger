import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 空状态数据
class EmptyStateData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyStateData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });
}

/// 预定义的空状态
class EmptyStates {
  static EmptyStateData noRecords({VoidCallback? onAction}) => EmptyStateData(
    icon: Icons.card_giftcard_rounded,
    title: '暂无记录',
    subtitle: '点击下方按钮开始记录您的第一笔礼金',
    actionText: '记一笔',
    onAction: onAction,
  );

  static EmptyStateData noGuests({VoidCallback? onAction}) => EmptyStateData(
    icon: Icons.people_outline_rounded,
    title: '暂无联系人',
    subtitle: '添加礼金记录后，联系人将自动出现在这里',
    actionText: '添加记录',
    onAction: onAction,
  );

  static EmptyStateData noStatistics() => const EmptyStateData(
    icon: Icons.bar_chart_rounded,
    title: '暂无统计数据',
    subtitle: '开始记账后，这里将显示您的收支统计',
  );

  static EmptyStateData searchNoResult(String query) => EmptyStateData(
    icon: Icons.search_off_rounded,
    title: '未找到匹配结果',
    subtitle: '没有找到与"$query"相关的联系人',
  );
}

/// 空状态组件
class EmptyStateWidget extends StatelessWidget {
  final EmptyStateData data;
  final bool animate;

  const EmptyStateWidget({
    super.key,
    required this.data,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标容器
              TweenAnimationBuilder<double>(
                duration: animate 
                    ? const Duration(milliseconds: 600) 
                    : Duration.zero,
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.accentColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 装饰圈
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                      // 图标
                      Icon(
                        data.icon,
                        size: 56,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              // 标题
              TweenAnimationBuilder<double>(
                duration: animate 
                    ? const Duration(milliseconds: 400) 
                    : Duration.zero,
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              // 副标题
              TweenAnimationBuilder<double>(
                duration: animate 
                    ? const Duration(milliseconds: 400) 
                    : Duration.zero,
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  data.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    ),
                  textAlign: TextAlign.center,
                ),
              ),
              // 操作按钮
              if (data.actionText != null && data.onAction != null) ...[
                const SizedBox(height: AppTheme.spacingL),
                TweenAnimationBuilder<double>(
                  duration: animate 
                      ? const Duration(milliseconds: 500) 
                      : Duration.zero,
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: ElevatedButton.icon(
                    onPressed: data.onAction,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(data.actionText!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                        vertical: AppTheme.spacingM,
                      ),
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

/// 精致的旋转渐变圆环 Loading 动画
class LoadingWidget extends StatefulWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 旋转的渐变圆环
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _controller.value * 2 * 3.14159,
                  child: CustomPaint(
                    painter: _GradientRingPainter(
                      progress: _controller.value,
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: AppTheme.spacingL),
            // 脉搏式文字动画
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final opacity = 0.5 + 0.5 * ((1 + _controller.value) % 1);
                return Opacity(
                  opacity: opacity,
                  child: child,
                );
              },
              child: Text(
                widget.message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 渐变圆环绘制器
class _GradientRingPainter extends CustomPainter {
  final double progress;

  _GradientRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 绘制底层圆环（淡色）
    final bgPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.1)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 绘制渐变圆弧
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final gradient = SweepGradient(
      colors: const [
        AppTheme.primaryColor,
        AppTheme.accentColor,
        AppTheme.primaryColor,
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientRotation(progress * 6.28),
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 绘制 270 度的圆弧
    canvas.drawArc(
      rect,
      -1.57, // 从顶部开始（-90度）
      4.71,  // 绘制 270 度
      false,
      gradientPaint,
    );

    // 添加光晕效果
    final glowPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.3)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      rect,
      -1.57,
      4.71,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_GradientRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

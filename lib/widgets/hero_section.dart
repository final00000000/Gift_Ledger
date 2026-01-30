import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/security_service.dart';
import 'animated_counter.dart';

/// 简约风格英雄区组件
/// 柔和配色 + 简洁卡片 + 清晰层次
class HeroSection extends StatelessWidget {
  final double totalReceived;
  final double totalSent;
  final double? receivedTrend;
  final double? sentTrend;
  final List<double>? recentTrend;
  final VoidCallback? onReceivedTap;
  final VoidCallback? onSentTap;

  const HeroSection({
    super.key,
    required this.totalReceived,
    required this.totalSent,
    this.receivedTrend,
    this.sentTrend,
    this.recentTrend,
    this.onReceivedTap,
    this.onSentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          _buildTitleRow(),
          const SizedBox(height: 20),
          // 收支数据
          _buildStatsRow(),
          const SizedBox(height: 16),
          // 净收支
          _buildBalanceRow(),
        ],
      ),
    );
  }

  /// 标题行
  Widget _buildTitleRow() {
    return Row(
      children: [
        // 简洁标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppTheme.primaryColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '收支总览',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // 迷你趋势图
        if (recentTrend != null && recentTrend!.length >= 2)
          _buildMiniChart(),
      ],
    );
  }

  /// 收支数据行
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: '收礼总额',
            amount: totalReceived,
            trend: receivedTrend,
            icon: Icons.arrow_downward_rounded,
            onTap: onReceivedTap,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '送礼总额',
            amount: totalSent,
            trend: sentTrend,
            icon: Icons.arrow_upward_rounded,
            onTap: onSentTap,
            color: AppTheme.accentColor,
          ),
        ),
      ],
    );
  }

  /// 统计卡片
  Widget _buildStatCard({
    required String title,
    required double amount,
    double? trend,
    required IconData icon,
    VoidCallback? onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: color.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                    size: 16,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: SecurityService().isUnlocked,
              builder: (context, isUnlocked, child) {
                return PrivacyAwareAnimatedCounter(
                  value: amount,
                  isUnlocked: isUnlocked,
                  prefix: '¥',
                  formatter: AnimatedCounter.formatAmount,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  mask: '¥****',
                );
              },
            ),
            if (trend != null) ...[
              const SizedBox(height: 8),
              _buildTrendBadge(trend, color),
            ],
          ],
        ),
      ),
    );
  }

  /// 趋势徽章
  Widget _buildTrendBadge(double trend, Color color) {
    final isPositive = trend >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color.withOpacity(0.8),
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 迷你趋势图
  Widget _buildMiniChart() {
    if (recentTrend == null || recentTrend!.length < 2) {
      return const SizedBox.shrink();
    }

    final maxValue = recentTrend!.reduce((a, b) => a > b ? a : b);
    final minValue = recentTrend!.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    if (range == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 60,
      height: 30,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _MiniChartPainter(
          data: recentTrend!,
          minValue: minValue,
          range: range,
          lineColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  /// 净收支行
  Widget _buildBalanceRow() {
    final balance = totalReceived - totalSent;
    final isPositive = balance >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '净收支',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: SecurityService().isUnlocked,
            builder: (context, isUnlocked, child) {
              if (!isUnlocked) {
                return Text(
                  '****',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }
              return Row(
                children: [
                  Icon(
                    isPositive ? Icons.add_rounded : Icons.remove_rounded,
                    color: isPositive ? AppTheme.primaryColor : AppTheme.accentColor,
                    size: 18,
                  ),
                  AnimatedCounter(
                    value: balance.abs(),
                    prefix: '¥',
                    formatter: AnimatedCounter.formatAmount,
                    style: TextStyle(
                      color: isPositive ? AppTheme.primaryColor : AppTheme.accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 迷你趋势图绘制器
class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final double minValue;
  final double range;
  final Color lineColor;

  _MiniChartPainter({
    required this.data,
    required this.minValue,
    required this.range,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (data[i] - minValue) / range;
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 绘制最后一个点
    final lastX = (data.length - 1) * stepX;
    final lastNormalizedY = (data.last - minValue) / range;
    final lastY = size.height - (lastNormalizedY * size.height);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.lineColor != lineColor;
  }
}

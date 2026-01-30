import 'package:flutter/material.dart';

/// 数字滚动动画组件
/// 金额数字从 0 滚动到实际值，带有弹性效果
class AnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;
  final int decimalPlaces;
  final String Function(double)? formatter;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.elasticOut,
    this.decimalPlaces = 0,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        String displayText;
        if (formatter != null) {
          displayText = formatter!(animatedValue);
        } else {
          displayText = animatedValue.toStringAsFixed(decimalPlaces);
        }
        return Text(
          '$prefix$displayText$suffix',
          style: style,
        );
      },
    );
  }

  /// 格式化金额显示
  /// 超过 10000 显示为 x.xxw
  /// 超过 1000000 显示为 x.xw
  static String formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 10000).toStringAsFixed(1)}w';
    }
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(2)}w';
    }
    return amount.toStringAsFixed(0);
  }
}

/// 带隐私保护的数字滚动动画组件
class PrivacyAwareAnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;
  final String Function(double)? formatter;
  final bool isUnlocked;
  final String mask;

  const PrivacyAwareAnimatedCounter({
    super.key,
    required this.value,
    required this.isUnlocked,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.elasticOut,
    this.formatter,
    this.mask = '****',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: Text(
        mask,
        style: style,
      ),
      secondChild: AnimatedCounter(
        value: value,
        style: style,
        prefix: prefix,
        suffix: suffix,
        duration: duration,
        curve: curve,
        formatter: formatter,
      ),
      crossFadeState: isUnlocked
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
    );
  }
}

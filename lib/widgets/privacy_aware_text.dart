import 'package:flutter/material.dart';
import '../services/security_service.dart';

class PrivacyAwareText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String mask;

  const PrivacyAwareText(
    this.text, {
    super.key,
    this.style,
    this.mask = '****',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SecurityService().isUnlocked,
      builder: (context, isUnlocked, child) {
        return AnimatedCrossFade(
          firstChild: Text(
            mask,
            style: style,
          ),
          secondChild: Text(
            text,
            style: style,
          ),
          crossFadeState: isUnlocked 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        );
      },
    );
  }
}

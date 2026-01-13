import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool withBackground;

  const AppLogo({
    super.key,
    this.size = 48,
    this.withBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: withBackground
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.22), // Matching typical icon roundness
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.05),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/icon/app_icon.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

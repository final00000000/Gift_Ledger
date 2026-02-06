import 'package:flutter/material.dart';
import 'dart:ui';

class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // 新中式奢华配色 (Chinese Luxury Palette)
  // ═══════════════════════════════════════════════════════════════════════════

  // 主色调 - 中国红与奢华金
  static const Color primaryColor = Color(0xFFC62828);      // Logo Red (Deep Red 800)
  static const Color accentColor = Color(0xFFD4AF37);       // 奢华金 Luxury Gold
  static const Color chineseRed = Color(0xFFBF1E2E);        // 中国红
  static const Color vermilion = Color(0xFFE63946);         // 朱红
  static const Color luxuryGold = Color(0xFFD4AF37);        // 奢华金
  static const Color champagneGold = Color(0xFFC49A48);     // 香槟金
  static const Color roseGold = Color(0xFFB76E79);          // 玫瑰金

  // 中性色 - 水墨风格
  static const Color inkBlack = Color(0xFF1A1A1A);          // 墨黑
  static const Color charcoal = Color(0xFF2D2D2D);          // 炭灰
  static const Color cloudGray = Color(0xFFE8E8E8);         // 云灰
  static const Color riceWhite = Color(0xFFFAF8F5);         // 米白（温暖的白）
  static const Color parchment = Color(0xFFF5F0E8);         // 羊皮纸色

  // 背景色 - 温暖的米白色调
  static const Color backgroundColor = Color(0xFFFAF8F5);   // 温暖米白背景
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF6B6B6B);

  // Functional Colors
  static const Color successColor = Color(0xFF43A047);      // Green 600
  static const Color warningColor = Color(0xFFFFA000);      // Amber 700
  static const Color errorColor = Color(0xFFD32F2F);        // Red 700

  // ═══════════════════════════════════════════════════════════════════════════
  // Hero Section 渐变色 - 红金渐变
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color heroGradientStart = Color(0xFFE63946); // 朱红
  static const Color heroGradientMiddle = Color(0xFFC62828); // 深红
  static const Color heroGradientEnd = Color(0xFF8B1538);   // 酒红

  // ═══════════════════════════════════════════════════════════════════════════
  // 玻璃态效果 (Glassmorphism)
  // ═══════════════════════════════════════════════════════════════════════════
  static Color get glassBackground => Colors.white.withValues(alpha: 0.85);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.3);
  static Color get glassBackgroundDark => Colors.black.withValues(alpha: 0.1);
  static Color get goldGlassBorder => luxuryGold.withValues(alpha: 0.3);
  static const double glassBlur = 20.0;
  static const double glassBlurLight = 10.0;

  // Quick Action Colors - 更和谐的配色
  static const Color eventBookColor = Color(0xFF8B5CF6);    // 紫色 - 活动簿
  static const Color pendingColor = Color(0xFFF97316);      // 橙色 - 待处理
  static const Color statisticsColor = Color(0xFF0EA5E9);   // 蓝色 - 统计
  static const Color settingsColor = Color(0xFF10B981);     // 绿色 - 设置

  // ═══════════════════════════════════════════════════════════════════════════
  // 圆角系统 (Border Radius System)
  // ═══════════════════════════════════════════════════════════════════════════
  static const double radiusXS = 6.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 28.0;
  static const double radiusHero = 32.0;    // 英雄区特大圆角

  // ═══════════════════════════════════════════════════════════════════════════
  // 间距系统 (Spacing System)
  // ═══════════════════════════════════════════════════════════════════════════
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  static const double spacingCard = 20.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // 动画系统 (Animation System) - 弹性动画
  // ═══════════════════════════════════════════════════════════════════════════
  static const Duration entryDuration = Duration(milliseconds: 800);
  static const Duration counterDuration = Duration(milliseconds: 1200);
  static const Duration staggerDelay = Duration(milliseconds: 100);
  static const Duration bounceDuration = Duration(milliseconds: 600);
  static const Duration microDuration = Duration(milliseconds: 200);

  // 动画曲线 - 弹性效果
  static const Curve entryCurve = Curves.easeOutCubic;
  static const Curve counterCurve = Curves.elasticOut;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;

  // ═══════════════════════════════════════════════════════════════════════════
  // 渐变系统 (Gradient System)
  // ═══════════════════════════════════════════════════════════════════════════

  // 英雄区渐变 - 红金渐变
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroGradientStart, heroGradientMiddle, heroGradientEnd],
    stops: [0.0, 0.5, 1.0],
  );

  // 金色渐变 - 用于装饰
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD4AF37),  // 奢华金
      Color(0xFFC49A48),  // 香槟金
      Color(0xFFD4AF37),  // 奢华金
    ],
  );

  // 玻璃态渐变背景
  static LinearGradient get glassGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.9),
      Colors.white.withValues(alpha: 0.7),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 装饰系统 (Decoration System)
  // ═══════════════════════════════════════════════════════════════════════════

  // 玻璃态装饰 - 基础版
  static BoxDecoration glassDecoration({
    double borderRadius = radiusLarge,
    Color? color,
    bool withGoldBorder = false,
  }) {
    return BoxDecoration(
      color: color ?? glassBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: withGoldBorder ? goldGlassBorder : glassBorder,
        width: withGoldBorder ? 1.5 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // 玻璃态装饰 - 带金色光晕
  static BoxDecoration glassDecorationLuxury({
    double borderRadius = radiusLarge,
  }) {
    return BoxDecoration(
      color: glassBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: goldGlassBorder, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: luxuryGold.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // 卡片阴影 - 柔和版
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // 卡片阴影 - 金色光晕
  static List<BoxShadow> get goldGlowShadow => [
    BoxShadow(
      color: luxuryGold.withValues(alpha: 0.2),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
        surface: backgroundColor,
        brightness: Brightness.light,
        outline: Colors.transparent,
        outlineVariant: Colors.transparent,
      ),
      dividerColor: Colors.transparent,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      iconTheme: const IconThemeData(color: primaryColor),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.withValues(alpha: 0.1),
        selectedColor: primaryColor.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        side: BorderSide.none,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
    );
  }
}

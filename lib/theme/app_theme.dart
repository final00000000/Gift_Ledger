import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors (From Logo)
  static const Color primaryColor = Color(0xFFC62828);      // Logo Red (Deep Red 800)
  static const Color accentColor = Color(0xFFC49A48);       // Champagne Gold for Sent/Expense
  
  // Neutral Colors (Light)
  static const Color backgroundColor = Color(0xFFF2F3F5);   // Slightly darker for better card contrast
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF6B6B6B);

  // Functional Colors
  static const Color successColor = Color(0xFF43A047);      // Green 600
  static const Color warningColor = Color(0xFFFFA000);      // Amber 700
  static const Color errorColor = Color(0xFFD32F2F);        // Red 700

  // Radii
  static const double radiusLarge = 16.0;
  static const double radiusMedium = 12.0;
  static const double radiusSmall = 8.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
        surface: backgroundColor,
        background: backgroundColor,
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
        shadowColor: Colors.black.withOpacity(0.1),
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
        backgroundColor: Colors.grey.withOpacity(0.1),
        selectedColor: primaryColor.withOpacity(0.1),
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

import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primary = Color(0xFF2C3E50); // Dark blue used in text
  static const Color secondary =
      Color(0xFF212529); // Dark color used in header/footer
  static const Color accent = Colors.blue; // Used in keyword tags

  // Background colors
  static const Color scaffoldBackground = Color(0xFFF5F6FA);
  static const Color cardBackground = Colors.white;

  // Text colors
  static const Color textPrimary = primary;
  static const Color textSecondary = Colors.grey;
  static const Color textLight = Colors.white;

  // Utility colors
  static const Color highlightYellow = Color.fromRGBO(255, 255, 0, 0.3);
  static const Color dividerColor =
      Color.fromRGBO(44, 62, 80, 0.1); // For borders etc.
  static const Color shadowColor = Color.fromRGBO(0, 0, 0, 0.05);

  static ThemeData get theme => ThemeData(
        primaryColor: primary,
        scaffoldBackgroundColor: scaffoldBackground,
        cardTheme: const CardTheme(
          color: cardBackground,
          elevation: 2,
        ),
      );
}

// Extension method for easy color opacity
extension ColorExtension on Color {
  Color withCustomOpacity(double opacity) => withValues(alpha: opacity);
}

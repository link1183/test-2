import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primary = Color(0xFF2C3E50); // Dark blue used in text
  static const Color secondary =
      Color(0xFF212529); // Dark color used in header/footer
  static const Color accent = Color(0xFF3498DB); // Used in keyword tags

  // Background colors
  static const Color scaffoldBackground = Color(0xfff8f9fa);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static const Color searchFieldBackground = Color(0xFFFFFFFF);

  static const Color categoryHeader = Color(0xffe9ecef);

  // Text colors
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textLight = Colors.white;

  // Utility colors
  static const Color highlightYellow = Color.fromRGBO(255, 255, 0, 0.3);
  static const Color dividerColor = Color(0xFFDEE2E6);
  static const Color shadowColor = Color.fromRGBO(0, 0, 0, 1.0);

  static const Color tagBackground = Color(0xFFE9F7FE);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        primaryColor: primary,
        scaffoldBackgroundColor: scaffoldBackground,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.15,
            height: 1.5,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
            height: 1.4,
            color: textPrimary,
          ),
        ).apply(
          bodyColor: textPrimary,
          displayColor: textPrimary,
        ),
        cardTheme: CardTheme(
          color: cardBackground,
          elevation: 0,
          margin: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 16,
          ),
          shadowColor: shadowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: dividerColor,
          thickness: 1,
          space: 16,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: tagBackground,
          labelStyle: TextStyle(color: accent),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      );
}

extension ColorExtension on Color {
  Color withCustomOpacity(double opacity) => withValues(alpha: opacity);
}

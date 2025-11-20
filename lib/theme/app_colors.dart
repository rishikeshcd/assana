import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary color
  static const Color primary = Color(0xFFEB5466);

  // Card background color
  static const Color cardBackground = Color(
    0x0DEF3F3F,
  ); // #EF3F3F0D (ARGB format)

  // Text colors
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFF999999);

  // Background colors
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F5F5);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE91E63);
  static const Color warning = Color(0xFFFF9800);

  // Light pink variations for cards
  static const Color lightPink = Color(0xFFFFE5EC);
  static const Color lightPinkContainer = Color(0xFFFFE5EC);
}

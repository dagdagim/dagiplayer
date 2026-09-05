import 'package:flutter/material.dart';

/// App typography definitions ensuring crisp hierarchy, readability,
/// and an editorial aesthetic. Local-first design with system font fallbacks.
class AppTypography {
  AppTypography._();

  static const List<String> _fontFallbacks = [
    'Inter',
    'Roboto',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static TextStyle get displayLarge => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.2,
      );

  static TextStyle get displayMedium => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
      );

  static TextStyle get displaySmall => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
      );

  static TextStyle get headlineLarge => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.35,
      );

  static TextStyle get titleMedium => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.35,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.4,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.35,
      );

  static TextStyle get labelLarge => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  static TextStyle get labelMedium => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      );

  static TextStyle get labelSmall => const TextStyle(
        fontFamilyFallback: _fontFallbacks,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      );
}

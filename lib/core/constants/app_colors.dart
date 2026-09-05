import 'package:flutter/material.dart';

/// App color palette adhering to the editorial media-app aesthetic.
/// Primary accent is warm burnt orange (#F26A21), with neutral backdrops.
/// Strictly NO purple, NO neon, NO excessive gradients.
class AppColors {
  AppColors._();

  // Primary Brand Accents
  static const Color primary = Color(0xFFF26A21);
  static const Color primaryDeep = Color(0xFFD95716);
  static const Color primaryLight = Color(0xFFFFF0E8);
  static const Color primaryDark = Color(0xFFB5420A);
  static const Color primaryGlow = Color(0x33F26A21);

  // Light Theme
  static const Color lightBackground = Color(0xFFF7F6F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFEFECE6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4E1DC);
  static const Color lightDivider = Color(0xFFE8E5DF);
  static const Color lightTextPrimary = Color(0xFF111111);
  static const Color lightTextSecondary = Color(0xFF777777);
  static const Color lightTextTertiary = Color(0xFF999999);

  // Dark Theme
  static const Color darkBackground = Color(0xFF101010);
  static const Color darkSurface = Color(0xFF191919);
  static const Color darkSurfaceSecondary = Color(0xFF232323);
  static const Color darkCard = Color(0xFF1C1C1C);
  static const Color darkBorder = Color(0xFF282828);
  static const Color darkDivider = Color(0xFF222222);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFF8E8E8E);
  static const Color darkTextTertiary = Color(0xFF5A5A5A);

  // AMOLED Theme (True Black)
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0C0C0C);
  static const Color amoledSurfaceSecondary = Color(0xFF161616);
  static const Color amoledCard = Color(0xFF0E0E0E);
  static const Color amoledBorder = Color(0xFF1E1E1E);
  static const Color amoledDivider = Color(0xFF1A1A1A);
  static const Color amoledTextPrimary = Color(0xFFFFFFFF);
  static const Color amoledTextSecondary = Color(0xFF888888);
  static const Color amoledTextTertiary = Color(0xFF555555);

  // Status & Utility Colors
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color info = Color(0xFF0288D1);

  // Overlay / Backdrop
  static const Color modalBackdrop = Color(0xCC080808);
  static const Color videoScrim = Color(0x80000000);
  static const Color miniPlayerDark = Color(0xFF1A1A1A);
  static const Color miniPlayerLight = Color(0xFFFFFFFF);
}

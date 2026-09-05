import 'package:flutter/material.dart';

/// Centralized dimensions and spacing conforming to 8-16px restrained radii
/// and consistent spacing tokens.
class AppDimensions {
  AppDimensions._();

  // Spacing Tokens
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double screenPadding = 16.0;

  // Corner Radii (Restrained, 8-16px)
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 999.0;

  // Border Radii
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(radiusLg));

  // Artwork & Thumbnail Sizes
  static const double songArtworkSize = 48.0;
  static const double songArtworkSizeLarge = 56.0;
  static const double albumTileSize = 140.0;
  static const double playlistTileSize = 140.0;
  static const double artistAvatarSize = 72.0;
  static const double videoCardWidth = 220.0;
  static const double videoCardHeight = 124.0;

  // Component Heights
  static const double miniPlayerHeight = 64.0;
  static const double bottomNavHeight = 64.0;
  static const double headerHeight = 56.0;
  static const double searchBarHeight = 44.0;
  static const double songTileHeight = 64.0;
  static const double buttonHeight = 44.0;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeMedium = 22.0;
  static const double iconSizeLarge = 28.0;
  static const double iconSizeXLarge = 36.0;
}

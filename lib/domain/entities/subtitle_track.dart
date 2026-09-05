import 'package:flutter/material.dart';

class SubtitleItem {
  final int index;
  final Duration startTime;
  final Duration endTime;
  final String text;

  const SubtitleItem({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}

class SubtitleTrack {
  final String id;
  final String label; // "English", "Amharic", "Arabic", "French", "Spanish", "Off"
  final String languageCode; // "en", "am", "ar", "fr", "es"
  final String? uri; // local file path or asset URI
  final List<SubtitleItem> items;

  const SubtitleTrack({
    required this.id,
    required this.label,
    required this.languageCode,
    this.uri,
    this.items = const [],
  });
}

class SubtitleStyleSettings {
  final double fontSize;
  final Color textColor;
  final Color backgroundColor;
  final double backgroundOpacity;
  final Duration delay; // offset in milliseconds
  final Alignment position;

  const SubtitleStyleSettings({
    this.fontSize = 16.0,
    this.textColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.backgroundOpacity = 0.65,
    this.delay = Duration.zero,
    this.position = Alignment.bottomCenter,
  });

  SubtitleStyleSettings copyWith({
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    double? backgroundOpacity,
    Duration? delay,
    Alignment? position,
  }) {
    return SubtitleStyleSettings(
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      delay: delay ?? this.delay,
      position: position ?? this.position,
    );
  }
}

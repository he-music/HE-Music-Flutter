import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AppPlayerColorMood { soft, vivid, dark }

/// Null colors follow the artwork; each override can be restored independently.
@immutable
class AppPlayerAppearance {
  const AppPlayerAppearance({
    this.mood = AppPlayerColorMood.vivid,
    this.backgroundColor,
    this.accentColor,
    this.animateCover = true,
  });

  final AppPlayerColorMood mood;
  final int? backgroundColor;
  final int? accentColor;
  final bool animateCover;

  AppPlayerAppearance copyWith({
    AppPlayerColorMood? mood,
    int? backgroundColor,
    int? accentColor,
    bool autoBackground = false,
    bool autoAccent = false,
    bool? animateCover,
  }) => AppPlayerAppearance(
    mood: mood ?? this.mood,
    backgroundColor: autoBackground
        ? null
        : backgroundColor ?? this.backgroundColor,
    accentColor: autoAccent ? null : accentColor ?? this.accentColor,
    animateCover: animateCover ?? this.animateCover,
  );

  String encode() => jsonEncode({
    'mood': mood.name,
    'background': backgroundColor,
    'accent': accentColor,
    'animateCover': animateCover,
  });

  static AppPlayerAppearance decode(String? raw) {
    try {
      final data = jsonDecode(raw ?? '{}');
      if (data is! Map<String, dynamic>) return const AppPlayerAppearance();
      int? color(Object? value) =>
          value is int && value >= 0 && value <= 0xffffffff
          ? 0xff000000 | (value & 0xffffff)
          : null;
      return AppPlayerAppearance(
        mood:
            AppPlayerColorMood.values
                .where((m) => m.name == data['mood'])
                .firstOrNull ??
            AppPlayerColorMood.vivid,
        backgroundColor: color(data['background']),
        accentColor: color(data['accent']),
        animateCover: data['animateCover'] is bool
            ? data['animateCover'] as bool
            : true,
      );
    } on FormatException {
      return const AppPlayerAppearance();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppPlayerAppearance &&
      mood == other.mood &&
      backgroundColor == other.backgroundColor &&
      accentColor == other.accentColor &&
      animateCover == other.animateCover;

  @override
  int get hashCode =>
      Object.hash(mood, backgroundColor, accentColor, animateCover);
}

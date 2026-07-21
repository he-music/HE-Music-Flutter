import 'package:flutter/material.dart';

enum AppLyricHighlightColor {
  sky('sky', Color(0xFF38BDF8)),
  emerald('emerald', Color(0xFF34D399)),
  amber('amber', Color(0xFFFBBF24)),
  coral('coral', Color(0xFFFB7185)),
  violet('violet', Color(0xFFA78BFA));

  const AppLyricHighlightColor(this.value, this.color);

  final String value;
  final Color color;

  static AppLyricHighlightColor fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppLyricHighlightColor.sky;
  }
}

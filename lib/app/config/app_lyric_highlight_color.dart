import 'package:flutter/material.dart';

enum AppLyricHighlightColor {
  sky('sky', '天蓝', Color(0xFF38BDF8)),
  emerald('emerald', '翠绿', Color(0xFF34D399)),
  amber('amber', '琥珀', Color(0xFFFBBF24)),
  coral('coral', '珊瑚', Color(0xFFFB7185)),
  violet('violet', '靛紫', Color(0xFFA78BFA));

  const AppLyricHighlightColor(this.value, this.label, this.color);

  final String value;
  final String label;
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

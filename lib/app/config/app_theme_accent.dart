import 'package:flutter/material.dart';

enum AppThemeAccent {
  forest('forest', Color(0xFF166534), Color(0xFF34D399)),
  ocean('ocean', Color(0xFF0F766E), Color(0xFF2DD4BF)),
  cobalt('cobalt', Color(0xFF1D4ED8), Color(0xFF60A5FA)),
  sunset('sunset', Color(0xFFEA580C), Color(0xFFFB923C)),
  rose('rose', Color(0xFFE11D48), Color(0xFFFB7185)),
  violet('violet', Color(0xFF7C3AED), Color(0xFFA78BFA)),
  amber('amber', Color(0xFFD97706), Color(0xFFFBBF24)),
  midnight('midnight', Color(0xFF334155), Color(0xFF94A3B8)),
  mint('mint', Color(0xFF059669), Color(0xFF6EE7B7)),
  cherry('cherry', Color(0xFFBE123C), Color(0xFFFF6B81)),
  graphite('graphite', Color(0xFF3F3F46), Color(0xFFA1A1AA));

  const AppThemeAccent(this.value, this.lightSeed, this.darkSeed);

  final String value;
  final Color lightSeed;
  final Color darkSeed;

  static AppThemeAccent fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppThemeAccent.forest;
  }
}

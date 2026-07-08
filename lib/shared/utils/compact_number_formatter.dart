import 'dart:ui';

String formatCompactPlayCount(String raw, Locale locale) {
  final value = int.tryParse(raw);
  if (value == null) {
    return raw;
  }
  final languageCode = locale.languageCode.toLowerCase();
  if (languageCode.startsWith('zh')) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return '$value';
  }
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}

String formatDurationSecondsLabel(String raw) {
  final totalSeconds = int.tryParse(raw);
  if (totalSeconds == null || totalSeconds < 0) {
    return raw;
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  return '$minuteText:$secondText';
}

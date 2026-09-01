String formatPublishDateOrEmpty(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final timestamp = int.tryParse(normalized);
  DateTime? date;
  if (timestamp != null) {
    if (timestamp <= 0) {
      return '';
    }
    final milliseconds = timestamp > 100000000000
        ? timestamp
        : timestamp * 1000;
    date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  } else {
    date = DateTime.tryParse(normalized);
  }
  if (date == null) {
    return normalized;
  }
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

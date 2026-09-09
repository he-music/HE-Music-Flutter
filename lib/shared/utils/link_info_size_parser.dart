const int _maxLinkInfoSizeBytes = 0x7FFFFFFFFFFFFFFF;

/// Parses a LinkInfo size as positive bytes or a binary KB/MB/GB value.
int? parseLinkInfoSizeBytes(String rawSize) {
  final match = RegExp(
    r'^(\d+)\s*(KB|MB|GB)?$',
    caseSensitive: false,
  ).firstMatch(rawSize.trim());
  if (match == null) {
    return null;
  }
  final value = int.tryParse(match.group(1)!);
  if (value == null || value <= 0) {
    return null;
  }
  final multiplier = switch (match.group(2)?.toUpperCase()) {
    'KB' => 1024,
    'MB' => 1024 * 1024,
    'GB' => 1024 * 1024 * 1024,
    _ => 1,
  };
  if (value > _maxLinkInfoSizeBytes ~/ multiplier) {
    return null;
  }
  return value * multiplier;
}

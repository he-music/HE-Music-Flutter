class PlayerQualityOption {
  const PlayerQualityOption({
    required this.name,
    required this.quality,
    required this.format,
    required this.url,
    this.description,
    this.sizeBytes,
  });

  final String name;
  final int quality;
  final String format;
  final String url;
  final String? description;
  final int? sizeBytes;

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) {
      return '';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final fixed = value >= 100 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fixed)} ${units[unitIndex]}';
  }
}

class RawLyricBundle {
  const RawLyricBundle({
    required this.lyric,
    this.translation = '',
    this.romanization = '',
  });

  final String lyric;
  final String translation;
  final String romanization;
}

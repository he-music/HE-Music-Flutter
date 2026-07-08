class LyricToken {
  const LyricToken({
    required this.text,
    required this.startOffset,
    required this.duration,
  });

  final String text;
  final Duration startOffset;
  final Duration duration;

  Duration get endOffset => startOffset + duration;
}

class LyricLine {
  const LyricLine({
    required this.start,
    required this.text,
    this.end,
    this.tokens = const <LyricToken>[],
    this.translation = '',
    this.romanization = '',
  });

  final Duration start;
  final String text;
  final Duration? end;
  final List<LyricToken> tokens;
  final String translation;
  final String romanization;

  bool get hasWordTiming => tokens.isNotEmpty;
}

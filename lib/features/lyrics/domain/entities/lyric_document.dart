import 'lyric_line.dart';

enum LyricSource { online, cache, manual, local }

class LyricDocument {
  const LyricDocument({required this.lines, this.offset = 0, this.source});

  const LyricDocument.empty()
    : lines = const <LyricLine>[],
      offset = 0,
      source = null;

  final LyricSource? source;

  LyricDocument withSource(LyricSource source) =>
      LyricDocument(lines: lines, offset: offset, source: source);

  final List<LyricLine> lines;
  final int offset;

  bool get isEmpty => lines.isEmpty;

  bool get hasWordTiming => lines.any((line) => line.hasWordTiming);
}

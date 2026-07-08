import 'lyric_line.dart';

class LyricDocument {
  const LyricDocument({required this.lines, this.offset = 0});

  const LyricDocument.empty() : lines = const <LyricLine>[], offset = 0;

  final List<LyricLine> lines;
  final int offset;

  bool get isEmpty => lines.isEmpty;

  bool get hasWordTiming => lines.any((line) => line.hasWordTiming);
}

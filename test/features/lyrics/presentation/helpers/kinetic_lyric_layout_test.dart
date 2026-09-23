import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/kinetic_lyric_layout.dart';

void main() {
  test(
    'subdivision preserves graphemes, absolute start and final token end',
    () {
      final glyphs = buildKineticGlyphs(
        const LyricLine(
          start: Duration(seconds: 3),
          end: Duration(seconds: 5),
          text: '你👨‍👩‍👧‍👦好',
          tokens: [
            LyricToken(
              text: '你👨‍👩‍👧‍👦好',
              startOffset: Duration(milliseconds: 200),
              duration: Duration(milliseconds: 1000),
            ),
          ],
        ),
      );
      expect(glyphs.map((g) => g.text), ['你', '👨‍👩‍👧‍👦', '好']);
      expect(glyphs.first.start, const Duration(milliseconds: 3200));
      expect(glyphs.last.end, const Duration(milliseconds: 4200));
      expect(glyphs[0].end, glyphs[1].start);
    },
  );

  test('plain and invalid timings keep text without invented onsets', () {
    for (final tokens in <List<LyricToken>>[
      [],
      [
        const LyricToken(
          text: 'wrong',
          startOffset: Duration.zero,
          duration: Duration(seconds: 1),
        ),
      ],
      [
        const LyricToken(
          text: 'hello',
          startOffset: Duration(milliseconds: -1),
          duration: Duration(seconds: 1),
        ),
      ],
    ]) {
      final glyphs = buildKineticGlyphs(
        LyricLine(
          start: Duration.zero,
          end: const Duration(seconds: 2),
          text: 'hello',
          tokens: tokens,
        ),
      );
      expect(glyphs.map((g) => g.text).join(), 'hello');
      expect(glyphs.every((g) => g.start == null), isTrue);
    }
  });

  test('arc reaches both onsets and bounds a long cross-line jump', () {
    const from = Offset(500, 0);
    const to = Offset(30, 400);
    expect(kineticArc(from, to, 0, 60), from);
    expect(kineticArc(from, to, 1, 60), to);
    expect(kineticArc(from, to, .5, 60), const Offset(265, 140));
  });
}

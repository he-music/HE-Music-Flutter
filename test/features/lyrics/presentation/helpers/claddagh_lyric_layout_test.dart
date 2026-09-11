import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/claddagh_lyric_layout.dart';

// Orbit fitting, readable tangents and grapheme timing remain independent of frames.
void main() {
  test(
    'tilted ellipse stays inside portrait and landscape with readable tangents',
    () {
      for (final size in [const Size(320, 500), const Size(700, 230)]) {
        final orbit = CladdaghOrbitGeometry(size);
        for (var i = -200; i <= 200; i++) {
          final angle = i * math.pi / 50;
          expect((Offset.zero & size).contains(orbit.point(angle)), isTrue);
          expect(orbit.tangent(angle).abs(), lessThanOrEqualTo(math.pi / 2));
        }
        expect(orbit.point(math.pi / 2).dx, greaterThan(orbit.center.dx));
        expect(orbit.point(math.pi / 2).dy, lessThan(orbit.center.dy));
      }
    },
  );
  test(
    'word boundaries split into graphemes without splitting emoji or CJK',
    () {
      const line = LyricLine(
        start: Duration(seconds: 2),
        end: Duration(seconds: 6),
        text: '你👨‍👩‍👧好',
        tokens: [
          LyricToken(
            text: '你👨‍👩‍👧',
            startOffset: Duration.zero,
            duration: Duration(seconds: 2),
          ),
          LyricToken(
            text: '好',
            startOffset: Duration(seconds: 2),
            duration: Duration(seconds: 2),
          ),
        ],
      );
      final glyphs = buildCladdaghGlyphs(line);
      expect(glyphs.map((g) => g.text), ['你', '👨‍👩‍👧', '好']);
      expect(glyphs.map((g) => g.start), [
        const Duration(seconds: 2),
        const Duration(seconds: 3),
        const Duration(seconds: 4),
      ]);
      expect(glyphs.last.end, const Duration(seconds: 6));
      expect(glyphs.last.endOffset, line.text.length);
    },
  );
  test(
    'invalid provider timing preserves text without inventing word timestamps',
    () {
      const line = LyricLine(
        start: Duration.zero,
        end: Duration(seconds: 1),
        text: 'abc',
        tokens: [
          LyricToken(
            text: 'wrong',
            startOffset: Duration.zero,
            duration: Duration(seconds: 1),
          ),
        ],
      );
      final glyphs = buildCladdaghGlyphs(line);
      expect(glyphs.map((g) => g.text).join(), 'abc');
      expect(glyphs.every((g) => !g.hasTiming), isTrue);
    },
  );
  test('half turn spring has exact endpoints and limited overshoot', () {
    expect(claddaghTransition(0), 0);
    expect(claddaghTransition(1), 1);
    for (var i = 0; i <= 100; i++) {
      expect(claddaghTransition(i / 100), inInclusiveRange(0, 1.1));
    }
  });
}

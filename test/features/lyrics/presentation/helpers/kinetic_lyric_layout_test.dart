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

  test('words span provider tokens and retain their full timing', () {
    final glyphs = buildKineticGlyphs(
      const LyricLine(
        start: Duration(seconds: 3),
        end: Duration(seconds: 5),
        text: 'Hello world',
        tokens: [
          LyricToken(
            text: 'Hel',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 300),
          ),
          LyricToken(
            text: 'lo',
            startOffset: Duration(milliseconds: 300),
            duration: Duration(milliseconds: 200),
          ),
          LyricToken(
            text: ' ',
            startOffset: Duration(milliseconds: 500),
            duration: Duration.zero,
          ),
          LyricToken(
            text: 'world',
            startOffset: Duration(milliseconds: 700),
            duration: Duration(milliseconds: 800),
          ),
        ],
      ),
    );
    expect(glyphs.map((g) => g.text), ['Hello', ' ', 'world']);
    expect(glyphs.first.start, const Duration(seconds: 3));
    expect(glyphs.first.end, const Duration(milliseconds: 3500));
    expect(glyphs[1].start, isNull);
    expect(glyphs.last.start, const Duration(milliseconds: 3700));
    expect(glyphs.last.end, const Duration(milliseconds: 4500));
  });

  test('mixed scripts preserve words, contractions and grapheme boundaries', () {
    const text =
        "你好don't stop café e\u0301té rock’n’roll 世界Привет Ελληνικά 👨‍👩‍👧‍👦";
    final glyphs = buildKineticGlyphs(
      const LyricLine(start: Duration.zero, text: text),
    );
    expect(glyphs.map((g) => g.text), [
      '你',
      '好',
      "don't",
      ' ',
      'stop',
      ' ',
      'café',
      ' ',
      'e\u0301té',
      ' ',
      'rock’n’roll',
      ' ',
      '世',
      '界',
      'Привет',
      ' ',
      'Ελληνικά',
      ' ',
      '👨‍👩‍👧‍👦',
    ]);
    expect(glyphs.map((g) => g.text).join(), text);
    expect(glyphs.every((g) => g.start == null && g.end == null), isTrue);
  });

  test('a phrase token yields word onsets without changing its time span', () {
    final glyphs = buildKineticGlyphs(
      const LyricLine(
        start: Duration.zero,
        end: Duration(seconds: 2),
        text: 'hello world',
        tokens: [
          LyricToken(
            text: 'hello world',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 1100),
          ),
        ],
      ),
    );
    expect(glyphs.map((g) => g.text), ['hello', ' ', 'world']);
    expect(glyphs.first.end, const Duration(milliseconds: 500));
    expect(glyphs.last.start, const Duration(milliseconds: 600));
    expect(glyphs.last.end, const Duration(milliseconds: 1100));
  });

  test(
    'punctuation and whitespace delimit words without splitting CJK graphemes',
    () {
      const text = "'hello',world!\n你好かな한글𠀀 👩🏽‍🎤 well-being dogs’";
      final glyphs = buildKineticGlyphs(
        const LyricLine(start: Duration.zero, text: text),
      );
      expect(glyphs.map((g) => g.text), [
        "'",
        'hello',
        "'",
        ',',
        'world',
        '!',
        '\n',
        '你',
        '好',
        'か',
        'な',
        '한',
        '글',
        '𠀀',
        ' ',
        '👩🏽‍🎤',
        ' ',
        'well',
        '-',
        'being',
        ' ',
        'dogs',
        '’',
      ]);
      expect(glyphs.map((g) => g.text).join(), text);
    },
  );

  test('a contraction spans untimed provider tokens without losing timing', () {
    final glyphs = buildKineticGlyphs(
      const LyricLine(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: "don't",
        tokens: [
          LyricToken(
            text: 'don',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 300),
          ),
          LyricToken(
            text: "'",
            startOffset: Duration(milliseconds: 300),
            duration: Duration.zero,
          ),
          LyricToken(
            text: 't',
            startOffset: Duration(milliseconds: 400),
            duration: Duration(milliseconds: 200),
          ),
        ],
      ),
    );
    expect(glyphs.single.text, "don't");
    expect(glyphs.single.start, const Duration(seconds: 1));
    expect(glyphs.single.end, const Duration(milliseconds: 1600));
  });

  test('empty text emits no animation units', () {
    expect(
      buildKineticGlyphs(const LyricLine(start: Duration.zero, text: '')),
      isEmpty,
    );
  });

  test('arc reaches both onsets and bounds a long cross-line jump', () {
    const from = Offset(500, 0);
    const to = Offset(30, 400);
    expect(kineticArc(from, to, 0, 60), from);
    expect(kineticArc(from, to, 1, 60), to);
    expect(kineticArc(from, to, .5, 60), const Offset(265, 140));
  });
}

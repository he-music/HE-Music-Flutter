import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/partita_lyric_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Partita resolver', () {
    test('uses source lines, preserves offset, and inserts no interlude', () {
      final engine = PartitaLyricLayoutEngine.fromDocument(
        const LyricDocument(
          offset: 500,
          lines: <LyricLine>[
            LyricLine(
              start: Duration(seconds: 1),
              end: Duration(seconds: 2),
              text: 'first',
            ),
            LyricLine(
              start: Duration(seconds: 8),
              end: Duration(seconds: 9),
              text: 'second',
            ),
          ],
        ),
      );

      final position = engine.resolvePosition(
        const Duration(milliseconds: 600),
      );
      expect(position.timelinePosition, const Duration(milliseconds: 1100));
      expect(position.activeIndex, 0);
      expect(position.recentIndex, isNull);
      expect(position.upcomingIndex, 1);
      expect(engine.lineCount, 2);
      expect(engine.lineAt(0)?.text, 'first');
      expect(engine.lineAt(2), isNull);

      final gap = engine.resolvePosition(const Duration(seconds: 4));
      expect(gap.activeIndex, isNull);
      expect(gap.recentIndex, 0);
      expect(gap.upcomingIndex, 1);
      expect(engine.document.lines, hasLength(2));
    });

    test('handles empty and pre-roll positions deterministically', () {
      final empty = PartitaLyricLayoutEngine.fromDocument(
        const LyricDocument.empty(),
      );
      final emptyPosition = empty.resolvePosition(Duration.zero);
      expect(emptyPosition.activeIndex, isNull);
      expect(emptyPosition.recentIndex, isNull);
      expect(emptyPosition.upcomingIndex, isNull);

      final engine = PartitaLyricLayoutEngine.fromDocument(_document);
      final before = engine.resolvePosition(Duration.zero);
      expect(before.activeIndex, isNull);
      expect(before.upcomingIndex, 0);
    });
    test('falls back through overlaps and honors render-end boundaries', () {
      final engine = PartitaLyricLayoutEngine.fromDocument(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              end: Duration(seconds: 10),
              text: 'long overlap',
            ),
            LyricLine(
              start: Duration(seconds: 2),
              end: Duration(seconds: 3),
              text: 'short overlap',
            ),
            LyricLine(
              start: Duration(seconds: 12),
              end: Duration(milliseconds: 12050),
              text: 'micro',
            ),
          ],
        ),
      );

      final exactEnd = engine.resolvePosition(const Duration(seconds: 3));
      expect(exactEnd.activeIndex, 1);

      final fallback = engine.resolvePosition(const Duration(seconds: 4));
      expect(fallback.activeIndex, 0);
      expect(fallback.recentIndex, 1);
      expect(fallback.upcomingIndex, 2);

      final microFloor = engine.resolvePosition(
        const Duration(milliseconds: 12067),
      );
      expect(microFloor.activeIndex, 2);
      expect(
        engine.resolvePosition(const Duration(milliseconds: 12068)).activeIndex,
        isNull,
      );
    });

    test(
      'derives Folia short and micro timing profiles from line duration',
      () {
        const normal = LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'normal',
        );
        const short = LyricLine(
          start: Duration.zero,
          end: Duration(milliseconds: 150),
          text: 'short',
        );
        const micro = LyricLine(
          start: Duration.zero,
          end: Duration(milliseconds: 50),
          text: 'micro',
        );
        const zero = LyricLine(
          start: Duration(seconds: 2),
          end: Duration(seconds: 2),
          text: 'zero',
        );

        expect(resolvePartitaTimingClass(normal), PartitaTimingClass.normal);
        expect(resolvePartitaTimingClass(short), PartitaTimingClass.short);
        expect(resolvePartitaTimingClass(micro), PartitaTimingClass.micro);
        expect(resolvePartitaTimingClass(zero), PartitaTimingClass.micro);
        expect(
          resolvePartitaLineRenderEnd(zero),
          const Duration(milliseconds: 2067),
        );
        expect(
          resolvePartitaLineTransitionDuration(short),
          const Duration(milliseconds: 160),
        );
        expect(
          resolvePartitaLineTransitionDuration(micro),
          const Duration(milliseconds: 120),
        );
        expect(
          resolvePartitaWordActiveEnd(
            line: short,
            start: Duration.zero,
            end: const Duration(milliseconds: 40),
          ),
          const Duration(milliseconds: 120),
        );
        expect(
          resolvePartitaWordActiveEnd(
            line: micro,
            start: Duration.zero,
            end: const Duration(milliseconds: 20),
          ),
          const Duration(milliseconds: 67),
        );
      },
    );
  });

  group('Partita semantic and timed words', () {
    test(
      'groups contractions and trailing punctuation without searching text',
      () {
        const line = LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 2),
          text: "It’s fine!",
          tokens: <LyricToken>[
            LyricToken(
              text: 'It',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 300),
            ),
            LyricToken(
              text: '’',
              startOffset: Duration(milliseconds: 300),
              duration: Duration(milliseconds: 100),
            ),
            LyricToken(
              text: 's',
              startOffset: Duration(milliseconds: 400),
              duration: Duration(milliseconds: 300),
            ),
            LyricToken(
              text: ' ',
              startOffset: Duration(milliseconds: 700),
              duration: Duration(milliseconds: 100),
            ),
            LyricToken(
              text: 'fine',
              startOffset: Duration(milliseconds: 800),
              duration: Duration(milliseconds: 500),
            ),
            LyricToken(
              text: '!',
              startOffset: Duration(milliseconds: 1300),
              duration: Duration(milliseconds: 300),
            ),
          ],
        );

        final units = buildPartitaSemanticUnits(line);
        final words = buildPartitaDisplayWords(line);
        expect(units.map((unit) => unit.text), <String>["It’s ", 'fine!']);
        expect(units.first.isSticky, isTrue);
        expect(units.last.isSticky, isTrue);
        expect(units.first.sourceTokenIndexes, <int>[0, 1, 2, 3]);
        expect(units.last.sourceTokenIndexes, <int>[4, 5]);
        expect(words.map((word) => word.text), <String>["It’s ", 'fine!']);
        expect(words.first.sourceTokenIndexes, <int>[0, 1, 2, 3]);
        expect(words.last.sourceTokenIndexes, <int>[4, 5]);
        expect(
          words.first.graphemes.map((slice) => slice.grapheme).join(),
          "It’s ",
        );
      },
    );

    test('keeps duplicate source token indexes distinct', () {
      final line = _timedLine(
        text: 'repeat repeat',
        tokenTexts: <String>['repeat', ' ', 'repeat'],
      );
      final words = buildPartitaDisplayWords(line);

      expect(words, hasLength(2));
      expect(words[0].sourceTokenIndexes, <int>[0, 1]);
      expect(words[1].sourceTokenIndexes, <int>[2]);
      expect(words[0].id, isNot(words[1].id));
    });

    test(
      'is grapheme-safe for CJK, Latin, combining marks, and mixed text',
      () {
        const line = LyricLine(
          start: Duration.zero,
          text: '你A e\u0301👨‍👩‍👧‍👦',
        );
        final units = buildPartitaSemanticUnits(line);
        final words = buildPartitaDisplayWords(line);

        expect(units.every((unit) => unit.text.trim().isNotEmpty), isTrue);
        expect(words.expand((word) => word.graphemes).length, 5);
        expect(
          words
              .expand((word) => word.graphemes)
              .map((slice) => slice.grapheme)
              .join(),
          line.text,
        );
        expect(
          words
              .expand((word) => word.graphemes)
              .where((slice) => slice.grapheme == '👨‍👩‍👧‍👦'),
          hasLength(1),
        );
        expect(words.every((word) => word.sourceTokenIndexes.isEmpty), isTrue);
      },
    );

    test(
      'strictly disables fine timing for mixed zero, nonmonotonic, and mismatch input',
      () {
        final cases = <LyricLine>[
          const LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: 'ab',
            tokens: <LyricToken>[
              LyricToken(
                text: 'a',
                startOffset: Duration.zero,
                duration: Duration(milliseconds: 400),
              ),
              LyricToken(
                text: 'b',
                startOffset: Duration(milliseconds: 400),
                duration: Duration.zero,
              ),
            ],
          ),
          const LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: 'ab',
            tokens: <LyricToken>[
              LyricToken(
                text: 'a',
                startOffset: Duration(milliseconds: 500),
                duration: Duration(milliseconds: 200),
              ),
              LyricToken(
                text: 'b',
                startOffset: Duration(milliseconds: 200),
                duration: Duration(milliseconds: 200),
              ),
            ],
          ),
          const LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: 'abc',
            tokens: <LyricToken>[
              LyricToken(
                text: 'ab',
                startOffset: Duration.zero,
                duration: Duration(milliseconds: 400),
              ),
            ],
          ),
        ];

        for (final line in cases) {
          expect(hasValidPartitaTokenTiming(line), isFalse);
          final units = buildPartitaSemanticUnits(line);
          final words = buildPartitaDisplayWords(line);
          expect(units, isNotEmpty);
          expect(words.every((word) => !word.isTimed), isTrue);
          expect(
            words
                .expand((word) => word.graphemes)
                .every((slice) => !slice.isTimed),
            isTrue,
          );
          final layout = _layout(line);
          expect(layout.hasFineTiming, isFalse);
          expect(layout.chunks.every((chunk) => !chunk.isTimed), isTrue);
        }
      },
    );

    test(
      'valid timing preserves token timing and evenly interpolates graphemes',
      () {
        final line = LyricLine(
          start: Duration.zero,
          end: const Duration(seconds: 1),
          text: '你好',
          tokens: const <LyricToken>[
            LyricToken(
              text: '你好',
              startOffset: Duration.zero,
              duration: Duration(seconds: 1),
            ),
          ],
        );
        final word = buildPartitaDisplayWords(line).single;

        expect(hasValidPartitaTokenTiming(line), isTrue);
        expect(word.isTimed, isTrue);
        expect(word.graphemes, hasLength(2));
        expect(word.graphemes.first.start, Duration.zero);
        expect(word.graphemes.first.end, const Duration(milliseconds: 500));
        expect(word.graphemes.last.end, const Duration(seconds: 1));
      },
    );
  });

  group('Partita Folia chunk layout', () {
    test(
      'uses the 65 percent height row target and preserves uneven split',
      () {
        final line = _timedLine(
          text: '0 1 2 3 4 5 6 7 8 9',
          tokenTexts: <String>[
            '0',
            ' ',
            '1',
            ' ',
            '2',
            ' ',
            '3',
            ' ',
            '4',
            ' ',
            '5',
            ' ',
            '6',
            ' ',
            '7',
            ' ',
            '8',
            ' ',
            '9',
          ],
        );
        final short = _layout(line, width: 500, height: 320);
        final tall = _layout(line, width: 500, height: 620);

        expect(short.chunks, hasLength(2));
        expect(tall.chunks, hasLength(4));
        expect(tall.columns, hasLength(1));
        expect(
          tall.chunks
              .map((chunk) => chunk.units.length)
              .reduce((a, b) => a + b),
          10,
        );
        final lengths = tall.chunks.map((chunk) => chunk.units.length).toList();
        expect(lengths.toSet(), hasLength(greaterThan(1)));
      },
    );

    test('always exposes one ordered column and no source-line rail', () {
      final layout = _layout(_document.lines[1], height: 600);

      expect(layout.columns, hasLength(1));
      expect(layout.chunks.map((chunk) => chunk.rowIndex), <int>[0, 1, 2]);
      expect(
        layout.units.map((unit) => unit.text).join(),
        layout.sourceLine.text,
      );
      expect(
        layout.chunks.expand((chunk) => chunk.units).map((unit) => unit.index),
        <int>[0, 1, 2],
      );
    });

    test(
      'rebuilding the same input is deterministic and height is responsive',
      () {
        final line = _document.lines[1];
        final first = _layout(line, width: 420, height: 420);
        final second = _layout(line, width: 420, height: 420);
        final otherHeight = _layout(line, width: 420, height: 700);

        expect(_snapshot(first), _snapshot(second));
        expect(first.fitScale, isNot(otherHeight.fitScale));
        expect(first.chunks.length, isNot(otherHeight.chunks.length));
        expect(
          first.chunks.first.transform.offset,
          second.chunks.first.transform.offset,
        );
        expect(
          first.chunks.first.words.first.geometry.center,
          second.chunks.first.words.first.geometry.center,
        );
      },
    );

    test('wraps words inside a narrow chunk before applying fit', () {
      final layout = _layout(
        const LyricLine(
          start: Duration.zero,
          text: 'one two three four five six',
        ),
        width: 170,
        height: 140,
      );

      expect(layout.chunks, hasLength(1));
      expect(
        layout.chunks.single.words
            .map((word) => word.geometry.center.dy)
            .toSet()
            .length,
        greaterThan(1),
      );
    });
    test('mirrors multi-word flow for RTL text direction', () {
      const line = LyricLine(start: Duration.zero, text: 'alpha beta gamma');
      final ltr = _layout(line, width: 700, height: 140);
      final rtl = _layout(
        line,
        width: 700,
        height: 140,
        textDirection: TextDirection.rtl,
      );
      final ltrWords = ltr.chunks.single.words;
      final rtlWords = rtl.chunks.single.words;

      expect(
        ltrWords.first.geometry.center.dx,
        lessThan(ltrWords.last.geometry.center.dx),
      );
      expect(
        rtlWords.first.geometry.center.dx,
        greaterThan(rtlWords.last.geometry.center.dx),
      );
    });

    test(
      'fits text, guides, visual bounds, and hit rects inside the stage',
      () {
        final layout = _layout(
          const LyricLine(
            start: Duration.zero,
            text: '一段很长的 CJK and Latin lyric with punctuation!',
            translation: 'one line only',
          ),
          width: 180,
          height: 190,
        );
        final stage = layout.stageBounds;

        expect(layout.columns, hasLength(1));
        expect(layout.visualBounds.left, greaterThanOrEqualTo(stage.left));
        expect(layout.visualBounds.top, greaterThanOrEqualTo(stage.top));
        expect(layout.visualBounds.right, lessThanOrEqualTo(stage.right));
        expect(layout.visualBounds.bottom, lessThanOrEqualTo(stage.bottom));
        for (final chunk in layout.chunks) {
          expect(chunk.visualBounds.left, greaterThanOrEqualTo(stage.left));
          expect(chunk.visualBounds.top, greaterThanOrEqualTo(stage.top));
          expect(chunk.visualBounds.right, lessThanOrEqualTo(stage.right));
          expect(chunk.visualBounds.bottom, lessThanOrEqualTo(stage.bottom));
          expect(chunk.hitRect.left, greaterThanOrEqualTo(stage.left));
          expect(chunk.hitRect.top, greaterThanOrEqualTo(stage.top));
          expect(chunk.hitRect.right, lessThanOrEqualTo(stage.right));
          expect(chunk.hitRect.bottom, lessThanOrEqualTo(stage.bottom));
          expect(chunk.guide.segments, hasLength(2));
          expect(chunk.guide.bounds, isNot(Rect.zero));
        }
        expect(layout.auxiliaryText, 'one line only');
        expect(layout.chunks[0].guide.side, PartitaGuideSide.left);
        if (layout.chunks.length > 1) {
          expect(layout.chunks[1].guide.side, PartitaGuideSide.right);
        }
      },
    );

    test('measurement cache reuses values and remains bounded', () {
      final cache = PartitaLyricLayoutCache(maximumEntries: 2);
      final engine = PartitaLyricLayoutEngine.fromDocument(_document);
      final options = _options();
      final first = engine.layoutLine(
        sourceLineIndex: 1,
        options: options,
        cache: cache,
      );
      final second = engine.layoutLine(
        sourceLineIndex: 1,
        options: options,
        cache: cache,
      );

      expect(second, same(first));
      expect(cache.length, 1);
      engine.layoutLine(sourceLineIndex: 0, options: options, cache: cache);
      engine.layoutLine(sourceLineIndex: 2, options: options, cache: cache);
      expect(cache.length, 2);
      expect(
        engine.layoutLine(sourceLineIndex: 1, options: options, cache: cache),
        isNot(same(first)),
      );
    });
  });
}

PartitaLineLayout _layout(
  LyricLine line, {
  double width = 360,
  double height = 420,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final engine = PartitaLyricLayoutEngine.fromDocument(
    LyricDocument(lines: <LyricLine>[line]),
  );
  return engine.layoutLine(
    sourceLineIndex: 0,
    options: _options(
      width: width,
      height: height,
      textDirection: textDirection,
    ),
  )!;
}

String _snapshot(PartitaLineLayout layout) {
  return layout.chunks
      .map(
        (chunk) => [
          chunk.units.map((unit) => unit.text).join(','),
          chunk.transform.offset.dx,
          chunk.transform.offset.dy,
          chunk.transform.scale,
          chunk.guide.side.name,
          ...chunk.words.map(
            (word) => [
              word.word.id,
              word.geometry.center.dx,
              word.geometry.center.dy,
              word.geometry.paintScale,
              word.geometry.paintRotation,
            ].join(':'),
          ),
        ].join('|'),
      )
      .join(';');
}

PartitaLyricLayoutOptions _options({
  double width = 360,
  double height = 420,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return PartitaLyricLayoutOptions(
    stageSize: Size(width, height),
    textDirection: textDirection,
    textStyle: const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
  );
}

LyricLine _timedLine({required String text, required List<String> tokenTexts}) {
  var offset = Duration.zero;
  final tokens = <LyricToken>[];
  for (final tokenText in tokenTexts) {
    final duration = Duration(milliseconds: tokenText.trim().isEmpty ? 5 : 20);
    tokens.add(
      LyricToken(text: tokenText, startOffset: offset, duration: duration),
    );
    offset += duration;
  }
  return LyricLine(
    start: Duration.zero,
    end: offset,
    text: text,
    tokens: tokens,
  );
}

const _document = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      text: '云从左边来',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'Clouds move right',
      translation: '云向右去',
    ),
    LyricLine(
      start: Duration(seconds: 4),
      end: Duration(seconds: 6),
      text: '重复 repeat，repeat',
    ),
    LyricLine(start: Duration(seconds: 6), text: '最后一行'),
  ],
);

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/monet_lyric_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonetLyricLayoutEngine position', () {
    test('resolves waiting active and passed line states', () {
      final engine = MonetLyricLayoutEngine(_timedDocument());

      final before = engine.resolvePosition(const Duration(milliseconds: 500));
      final beforeWindow = engine.buildVisibleWindow(position: before);
      expect(before.activeIndex, isNull);
      expect(before.upcomingIndex, 0);
      expect(
        beforeWindow.map((entry) => entry.status),
        everyElement(MonetLyricLineStatus.waiting),
      );

      final active = engine.resolvePosition(const Duration(milliseconds: 3500));
      final activeWindow = engine.buildVisibleWindow(position: active);
      expect(active.activeIndex, 1);
      expect(activeWindow.map((entry) => entry.status), <MonetLyricLineStatus>[
        MonetLyricLineStatus.passed,
        MonetLyricLineStatus.active,
        MonetLyricLineStatus.waiting,
      ]);
    });

    test('holds an active line through a short gap for a direct handoff', () {
      final engine = MonetLyricLayoutEngine(_timedDocument());

      final position = engine.resolvePosition(
        const Duration(milliseconds: 2500),
      );
      final window = engine.buildVisibleWindow(position: position);

      expect(position.activeIndex, 0);
      expect(position.recentIndex, isNull);
      expect(position.upcomingIndex, 1);
      expect(window.singleWhere((entry) => entry.offset == 0).index, 0);
      expect(window[0].status, MonetLyricLineStatus.active);
      expect(window[1].status, MonetLyricLineStatus.waiting);
    });

    test(
      'inserts a timed six-dot interlude for gaps longer than three seconds',
      () {
        const document = LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration(seconds: 1),
              end: Duration(seconds: 2),
              text: 'before gap',
            ),
            LyricLine(
              start: Duration(seconds: 8),
              end: Duration(seconds: 9),
              text: 'after gap',
            ),
          ],
        );
        final engine = MonetLyricLayoutEngine(document);

        final position = engine.resolvePosition(const Duration(seconds: 4));
        final active = engine
            .buildVisibleWindow(position: position)
            .singleWhere(
              (entry) => entry.status == MonetLyricLineStatus.active,
            );
        final tokens = buildMonetDisplayTokens(active.line);

        expect(engine.lineCount, 3);
        expect(position.activeIndex, 1);
        expect(active.isInterlude, isTrue);
        expect(active.line.text, '......');
        expect(tokens, hasLength(6));
        expect(
          tokens.every((token) => token.text == '.' && token.hasTiming),
          isTrue,
        );
        expect(
          resolveMonetTokenProgress(
            timelinePosition: const Duration(seconds: 4),
            token: tokens.first,
          ),
          1,
        );
        expect(
          resolveMonetTokenProgress(
            timelinePosition: const Duration(seconds: 4),
            token: tokens[2],
          ),
          inInclusiveRange(0.0, 1.0),
        );
      },
    );

    test('keeps the final line active when it has no end', () {
      final engine = MonetLyricLayoutEngine(_timedDocument());

      final position = engine.resolvePosition(const Duration(hours: 2));

      expect(position.activeIndex, 2);
      expect(position.upcomingIndex, isNull);
    });

    test('applies document offset to the playback timeline', () {
      final engine = MonetLyricLayoutEngine(
        const LyricDocument(
          offset: 500,
          lines: <LyricLine>[
            LyricLine(
              start: Duration(seconds: 1),
              end: Duration(seconds: 2),
              text: 'offset line',
            ),
          ],
        ),
      );

      final position = engine.resolvePosition(
        const Duration(milliseconds: 600),
      );

      expect(position.timelinePosition, const Duration(milliseconds: 1100));
      expect(position.activeIndex, 0);
    });

    test('returns an empty position and window for an empty document', () {
      final engine = MonetLyricLayoutEngine(const LyricDocument.empty());

      final position = engine.resolvePosition(Duration.zero);

      expect(position.activeIndex, isNull);
      expect(position.recentIndex, isNull);
      expect(position.upcomingIndex, isNull);
      expect(engine.buildVisibleWindow(position: position), isEmpty);
    });
  });

  group('Monet visible window', () {
    test('stays finite at the beginning middle and end', () {
      final engine = MonetLyricLayoutEngine(_manyLinesDocument());

      final first = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(milliseconds: 100)),
      );
      final middle = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(milliseconds: 3100)),
      );
      final last = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(milliseconds: 6100)),
      );

      expect(first.map((entry) => entry.index), <int>[0, 1, 2]);
      expect(middle.map((entry) => entry.index), <int>[1, 2, 3, 4, 5]);
      expect(last.map((entry) => entry.index), <int>[4, 5, 6]);
      expect(middle.map((entry) => entry.offset), <int>[-2, -1, 0, 1, 2]);
    });

    test('clamps manual anchors to document boundaries', () {
      final engine = MonetLyricLayoutEngine(_manyLinesDocument());
      final position = engine.resolvePosition(
        const Duration(milliseconds: 3100),
      );

      final beforeStart = engine.buildVisibleWindow(
        position: position,
        manualAnchorIndex: -100,
      );
      final afterEnd = engine.buildVisibleWindow(
        position: position,
        manualAnchorIndex: 100,
      );

      expect(beforeStart.map((entry) => entry.index), <int>[0, 1, 2]);
      expect(beforeStart.map((entry) => entry.offset), <int>[0, 1, 2]);
      expect(afterEnd.map((entry) => entry.index), <int>[4, 5, 6]);
      expect(afterEnd.map((entry) => entry.offset), <int>[-2, -1, 0]);
    });

    test('returns stable indices offsets statuses and keys', () {
      final engine = MonetLyricLayoutEngine(_manyLinesDocument());
      final position = engine.resolvePosition(
        const Duration(milliseconds: 3100),
      );

      final first = engine.buildVisibleWindow(position: position);
      final second = engine.buildVisibleWindow(position: position);

      expect(
        second.map((entry) => entry.index),
        first.map((entry) => entry.index),
      );
      expect(
        second.map((entry) => entry.offset),
        first.map((entry) => entry.offset),
      );
      expect(
        second.map((entry) => entry.status),
        first.map((entry) => entry.status),
      );
      expect(second.map((entry) => entry.key), first.map((entry) => entry.key));
    });
  });

  group('Monet display tokens', () {
    test(
      'uses token order and cursor for CJK spaces punctuation and repeats',
      () {
        const line = LyricLine(
          start: Duration(seconds: 10),
          end: Duration(seconds: 12),
          text: '你 好，你',
          tokens: <LyricToken>[
            LyricToken(
              text: '你',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 300),
            ),
            LyricToken(
              text: ' ',
              startOffset: Duration(milliseconds: 300),
              duration: Duration(milliseconds: 200),
            ),
            LyricToken(
              text: '好，',
              startOffset: Duration(milliseconds: 500),
              duration: Duration(milliseconds: 500),
            ),
            LyricToken(
              text: '你',
              startOffset: Duration(seconds: 1),
              duration: Duration(milliseconds: 400),
            ),
          ],
        );

        final tokens = buildMonetDisplayTokens(line);

        expect(tokens.map((token) => token.text).join(), line.text);
        expect(tokens.map((token) => token.startOffset), <int>[0, 1, 2, 4]);
        expect(tokens.map((token) => token.endOffset), <int>[1, 2, 4, 5]);
        expect(tokens[0].start, const Duration(seconds: 10));
        expect(tokens[2].end, const Duration(seconds: 11));
        expect(tokens[3].startOffset, 4);
        expect(tokens[3].hasTiming, isTrue);
      },
    );

    test(
      'computes absolute token progress and clamps it to zero through one',
      () {
        const line = LyricLine(
          start: Duration(seconds: 4),
          end: Duration(seconds: 6),
          text: 'word',
          tokens: <LyricToken>[
            LyricToken(
              text: 'word',
              startOffset: Duration(milliseconds: 500),
              duration: Duration(seconds: 1),
            ),
          ],
        );
        final token = buildMonetDisplayTokens(line).single;

        expect(token.start, const Duration(milliseconds: 4500));
        expect(token.end, const Duration(milliseconds: 5500));
        expect(
          resolveMonetTokenProgress(
            timelinePosition: const Duration(seconds: 4),
            token: token,
          ),
          0,
        );
        expect(
          resolveMonetTokenProgress(
            timelinePosition: const Duration(seconds: 5),
            token: token,
          ),
          closeTo(0.5, 0.0001),
        );
        expect(
          resolveMonetTokenProgress(
            timelinePosition: const Duration(seconds: 7),
            token: token,
          ),
          1,
        );
      },
    );

    test('falls back to one untimed line when token text does not match', () {
      const line = LyricLine(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'repeat repeat',
        tokens: <LyricToken>[
          LyricToken(
            text: 'repeat',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 300),
          ),
          LyricToken(
            text: 'repeat',
            startOffset: Duration(milliseconds: 300),
            duration: Duration(milliseconds: 300),
          ),
        ],
      );

      final token = buildMonetDisplayTokens(line).single;

      expect(token.text, line.text);
      expect(token.startOffset, 0);
      expect(token.endOffset, line.text.length);
      expect(token.hasTiming, isFalse);
      expect(
        resolveMonetTokenProgress(
          timelinePosition: const Duration(hours: 1),
          token: token,
        ),
        0,
      );
    });

    test('falls back when a word-timed line has no end', () {
      const line = LyricLine(
        start: Duration(seconds: 1),
        text: 'complete',
        tokens: <LyricToken>[
          LyricToken(
            text: 'complete',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 500),
          ),
        ],
      );

      final token = buildMonetDisplayTokens(line).single;

      expect(token.text, line.text);
      expect(token.hasTiming, isFalse);
    });

    test('keeps word timing when the source has zero-duration separators', () {
      const line = LyricLine(
        start: Duration.zero,
        end: Duration(milliseconds: 3472),
        text: '想要放 放不掉 泪在飘',
        tokens: <LyricToken>[
          LyricToken(
            text: '想',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 206),
          ),
          LyricToken(
            text: '要',
            startOffset: Duration(milliseconds: 206),
            duration: Duration(milliseconds: 273),
          ),
          LyricToken(
            text: '放',
            startOffset: Duration(milliseconds: 479),
            duration: Duration(milliseconds: 448),
          ),
          LyricToken(
            text: ' ',
            startOffset: Duration(milliseconds: 927),
            duration: Duration.zero,
          ),
          LyricToken(
            text: '放',
            startOffset: Duration(milliseconds: 927),
            duration: Duration(milliseconds: 224),
          ),
          LyricToken(
            text: '不',
            startOffset: Duration(milliseconds: 1151),
            duration: Duration(milliseconds: 256),
          ),
          LyricToken(
            text: '掉',
            startOffset: Duration(milliseconds: 1407),
            duration: Duration(milliseconds: 497),
          ),
          LyricToken(
            text: ' ',
            startOffset: Duration(milliseconds: 1904),
            duration: Duration.zero,
          ),
          LyricToken(
            text: '泪',
            startOffset: Duration(milliseconds: 1904),
            duration: Duration(milliseconds: 254),
          ),
          LyricToken(
            text: '在',
            startOffset: Duration(milliseconds: 2158),
            duration: Duration(milliseconds: 467),
          ),
          LyricToken(
            text: '飘',
            startOffset: Duration(milliseconds: 2625),
            duration: Duration(milliseconds: 847),
          ),
        ],
      );

      final tokens = buildMonetDisplayTokens(line);

      expect(tokens, hasLength(11));
      expect(tokens.map((token) => token.text).join(), line.text);
      expect(tokens.where((token) => token.hasTiming), hasLength(9));
      expect(tokens[3].hasTiming, isFalse);
      expect(tokens[4].start, const Duration(milliseconds: 927));
    });

    test('keeps timed neighbors around a zero-duration glyph', () {
      const line = LyricLine(
        start: Duration.zero,
        end: Duration(milliseconds: 200),
        text: '看看',
        tokens: <LyricToken>[
          LyricToken(
            text: '看',
            startOffset: Duration.zero,
            duration: Duration.zero,
          ),
          LyricToken(
            text: '看',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 200),
          ),
        ],
      );

      final tokens = buildMonetDisplayTokens(line);

      expect(tokens, hasLength(2));
      expect(tokens.first.hasTiming, isFalse);
      expect(tokens.last.hasTiming, isTrue);
      expect(tokens.last.start, Duration.zero);
    });

    test('falls back safely for invalid token timing', () {
      const invalidLines = <LyricLine>[
        LyricLine(
          start: Duration.zero,
          text: 'negative',
          tokens: <LyricToken>[
            LyricToken(
              text: 'negative',
              startOffset: Duration(milliseconds: -1),
              duration: Duration(milliseconds: 10),
            ),
          ],
        ),
        LyricLine(
          start: Duration.zero,
          text: 'ab',
          tokens: <LyricToken>[
            LyricToken(
              text: 'a',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 500),
            ),
            LyricToken(
              text: 'b',
              startOffset: Duration(milliseconds: 400),
              duration: Duration(milliseconds: 500),
            ),
          ],
        ),
        LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'late',
          tokens: <LyricToken>[
            LyricToken(
              text: 'late',
              startOffset: Duration(milliseconds: 900),
              duration: Duration(milliseconds: 200),
            ),
          ],
        ),
      ];

      for (final line in invalidLines) {
        final tokens = buildMonetDisplayTokens(line);
        expect(tokens, hasLength(1));
        expect(tokens.single.text, line.text);
        expect(tokens.single.hasTiming, isFalse);
      }
    });
  });

  group('Monet text layout', () {
    test('wraps a long active line without clipping its measured height', () {
      final engine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              text:
                  'This deliberately long active lyric must wrap across several lines on a narrow rail.',
            ),
          ],
        ),
      );
      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(Duration.zero),
      );

      final layout = layoutMonetLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(width: 150, height: 180),
      ).single;

      expect(layout.measurement.mainLineCount, greaterThan(1));
      expect(layout.measurement.mainTextClipped, isFalse);
      expect(
        layout.measurement.visualSize.height,
        greaterThan(layout.measurement.mainTextSize.height),
      );
    });

    test('keeps a fitting active block fully inside the rail', () {
      final engine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[LyricLine(start: Duration.zero, text: 'active')],
        ),
      );
      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(Duration.zero),
      );

      final layout = layoutMonetLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(width: 180, height: 120, anchorAlignment: 0),
      ).single;

      expect(layout.measurement.visualSize.height, lessThanOrEqualTo(120));
      expect(layout.rect.top, greaterThanOrEqualTo(0));
      expect(layout.rect.bottom, lessThanOrEqualTo(120));
      expect(layout.hitRect, layout.rect);
    });

    test('measures present missing and long translation content', () {
      final translatedEngine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              text: 'main',
              translation:
                  'A deliberately long translation that wraps over several rows in a narrow rail.',
            ),
          ],
        ),
      );
      final translated = _layoutSingle(translatedEngine, width: 145);
      expect(translated.measurement.translationText, isNotNull);
      expect(translated.measurement.translationLineCount, greaterThan(1));
      expect(translated.measurement.translationSize.height, greaterThan(0));

      final missingEngine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[LyricLine(start: Duration.zero, text: 'main')],
        ),
      );
      final missing = _layoutSingle(missingEngine, width: 145);
      expect(missing.measurement.translationText, isNull);
      expect(missing.measurement.translationSize, Size.zero);
    });

    test('uses romanization fallback and honors translation visibility', () {
      final engine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(start: Duration.zero, text: '夜曲', romanization: 'ye qu'),
          ],
        ),
      );

      final visible = _layoutSingle(engine);
      final hidden = _layoutSingle(engine, showTranslation: false);

      expect(visible.measurement.translationText, 'ye qu');
      expect(hidden.measurement.translationText, isNull);
    });

    test('keeps every line hit rect inside the rail bounds', () {
      final engine = MonetLyricLayoutEngine(_manyLinesDocument());
      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(milliseconds: 3100)),
        before: 4,
        after: 4,
      );
      const rail = Size(180, 120);

      final layouts = layoutMonetLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(width: rail.width, height: rail.height),
      );

      for (final layout in layouts) {
        expect(layout.hitRect.left, greaterThanOrEqualTo(0));
        expect(layout.hitRect.top, greaterThanOrEqualTo(0));
        expect(layout.hitRect.right, lessThanOrEqualTo(rail.width));
        expect(layout.hitRect.bottom, lessThanOrEqualTo(rail.height));
        expect(layout.hitRect.width, greaterThanOrEqualTo(0));
        expect(layout.hitRect.height, greaterThanOrEqualTo(0));
      }
    });

    test('cache key changes with content size font and display options', () {
      final baseEngine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              text: 'base',
              translation: 'translation',
            ),
          ],
        ),
      );
      final changedContentEngine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              text: 'changed',
              translation: 'translation',
            ),
          ],
        ),
      );

      final base = _layoutSingle(baseEngine).cacheKey;
      final content = _layoutSingle(changedContentEngine).cacheKey;
      final width = _layoutSingle(baseEngine, width: 240).cacheKey;
      final height = _layoutSingle(baseEngine, height: 320).cacheKey;
      final font = _layoutSingle(baseEngine, activeFontSize: 34).cacheKey;
      final display = _layoutSingle(
        baseEngine,
        showTranslation: false,
      ).cacheKey;

      expect(<String>{
        base,
        content,
        width,
        height,
        font,
        display,
      }, hasLength(6));
    });

    test('cache key ignores text colors that do not affect measurement', () {
      final engine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(start: Duration.zero, text: 'same metrics'),
          ],
        ),
      );

      final first = _layoutSingle(engine, color: Colors.red).cacheKey;
      final second = _layoutSingle(engine, color: Colors.blue).cacheKey;

      expect(first, second);
    });

    test('measurement cache reuses an identical measured result', () {
      final engine = MonetLyricLayoutEngine(
        const LyricDocument(
          lines: <LyricLine>[LyricLine(start: Duration.zero, text: 'cached')],
        ),
      );
      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(Duration.zero),
      );
      final cache = MonetLyricMeasurementCache();

      final first = layoutMonetLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(),
        cache: cache,
      ).single;
      final second = layoutMonetLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(),
        cache: cache,
      ).single;

      expect(second.measurement, same(first.measurement));
      expect(cache.length, 1);
    });
  });
}

LyricDocument _timedDocument() {
  return const LyricDocument(
    lines: <LyricLine>[
      LyricLine(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'first',
      ),
      LyricLine(
        start: Duration(seconds: 3),
        end: Duration(seconds: 4),
        text: 'second',
      ),
      LyricLine(start: Duration(seconds: 5), text: 'last'),
    ],
  );
}

LyricDocument _manyLinesDocument() {
  return LyricDocument(
    lines: List<LyricLine>.generate(
      7,
      (index) => LyricLine(
        start: Duration(seconds: index),
        end: index == 6 ? null : Duration(seconds: index, milliseconds: 800),
        text: 'line $index',
      ),
      growable: false,
    ),
  );
}

MonetPositionedLyricLine _layoutSingle(
  MonetLyricLayoutEngine engine, {
  double width = 180,
  double height = 240,
  double activeFontSize = 28,
  bool showTranslation = true,
  Color color = Colors.white,
}) {
  final entries = engine.buildVisibleWindow(
    position: engine.resolvePosition(Duration.zero),
  );
  return layoutMonetLyricWindow(
    engine: engine,
    entries: entries,
    options: _options(
      width: width,
      height: height,
      activeFontSize: activeFontSize,
      showTranslation: showTranslation,
      color: color,
    ),
  ).single;
}

MonetLyricLayoutOptions _options({
  double width = 180,
  double height = 240,
  double activeFontSize = 28,
  bool showTranslation = true,
  Color color = Colors.white,
  double anchorAlignment = 0.46,
}) {
  return MonetLyricLayoutOptions(
    railSize: Size(width, height),
    activeTextStyle: TextStyle(
      fontSize: activeFontSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: color,
    ),
    inactiveTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: color,
    ),
    translationTextStyle: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: color,
    ),
    showTranslation: showTranslation,
    anchorAlignment: anchorAlignment,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/monet_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/partita_lyric_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Partita document projection', () {
    test('keeps source indices stable across a synthetic interlude', () {
      final engine = PartitaLyricLayoutEngine.fromDocument(
        const LyricDocument(
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

      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(seconds: 4)),
      );

      expect(entries.map((entry) => entry.index), <int>[0, 1, 2]);
      expect(entries.map((entry) => entry.sourceIndex), <int>[0, 0, 1]);
      expect(entries[1].isInterlude, isTrue);
      expect(entries[2].sourceIndex.isOdd, isTrue);
    });

    test('handles empty and pre-roll positions deterministically', () {
      final empty = PartitaLyricLayoutEngine.fromDocument(
        const LyricDocument.empty(),
      );
      final emptyPosition = empty.resolvePosition(Duration.zero);
      expect(emptyPosition.activeIndex, isNull);
      expect(empty.buildVisibleWindow(position: emptyPosition), isEmpty);

      final engine = PartitaLyricLayoutEngine.fromDocument(_document);
      final before = engine.resolvePosition(const Duration(milliseconds: 100));
      final window = engine.buildVisibleWindow(position: before);
      expect(before.activeIndex, isNull);
      expect(before.upcomingIndex, 0);
      expect(
        window.every((entry) => entry.status == MonetLyricLineStatus.waiting),
        isTrue,
      );
    });

    test('falls back when any source token has zero duration', () {
      const line = LyricLine(
        start: Duration.zero,
        end: Duration(seconds: 1),
        text: '云 阶',
        tokens: <LyricToken>[
          LyricToken(
            text: '云',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 400),
          ),
          LyricToken(
            text: ' ',
            startOffset: Duration(milliseconds: 400),
            duration: Duration.zero,
          ),
          LyricToken(
            text: '阶',
            startOffset: Duration(milliseconds: 400),
            duration: Duration(milliseconds: 400),
          ),
        ],
      );

      final displayTokens = buildPartitaDisplayTokens(line);

      expect(displayTokens, hasLength(1));
      expect(displayTokens.single.text, line.text);
      expect(displayTokens.single.hasTiming, isFalse);
    });
  });

  group('Partita cloud-step layout', () {
    test('alternates by source parity with deterministic bounded offsets', () {
      final engine = PartitaLyricLayoutEngine.fromDocument(_document);
      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(seconds: 3)),
        before: 3,
        after: 3,
      );
      final first = layoutPartitaLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(),
      );
      final second = layoutPartitaLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(),
      );

      expect(
        second.map((line) => line.cloudOffset),
        first.map((line) => line.cloudOffset),
      );
      for (final line in first) {
        if (line.cloudOffset == 0) continue;
        expect(
          line.cloudOffset.isNegative,
          line.entry.sourceIndex.isEven,
          reason: 'source index ${line.entry.sourceIndex}',
        );
        expect(line.rect.left, greaterThanOrEqualTo(0));
        expect(line.rect.right, lessThanOrEqualTo(260));
        expect(line.hitRect.left, greaterThanOrEqualTo(0));
        expect(line.hitRect.right, lessThanOrEqualTo(260));
      }
    });

    test('clamps cloud offsets when measured text consumes the width', () {
      expect(
        resolvePartitaCloudStepOffset(
          sourceIndex: 0,
          relativeOffset: 3,
          availableWidth: 200,
        ),
        lessThan(0),
      );
      expect(
        resolvePartitaCloudStepOffset(
          sourceIndex: 1,
          relativeOffset: 3,
          availableWidth: 200,
        ),
        greaterThan(0),
      );

      final engine = PartitaLyricLayoutEngine.fromDocument(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              text:
                  'A very long active line wraps across the available width instead of escaping the cloud rail.',
              translation:
                  'A long auxiliary sentence remains directly below the main lyric.',
            ),
          ],
        ),
      );
      final layout = layoutPartitaLyricWindow(
        engine: engine,
        entries: engine.buildVisibleWindow(
          position: engine.resolvePosition(Duration.zero),
        ),
        options: _options(width: 170, height: 250),
      ).single;

      expect(layout.measurement.mainLineCount, greaterThan(1));
      expect(layout.measurement.mainTextClipped, isFalse);
      expect(layout.measurement.auxiliaryLineCount, greaterThan(1));
      expect(layout.rect.left, greaterThanOrEqualTo(0));
      expect(layout.rect.right, lessThanOrEqualTo(170));
      expect(layout.hitRect, isNot(Rect.zero));
    });

    test('translation wins and romanization is the missing fallback', () {
      final translated = _singleLayout(
        const LyricLine(
          start: Duration.zero,
          text: '夜曲',
          translation: 'Nocturne',
          romanization: 'ye qu',
        ),
      );
      final romanized = _singleLayout(
        const LyricLine(
          start: Duration.zero,
          text: '夜曲',
          romanization: 'ye qu',
        ),
      );
      final missing = _singleLayout(
        const LyricLine(start: Duration.zero, text: '夜曲'),
      );

      expect(translated.measurement.auxiliaryText, 'Nocturne');
      expect(romanized.measurement.auxiliaryText, 'ye qu');
      expect(missing.measurement.auxiliaryText, isNull);
      expect(missing.measurement.auxiliarySize, Size.zero);
    });

    test('measurement cache reuses identical CJK and Latin geometry', () {
      final engine = PartitaLyricLayoutEngine.fromDocument(_document);
      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(seconds: 3)),
      );
      final cache = PartitaLyricMeasurementCache();
      final first = layoutPartitaLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(),
        cache: cache,
      );
      final second = layoutPartitaLyricWindow(
        engine: engine,
        entries: entries,
        options: _options(),
        cache: cache,
      );

      expect(second.first.measurement, same(first.first.measurement));
      expect(cache.length, first.length);
    });
  });
}

PartitaPositionedLyricLine _singleLayout(LyricLine line) {
  final engine = PartitaLyricLayoutEngine.fromDocument(
    LyricDocument(lines: <LyricLine>[line]),
  );
  return layoutPartitaLyricWindow(
    engine: engine,
    entries: engine.buildVisibleWindow(
      position: engine.resolvePosition(Duration.zero),
    ),
    options: _options(),
  ).single;
}

PartitaLyricLayoutOptions _options({double width = 260, double height = 320}) {
  return PartitaLyricLayoutOptions(
    railSize: Size(width, height),
    activeTextStyle: const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    inactiveTextStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
    auxiliaryTextStyle: const TextStyle(fontSize: 13, height: 1.3),
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

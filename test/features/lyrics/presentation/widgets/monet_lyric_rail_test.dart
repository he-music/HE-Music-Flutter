import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/monet_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/monet_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/monet_lyric_rail.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/monet_lyric_page.dart';

final _testPositionProvider =
    NotifierProvider<_TestPositionController, Duration>(
      _TestPositionController.new,
    );

const _palette = PlayerScenePalette(
  surface: Color(0xff15181b),
  surfaceDeep: Color(0xff090b0d),
  surfaceRaised: Color(0xff24282d),
  edge: Color(0xff8ad7c1),
  accent: Color(0xffffd166),
  foreground: Color(0xfff7f8f4),
  secondaryForeground: Color(0xffb8c2bd),
  onAccent: Color(0xff11120f),
);

const _alternatePalette = PlayerScenePalette(
  surface: Color(0xff20151b),
  surfaceDeep: Color(0xff0d090b),
  surfaceRaised: Color(0xff31232a),
  edge: Color(0xffff9fb4),
  accent: Color(0xff7ee8ff),
  foreground: Color(0xfffff7fa),
  secondaryForeground: Color(0xffd8bfc9),
  onAccent: Color(0xff071114),
);

void main() {
  group('Monet painter data', () {
    testWidgets('precomputes timed token boxes and paints an accent sweep', (
      tester,
    ) async {
      var paintCount = 0;
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onPaint: () => paintCount += 1),
      );
      await tester.pump();

      final painter = _painter(tester);
      final active = _activePaintLine(painter.data);
      expect(active.accentPainter, isNotNull);
      expect(active.glowPainter, isNotNull);
      expect(active.tokens, hasLength(4));
      expect(active.tokens.every((token) => token.boxes.isNotEmpty), isTrue);
      expect(active.tokens.map((token) => token.token.text).join(), '你 好，你');

      final token = active.tokens[2];
      final earlyProgress = resolveMonetTokenProgress(
        timelinePosition: const Duration(milliseconds: 2550),
        token: token.token,
      );
      final laterProgress = resolveMonetTokenProgress(
        timelinePosition: const Duration(milliseconds: 2850),
        token: token.token,
      );
      final earlyWidth = _clipWidth(token.boxes, earlyProgress);
      final laterWidth = _clipWidth(token.boxes, laterProgress);
      expect(laterProgress, greaterThan(earlyProgress));
      expect(laterWidth, greaterThan(earlyWidth));
      expect(paintCount, greaterThan(0));
    });

    testWidgets('uses line-level active paint without timing', (tester) async {
      await tester.pumpWidget(_buildRailApp(document: _lineOnlyDocument));
      await tester.pump();

      final active = _activePaintLine(_painter(tester).data);
      expect(active.accentPainter, isNull);
      expect(active.tokens, isEmpty);
      expect(
        (active.mainPainter.text as TextSpan).style?.color,
        _palette.foreground.withValues(alpha: 0.98),
      );
    });

    testWidgets('word-by-word disabled uses the same line-level fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, enableWordByWordLyric: false),
      );
      await tester.pump();

      final active = _activePaintLine(_painter(tester).data);
      expect(active.accentPainter, isNull);
      expect(active.tokens, isEmpty);
    });

    testWidgets(
      'CJK repeats spaces punctuation and wrapped boxes keep offsets',
      (tester) async {
        const text = '你 你好，你 你好，重复的长句必须换行';
        const document = LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              end: Duration(seconds: 10),
              text: text,
              tokens: <LyricToken>[
                LyricToken(
                  text: text,
                  startOffset: Duration.zero,
                  duration: Duration(seconds: 8),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          _buildRailApp(
            document: document,
            size: const Size(150, 300),
            initialPosition: const Duration(seconds: 2),
          ),
        );
        await tester.pump();

        final active = _activePaintLine(_painter(tester).data);
        final token = active.tokens.single;
        expect(token.token.startOffset, 0);
        expect(token.token.endOffset, text.length);
        expect(token.boxes.length, greaterThan(1));
        expect(
          token.boxes.map((box) => box.top).toSet().length,
          greaterThan(1),
        );

        final clips = resolveMonetTokenClipRects(
          boxes: const <Rect>[
            Rect.fromLTWH(0, 0, 40, 20),
            Rect.fromLTWH(0, 24, 40, 20),
          ],
          progress: 0.75,
          textDirection: TextDirection.ltr,
        );
        expect(clips, const <Rect>[
          Rect.fromLTWH(0, 0, 40, 20),
          Rect.fromLTWH(0, 24, 20, 20),
        ]);
      },
    );
    test('interpolates line scale across an active state change', () {
      expect(
        resolveMonetLineTransitionScale(
          currentFontSize: 40,
          previousFontSize: 20,
          transitionValue: 0,
        ),
        closeTo(0.5, 0.0001),
      );
      expect(
        resolveMonetLineTransitionScale(
          currentFontSize: 40,
          previousFontSize: 20,
          transitionValue: 0.5,
        ),
        closeTo(0.75, 0.0001),
      );
      expect(
        resolveMonetLineTransitionScale(
          currentFontSize: 40,
          previousFontSize: 20,
          transitionValue: 1,
        ),
        1,
      );
    });
  });

  group('Monet repaint isolation', () {
    testWidgets(
      'same-line position ticks repaint without rebuilding structure',
      (tester) async {
        var outerBuildCount = 0;
        var structureBuildCount = 0;
        var paintCount = 0;
        await tester.pumpWidget(
          _buildRailApp(
            document: _timedDocument,
            onOuterBuild: () => outerBuildCount += 1,
            onStructureBuild: () => structureBuildCount += 1,
            onPaint: () => paintCount += 1,
          ),
        );
        await tester.pump();
        final initialOuterBuildCount = outerBuildCount;
        final initialStructureBuildCount = structureBuildCount;
        final initialPaintCount = paintCount;
        final container = _container(tester);

        container
            .read(_testPositionProvider.notifier)
            .update(const Duration(milliseconds: 2700));
        await tester.pump();

        expect(outerBuildCount, initialOuterBuildCount);
        expect(structureBuildCount, initialStructureBuildCount);
        expect(paintCount, greaterThan(initialPaintCount));
      },
    );

    testWidgets('line crossing rebuilds only the rail structure', (
      tester,
    ) async {
      var outerBuildCount = 0;
      var structureBuildCount = 0;
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          onOuterBuild: () => outerBuildCount += 1,
          onStructureBuild: () => structureBuildCount += 1,
        ),
      );
      await tester.pump();
      final initialOuterBuildCount = outerBuildCount;
      final initialStructureBuildCount = structureBuildCount;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 4100));
      await tester.pump();

      expect(outerBuildCount, initialOuterBuildCount);
      expect(structureBuildCount, greaterThan(initialStructureBuildCount));
      expect(_activePaintLine(_painter(tester).data).positioned.entry.index, 2);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Monet responsive layout', () {
    for (final size in <Size>[
      const Size(280, 220),
      const Size(390, 700),
      const Size(760, 280),
      const Size(1000, 700),
    ]) {
      testWidgets('keeps active long text readable at $size', (tester) async {
        await tester.pumpWidget(
          _buildRailApp(
            document: _longDocument,
            size: size,
            initialPosition: const Duration(milliseconds: 500),
          ),
        );
        await tester.pump();

        final active = _activePaintLine(_painter(tester).data);
        expect(active.positioned.measurement.mainLineCount, greaterThan(1));
        expect(active.positioned.measurement.mainTextClipped, isFalse);
        expect(active.translationPainter, isNotNull);
        expect(
          active.positioned.hitRect.intersect(Offset.zero & size).isEmpty,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('translation wins and romanization fills only when missing', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _translationDocument));
      await tester.pump();
      expect(
        _activePaintLine(
          _painter(tester).data,
        ).positioned.measurement.translationText,
        'translated active',
      );

      await tester.pumpWidget(_buildRailApp(document: _romanizationDocument));
      await tester.pump();
      expect(
        _activePaintLine(
          _painter(tester).data,
        ).positioned.measurement.translationText,
        'romanized active',
      );
      expect(
        _painter(tester).data.lines
            .where(
              (line) =>
                  line.positioned.entry.status != MonetLyricLineStatus.active,
            )
            .every((line) => line.translationPainter == null),
        isTrue,
      );
    });
  });

  group('Monet interaction', () {
    testWidgets('wheel steps manual anchor and resets after 1800ms idle', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();
      expect(_anchorIndex(tester), 1);

      _sendScroll(tester, 70);
      await tester.pump();
      expect(_anchorIndex(tester), 2);

      await tester.pump(const Duration(milliseconds: 1000));
      _sendScroll(tester, 20);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_anchorIndex(tester), 2);
      await tester.pump(const Duration(milliseconds: 900));
      expect(_anchorIndex(tester), 1);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('wheel and drag clamp manual anchor to document boundaries', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();

      for (var index = 0; index < 12; index++) {
        _sendScroll(tester, -70);
        await tester.pump();
      }
      expect(_anchorIndex(tester), 0);

      await tester.drag(find.byType(MonetLyricRail), const Offset(0, -500));
      await tester.pump();
      expect(_anchorIndex(tester), lessThanOrEqualTo(1));
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('tap seeks through visible hit rect with offset correction', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(
          document: _offsetDocument,
          onSeek: seeks.add,
          initialPosition: const Duration(milliseconds: 1700),
        ),
      );
      await tester.pump();

      final active = _activePaintLine(_painter(tester).data);
      final railTopLeft = tester.getTopLeft(find.byType(MonetLyricRail));
      await tester.tapAt(railTopLeft + active.positioned.hitRect.center);
      await tester.pump();

      expect(seeks, <Duration>[const Duration(milliseconds: 1500)]);
    });

    testWidgets('negative offset-corrected seek clamps to zero', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(
          document: _offsetDocument,
          onSeek: seeks.add,
          initialPosition: Duration.zero,
        ),
      );
      await tester.pump();
      final active = _activePaintLine(_painter(tester).data);
      final railTopLeft = tester.getTopLeft(find.byType(MonetLyricRail));
      await tester.tapAt(railTopLeft + active.positioned.hitRect.center);
      await tester.pump();
      expect(seeks, <Duration>[Duration.zero]);
    });

    testWidgets('disabled seek and drag never invoke seek', (tester) async {
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onSeek: null),
      );
      await tester.pump();
      final active = _activePaintLine(_painter(tester).data);
      final railTopLeft = tester.getTopLeft(find.byType(MonetLyricRail));
      await tester.tapAt(railTopLeft + active.positioned.hitRect.center);
      await tester.drag(find.byType(MonetLyricRail), const Offset(0, -80));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('drag gesture does not turn into a line tap', (tester) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onSeek: seeks.add),
      );
      await tester.pump();
      await tester.drag(find.byType(MonetLyricRail), const Offset(0, -80));
      await tester.pump();
      expect(seeks, isEmpty);
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Monet host lifecycle', () {
    testWidgets('loading empty and error states never retain old lyrics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPageApp(const AsyncLoading<LyricDocument>()),
      );
      expect(
        find.byKey(const ValueKey<String>('monet-lyric-loading')),
        findsOneWidget,
      );
      expect(find.byType(MonetLyricRail), findsNothing);

      await tester.pumpWidget(
        _buildPageApp(const AsyncData<LyricDocument>(LyricDocument.empty())),
      );
      expect(
        find.byKey(const ValueKey<String>('monet-lyric-empty')),
        findsOneWidget,
      );
      expect(find.text('No lyrics'), findsOneWidget);

      await tester.pumpWidget(
        _buildPageApp(
          AsyncError<LyricDocument>(StateError('failed'), StackTrace.empty),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('monet-lyric-error')),
        findsOneWidget,
      );
      expect(find.textContaining('failed'), findsNothing);
      expect(find.byType(MonetLyricRail), findsNothing);
    });

    testWidgets('document and palette replacement discard old render data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRailApp(document: _lineOnlyDocument, palette: _palette),
      );
      await tester.pump();
      expect(_paintedTexts(tester), contains('plain active'));

      await tester.pumpWidget(
        _buildRailApp(
          document: _replacementDocument,
          palette: _alternatePalette,
        ),
      );
      await tester.pump();
      final active = _activePaintLine(_painter(tester).data);
      expect(_paintedTexts(tester), contains('replacement active'));
      expect(_paintedTexts(tester), isNot(contains('plain active')));
      expect(
        (active.mainPainter.text as TextSpan).style?.color,
        _alternatePalette.foreground.withValues(alpha: 0.98),
      );
    });

    testWidgets(
      'request identity replacement clears manual anchor and transition data',
      (tester) async {
        await tester.pumpWidget(
          _buildRailApp(
            document: _lineOnlyDocument,
            documentIdentity: 'qq::track-a::',
          ),
        );
        await tester.pump();
        _sendScroll(tester, 70);
        await tester.pump();
        expect(_anchorIndex(tester), 2);

        await tester.pumpWidget(
          _buildRailApp(
            document: _lineOnlyDocument,
            documentIdentity: 'qq::track-b::',
          ),
        );
        await tester.pump();

        expect(_anchorIndex(tester), 1);
        expect(_painter(tester).previousData, isNull);
      },
    );

    testWidgets('palette fallback and dispose with pending timer stay safe', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPageApp(
          const AsyncData<LyricDocument>(_timedDocument),
          palette: null,
        ),
      );
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _buildRailApp({
  required LyricDocument document,
  Size size = const Size(430, 620),
  Duration initialPosition = const Duration(milliseconds: 2500),
  bool enableWordByWordLyric = true,
  String? documentIdentity,
  PlayerScenePalette palette = _palette,
  ValueChanged<Duration>? onSeek,
  VoidCallback? onOuterBuild,
  VoidCallback? onStructureBuild,
  VoidCallback? onPaint,
}) {
  return ProviderScope(
    overrides: [
      _testPositionProvider.overrideWith(
        () => _TestPositionController(initialPosition),
      ),
      lyricPositionProvider.overrideWith(
        (ref) => ref.watch(_testPositionProvider),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            size: size,
            child: Builder(
              builder: (context) {
                onOuterBuild?.call();
                return MonetLyricRail(
                  key: const ValueKey<String>('test-monet-rail'),
                  document: document,
                  documentIdentity: documentIdentity,
                  fontPreset: AppLyricFontPreset.medium,
                  enableWordByWordLyric: enableWordByWordLyric,
                  palette: palette,
                  onSeek: onSeek,
                  debugOnStructureBuild: onStructureBuild,
                  debugOnPaint: onPaint,
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildPageApp(
  AsyncValue<LyricDocument> document, {
  PlayerScenePalette? palette = _palette,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestConfigController.new),
      currentLyricDocumentProvider.overrideWithValue(document),
      lyricPositionProvider.overrideWithValue(
        const Duration(milliseconds: 2500),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MonetLyricPage(
          emptyText: 'No lyrics',
          onSeek: null,
          palette: palette,
        ),
      ),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(MonetLyricRail)));
}

MonetLyricPainter _painter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey<String>('monet-lyric-painter')),
          )
          .painter!
      as MonetLyricPainter;
}

MonetLyricPaintLine _activePaintLine(MonetLyricRenderData data) {
  return data.lines.singleWhere(
    (line) => line.positioned.entry.status == MonetLyricLineStatus.active,
  );
}

int _anchorIndex(WidgetTester tester) {
  return _painter(tester).data.lines
      .singleWhere((line) => line.positioned.entry.offset == 0)
      .positioned
      .entry
      .index;
}

void _sendScroll(WidgetTester tester, double deltaY) {
  final center = tester.getCenter(find.byType(MonetLyricRail));
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: center,
      scrollDelta: Offset(0, deltaY),
      kind: PointerDeviceKind.mouse,
    ),
  );
}

double _clipWidth(List<Rect> boxes, double progress) {
  return resolveMonetTokenClipRects(
    boxes: boxes,
    progress: progress,
    textDirection: TextDirection.ltr,
  ).fold<double>(0, (sum, rect) => sum + rect.width);
}

List<String> _paintedTexts(WidgetTester tester) {
  return _painter(tester).data.lines
      .map((line) => (line.mainPainter.text as TextSpan).text ?? '')
      .toList(growable: false);
}

class _TestPositionController extends Notifier<Duration> {
  _TestPositionController([this.initialPosition = Duration.zero]);

  final Duration initialPosition;

  @override
  Duration build() => initialPosition;

  void update(Duration value) {
    state = value;
  }
}

class _TestConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

const _timedDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'before line',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: '你 好，你',
      translation: 'translated active',
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
          duration: Duration(milliseconds: 500),
        ),
      ],
    ),
    LyricLine(
      start: Duration(seconds: 4),
      end: Duration(seconds: 6),
      text: 'after line',
    ),
    LyricLine(
      start: Duration(seconds: 6),
      end: Duration(seconds: 8),
      text: 'fourth line',
    ),
  ],
);

const _lineOnlyDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'before plain',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'plain active',
    ),
    LyricLine(start: Duration(seconds: 4), text: 'after plain'),
  ],
);

const _replacementDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'replacement before',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'replacement active',
    ),
  ],
);

const _longDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 5),
      text:
          'An intentionally long active lyric wraps completely on narrow screens without clipping any active words.',
      translation:
          'A translated layer remains attached to the active line and never covers its neighboring context.',
    ),
    LyricLine(start: Duration(seconds: 5), text: 'nearby context'),
  ],
);

const _translationDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'context',
      translation: 'hidden context translation',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'active',
      translation: 'translated active',
      romanization: 'romanized active',
    ),
  ],
);

const _romanizationDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(start: Duration.zero, end: Duration(seconds: 2), text: 'context'),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'active',
      romanization: 'romanized active',
    ),
  ],
);

const _offsetDocument = LyricDocument(
  offset: 500,
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 1),
      text: 'clamped seek',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'offset seek',
    ),
  ],
);

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
import 'package:he_music_flutter/features/lyrics/presentation/widgets/partita_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/partita_lyric_rail.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/partita_lyric_page.dart';

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

void main() {
  group('Partita painter', () {
    testWidgets('projects timed repeated CJK tokens without text search', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();

      final active = _activeLine(_painter(tester).data);
      expect(active.accentPainter, isNotNull);
      expect(active.glowPainter, isNotNull);
      expect(active.tokens.map((token) => token.token.text).join(), '你 好，你');
      expect(active.tokens.every((token) => token.boxes.isNotEmpty), isTrue);
      expect(active.positioned.measurement.auxiliaryText, 'translated active');
    });

    testWidgets(
      'invalid timing falls back to a clear line-level active style',
      (tester) async {
        const document = LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              end: Duration(seconds: 1),
              text: 'repeat repeat',
              tokens: <LyricToken>[
                LyricToken(
                  text: 'repeat',
                  startOffset: Duration.zero,
                  duration: Duration(milliseconds: 700),
                ),
                LyricToken(
                  text: 'repeat',
                  startOffset: Duration(milliseconds: 500),
                  duration: Duration(milliseconds: 700),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          _buildRailApp(document: document, initialPosition: Duration.zero),
        );
        await tester.pump();

        final active = _activeLine(_painter(tester).data);
        expect(active.accentPainter, isNull);
        expect(active.tokens, isEmpty);
        expect(
          (active.mainPainter.text as TextSpan).style?.color,
          _palette.foreground.withValues(alpha: 0.98),
        );
      },
    );

    test('guide L segments remain outside text and inside rail bounds', () {
      const textRect = Rect.fromLTWH(55, 40, 90, 48);
      const bounds = Rect.fromLTWH(0, 0, 200, 140);
      final segments = resolvePartitaGuideSegments(
        textRect: textRect,
        bounds: bounds,
        progress: 1,
      );

      expect(segments, hasLength(4));
      for (final segment in segments) {
        expect(bounds.contains(segment.start), isTrue);
        expect(bounds.contains(segment.end), isTrue);
        expect(textRect.contains(segment.start), isFalse);
        expect(textRect.contains(segment.end), isFalse);
      }
      expect(segments[1].end.dx, lessThan(textRect.left));
      expect(segments[3].end.dx, greaterThan(textRect.right));
    });
  });

  group('Partita repaint isolation', () {
    testWidgets('same-line ticks repaint without rebuilding outer structure', (
      tester,
    ) async {
      var outerBuilds = 0;
      var structureBuilds = 0;
      var paints = 0;
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          onOuterBuild: () => outerBuilds += 1,
          onStructureBuild: () => structureBuilds += 1,
          onPaint: () => paints += 1,
        ),
      );
      await tester.pump();
      final initialOuter = outerBuilds;
      final initialStructure = structureBuilds;
      final initialPaints = paints;
      final data = _painter(tester).data;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 2700));
      await tester.pump();

      expect(outerBuilds, initialOuter);
      expect(structureBuilds, initialStructure);
      expect(paints, greaterThan(initialPaints));
      expect(_painter(tester).data, same(data));
    });

    testWidgets('crossing a line rebuilds only Partita render data', (
      tester,
    ) async {
      var outerBuilds = 0;
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          onOuterBuild: () => outerBuilds += 1,
        ),
      );
      await tester.pump();
      final initialOuter = outerBuilds;
      final initialData = _painter(tester).data;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 4300));
      await tester.pump();

      expect(outerBuilds, initialOuter);
      expect(_painter(tester).data, isNot(same(initialData)));
      expect(_activeLine(_painter(tester).data).positioned.entry.index, 2);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Partita interaction and lifecycle', () {
    testWidgets('tap seeks with document offset and disabled seek is inert', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(
          document: _offsetDocument,
          initialPosition: const Duration(milliseconds: 1700),
          onSeek: seeks.add,
        ),
      );
      await tester.pump();
      final active = _activeLine(_painter(tester).data);
      await tester.tapAt(
        tester.getTopLeft(find.byType(PartitaLyricRail)) +
            active.positioned.hitRect.center,
      );
      await tester.pump();
      expect(seeks, <Duration>[const Duration(milliseconds: 1500)]);

      await tester.pumpWidget(
        _buildRailApp(document: _offsetDocument, onSeek: null),
      );
      await tester.pump();
      final disabled = _activeLine(_painter(tester).data);
      await tester.tapAt(
        tester.getTopLeft(find.byType(PartitaLyricRail)) +
            disabled.positioned.hitRect.center,
      );
      expect(seeks, hasLength(1));
    });

    testWidgets('wheel pauses follow, idle resets, and any seek clears it', (
      tester,
    ) async {
      final seekSignal = ValueNotifier<int>(0);
      addTearDown(seekSignal.dispose);
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, seekListenable: seekSignal),
      );
      await tester.pump();
      expect(_anchorIndex(tester), 1);

      _sendScroll(tester, 70);
      await tester.pump();
      expect(_anchorIndex(tester), 2);

      await tester.pump(const Duration(milliseconds: 1801));
      expect(_anchorIndex(tester), 1);
      await tester.pump(const Duration(milliseconds: 400));

      _sendScroll(tester, 70);
      await tester.pump();
      expect(_anchorIndex(tester), 2);
      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 3000));
      seekSignal.value += 1;
      await tester.pump();
      expect(_anchorIndex(tester), 1);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
      'document identity resets manual state and stale transition data',
      (tester) async {
        await tester.pumpWidget(
          _buildRailApp(
            document: _timedDocument,
            documentIdentity: 'qq::track-a',
          ),
        );
        await tester.pump();
        _sendScroll(tester, 70);
        await tester.pump();
        expect(_anchorIndex(tester), 2);

        await tester.pumpWidget(
          _buildRailApp(
            document: _timedDocument,
            documentIdentity: 'qq::track-b',
          ),
        );
        await tester.pump();

        expect(_anchorIndex(tester), 1);
        expect(_painter(tester).previousData, isNull);
      },
    );

    testWidgets('breathing remains low-frequency and stops when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, breathingEnabled: true),
      );
      await tester.pump(const Duration(milliseconds: 850));
      expect(_painter(tester).breathing.value, closeTo(0.25, 0.03));

      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, breathingEnabled: false),
      );
      await tester.pump();
      expect(_painter(tester).breathing.value, 0);
    });

    testWidgets('drag never becomes a seek and pending resources dispose', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onSeek: seeks.add),
      );
      await tester.pump();
      await tester.drag(find.byType(PartitaLyricRail), const Offset(0, -90));
      await tester.pump();
      expect(seeks, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('Partita host', () {
    testWidgets('loading empty error and palette fallback are isolated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPageApp(const AsyncLoading<LyricDocument>()),
      );
      expect(
        find.byKey(const ValueKey<String>('partita-lyric-loading')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _buildPageApp(const AsyncData<LyricDocument>(LyricDocument.empty())),
      );
      expect(
        find.byKey(const ValueKey<String>('partita-lyric-empty')),
        findsOneWidget,
      );
      expect(find.text('No lyrics'), findsOneWidget);

      await tester.pumpWidget(
        _buildPageApp(
          AsyncError<LyricDocument>(StateError('private'), StackTrace.empty),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('partita-lyric-error')),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);

      await tester.pumpWidget(
        _buildPageApp(
          const AsyncData<LyricDocument>(_timedDocument),
          palette: null,
        ),
      );
      await tester.pump();
      expect(find.byType(PartitaLyricRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _buildRailApp({
  required LyricDocument document,
  Size size = const Size(430, 620),
  Duration initialPosition = const Duration(milliseconds: 2500),
  ValueChanged<Duration>? onSeek,
  String? documentIdentity,
  bool breathingEnabled = false,
  Listenable? seekListenable,
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
                return PartitaLyricRail(
                  key: const ValueKey<String>('test-partita-rail'),
                  document: document,
                  documentIdentity: documentIdentity,
                  fontPreset: AppLyricFontPreset.medium,
                  enableWordByWordLyric: true,
                  palette: _palette,
                  onSeek: onSeek,
                  breathingEnabled: breathingEnabled,
                  seekListenable: seekListenable,
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
        body: PartitaLyricPage(
          emptyText: 'No lyrics',
          onSeek: null,
          palette: palette,
          breathingEnabled: false,
        ),
      ),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(PartitaLyricRail)),
  );
}

PartitaLyricPainter _painter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey<String>('partita-lyric-painter')),
          )
          .painter!
      as PartitaLyricPainter;
}

PartitaLyricPaintLine _activeLine(PartitaLyricRenderData data) {
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
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: tester.getCenter(find.byType(PartitaLyricRail)),
      scrollDelta: Offset(0, deltaY),
      kind: PointerDeviceKind.mouse,
    ),
  );
}

class _TestPositionController extends Notifier<Duration> {
  _TestPositionController([this.initialPosition = Duration.zero]);

  final Duration initialPosition;

  @override
  Duration build() => initialPosition;

  void update(Duration value) => state = value;
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
    LyricLine(start: Duration(seconds: 6), text: 'last line'),
  ],
);

const _offsetDocument = LyricDocument(
  offset: 500,
  lines: <LyricLine>[
    LyricLine(start: Duration.zero, end: Duration(seconds: 1), text: 'clamped'),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: 'offset seek',
    ),
  ],
);

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
  group('Partita painter state', () {
    test('resolves bounded waiting active and passed intervals', () {
      const start = Duration(seconds: 2);
      const end = Duration(seconds: 3);
      const lookahead = Duration(milliseconds: 150);

      expect(
        resolvePartitaTimingState(
          timelinePosition: const Duration(milliseconds: 1849),
          start: start,
          end: end,
          lookahead: lookahead,
        ),
        PartitaTimingState.waiting,
      );
      expect(
        resolvePartitaTimingState(
          timelinePosition: const Duration(milliseconds: 1850),
          start: start,
          end: end,
          lookahead: lookahead,
        ),
        PartitaTimingState.active,
      );
      expect(
        resolvePartitaTimingState(
          timelinePosition: const Duration(milliseconds: 3001),
          start: start,
          end: end,
          lookahead: lookahead,
        ),
        PartitaTimingState.passed,
      );
      expect(
        resolvePartitaEntryProgress(
          timelinePosition: const Duration(milliseconds: 1925),
          start: start,
          lookahead: lookahead,
        ),
        closeTo(0.5, 0.001),
      );
      expect(
        resolvePartitaPassedProgress(
          timelinePosition: const Duration(milliseconds: 3250),
          end: end,
        ),
        closeTo(0.5, 0.001),
      );
      expect(
        resolvePartitaPassedProgress(
          timelinePosition: const Duration(seconds: 8),
          end: end,
        ),
        1,
      );
    });

    testWidgets('renders one source line as timed chunks and words', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();

      final data = _painter(tester).data;
      final layout = data.layout!;
      expect(layout.sourceLineIndex, 1);
      expect(layout.sourceLine.text, '你 好，你');
      expect(layout.columns, hasLength(1));
      expect(layout.chunks, hasLength(3));
      expect(
        layout.chunks
            .expand((chunk) => chunk.units)
            .map((unit) => unit.text)
            .join(),
        layout.sourceLine.text,
      );
      expect(data.fineTimingEnabled, isTrue);
      expect(
        data.chunks
            .expand((chunk) => chunk.words)
            .expand((word) => word.layout.word.sourceTokenIndexes),
        <int>[0, 1, 2, 3],
      );
      expect(data.auxiliaryPainter?.text?.toPlainText(), 'translated active');
      expect(layout.chunks.map((chunk) => chunk.guide.side.name), <String>[
        'left',
        'right',
        'left',
      ]);
    });

    testWidgets(
      'invalid timing keeps chunks but uses line-level active state',
      (tester) async {
        const document = LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration.zero,
              end: Duration(seconds: 2),
              text: 'repeat repeat again',
              tokens: <LyricToken>[
                LyricToken(
                  text: 'repeat',
                  startOffset: Duration.zero,
                  duration: Duration(milliseconds: 700),
                ),
                LyricToken(
                  text: ' ',
                  startOffset: Duration(milliseconds: 700),
                  duration: Duration.zero,
                ),
                LyricToken(
                  text: 'repeat',
                  startOffset: Duration(milliseconds: 700),
                  duration: Duration(milliseconds: 500),
                ),
                LyricToken(
                  text: ' ',
                  startOffset: Duration(milliseconds: 1200),
                  duration: Duration(milliseconds: 50),
                ),
                LyricToken(
                  text: 'again',
                  startOffset: Duration(milliseconds: 1250),
                  duration: Duration(milliseconds: 500),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          _buildRailApp(document: document, initialPosition: Duration.zero),
        );
        await tester.pump();

        final data = _painter(tester).data;
        expect(data.layout?.units, hasLength(3));
        expect(data.layout?.chunks.length, greaterThan(1));
        expect(data.layout?.hasFineTiming, isFalse);
        expect(data.fineTimingEnabled, isFalse);
        expect(
          data.layout!.displayWords.every((word) => !word.isTimed),
          isTrue,
        );
      },
    );
    testWidgets('reserves scaled two-line auxiliary text below chunks', (
      tester,
    ) async {
      const document = LyricDocument(
        lines: <LyricLine>[
          LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 4),
            text: 'main words stay above',
            translation:
                'a deliberately long translated subtitle that wraps onto two lines',
          ),
        ],
      );
      await tester.pumpWidget(
        _buildRailApp(
          document: document,
          size: const Size(260, 240),
          textScaler: const TextScaler.linear(2),
          initialPosition: const Duration(seconds: 1),
        ),
      );
      await tester.pump();

      final data = _painter(tester).data;
      expect(data.auxiliaryPainter?.maxLines, 2);
      expect(
        data.layout!.visualBounds.bottom,
        lessThanOrEqualTo(data.auxiliaryOffset!.dy),
      );
    });
  });

  group('Partita repaint isolation', () {
    testWidgets('same-line ticks repaint without rebuilding or text layout', (
      tester,
    ) async {
      var outerBuilds = 0;
      var structureBuilds = 0;
      var textLayouts = 0;
      var paints = 0;
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          onOuterBuild: () => outerBuilds += 1,
          onStructureBuild: () => structureBuilds += 1,
          onTextLayout: () => textLayouts += 1,
          onPaint: () => paints += 1,
        ),
      );
      await tester.pump();
      final initialOuter = outerBuilds;
      final initialStructure = structureBuilds;
      final initialTextLayouts = textLayouts;
      final initialPaints = paints;
      final data = _painter(tester).data;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 2700));
      await tester.pump();

      expect(outerBuilds, initialOuter);
      expect(structureBuilds, initialStructure);
      expect(textLayouts, initialTextLayouts);
      expect(paints, greaterThan(initialPaints));
      expect(_painter(tester).data, same(data));
    });

    testWidgets('playback crossing lines keeps a manual composition stable', (
      tester,
    ) async {
      var structureBuilds = 0;
      var textLayouts = 0;
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          onStructureBuild: () => structureBuilds += 1,
          onTextLayout: () => textLayouts += 1,
        ),
      );
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      final manualData = _painter(tester).data;
      final manualStructureBuilds = structureBuilds;
      final manualTextLayouts = textLayouts;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 4300));
      await tester.pump();

      expect(_selectedIndex(tester), 2);
      expect(_painter(tester).data, same(manualData));
      expect(structureBuilds, manualStructureBuilds);
      expect(textLayouts, manualTextLayouts);
    });

    testWidgets('crossing a line replaces only the Partita composition', (
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
      expect(_painter(tester).data.layout?.sourceLineIndex, 2);
      expect(_painter(tester).previousData, same(initialData));
      await tester.pump(const Duration(milliseconds: 320));
    });
  });

  group('Partita interaction and lifecycle', () {
    testWidgets('tap seeks the selected chunk with document offset', (
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
      final chunk = _painter(tester).data.chunks.first.layout;
      await tester.tapAt(
        tester.getTopLeft(find.byType(PartitaLyricRail)) + chunk.hitRect.center,
      );
      await tester.pump();
      expect(seeks, <Duration>[const Duration(milliseconds: 1500)]);

      await tester.pumpWidget(
        _buildRailApp(document: _offsetDocument, onSeek: null),
      );
      await tester.pump();
      final disabledChunk = _painter(tester).data.chunks.first.layout;
      await tester.tapAt(
        tester.getTopLeft(find.byType(PartitaLyricRail)) +
            disabledChunk.hitRect.center,
      );
      expect(seeks, hasLength(1));
    });

    testWidgets(
      'wheel browses one-line compositions and reset follows playback',
      (tester) async {
        final seekSignal = ValueNotifier<int>(0);
        addTearDown(seekSignal.dispose);
        await tester.pumpWidget(
          _buildRailApp(document: _timedDocument, seekListenable: seekSignal),
        );
        await tester.pump();
        expect(_selectedIndex(tester), 1);

        _sendScroll(tester, 70);
        await tester.pump();
        expect(_selectedIndex(tester), 2);
        expect(_painter(tester).data.forceLineActive, isTrue);

        expect(
          resolvePartitaPaintEntry(
            forceActive: true,
            state: PartitaTimingState.active,
            timelinePosition: const Duration(milliseconds: 2500),
            start: const Duration(seconds: 4),
            lookahead: const Duration(milliseconds: 150),
          ),
          1,
        );
        await tester.pump(const Duration(milliseconds: 1801));
        expect(_selectedIndex(tester), 1);
        await tester.pump(const Duration(milliseconds: 320));

        _sendScroll(tester, 70);
        await tester.pump();
        expect(_selectedIndex(tester), 2);
        seekSignal.value += 1;
        await tester.pump();
        expect(_selectedIndex(tester), 1);
        await tester.pump(const Duration(milliseconds: 320));
      },
    );

    testWidgets('exposes one seek semantic node for the selected line', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onSeek: (_) {}),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('你 好，你\ntranslated active'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('document identity clears manual and outgoing data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          documentIdentity: 'qq::track-a',
        ),
      );
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      expect(_selectedIndex(tester), 2);

      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          documentIdentity: 'qq::track-b',
        ),
      );
      await tester.pump();

      expect(_selectedIndex(tester), 1);
      expect(_painter(tester).previousData, isNull);
    });

    testWidgets('breathing is bounded and stops when disabled', (tester) async {
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, breathingEnabled: true),
      );
      await tester.pump(const Duration(milliseconds: 1750));
      expect(_painter(tester).breathing.value, closeTo(0.25, 0.03));

      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, breathingEnabled: false),
      );
      await tester.pump();
      expect(_painter(tester).breathing.value, 0);
    });

    testWidgets('drag never seeks and pending resources dispose', (
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
    testWidgets('loading empty error and palette fallback share the canvas', (
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
      final host = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('partita-lyric-page')),
      );
      expect((host.decoration as BoxDecoration).color, isNotNull);
      expect(find.byType(PartitaLyricRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _buildRailApp({
  required LyricDocument document,
  Size size = const Size(430, 620),
  TextScaler? textScaler,
  Duration initialPosition = const Duration(milliseconds: 2500),
  ValueChanged<Duration>? onSeek,
  String? documentIdentity,
  bool breathingEnabled = false,
  Listenable? seekListenable,
  VoidCallback? onOuterBuild,
  VoidCallback? onStructureBuild,
  VoidCallback? onTextLayout,
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
                final rail = PartitaLyricRail(
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
                  debugOnTextLayout: onTextLayout,
                  debugOnPaint: onPaint,
                );
                if (textScaler == null) return rail;
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: rail,
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

int _selectedIndex(WidgetTester tester) {
  return _painter(tester).data.layout!.sourceLineIndex;
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

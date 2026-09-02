import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/cadenza_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/cadenza_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/cadenza_lyric_rail.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/cadenza_lyric_page.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cadenza painter timing', () {
    test('resolves bounded waiting active and passed intervals', () {
      const start = Duration(seconds: 2);
      const end = Duration(seconds: 3);
      const lookahead = Duration(milliseconds: 180);

      expect(
        resolveCadenzaTimingState(
          timelinePosition: const Duration(milliseconds: 1819),
          start: start,
          end: end,
          lookahead: lookahead,
        ),
        CadenzaTimingState.waiting,
      );
      expect(
        resolveCadenzaTimingState(
          timelinePosition: const Duration(milliseconds: 1820),
          start: start,
          end: end,
          lookahead: lookahead,
        ),
        CadenzaTimingState.active,
      );
      expect(
        resolveCadenzaTimingState(
          timelinePosition: const Duration(milliseconds: 3001),
          start: start,
          end: end,
          lookahead: lookahead,
        ),
        CadenzaTimingState.passed,
      );
      expect(
        resolveCadenzaEntryProgress(
          timelinePosition: const Duration(milliseconds: 1910),
          start: start,
          lookahead: lookahead,
        ),
        closeTo(0.5, 0.001),
      );
      expect(
        resolveCadenzaPassedProgress(
          timelinePosition: const Duration(milliseconds: 5500),
          end: end,
        ),
        closeTo(0.5, 0.001),
      );
      expect(
        resolveCadenzaPassedProgress(
          timelinePosition: const Duration(seconds: 8),
          end: end,
        ),
        1,
      );
    });

    test('active color mix advances and fades by reveal profile', () {
      const start = Duration(seconds: 2);
      const end = Duration(seconds: 3);
      double mix(Duration position, CadenzaRevealProfile profile) {
        return resolveCadenzaActiveMix(
          timelinePosition: position,
          start: start,
          end: end,
          revealProfile: profile,
          lineRenderEnd: const Duration(milliseconds: 3067),
        );
      }

      expect(
        mix(const Duration(milliseconds: 1999), CadenzaRevealProfile.normal),
        0,
      );
      expect(
        mix(const Duration(milliseconds: 2500), CadenzaRevealProfile.normal),
        0.5,
      );
      expect(mix(end, CadenzaRevealProfile.normal), 1);
      expect(
        mix(const Duration(milliseconds: 3400), CadenzaRevealProfile.normal),
        0.5,
      );
      expect(
        mix(const Duration(milliseconds: 3800), CadenzaRevealProfile.normal),
        0,
      );
      expect(
        mix(const Duration(milliseconds: 3060), CadenzaRevealProfile.fast),
        0.5,
      );
      expect(mix(start, CadenzaRevealProfile.instant), 1);
      expect(
        mix(const Duration(milliseconds: 3068), CadenzaRevealProfile.instant),
        0,
      );
      expect(
        resolveCadenzaActiveMix(
          timelinePosition: Duration.zero,
          start: start,
          end: end,
          revealProfile: CadenzaRevealProfile.normal,
          lineRenderEnd: end,
          forceActive: true,
        ),
        1,
      );
    });

    test('grapheme color mix consumes each measured timing slice', () {
      const line = LyricLine(
        start: Duration(seconds: 2),
        end: Duration(seconds: 4),
        text: 'abcd',
        tokens: <LyricToken>[
          LyricToken(
            startOffset: Duration.zero,
            duration: Duration(seconds: 2),
            text: 'abcd',
          ),
        ],
      );
      final fragment = _layout(line).fragments.single;
      expect(fragment.graphemes, hasLength(4));
      final first = fragment.graphemes[0].slice;
      final second = fragment.graphemes[1].slice;

      double mix(CadenzaGraphemeSlice grapheme, Duration position) {
        return resolveCadenzaGraphemeActiveMix(
          timelinePosition: position,
          grapheme: grapheme,
          revealProfile: CadenzaRevealProfile.normal,
          lineRenderEnd: line.end,
        );
      }

      expect(mix(first, const Duration(milliseconds: 2250)), 0.5);
      expect(mix(second, const Duration(milliseconds: 2250)), 0);
      expect(mix(second, const Duration(milliseconds: 2750)), 0.5);
      expect(mix(first, const Duration(milliseconds: 3500)), 0);
    });

    test('entry progress never translates a fragment', () {
      const drift = Offset(24, -16);
      for (final entry in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(
          resolveCadenzaFragmentOffset(
            entryProgress: entry,
            passedProgress: 0,
            passedDrift: drift,
          ),
          Offset.zero,
        );
      }
      expect(
        resolveCadenzaFragmentOffset(
          entryProgress: 1,
          passedProgress: 0.5,
          passedDrift: drift,
        ),
        const Offset(12, -8),
      );
    });

    test('normal short and micro lines keep bounded visible progression', () {
      const normal = LyricLine(
        start: Duration(seconds: 2),
        end: Duration(seconds: 3),
        text: 'normal line',
      );
      const short = LyricLine(
        start: Duration(seconds: 2),
        end: Duration(milliseconds: 2150),
        text: 'short line',
      );
      const micro = LyricLine(
        start: Duration(seconds: 2),
        end: Duration(milliseconds: 2050),
        text: 'micro line',
      );

      final cases =
          <
            ({
              LyricLine line,
              CadenzaTimingClass timingClass,
              Duration lookahead,
            })
          >[
            (
              line: normal,
              timingClass: CadenzaTimingClass.normal,
              lookahead: const Duration(milliseconds: 180),
            ),
            (
              line: short,
              timingClass: CadenzaTimingClass.short,
              lookahead: const Duration(milliseconds: 45),
            ),
            (
              line: micro,
              timingClass: CadenzaTimingClass.micro,
              lookahead: Duration.zero,
            ),
          ];

      for (final value in cases) {
        final layout = _layout(value.line);
        final renderEnd = resolveCadenzaLineRenderEnd(value.line)!;
        expect(layout.timingClass, value.timingClass);
        expect(resolveCadenzaLookahead(value.timingClass), value.lookahead);
        expect(
          resolveCadenzaLineOpacity(
            layout: layout,
            timelinePosition: value.line.start,
          ),
          1,
        );
        expect(
          resolveCadenzaLineOpacity(
            layout: layout,
            timelinePosition: value.line.end!,
          ),
          1,
        );
        expect(
          resolveCadenzaLineOpacity(
            layout: layout,
            timelinePosition: renderEnd,
          ),
          0,
        );

        if (value.lookahead > Duration.zero) {
          final entryStart = value.line.start - value.lookahead;
          final midpoint = entryStart + value.lookahead ~/ 2;
          expect(
            resolveCadenzaLineOpacity(
              layout: layout,
              timelinePosition: entryStart,
            ),
            0,
          );
          expect(
            resolveCadenzaLineOpacity(
              layout: layout,
              timelinePosition: midpoint,
            ),
            inExclusiveRange(0, 1),
          );
        }
      }

      expect(
        resolveCadenzaLineTransitionDuration(normal),
        const Duration(milliseconds: 300),
      );
      expect(
        resolveCadenzaLineTransitionDuration(short),
        const Duration(milliseconds: 160),
      );
      expect(resolveCadenzaLineTransitionDuration(micro), Duration.zero);
    });

    testWidgets('disabled word timing uses the stable line fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, enableWordByWordLyric: false),
      );
      await tester.pump();

      final data = _painter(tester).data;
      final fragment = data.fragments.first.layout;
      expect(data.layout?.hasFineTiming, isTrue);
      expect(data.fineTimingEnabled, isFalse);
      expect(
        resolveCadenzaTimingState(
          timelinePosition: Duration.zero,
          start: fragment.start,
          end: fragment.end,
          lookahead: const Duration(milliseconds: 180),
          forceActive: !data.fineTimingEnabled,
        ),
        CadenzaTimingState.active,
      );
      expect(
        resolveCadenzaEntryProgress(
          timelinePosition: Duration.zero,
          start: fragment.start,
          lookahead: const Duration(milliseconds: 180),
          forceActive: !data.fineTimingEnabled,
        ),
        1,
      );
    });
  });

  group('Cadenza repaint isolation', () {
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
      final initialData = _painter(tester).data;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 2700));
      await tester.pump();

      expect(outerBuilds, initialOuter);
      expect(structureBuilds, initialStructure);
      expect(textLayouts, initialTextLayouts);
      expect(paints, greaterThan(initialPaints));
      expect(_painter(tester).data, same(initialData));
    });

    testWidgets('settled text has no ambient animation repaint', (
      tester,
    ) async {
      var paints = 0;
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onPaint: () => paints += 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      final settledPaints = paints;

      await tester.pump(const Duration(seconds: 1));

      expect(paints, settledPaints);
    });

    test(
      'active fragment coverage stays stable across position ticks',
      () async {
        const line = LyricLine(
          start: Duration(seconds: 2),
          end: Duration(seconds: 4),
          text: 'steady',
          tokens: <LyricToken>[
            LyricToken(
              text: 'steady',
              startOffset: Duration.zero,
              duration: Duration(seconds: 2),
            ),
          ],
        );
        const size = Size(430, 620);
        const options = CadenzaLyricLayoutOptions(
          stageSize: size,
          textStyle: TextStyle(fontSize: 46),
        );
        final data = buildCadenzaLyricRenderData(
          size: size,
          layout: CadenzaLyricLayoutEngine.fromDocument(
            const LyricDocument(lines: <LyricLine>[line]),
          ).layoutLine(renderLineIndex: 0, options: options),
          options: options,
          auxiliaryTextStyle: const TextStyle(fontSize: 14),
          palette: _palette,
          enableWordByWordLyric: true,
          forceLineActive: false,
          timelineOffset: Duration.zero,
        );

        final first = await _paintCoverage(
          data,
          const Duration(milliseconds: 2530),
        );
        final second = await _paintCoverage(
          data,
          const Duration(milliseconds: 2580),
        );

        expect(second, orderedEquals(first));
      },
    );
    testWidgets('crossing a line replaces only the rail render data', (
      tester,
    ) async {
      var outerBuilds = 0;
      var structureBuilds = 0;
      var textLayouts = 0;
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          onOuterBuild: () => outerBuilds += 1,
          onStructureBuild: () => structureBuilds += 1,
          onTextLayout: () => textLayouts += 1,
        ),
      );
      await tester.pump();
      final initialOuter = outerBuilds;
      final initialStructure = structureBuilds;
      final initialTextLayouts = textLayouts;
      final initialData = _painter(tester).data;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 4300));
      await tester.pump();

      final painter = _painter(tester);
      expect(outerBuilds, initialOuter);
      expect(structureBuilds, initialStructure + 1);
      expect(textLayouts, greaterThan(initialTextLayouts));
      expect(painter.data, isNot(same(initialData)));
      expect(painter.data.layout?.sourceLineIndex, 2);
      expect(painter.previousData, same(initialData));
      await tester.pump(const Duration(milliseconds: 320));
    });
  });

  group('Cadenza render data', () {
    testWidgets('highlight override enters the effective render palette', (
      tester,
    ) async {
      const highlight = Color(0xff123456);
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, highlightColor: highlight),
      );
      await tester.pump();

      final data = _painter(tester).data;
      expect(data.palette.accent, highlight);
      expect(data.palette.foreground, _palette.foreground);
      final activeStyle = data.fragments.first.activePainter.text as TextSpan;
      expect(activeStyle.style?.color, highlight);
    });

    testWidgets('translation is represented by one auxiliary paint layer', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();

      final data = _painter(tester).data;
      expect(data.layout?.auxiliaryText, 'translated active');
      expect(data.auxiliaryPainter?.text?.toPlainText(), 'translated active');
      expect(
        _allPainterTexts(data).where((text) => text == 'translated active'),
        hasLength(1),
      );
      expect(
        data.fragments.map((fragment) => fragment.layout.text).join(),
        data.layout?.sourceLine.text,
      );
    });
  });

  group('Cadenza interaction and lifecycle', () {
    testWidgets('tap seeks through a hit rect with document offset only', (
      tester,
    ) async {
      final seeks = <Duration>[];
      const size = Size(430, 620);
      await tester.pumpWidget(
        _buildRailApp(
          document: _offsetDocument,
          size: size,
          initialPosition: const Duration(milliseconds: 1700),
          onSeek: seeks.add,
        ),
      );
      await tester.pump();

      final data = _painter(tester).data;
      final railOrigin = tester.getTopLeft(find.byType(CadenzaLyricRail));
      final outside = _pointOutsideHitRects(data, size);
      await tester.tapAt(railOrigin + outside);
      await tester.pump();
      expect(seeks, isEmpty);

      await tester.tapAt(
        railOrigin + data.fragments.first.layout.hitRect.center,
      );
      await tester.pump();
      expect(seeks, <Duration>[const Duration(milliseconds: 1500)]);
    });

    testWidgets('synthetic interlude fragments never seek', (tester) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(
          document: _longGapDocument,
          initialPosition: const Duration(seconds: 5),
          onSeek: seeks.add,
        ),
      );
      await tester.pump();

      final data = _painter(tester).data;
      expect(data.layout?.isInterlude, isTrue);
      expect(data.layout?.sourceLineIndex, -1);
      await tester.tapAt(
        tester.getTopLeft(find.byType(CadenzaLyricRail)) +
            data.fragments.first.layout.hitRect.center,
      );
      await tester.pump();
      expect(seeks, isEmpty);
    });

    testWidgets('wheel and vertical drag browse then return after idle', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onSeek: seeks.add),
      );
      await tester.pump();
      expect(_selectedIndex(tester), 1);

      _sendScroll(tester, 70);
      await tester.pump();
      expect(_selectedIndex(tester), 2);
      expect(_painter(tester).data.forceLineActive, isTrue);
      await tester.pump(const Duration(milliseconds: 1799));
      expect(_selectedIndex(tester), 2);
      await tester.pump(const Duration(milliseconds: 2));
      expect(_selectedIndex(tester), 1);
      await tester.pump(const Duration(milliseconds: 320));

      await tester.drag(find.byType(CadenzaLyricRail), const Offset(0, -90));
      await tester.pump();
      expect(_selectedIndex(tester), 2);
      expect(_painter(tester).data.forceLineActive, isTrue);
      expect(seeks, isEmpty);
      await tester.pump(const Duration(milliseconds: 1801));
      expect(_selectedIndex(tester), 1);
      await tester.pump(const Duration(milliseconds: 320));
    });

    testWidgets('first fragment tap after drag seeks immediately', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, onSeek: seeks.add),
      );
      await tester.pump();
      await tester.drag(find.byType(CadenzaLyricRail), const Offset(0, -90));
      await tester.pump();
      final data = _painter(tester).data;
      expect(data.layout?.sourceLineIndex, 2);

      await tester.tapAt(
        tester.getTopLeft(find.byType(CadenzaLyricRail)) +
            data.fragments.first.layout.hitRect.center,
      );
      await tester.pump();

      expect(seeks, <Duration>[const Duration(seconds: 4)]);
    });

    testWidgets('seek listenable immediately clears manual browsing', (
      tester,
    ) async {
      final seekSignal = ValueNotifier<int>(0);
      addTearDown(seekSignal.dispose);
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, seekListenable: seekSignal),
      );
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      expect(_selectedIndex(tester), 2);

      seekSignal.value += 1;
      await tester.pump();

      expect(_selectedIndex(tester), 1);
      expect(_painter(tester).data.forceLineActive, isFalse);
      expect(_painter(tester).previousData, isNull);
    });

    testWidgets('identity and content replacement discard old layouts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, documentIdentity: 'track-a'),
      );
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      final manualLayout = _painter(tester).data.layout;
      expect(manualLayout?.sourceLine.text, 'after line');

      await tester.pumpWidget(
        _buildRailApp(document: _timedDocument, documentIdentity: 'track-b'),
      );
      await tester.pump();
      final identityData = _painter(tester).data;
      expect(identityData.layout?.sourceLine.text, 'sing with me');
      expect(identityData.layout, isNot(same(manualLayout)));
      expect(identityData.forceLineActive, isFalse);
      expect(_painter(tester).previousData, isNull);

      final identityLayout = identityData.layout;
      await tester.pumpWidget(
        _buildRailApp(
          document: _replacementDocument,
          documentIdentity: 'track-b',
        ),
      );
      await tester.pump();
      final replacementData = _painter(tester).data;
      expect(replacementData.layout?.sourceLine.text, 'replacement active');
      expect(replacementData.layout, isNot(same(identityLayout)));
      expect(
        _allPainterTexts(replacementData),
        isNot(contains('sing with me')),
      );
      expect(_painter(tester).previousData, isNull);
    });

    testWidgets('pending manual reset and animation dispose without errors', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      expect(_selectedIndex(tester), 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('Cadenza page host', () {
    testWidgets('exposes loading empty and error state keys', (tester) async {
      await tester.pumpWidget(
        _buildPageApp(const AsyncLoading<LyricDocument>()),
      );
      expect(
        find.byKey(const ValueKey<String>('cadenza-lyric-page')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('cadenza-lyric-loading')),
        findsOneWidget,
      );
      expect(find.byType(CadenzaLyricRail), findsNothing);

      await tester.pumpWidget(
        _buildPageApp(const AsyncData<LyricDocument>(LyricDocument.empty())),
      );
      expect(
        find.byKey(const ValueKey<String>('cadenza-lyric-empty')),
        findsOneWidget,
      );
      expect(find.text('No lyrics'), findsOneWidget);
      expect(find.byType(CadenzaLyricRail), findsNothing);

      await tester.pumpWidget(
        _buildPageApp(
          AsyncError<LyricDocument>(StateError('private'), StackTrace.empty),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('cadenza-lyric-error')),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);
      expect(find.byType(CadenzaLyricRail), findsNothing);
    });

    testWidgets('resolves auto preset and custom highlight modes', (
      tester,
    ) async {
      const custom = Color(0xff2dd4bf);
      final cases =
          <
            ({
              AppLyricHighlightMode mode,
              AppLyricHighlightColor preset,
              int? customValue,
              Color expected,
            })
          >[
            (
              mode: AppLyricHighlightMode.auto,
              preset: AppLyricHighlightColor.sky,
              customValue: null,
              expected: _palette.accent,
            ),
            (
              mode: AppLyricHighlightMode.preset,
              preset: AppLyricHighlightColor.amber,
              customValue: null,
              expected: AppLyricHighlightColor.amber.color,
            ),
            (
              mode: AppLyricHighlightMode.custom,
              preset: AppLyricHighlightColor.sky,
              customValue: custom.toARGB32(),
              expected: custom,
            ),
          ];

      for (final value in cases) {
        await tester.pumpWidget(
          _buildPageApp(
            const AsyncData<LyricDocument>(_timedDocument),
            highlightMode: value.mode,
            highlightPreset: value.preset,
            highlightCustomColor: value.customValue,
          ),
        );
        await tester.pump();
        expect(_painter(tester).data.palette.accent, value.expected);
      }
    });
  });
}

Future<List<int>> _paintCoverage(
  CadenzaLyricRenderData data,
  Duration position,
) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final positionListenable = ValueNotifier<Duration>(position);
  final painter = CadenzaLyricPainter(
    data: data,
    previousData: null,
    position: positionListenable,
    transition: const AlwaysStoppedAnimation<double>(1),
  );
  painter.paint(canvas, data.size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    data.size.width.ceil(),
    data.size.height.ceil(),
  );
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  positionListenable.dispose();
  final rgba = bytes!.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  final coveredPixels = <int>[];
  for (var offset = 3, pixel = 0; offset < rgba.length; offset += 4, pixel++) {
    if (rgba[offset] > 0) coveredPixels.add(pixel);
  }
  return coveredPixels;
}

Widget _buildRailApp({
  required LyricDocument document,
  Size size = const Size(430, 620),
  Duration initialPosition = const Duration(milliseconds: 2500),
  bool enableWordByWordLyric = true,
  String? documentIdentity,
  Color? highlightColor,
  ValueChanged<Duration>? onSeek,
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
                return CadenzaLyricRail(
                  key: const ValueKey<String>('test-cadenza-rail'),
                  document: document,
                  documentIdentity: documentIdentity,
                  fontPreset: AppLyricFontPreset.medium,
                  enableWordByWordLyric: enableWordByWordLyric,
                  palette: _palette,
                  highlightColor: highlightColor,
                  onSeek: onSeek,
                  seekListenable: seekListenable,
                  debugOnStructureBuild: onStructureBuild,
                  debugOnTextLayout: onTextLayout,
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
  AppLyricHighlightMode highlightMode = AppLyricHighlightMode.preset,
  AppLyricHighlightColor highlightPreset = AppLyricHighlightColor.sky,
  int? highlightCustomColor,
}) {
  return ProviderScope(
    key: ValueKey<String>(
      '${highlightMode.name}-${highlightPreset.value}-$highlightCustomColor',
    ),
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestConfigController(
          highlightMode: highlightMode,
          highlightPreset: highlightPreset,
          highlightCustomColor: highlightCustomColor,
        ),
      ),
      currentLyricDocumentProvider.overrideWithValue(document),
      currentLyricRequestProvider.overrideWithValue(null),
      lyricPositionProvider.overrideWithValue(
        const Duration(milliseconds: 2500),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: CadenzaLyricPage(
          emptyText: 'No lyrics',
          onSeek: null,
          palette: _palette,
        ),
      ),
    ),
  );
}

CadenzaLineLayout _layout(LyricLine line) {
  return CadenzaLyricLayoutEngine.fromDocument(
    LyricDocument(lines: <LyricLine>[line]),
  ).layoutLine(
    renderLineIndex: 0,
    options: const CadenzaLyricLayoutOptions(
      stageSize: Size(430, 620),
      textStyle: TextStyle(fontSize: 46),
    ),
  )!;
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(CadenzaLyricRail)),
  );
}

CadenzaLyricPainter _painter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey<String>('cadenza-lyric-painter')),
          )
          .painter!
      as CadenzaLyricPainter;
}

int _selectedIndex(WidgetTester tester) {
  return _painter(tester).data.layout!.sourceLineIndex;
}

List<String> _allPainterTexts(CadenzaLyricRenderData data) {
  return <String>[
    for (final fragment in data.fragments) ...<String>[
      fragment.bodyPainter.text?.toPlainText() ?? '',
      fragment.activePainter.text?.toPlainText() ?? '',
    ],
    if (data.auxiliaryPainter != null)
      data.auxiliaryPainter!.text?.toPlainText() ?? '',
  ];
}

Offset _pointOutsideHitRects(CadenzaLyricRenderData data, Size size) {
  final candidates = <Offset>[
    const Offset(1, 1),
    Offset(size.width - 1, 1),
    Offset(1, size.height - 1),
    Offset(size.width - 1, size.height - 1),
    Offset(size.width / 2, size.height - 1),
  ];
  return candidates.firstWhere(
    (point) => data.fragments.every(
      (fragment) => !fragment.layout.hitRect.contains(point),
    ),
  );
}

void _sendScroll(WidgetTester tester, double deltaY) {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: tester.getCenter(find.byType(CadenzaLyricRail)),
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
  _TestConfigController({
    required this.highlightMode,
    required this.highlightPreset,
    required this.highlightCustomColor,
  });

  final AppLyricHighlightMode highlightMode;
  final AppLyricHighlightColor highlightPreset;
  final int? highlightCustomColor;

  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    lyricHighlightMode: highlightMode,
    lyricHighlightPreset: highlightPreset,
    lyricHighlightCustomColor: highlightCustomColor,
  );
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
      text: 'sing with me',
      translation: 'translated active',
      tokens: <LyricToken>[
        LyricToken(
          text: 'sing',
          startOffset: Duration.zero,
          duration: Duration(milliseconds: 400),
        ),
        LyricToken(
          text: ' ',
          startOffset: Duration(milliseconds: 400),
          duration: Duration(milliseconds: 100),
        ),
        LyricToken(
          text: 'with',
          startOffset: Duration(milliseconds: 500),
          duration: Duration(milliseconds: 400),
        ),
        LyricToken(
          text: ' ',
          startOffset: Duration(milliseconds: 900),
          duration: Duration(milliseconds: 100),
        ),
        LyricToken(
          text: 'me',
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

const _longGapDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 1),
      text: 'before gap',
    ),
    LyricLine(
      start: Duration(seconds: 10),
      end: Duration(seconds: 12),
      text: 'after gap',
    ),
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

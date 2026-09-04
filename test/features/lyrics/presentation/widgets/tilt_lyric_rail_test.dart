import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/tilt_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/tilt_lyric_rail.dart';

final _testPositionProvider =
    NotifierProvider<_TestPositionController, Duration>(
      _TestPositionController.new,
    );

const _palette = PlayerScenePalette(
  surface: Color(0xff15181b),
  surfaceDeep: Color(0xff090b0d),
  surfaceRaised: Color(0xff202428),
  foreground: Color(0xfff5f0e8),
  secondaryForeground: Color(0xffb8c2bd),
  accent: Color(0xff80cbc4),
  edge: Color(0xff263238),
  onAccent: Color(0xff11120f),
);

void main() {
  group('Tilt repaint isolation', () {
    testWidgets('same-line ticks repaint without rebuilding or text layout', (
      tester,
    ) async {
      var outerBuilds = 0;
      var structureBuilds = 0;
      var textLayouts = 0;
      var paints = 0;
      await tester.pumpWidget(
        _buildRailApp(
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
      final initialTextPainter =
          initialData.segments.first.graphemes.first.bodyPainter;

      _container(
        tester,
      ).read(_testPositionProvider.notifier).update(const Duration(seconds: 2));
      await tester.pump();

      final painter = _painter(tester);
      expect(outerBuilds, initialOuter);
      expect(structureBuilds, initialStructure);
      expect(textLayouts, initialTextLayouts);
      expect(paints, greaterThan(initialPaints));
      expect(painter.data, same(initialData));
      expect(
        painter.data.segments.first.graphemes.first.bodyPainter,
        same(initialTextPainter),
      );
    });

    testWidgets('crossing a line rebuilds only the Tilt render data', (
      tester,
    ) async {
      var outerBuilds = 0;
      var structureBuilds = 0;
      var textLayouts = 0;
      await tester.pumpWidget(
        _buildRailApp(
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

      _container(
        tester,
      ).read(_testPositionProvider.notifier).update(const Duration(seconds: 5));
      await tester.pump();

      final painter = _painter(tester);
      expect(outerBuilds, initialOuter);
      expect(structureBuilds, initialStructure + 1);
      expect(textLayouts, greaterThan(initialTextLayouts));
      expect(painter.data, isNot(same(initialData)));
      expect(painter.data.layout?.sourceLine.text, 'second active line');
    });

    testWidgets('document auxiliary changes invalidate cached render data', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp());
      await tester.pump();
      final initialData = _painter(tester).data;

      await tester.pumpWidget(_buildRailApp(document: _translatedDocument));
      await tester.pump();

      final updatedData = _painter(tester).data;
      expect(updatedData, isNot(same(initialData)));
      expect(updatedData.layout?.auxiliaryText, 'translated first line');
      expect(find.text('translated first line'), findsOneWidget);
    });

    testWidgets('palette changes rebuild cached paint data', (tester) async {
      await tester.pumpWidget(_buildRailApp(document: _interludeDocument));
      await tester.pump();
      final initialData = _painter(tester).data;
      const nextAccent = Color(0xffff6f61);

      await tester.pumpWidget(
        _buildRailApp(
          document: _interludeDocument,
          palette: _palette.copyWith(accent: nextAccent),
        ),
      );
      await tester.pump();

      final updatedData = _painter(tester).data;
      expect(updatedData, isNot(same(initialData)));
      expect(
        updatedData.segments
            .expand((segment) => segment.graphemes)
            .every((grapheme) => grapheme.activeColor == nextAccent),
        isTrue,
      );
    });

    testWidgets('document identity clears manual browsing state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp());
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      expect(
        _painter(tester).data.layout?.sourceLine.text,
        'second active line',
      );

      await tester.pumpWidget(
        _buildRailApp(documentIdentity: 'replacement-document'),
      );
      await tester.pump();

      expect(
        _painter(tester).data.layout?.sourceLine.text,
        'first active line',
      );
    });

    testWidgets('pending manual reset disposes without errors', (tester) async {
      await tester.pumpWidget(_buildRailApp());
      await tester.pump();
      _sendScroll(tester, 70);
      await tester.pump();
      expect(
        _painter(tester).data.layout?.sourceLine.text,
        'second active line',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
    });
  });
}

Widget _buildRailApp({
  LyricDocument document = _document,
  String documentIdentity = 'tilt-test-document',
  PlayerScenePalette palette = _palette,
  VoidCallback? onOuterBuild,
  VoidCallback? onStructureBuild,
  VoidCallback? onTextLayout,
  VoidCallback? onPaint,
}) {
  return ProviderScope(
    overrides: [
      _testPositionProvider.overrideWith(
        () => _TestPositionController(const Duration(seconds: 1)),
      ),
      lyricPositionProvider.overrideWith(
        (ref) => ref.watch(_testPositionProvider),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 430,
            height: 620,
            child: Builder(
              builder: (context) {
                onOuterBuild?.call();
                return TiltLyricRail(
                  document: document,
                  documentIdentity: documentIdentity,
                  fontPreset: AppLyricFontPreset.medium,
                  enableWordByWordLyric: true,
                  palette: palette,
                  onSeek: (_) {},
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

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(TiltLyricRail)));
}

TiltLyricPainter _painter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey<String>('tilt-lyric-painter')),
          )
          .painter!
      as TiltLyricPainter;
}

void _sendScroll(WidgetTester tester, double deltaY) {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: tester.getCenter(find.byType(TiltLyricRail)),
      scrollDelta: Offset(0, deltaY),
      kind: PointerDeviceKind.mouse,
    ),
  );
}

const _document = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 4),
      text: 'first active line',
      tokens: <LyricToken>[
        LyricToken(
          text: 'first active line',
          startOffset: Duration.zero,
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    LyricLine(
      start: Duration(seconds: 4),
      end: Duration(seconds: 8),
      text: 'second active line',
      tokens: <LyricToken>[
        LyricToken(
          text: 'second active line',
          startOffset: Duration.zero,
          duration: Duration(seconds: 4),
        ),
      ],
    ),
  ],
);

const _translatedDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 4),
      text: 'first active line',
      translation: 'translated first line',
      tokens: <LyricToken>[
        LyricToken(
          text: 'first active line',
          startOffset: Duration.zero,
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    LyricLine(
      start: Duration(seconds: 4),
      end: Duration(seconds: 8),
      text: 'second active line',
      tokens: <LyricToken>[
        LyricToken(
          text: 'second active line',
          startOffset: Duration.zero,
          duration: Duration(seconds: 4),
        ),
      ],
    ),
  ],
);

const _interludeDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration(seconds: 5),
      end: Duration(seconds: 9),
      text: 'delayed first line',
    ),
  ],
);

class _TestPositionController extends Notifier<Duration> {
  _TestPositionController([this.initialPosition = Duration.zero]);

  final Duration initialPosition;

  @override
  Duration build() => initialPosition;

  void update(Duration value) => state = value;
}

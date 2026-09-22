import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/cinema_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/cinema_lyric_rail.dart';

final _testPositionProvider =
    NotifierProvider<_TestPositionController, Duration>(
      _TestPositionController.new,
    );

const _palette = PlayerScenePalette(
  surface: Color(0xff15181b),
  surfaceDeep: Color(0xff090b0d),
  surfaceRaised: Color(0xff24282d),
  edge: Color(0xff8ad7c1),
  accent: Color(0xff35c4ff),
  foreground: Color(0xfff7f8f4),
  secondaryForeground: Color(0xffb8c2bd),
  onAccent: Color(0xff11120f),
);

void main() {
  group('Cinema lyric painter', () {
    test('clips timed text across wrapped boxes in both directions', () {
      const boxes = <Rect>[
        Rect.fromLTWH(0, 0, 40, 20),
        Rect.fromLTWH(0, 24, 40, 20),
      ];
      expect(
        resolveCinemaTokenClipRects(
          boxes: boxes,
          progress: 0.75,
          textDirection: TextDirection.ltr,
        ),
        const <Rect>[Rect.fromLTWH(0, 0, 40, 20), Rect.fromLTWH(0, 24, 20, 20)],
      );
      expect(
        resolveCinemaTokenClipRects(
          boxes: boxes,
          progress: 0.25,
          textDirection: TextDirection.rtl,
        ),
        const <Rect>[Rect.fromLTWH(20, 0, 20, 20)],
      );
    });

    testWidgets('centers the active line and builds timed accent data', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();

      final painter = _painter(tester);
      final active = _focusedLine(painter.data);
      expect(active.entry.line.text, '玻璃天台');
      expect(active.tokens, hasLength(4));
      expect(active.tokens.every((token) => token.boxes.isNotEmpty), isTrue);
      expect(active.translationPainter, isNotNull);
      expect(
        active.mainOrigin.dx + active.mainPainter.width / 2,
        closeTo(painter.data.size.width / 2, 0.01),
      );
      expect(
        active.translationOrigin!.dx + active.translationPainter!.width / 2,
        closeTo(painter.data.size.width / 2, 0.01),
      );
    });

    testWidgets('uses a full accent fallback without word timing', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRailApp(document: _lineOnlyDocument));
      await tester.pump();

      final active = _focusedLine(_painter(tester).data);
      expect(active.accentPainter, isNull);
      expect(active.tokens, isEmpty);
      expect(
        (active.mainPainter.text as TextSpan).style?.color,
        _palette.accent,
      );
    });
  });

  group('Cinema lyric repaint isolation', () {
    testWidgets('same-line ticks repaint without rebuilding structure', (
      tester,
    ) async {
      var structureBuilds = 0;
      var paints = 0;
      await tester.pumpWidget(
        _buildRailApp(
          document: _timedDocument,
          onStructureBuild: () => structureBuilds += 1,
          onPaint: () => paints += 1,
        ),
      );
      await tester.pump();
      final initialData = _painter(tester).data;
      final initialBuilds = structureBuilds;
      final initialPaints = paints;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 2900));
      await tester.pump();

      expect(_painter(tester).data, same(initialData));
      expect(structureBuilds, initialBuilds);
      expect(paints, greaterThan(initialPaints));
    });

    testWidgets('line crossing replaces the three-line stage', (tester) async {
      await tester.pumpWidget(_buildRailApp(document: _timedDocument));
      await tester.pump();
      final initialData = _painter(tester).data;

      _container(tester)
          .read(_testPositionProvider.notifier)
          .update(const Duration(milliseconds: 4100));
      await tester.pump();

      final crossed = _painter(tester);
      expect(crossed.data, isNot(same(initialData)));
      expect(_focusedLine(crossed.data).entry.line.text, '低频大厅');
      expect(crossed.previousData, same(initialData));
      await tester.pumpAndSettle();
      expect(_painter(tester).previousData, isNull);
    });
  });

  group('Cinema lyric layout', () {
    for (final size in <Size>[
      const Size(280, 240),
      const Size(390, 640),
      const Size(760, 280),
      const Size(1000, 700),
    ]) {
      testWidgets('keeps the focused text centered and separated at $size', (
        tester,
      ) async {
        tester.view.physicalSize = Size(size.width + 40, size.height + 40);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _buildRailApp(document: _longDocument, size: size),
        );
        await tester.pump();

        final data = _painter(tester).data;
        final active = _focusedLine(data);
        expect(active.mainPainter.didExceedMaxLines, isFalse);
        expect(
          active.mainOrigin.dx + active.mainPainter.width / 2,
          closeTo(data.size.width / 2, 0.01),
        );
        final before = data.lines.where((line) => line.entry.offset < 0);
        final after = data.lines.where((line) => line.entry.offset > 0);
        expect(
          before.every((line) => line.rect.bottom <= active.rect.top),
          isTrue,
        );
        expect(
          after.every((line) => line.rect.top >= active.rect.bottom),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Widget _buildRailApp({
  required LyricDocument document,
  Size size = const Size(430, 620),
  Duration initialPosition = const Duration(milliseconds: 2500),
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
            child: CinemaLyricRail(
              document: document,
              fontPreset: AppLyricFontPreset.medium,
              enableWordByWordLyric: true,
              palette: _palette,
              onSeek: null,
              debugOnStructureBuild: onStructureBuild,
              debugOnPaint: onPaint,
            ),
          ),
        ),
      ),
    ),
  );
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(CinemaLyricRail)),
  );
}

CinemaLyricPainter _painter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey<String>('cinema-lyric-painter')),
          )
          .painter!
      as CinemaLyricPainter;
}

CinemaLyricPaintLine _focusedLine(CinemaLyricRenderData data) {
  return data.lines.singleWhere((line) => line.entry.offset == 0);
}

class _TestPositionController extends Notifier<Duration> {
  _TestPositionController([this.initialPosition = Duration.zero]);

  final Duration initialPosition;

  @override
  Duration build() => initialPosition;

  void update(Duration value) => state = value;
}

const _timedDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(start: Duration.zero, end: Duration(seconds: 2), text: '城市回声'),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: '玻璃天台',
      translation: 'Glass Rooftop',
      tokens: <LyricToken>[
        LyricToken(
          text: '玻',
          startOffset: Duration.zero,
          duration: Duration(milliseconds: 400),
        ),
        LyricToken(
          text: '璃',
          startOffset: Duration(milliseconds: 400),
          duration: Duration(milliseconds: 400),
        ),
        LyricToken(
          text: '天',
          startOffset: Duration(milliseconds: 800),
          duration: Duration(milliseconds: 400),
        ),
        LyricToken(
          text: '台',
          startOffset: Duration(milliseconds: 1200),
          duration: Duration(milliseconds: 400),
        ),
      ],
    ),
    LyricLine(
      start: Duration(seconds: 4),
      end: Duration(seconds: 6),
      text: '低频大厅',
    ),
    LyricLine(start: Duration(seconds: 6), text: '信号房间'),
  ],
);

const _lineOnlyDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(start: Duration.zero, end: Duration(seconds: 2), text: '上一句'),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      text: '整句高亮',
    ),
    LyricLine(start: Duration(seconds: 4), text: '下一句'),
  ],
);

const _longDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(start: Duration.zero, end: Duration(seconds: 2), text: '上一句歌词'),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 8),
      text: '这是一句需要在狭窄屏幕上自然换行并保持完整可读的很长歌词内容',
      translation: 'A long translated line remains centered and readable.',
    ),
    LyricLine(start: Duration(seconds: 8), text: '下一句歌词'),
  ],
);

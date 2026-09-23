import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/fold_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/fold_lyric_rail.dart';

class _Clock extends Notifier<Duration> {
  @override
  Duration build() => const Duration(seconds: 9);
  void set(Duration value) => state = value;
}

final _clock = NotifierProvider<_Clock, Duration>(_Clock.new);

class _Playing extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool value) => state = value;
}

final _playing = NotifierProvider<_Playing, bool>(_Playing.new);
final _document = LyricDocument(
  lines: List.generate(
    40,
    (index) => LyricLine(
      start: Duration(seconds: index * 4),
      end: Duration(seconds: index * 4 + 4),
      text: ['城市回声', '玻璃天台', '低频大厅', '信号房间'][index % 4],
      translation: [
        'City Echoes',
        'Glass Rooftop',
        'Low Frequency Hall',
        'Signal Room',
      ][index % 4],
      tokens: [
        LyricToken(
          text: ['城市回声', '玻璃天台', '低频大厅', '信号房间'][index % 4],
          startOffset: Duration.zero,
          duration: const Duration(seconds: 4),
        ),
      ],
    ),
  ),
);

Widget _app({
  LyricDocument? document,
  VoidCallback? build,
  VoidCallback? layout,
  VoidCallback? paint,
  ValueChanged<Duration>? seek,
  Listenable? revision,
  bool reduced = false,
  bool wordHighlight = true,
  double textScale = 1,
  Size size = const Size(390, 600),
  TextDirection direction = TextDirection.ltr,
  Color? background,
}) => ProviderScope(
  overrides: [
    lyricPositionProvider.overrideWith((ref) => ref.watch(_clock)),
    lyricPlaybackActiveProvider.overrideWith((ref) => ref.watch(_playing)),
  ],
  child: MaterialApp(
    theme: ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'FoldPreview',
        fontFamilyFallback: ['FoldCjk'],
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: reduced,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox.fromSize(
            size: size,
            child: RepaintBoundary(
              key: const ValueKey('fold-capture'),
              child: ColoredBox(
                color: background ?? Colors.transparent,
                child: FoldLyricRail(
                  document: document ?? _document,
                  fontPreset: AppLyricFontPreset.medium,
                  enableWordByWordLyric: wordHighlight,
                  palette: classicPlayerScenePaletteFallback,
                  onSeek: seek,
                  seekListenable: revision,
                  debugOnStructureBuild: build,
                  debugOnTextLayout: layout,
                  debugOnPaint: paint,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
FoldLyricPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('fold-lyric-painter')),
            )
            .painter!
        as FoldLyricPainter;
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FoldLyricRail)));
void _time(WidgetTester tester, int milliseconds) => _container(
  tester,
).read(_clock.notifier).set(Duration(milliseconds: milliseconds));

void main() {
  testWidgets(
    'samples and folding frames repaint without rebuilding or laying out text',
    (tester) async {
      var builds = 0;
      var layouts = 0;
      var paints = 0;
      await tester.pumpWidget(
        _app(
          build: () => builds++,
          layout: () => layouts++,
          paint: () => paints++,
        ),
      );
      final initial = (builds, layouts);
      final initialPaints = paints;
      for (var i = 1; i <= 10; i++) {
        _time(tester, 9000 + i * 20);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect((builds, layouts), initial);
      expect(paints, greaterThan(initialPaints));
      _time(tester, 11900);
      await tester.pump();
      _time(tester, 12000);
      await tester.pump();
      expect(_painter(tester).anchor, 3);
      expect(_painter(tester).focus, closeTo(2, 0.001));
      final boundary = (builds, layouts);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_painter(tester).focus, greaterThan(2));
      expect((builds, layouts), boundary);
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).focus, 3);
    },
  );

  testWidgets(
    'folded text remains seekable and seeks snap with document offset',
    (tester) async {
      final seeks = <Duration>[];
      final revision = ChangeNotifier();
      final document = LyricDocument(lines: _document.lines, offset: 500);
      await tester.pumpWidget(
        _app(document: document, seek: seeks.add, revision: revision),
      );
      final painter = _painter(tester);
      Offset? foldedPoint;
      for (var y = 5.0; y < 480; y += 2) {
        final point = Offset(195, y);
        if (painter.rowAt(point)?.entry.index == 3) {
          foldedPoint = point;
          break;
        }
      }
      expect(foldedPoint, isNotNull);
      await tester.tapAt(
        tester.getTopLeft(find.byType(FoldLyricRail)) + foldedPoint!,
      );
      expect(seeks, [const Duration(milliseconds: 11500)]);
      revision.notifyListeners();
      _time(tester, 11600);
      await tester.pump();
      expect(_painter(tester).anchor, 3);
      expect(_painter(tester).motion.value, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      revision.dispose();
    },
  );

  testWidgets(
    'manual browse returns to playback and retired paragraphs are disposed',
    (tester) async {
      await tester.pumpWidget(_app());
      final oldRow = _painter(tester).rows.first;
      await tester.drag(find.byType(FoldLyricRail), const Offset(0, -170));
      await tester.pump();
      expect(_painter(tester).anchor, greaterThan(2));
      _time(tester, 80000);
      await tester.pump();
      expect(_painter(tester).anchor, lessThan(20));
      await tester.pump(const Duration(seconds: 3));
      expect(_painter(tester).anchor, 20);
      expect(_painter(tester).rows.length, lessThanOrEqualTo(7));
      expect(oldRow.base.debugDisposed, isTrue);
      await tester.pumpWidget(
        _app(
          document: const LyricDocument(
            lines: [LyricLine(start: Duration.zero, text: 'replacement')],
          ),
        ),
      );
      expect(_painter(tester).rows.single.entry.line.text, 'replacement');
      final last = _painter(tester).rows.single;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(last.base.debugDisposed, isTrue);
    },
  );

  testWidgets(
    'pause and reduced motion settle the fold while lyrics still update',
    (tester) async {
      await tester.pumpWidget(_app());
      _time(tester, 11900);
      await tester.pump();
      _time(tester, 12000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_painter(tester).motion.value, lessThan(1));
      _container(tester).read(_playing.notifier).set(false);
      await tester.pump();
      expect(_painter(tester).motion.value, 1);
      await tester.pumpWidget(_app(reduced: true));
      _container(tester).read(_playing.notifier).set(true);
      _time(tester, 15900);
      await tester.pump();
      _time(tester, 16000);
      await tester.pump();
      expect(_painter(tester).anchor, 4);
      expect(_painter(tester).motion.value, 1);
    },
  );

  testWidgets(
    'long RTL lines, large text, missing timing and empty documents are supported',
    (tester) async {
      final document = LyricDocument(
        lines: [
          LyricLine(
            start: Duration.zero,
            text: List.filled(15, 'مرحبا بالعالم').join(' '),
            translation: 'A long translation that wraps on a narrow screen',
          ),
        ],
      );
      await tester.pumpWidget(
        _app(
          document: document,
          size: const Size(280, 250),
          textScale: 1.8,
          direction: TextDirection.rtl,
          wordHighlight: false,
        ),
      );
      expect(_painter(tester).rows.single.base.width, lessThanOrEqualTo(216));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_app(document: const LyricDocument(lines: [])));
      expect(_painter(tester).rows, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lyric surface preserves transparency outside glyphs', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('fold-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var transparent = 0;
        for (var i = 3; i < data.lengthInBytes; i += 4) {
          if (data.getUint8(i) == 0) transparent++;
        }
        expect(transparent / (image.width * image.height), greaterThan(0.80));
        expect(data.getUint8(3), 0);
      } finally {
        image.dispose();
      }
    });
  });

  testWidgets(
    'export fold motion preview',
    (tester) async {
      await tester.runAsync(() async {
        await (FontLoader('FoldPreview')..addFont(
              File(
                'test/assets/fonts/Roboto-Regular.ttf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
        await (FontLoader('FoldCjk')..addFont(
              File(
                'test/assets/fonts/DroidSansFallback-PreviewSubset.ttf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
        await Directory('build/fold-preview').create(recursive: true);
      });
      await tester.pumpWidget(_app(background: const Color(0xff171b24)));
      _time(tester, 11900);
      await tester.pump();
      for (var frame = 0; frame < 75; frame++) {
        if (frame == 15) _time(tester, 12000);
        if (frame > 15) _time(tester, 12000 + (frame - 15) * 33);
        await tester.pump(const Duration(milliseconds: 33));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('fold-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              'build/fold-preview/frame-${frame.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
    },
    skip: !const bool.fromEnvironment('EXPORT_FOLD_PREVIEW'),
  );
}

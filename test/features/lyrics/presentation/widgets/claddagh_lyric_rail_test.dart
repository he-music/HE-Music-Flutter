import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/claddagh_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/claddagh_lyric_rail.dart';

// Tests observe the real painter rather than mirroring its geometry.
class _Position extends Notifier<Duration> {
  @override
  Duration build() => const Duration(seconds: 1);
  void set(Duration value) => state = value;
}

final _position = NotifierProvider<_Position, Duration>(_Position.new);
final _document = LyricDocument(
  lines: List.generate(
    100,
    (i) => LyricLine(
      start: Duration(seconds: i * 4),
      end: Duration(seconds: (i + 1) * 4),
      text: i == 0 ? 'Time moves with every word' : 'The wheel carries line $i',
      translation: 'A moment in the music',
      tokens: [
        LyricToken(
          text: i == 0
              ? 'Time moves with every word'
              : 'The wheel carries line $i',
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
  ValueChanged<Duration>? seek,
  Listenable? seekListenable,
  Size size = const Size(390, 600),
}) => ProviderScope(
  overrides: [
    lyricPositionProvider.overrideWith((ref) => ref.watch(_position)),
    lyricPlaybackActiveProvider.overrideWith((ref) => true),
  ],
  child: MaterialApp(
    theme: ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'CladdaghPreview',
      ),
    ),
    home: Scaffold(
      backgroundColor: const Color(0xff101b14),
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CladdaghLyricRail(
            document: document ?? _document,
            fontPreset: AppLyricFontPreset.medium,
            enableWordByWordLyric: true,
            palette: classicPlayerScenePaletteFallback,
            onSeek: seek,
            seekListenable: seekListenable,
            debugOnStructureBuild: build,
            debugOnTextLayout: layout,
          ),
        ),
      ),
    ),
  ),
);
CladdaghLyricPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('claddagh-lyric-painter')),
            )
            .painter!
        as CladdaghLyricPainter;
_Position _clock(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(CladdaghLyricRail)),
).read(_position.notifier);

void main() {
  testWidgets(
    'samples and spring frames repaint without structure or text layout',
    (tester) async {
      var builds = 0;
      var layouts = 0;
      await tester.pumpWidget(
        _app(build: () => builds++, layout: () => layouts++),
      );
      final initial = (builds, layouts);
      for (var i = 1; i <= 20; i++) {
        _clock(tester).set(Duration(milliseconds: 1000 + i * 20));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect((builds, layouts), initial);
      _clock(tester).set(const Duration(milliseconds: 3900));
      await tester.pump();
      _clock(tester).set(const Duration(milliseconds: 4000));
      await tester.pump();
      expect(_painter(tester).anchor, 1);
      final boundary = (builds, layouts);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_painter(tester).motion.value, lessThan(1));
      expect((builds, layouts), boundary);
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).motion.value, 1);
    },
  );

  testWidgets('seek, bounded window, replaced document and retired resources', (
    tester,
  ) async {
    final seeks = <Duration>[];
    final revision = ChangeNotifier();
    await tester.pumpWidget(_app(seek: seeks.add, seekListenable: revision));
    final oldRow = _painter(tester).rows.first;
    final rail = tester.getTopLeft(find.byType(CladdaghLyricRail));
    await tester.tapAt(rail + _painter(tester).geometry.point(0));
    expect(seeks, [Duration.zero]);
    _clock(tester).set(const Duration(seconds: 200));
    await tester.pump();
    expect(_painter(tester).rows.length, lessThanOrEqualTo(4));
    expect(_painter(tester).anchor, 50);
    expect(oldRow.glyphs.first.debugDisposed, isTrue);
    revision.notifyListeners();
    await tester.pump();
    expect(_painter(tester).motion.value, 1);
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
    expect(last.glyphs.first.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
    revision.dispose();
  });

  testWidgets(
    'manual browsing returns to latest playback and short seeks snap',
    (tester) async {
      final seek = ChangeNotifier();
      await tester.pumpWidget(_app(seekListenable: seek));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(CladdaghLyricRail)),
          scrollDelta: const Offset(0, 90),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();
      expect(_painter(tester).anchor, 1);
      _clock(tester).set(const Duration(seconds: 12));
      await tester.pump();
      expect(_painter(tester).anchor, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(_painter(tester).anchor, 3);
      _clock(tester).set(const Duration(milliseconds: 15900));
      await tester.pump();
      seek.notifyListeners();
      _clock(tester).set(const Duration(milliseconds: 16000));
      await tester.pump();
      expect(_painter(tester).anchor, 4);
      expect(_painter(tester).motion.value, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      seek.dispose();
    },
  );

  testWidgets(
    'wheel distance is independent of event count and ignores subthreshold structure updates',
    (tester) async {
      var builds = 0;
      var layouts = 0;
      await tester.pumpWidget(
        _app(build: () => builds++, layout: () => layouts++),
      );
      void scroll(double delta) => tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(CladdaghLyricRail)),
          scrollDelta: Offset(0, delta),
          kind: PointerDeviceKind.mouse,
        ),
      );
      final initial = (builds, layouts);
      for (var i = 0; i < 29; i++) {
        scroll(3);
        await tester.pump();
      }
      expect((builds, layouts), initial);
      expect(_painter(tester).anchor, 0);
      scroll(3);
      await tester.pump();
      expect(_painter(tester).anchor, 1);
      for (var i = 0; i < 60; i++) {
        scroll(3);
      }
      await tester.pump();
      expect(_painter(tester).anchor, 3);
      await tester.pump(const Duration(seconds: 3));
      scroll(270);
      await tester.pump();
      expect(_painter(tester).anchor, 3);
      scroll(80);
      scroll(-10);
      await tester.pump();
      expect(_painter(tester).anchor, 3);
      scroll(-80);
      await tester.pump();
      expect(_painter(tester).anchor, 2);
      scroll(80);
      await tester.pump(const Duration(seconds: 3));
      scroll(10);
      await tester.pump();
      expect(_painter(tester).anchor, 0);
      scroll(9000);
      await tester.pump();
      expect(_painter(tester).anchor, 5);
      expect(_painter(tester).rows.length, lessThanOrEqualTo(4));
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'slow active drag keeps manual anchor until ${cancel ? "cancel" : "release"} and idle',
      (tester) async {
        await tester.pumpWidget(_app());
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CladdaghLyricRail)),
        );
        await gesture.moveBy(const Offset(0, -25));
        await tester.pump();
        await gesture.moveBy(const Offset(0, -65));
        await tester.pump();
        expect(_painter(tester).anchor, 1);
        _clock(tester).set(const Duration(seconds: 12));
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          await gesture.moveBy(const Offset(0, -2));
          await tester.pump(const Duration(seconds: 1));
          expect(_painter(tester).anchor, 1);
        }
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pump(const Duration(seconds: 2));
        expect(_painter(tester).anchor, 1);
        await tester.pump(const Duration(milliseconds: 600));
        expect(_painter(tester).anchor, 3);
      },
    );
  }

  testWidgets('long Latin and CJK arcs fit portrait and landscape stages', (
    tester,
  ) async {
    for (final size in [const Size(320, 500), const Size(700, 230)]) {
      await tester.pumpWidget(
        _app(
          size: size,
          document: LyricDocument(
            lines: [
              LyricLine(
                start: Duration.zero,
                text: List.filled(40, 'long lyrics 回环歌词').join(' '),
                romanization: 'alternate text',
              ),
            ],
          ),
        ),
      );
      final row = _painter(tester).rows.single;
      expect(row.subtitle!.width, lessThanOrEqualTo(size.width - 48));
      expect(row.glyphs, isNotEmpty);
      expect(row.angles.last - row.angles.first, lessThanOrEqualTo(4.25));
      expect(row.subtitle, isNotNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'offset applies to orbit timing and seeks, gaps remain nonseekable',
    (tester) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _app(
          document: const LyricDocument(
            offset: 500,
            lines: [
              LyricLine(
                start: Duration(seconds: 4),
                end: Duration(seconds: 6),
                text: 'AB',
                tokens: [
                  LyricToken(
                    text: 'AB',
                    startOffset: Duration.zero,
                    duration: Duration(seconds: 2),
                  ),
                ],
              ),
              LyricLine(
                start: Duration(seconds: 12),
                end: Duration(seconds: 14),
                text: 'CD',
              ),
            ],
          ),
          seek: seeks.add,
        ),
      );
      _clock(tester).set(const Duration(milliseconds: 4000));
      await tester.pump();
      final painter = _painter(tester);
      final row = painter.rows.firstWhere(
        (row) => row.entry.index == painter.activeIndex,
      );
      expect(row.entry.line.text, 'AB');
      expect(
        row.wordOffset(const Duration(milliseconds: 4500)),
        closeTo((row.angles[0] + row.angles[1]) / 2, 0.001),
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(CladdaghLyricRail)) +
            painter.geometry.point(0),
      );
      expect(seeks, [const Duration(milliseconds: 3500)]);
      _clock(tester).set(const Duration(seconds: 8));
      await tester.pump();
      final gap = _painter(tester);
      expect(gap.rows.any((row) => row.entry.isInterlude), isTrue);
      await tester.tapAt(
        tester.getTopLeft(find.byType(CladdaghLyricRail)) +
            gap.geometry.point(0),
      );
      expect(seeks, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal Latin and CJK lyrics retain readable foreground scale and measured spacing',
    (tester) async {
      for (final text in ['The wheel carries line 4', '回环流转每一个字都随音乐起舞']) {
        for (final size in [const Size(320, 500), const Size(700, 230)]) {
          await tester.pumpWidget(
            _app(
              size: size,
              document: LyricDocument(
                lines: [
                  LyricLine(
                    start: Duration.zero,
                    end: const Duration(seconds: 8),
                    text: text,
                  ),
                ],
              ),
            ),
          );
          final painter = _painter(tester);
          final row = painter.rows.single;
          expect(row.glyphScale, greaterThan(0.50));
          for (var i = 1; i < row.glyphs.length; i++) {
            final measuredAdvance =
                (row.angles[i] - row.angles[i - 1]) * painter.geometry.radius;
            final foregroundWidth =
                (row.glyphs[i].width + row.glyphs[i - 1].width) /
                2 *
                1.55 *
                row.glyphScale;
            expect(measuredAdvance, greaterThanOrEqualTo(foregroundWidth));
          }
        }
      }
    },
  );
}

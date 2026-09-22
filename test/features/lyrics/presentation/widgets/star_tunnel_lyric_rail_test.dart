import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/star_tunnel_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/star_tunnel_lyric_rail.dart';

class _Position extends Notifier<Duration> {
  @override
  Duration build() => const Duration(seconds: 1);
  void set(Duration value) => state = value;
}

class _Playing extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool value) => state = value;
}

final _position = NotifierProvider<_Position, Duration>(_Position.new);
final _playing = NotifierProvider<_Playing, bool>(_Playing.new);
final _document = LyricDocument(
  lines: List.generate(
    100,
    (i) => LyricLine(
      start: Duration(seconds: i * 4),
      end: Duration(seconds: (i + 1) * 4),
      text: 'Across the stars $i',
      translation: 'Into the light',
      tokens: const [
        LyricToken(
          text: 'Across the stars',
          startOffset: Duration.zero,
          duration: Duration(seconds: 4),
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
  bool disabled = false,
  bool ticker = true,
  Size size = const Size(390, 600),
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    lyricPositionProvider.overrideWith((ref) => ref.watch(_position)),
    lyricPlaybackActiveProvider.overrideWith((ref) => ref.watch(_playing)),
  ],
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disabled,
        textScaler: TextScaler.linear(textScale),
      ),
      child: TickerMode(
        enabled: ticker,
        child: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: StarTunnelLyricRail(
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
  ),
);
final _paintFinder = find.byKey(const ValueKey('star-tunnel-lyric-painter'));
StarTunnelLyricPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paintFinder).painter! as StarTunnelLyricPainter;
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(StarTunnelLyricRail)));
void _set(WidgetTester tester, int millis) => _container(
  tester,
).read(_position.notifier).set(Duration(milliseconds: millis));
Future<void> _crossLine(WidgetTester tester) async {
  _set(tester, 3900);
  await tester.pump();
  _set(tester, 4000);
  await tester.pump();
}

void main() {
  testWidgets('progress and flight frames repaint without layout or rebuild', (
    tester,
  ) async {
    var builds = 0;
    var layouts = 0;
    await tester.pumpWidget(
      _app(build: () => builds++, layout: () => layouts++),
    );
    final initialBuilds = builds;
    final initialLayouts = layouts;
    for (var i = 1; i <= 10; i++) {
      _set(tester, 1000 + i * 40);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(builds, initialBuilds);
    expect(layouts, initialLayouts);
    await _crossLine(tester);
    expect(_painter(tester).anchor, 1);
    expect(_painter(tester).depthOffset, greaterThan(0));
    final transitionBuilds = builds;
    final transitionLayouts = layouts;
    final startBounds = _painter(tester).boundsFor(
      _painter(tester).rows.firstWhere((r) => r.entry.index == 1),
      tester.getSize(_paintFinder),
    );
    await tester.pump(const Duration(milliseconds: 180));
    final moving = _painter(tester);
    final movedBounds = moving.boundsFor(
      moving.rows.firstWhere((r) => r.entry.index == 1),
      tester.getSize(_paintFinder),
    );
    expect(movedBounds.width, greaterThan(startBounds.width));
    expect(movedBounds.center.dy, greaterThan(startBounds.center.dy));
    expect(builds, transitionBuilds);
    expect(layouts, transitionLayouts);
    expect(moving.rows.length, lessThanOrEqualTo(6));
    await tester.pump(const Duration(milliseconds: 700));
    expect(_painter(tester).depthOffset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'distant lines shrink without overlapping and tap seeks with offset',
    (tester) async {
      Duration? seek;
      await tester.pumpWidget(
        _app(
          document: LyricDocument(lines: _document.lines, offset: 300),
          seek: (value) => seek = value,
        ),
      );
      final painter = _painter(tester);
      final size = tester.getSize(_paintFinder);
      final visible = painter.rows
          .where(
            (r) =>
                r.entry.index >= painter.anchor &&
                r.entry.index < painter.anchor + 4,
          )
          .toList();
      for (var i = 1; i < visible.length; i++) {
        final nearer = painter.boundsFor(visible[i - 1], size);
        final farther = painter.boundsFor(visible[i], size);
        expect(farther.width, lessThan(nearer.width));
        expect(farther.bottom, lessThan(nearer.top));
      }
      final next = visible[1];
      await tester.tapAt(
        tester.getTopLeft(_paintFinder) + painter.boundsFor(next, size).center,
      );
      expect(seek, const Duration(milliseconds: 3700));
    },
  );

  testWidgets('pause and reduced motion settle an in-flight line', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _crossLine(tester);
    expect(_painter(tester).depthOffset, greaterThan(0));
    _container(tester).read(_playing.notifier).set(false);
    await tester.pump();
    expect(_painter(tester).depthOffset, 0);
    _container(tester).read(_playing.notifier).set(true);
    await tester.pump();
    _set(tester, 7900);
    await tester.pump();
    _set(tester, 8000);
    await tester.pump();
    expect(_painter(tester).depthOffset, greaterThan(0));
    await tester.pumpWidget(_app(disabled: true));
    expect(_painter(tester).depthOffset, 0);
    _set(tester, 11900);
    await tester.pump();
    _set(tester, 12000);
    await tester.pump();
    expect(_painter(tester).anchor, 3);
    expect(_painter(tester).depthOffset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seek revisions and large position jumps snap without flying', (
    tester,
  ) async {
    final revision = ChangeNotifier();
    addTearDown(revision.dispose);
    await tester.pumpWidget(_app(seekListenable: revision));
    _set(tester, 3900);
    await tester.pump();
    revision.notifyListeners();
    _set(tester, 4000);
    await tester.pump();
    expect(_painter(tester).anchor, 1);
    expect(_painter(tester).depthOffset, 0);
    _set(tester, 200000);
    await tester.pump();
    expect(_painter(tester).anchor, 50);
    expect(_painter(tester).depthOffset, 0);
    _set(tester, 1000);
    await tester.pump();
    expect(_painter(tester).anchor, 0);
    expect(_painter(tester).depthOffset, 0);
  });

  testWidgets(
    'wheel browsing returns to playback and document replacement resets it',
    (tester) async {
      await tester.pumpWidget(_app());
      Future<void> scroll() async {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(_paintFinder),
            scrollDelta: const Offset(0, 180),
          ),
        );
        await tester.pump();
      }

      await scroll();
      expect(_painter(tester).anchor, 2);
      await tester.pump(const Duration(milliseconds: 2600));
      expect(_painter(tester).anchor, 0);
      await scroll();
      expect(_painter(tester).anchor, 2);
      await tester.pumpWidget(
        _app(
          document: const LyricDocument(
            lines: [
              LyricLine(
                start: Duration.zero,
                end: Duration(seconds: 10),
                text: 'A new sky',
              ),
            ],
          ),
        ),
      );
      expect(_painter(tester).anchor, 0);
      expect(_painter(tester).rows.single.entry.line.text, 'A new sky');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ordinary LRC, large type and small viewport remain bounded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        size: const Size(280, 180),
        textScale: 1.8,
        document: LyricDocument(
          lines: List.generate(
            5,
            (i) => LyricLine(
              start: Duration(seconds: i * 4),
              end: Duration(seconds: (i + 1) * 4),
              text: 'A very long lyric line ' * 12,
              translation: 'A long translation ' * 8,
            ),
          ),
        ),
      ),
    );
    final painter = _painter(tester);
    expect(painter.rows.first.base.didExceedMaxLines, isTrue);
    expect(painter.rows.first.tokens.any((token) => token.hasTiming), isFalse);
    final size = tester.getSize(_paintFinder);
    final visible = painter.visibleRows(size).toList();
    for (var i = 1; i < visible.length; i++) {
      expect(
        painter.boundsFor(visible[i], size).bottom,
        lessThan(painter.boundsFor(visible[i - 1], size).top),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(document: const LyricDocument(lines: [])));
    expect(_painter(tester).rows, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden ticker settles motion and disposal releases callbacks', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _crossLine(tester);
    await tester.pumpWidget(_app(ticker: false));
    expect(_painter(tester).depthOffset, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}

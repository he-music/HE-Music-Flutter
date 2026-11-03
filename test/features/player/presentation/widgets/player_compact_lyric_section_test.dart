import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/single_line_lyric.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_compact_lyric_section.dart';

final _testPositionProvider =
    NotifierProvider<_TestPositionController, Duration>(
      _TestPositionController.new,
    );

final _testDocumentProvider =
    NotifierProvider<_TestDocumentController, LyricDocument>(
      _TestDocumentController.new,
    );

void main() {
  for (final updateDocument in [false, true]) {
    final source = updateDocument ? 'document' : 'progress';
    testWidgets('remounting compact lyric flushes inactive $source safely', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_TestConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          currentLyricDocumentProvider.overrideWith(
            (ref) => AsyncData(ref.watch(_testDocumentProvider)),
          ),
          lyricPositionProvider.overrideWith(
            (ref) => ref.watch(_testPositionProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      Widget app({required bool showLyric}) {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) => showLyric
                    ? PlayerCompactLyricSection(onTap: _noop)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(app(showLyric: true));
      expect(find.bySemanticsLabel('第一句'), findsOneWidget);
      await tester.pumpWidget(app(showLyric: false));

      if (updateDocument) {
        container
            .read(_testDocumentProvider.notifier)
            .update(
              const LyricDocument(
                lines: [LyricLine(start: Duration.zero, text: '新歌曲歌词')],
              ),
            );
      } else {
        container
            .read(_testPositionProvider.notifier)
            .update(const Duration(seconds: 2));
      }
      await tester.pumpWidget(app(showLyric: true));

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(updateDocument ? '新歌曲歌词' : '第二句'),
        findsOneWidget,
      );
    });
  }

  testWidgets('position updates within one line do not rebuild compact lyric', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());

    final initialTapTarget = tester.widget<InkWell>(
      find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerCompactLyricSection)),
    );

    container
        .read(_testPositionProvider.notifier)
        .update(const Duration(seconds: 1));
    await tester.pump();

    expect(
      tester.widget<InkWell>(
        find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
      ),
      same(initialTapTarget),
    );
    expect(find.bySemanticsLabel('第一句'), findsOneWidget);
  });

  testWidgets('crossing a lyric boundary rebuilds compact lyric text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());

    final initialTapTarget = tester.widget<InkWell>(
      find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerCompactLyricSection)),
    );

    container
        .read(_testPositionProvider.notifier)
        .update(const Duration(seconds: 2));
    await tester.pump();

    expect(
      tester.widget<InkWell>(
        find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
      ),
      isNot(same(initialTapTarget)),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('第二句'), findsOneWidget);
  });

  testWidgets(
    'explicit lyric end keeps gaps empty across forward and back seeks',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          document: const LyricDocument(
            lines: <LyricLine>[
              LyricLine(
                start: Duration.zero,
                end: Duration(seconds: 1),
                text: '第一句',
              ),
              LyricLine(start: Duration(seconds: 2), text: '第二句'),
            ],
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerCompactLyricSection)),
      );
      final positionController = container.read(_testPositionProvider.notifier);

      positionController.update(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('第一句'), findsNothing);
      expect(find.bySemanticsLabel('第二句'), findsNothing);

      positionController.update(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('第二句'), findsOneWidget);

      positionController.update(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('第一句'), findsOneWidget);
    },
  );
  for (final mode in AppLyricHighlightMode.values) {
    testWidgets('timed preview follows $mode color and live word setting', (
      tester,
    ) async {
      final config = AppConfigState.initial.copyWith(
        enableWordByWordLyric: true,
        lyricHighlightMode: mode,
        lyricHighlightPreset: AppLyricHighlightColor.emerald,
        lyricHighlightCustomColor: Colors.red.toARGB32(),
      );
      await tester.pumpWidget(
        _buildTestApp(
          document: const LyricDocument(lines: [_timedLine]),
          config: config,
        ),
      );
      await tester.pumpAndSettle();
      final expectedColor = switch (mode) {
        AppLyricHighlightMode.auto => Colors.purple,
        AppLyricHighlightMode.preset => AppLyricHighlightColor.emerald.color,
        AppLyricHighlightMode.custom => Colors.red,
      };
      expect(
        _painter(tester).highlight!.text!.style!.color!.toARGB32(),
        expectedColor.toARGB32(),
      );
      final controller =
          _container(tester).read(appConfigProvider.notifier)
              as _TestConfigController;
      controller.update(config.copyWith(enableWordByWordLyric: false));
      await tester.pump();
      expect(_painter(tester).highlight, isNull);
      expect(
        _painter(tester).base.text!.style!.color,
        Colors.white.withValues(alpha: 0.92),
      );
      controller.update(
        config.copyWith(
          lyricHighlightMode: AppLyricHighlightMode.custom,
          lyricHighlightCustomColor: Colors.orange.toARGB32(),
        ),
      );
      await tester.pump();
      expect(
        _painter(tester).highlight!.text!.style!.color!.toARGB32(),
        Colors.orange.toARGB32(),
      );
    });
  }

  for (final invalidTiming in [false, true]) {
    testWidgets(
      'untimed or invalid timing keeps white with custom color ($invalidTiming)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            config: AppConfigState.initial.copyWith(
              enableWordByWordLyric: true,
              lyricHighlightMode: AppLyricHighlightMode.custom,
              lyricHighlightCustomColor: Colors.red.toARGB32(),
            ),
            document: LyricDocument(
              lines: [
                LyricLine(
                  start: Duration.zero,
                  end: const Duration(seconds: 4),
                  text: 'Hello world',
                  tokens: invalidTiming
                      ? const [
                          LyricToken(
                            text: 'mismatched text',
                            startOffset: Duration.zero,
                            duration: Duration(seconds: 4),
                          ),
                        ]
                      : const [],
                ),
              ],
            ),
          ),
        );
        expect(_painter(tester).highlight, isNull);
        expect(
          _painter(tester).base.text!.style!.color,
          Colors.white.withValues(alpha: 0.92),
        );
      },
    );
  }

  testWidgets(
    'word samples repaint cached text without rebuilding the preview',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          document: const LyricDocument(lines: [_timedLine]),
          config: AppConfigState.initial.copyWith(enableWordByWordLyric: true),
        ),
      );
      await tester.pumpAndSettle();
      final painter = _painter(tester);
      final target = tester.widget<InkWell>(
        find.byKey(const ValueKey('player-compact-lyric-tap')),
      );
      final clock = _container(tester).read(_testPositionProvider.notifier);
      clock.update(const Duration(seconds: 3));
      await tester.pump();
      expect(_painter(tester), same(painter));
      expect(painter.position.value, const Duration(seconds: 3));
      expect(
        tester.widget<InkWell>(
          find.byKey(const ValueKey('player-compact-lyric-tap')),
        ),
        same(target),
      );
    },
  );

  testWidgets('document offset selects preview and word timeline together', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        document: const LyricDocument(
          offset: 2000,
          lines: [
            LyricLine(start: Duration.zero, text: 'Before'),
            LyricLine(start: Duration(seconds: 2), text: 'After'),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('After'), findsOneWidget);
    expect(find.bySemanticsLabel('Before'), findsNothing);
    expect(_painter(tester).documentOffset, 2000);
  });

  testWidgets('reduced motion removes cut fades while keeping the tap action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _buildTestApp(reduceMotion: true, onTap: () => taps++),
    );
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
    expect(_painter(tester).reduceMotion, isTrue);
    await tester.tap(find.byKey(const ValueKey('player-compact-lyric-tap')));
    expect(taps, 1);
    expect(tester.getSize(find.byType(PlayerCompactLyricSection)).height, 40);
  });
}

Widget _buildTestApp({
  LyricDocument document = const LyricDocument(
    lines: <LyricLine>[
      LyricLine(start: Duration.zero, text: '第一句'),
      LyricLine(start: Duration(seconds: 2), text: '第二句'),
    ],
  ),
  AppConfigState? config,
  bool reduceMotion = false,
  VoidCallback onTap = _noop,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(() => _TestConfigController(config)),
      playerAutoLyricHighlightColorProvider.overrideWith(
        (ref) async => Colors.purple,
      ),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      currentLyricDocumentProvider.overrideWithValue(
        AsyncData<LyricDocument>(document),
      ),
      lyricPositionProvider.overrideWith(
        (ref) => ref.watch(_testPositionProvider),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: PlayerCompactLyricSection(onTap: onTap)),
      ),
    ),
  );
}

class _TestConfigController extends AppConfigController {
  _TestConfigController([this.initial]);
  final AppConfigState? initial;

  @override
  AppConfigState build() => initial ?? AppConfigState.initial;

  void update(AppConfigState value) => state = value;
}

SingleLineLyricPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint &&
                    widget.painter is SingleLineLyricPainter,
              ),
            )
            .painter!
        as SingleLineLyricPainter;

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PlayerCompactLyricSection)),
);

const _timedLine = LyricLine(
  start: Duration.zero,
  end: Duration(seconds: 8),
  text: 'Hello world',
  tokens: [
    LyricToken(
      text: 'Hello ',
      startOffset: Duration.zero,
      duration: Duration(seconds: 4),
    ),
    LyricToken(
      text: 'world',
      startOffset: Duration(seconds: 4),
      duration: Duration(seconds: 4),
    ),
  ],
);

void _noop() {}

class _TestPositionController extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;

  void update(Duration position) {
    state = position;
  }
}

class _TestDocumentController extends Notifier<LyricDocument> {
  @override
  LyricDocument build() => const LyricDocument(
    lines: [
      LyricLine(start: Duration.zero, text: '第一句'),
      LyricLine(start: Duration(seconds: 2), text: '第二句'),
    ],
  );

  void update(LyricDocument document) {
    state = document;
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'song-1', title: '测试歌曲', artist: '测试歌手'),
    ]);
  }
}

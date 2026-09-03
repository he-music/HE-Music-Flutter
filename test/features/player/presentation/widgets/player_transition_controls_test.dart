import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_control_bar.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_progress_bar.dart';

void main() {
  testWidgets('pending controls keep skip and queue enabled only', (
    tester,
  ) async {
    var previousCalls = 0;
    var nextCalls = 0;
    var queueCalls = 0;
    var playCalls = 0;
    var modeCalls = 0;
    var seekCalls = 0;

    await tester.pumpWidget(
      _buildControls(
        isTrackTransitioning: true,
        onPrevious: () => previousCalls += 1,
        onNext: () => nextCalls += 1,
        onOpenQueue: () => queueCalls += 1,
        onPlayPause: () => playCalls += 1,
        onCyclePlayMode: () => modeCalls += 1,
        onSeek: (_) => seekCalls += 1,
      ),
    );

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('player-progress-slider')),
    );
    expect(slider.onChanged, isNull);
    expect(_button(tester, Icons.repeat_rounded).onPressed, isNull);
    expect(
      find.byKey(const ValueKey<String>('player-control-preparing-indicator')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pump();

    expect(previousCalls, 1);
    expect(nextCalls, 1);
    expect(queueCalls, 1);
    expect(playCalls, 0);
    expect(modeCalls, 0);
    expect(seekCalls, 0);
  });

  testWidgets('settled controls restore play mode play and seek callbacks', (
    tester,
  ) async {
    var playCalls = 0;
    var modeCalls = 0;
    Duration? seekPosition;
    await tester.pumpWidget(
      _buildControls(
        isTrackTransitioning: false,
        onPrevious: () {},
        onNext: () {},
        onOpenQueue: () {},
        onPlayPause: () => playCalls += 1,
        onCyclePlayMode: () => modeCalls += 1,
        onSeek: (value) => seekPosition = value,
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.tap(find.byIcon(Icons.repeat_rounded));
    tester
        .widget<Slider>(
          find.byKey(const ValueKey<String>('player-progress-slider')),
        )
        .onChanged!(90000);

    expect(playCalls, 1);
    expect(modeCalls, 1);
    expect(seekPosition, const Duration(seconds: 90));
    expect(
      find.byKey(const ValueKey<String>('player-control-preparing-indicator')),
      findsNothing,
    );
  });

  testWidgets('primary playback control stays borderless under scene palette', (
    tester,
  ) async {
    const palette = PlayerScenePalette(
      surface: Color(0xFF253535),
      surfaceDeep: Color(0xFF101818),
      surfaceRaised: Color(0xFF344747),
      edge: Color(0xFF8BC9BD),
      accent: Color(0xFFE2B56D),
      foreground: Color(0xFFF5FAF8),
      secondaryForeground: Color(0xC7DCE8E4),
      onAccent: Color(0xFF17201E),
    );
    await tester.pumpWidget(
      _buildControls(
        palette: palette,
        isTrackTransitioning: false,
        onPrevious: () {},
        onNext: () {},
        onOpenQueue: () {},
        onPlayPause: () {},
        onCyclePlayMode: () {},
        onSeek: (_) {},
      ),
    );

    final sliderTheme = tester.widget<SliderTheme>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('player-progress-slider')),
        matching: find.byType(SliderTheme),
      ),
    );
    expect(sliderTheme.data.activeTrackColor, Colors.white);
    expect(
      sliderTheme.data.inactiveTrackColor,
      Colors.white.withValues(alpha: 0.2),
    );
    expect(sliderTheme.data.thumbColor, Colors.white);
    expect(sliderTheme.data.overlayColor, Colors.white.withValues(alpha: 0.14));

    expect(
      _button(tester, Icons.repeat_rounded).color,
      Colors.white.withValues(alpha: 0.84),
    );
    expect(
      _button(tester, Icons.queue_music_rounded).color,
      Colors.white.withValues(alpha: 0.84),
    );
    expect(_button(tester, Icons.skip_previous_rounded).color, Colors.white);
    expect(_button(tester, Icons.skip_next_rounded).color, Colors.white);

    final playButton = _button(tester, Icons.play_arrow_rounded);
    expect(
      playButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
      Colors.white,
    );
    expect(
      playButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      Colors.transparent,
    );
  });

  testWidgets(
    'progress slider exposes played, buffered, and remaining ranges',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerProgressBar(
              position: const Duration(seconds: 30),
              bufferedPosition: const Duration(seconds: 90),
              duration: const Duration(minutes: 3),
              onSeek: (_) {},
            ),
          ),
        ),
      );

      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey<String>('player-progress-slider')),
      );
      final sliderTheme = tester.widget<SliderTheme>(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('player-progress-slider')),
          matching: find.byType(SliderTheme),
        ),
      );

      expect(slider.value, 30000);
      expect(slider.secondaryTrackValue, 90000);
      expect(slider.max, 180000);
      expect(
        sliderTheme.data.secondaryActiveTrackColor,
        Colors.white.withValues(alpha: 0.32),
      );
    },
  );
}

Widget _buildControls({
  required bool isTrackTransitioning,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
  required VoidCallback onOpenQueue,
  required VoidCallback onPlayPause,
  required VoidCallback onCyclePlayMode,
  required ValueChanged<Duration> onSeek,
  PlayerScenePalette? palette,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: <ThemeExtension<dynamic>>[?palette]),
    home: Scaffold(
      body: Column(
        children: <Widget>[
          PlayerProgressBar(
            position: const Duration(seconds: 30),
            duration: const Duration(minutes: 3),
            enabled: !isTrackTransitioning,
            onSeek: onSeek,
          ),
          PlayerControlBar(
            localeCode: 'en',
            isPlaying: false,
            playMode: PlayerPlayMode.sequence,
            isTrackTransitioning: isTrackTransitioning,
            onOpenQueue: onOpenQueue,
            onCyclePlayMode: onCyclePlayMode,
            onPrevious: onPrevious,
            onPlayPause: onPlayPause,
            onNext: onNext,
          ),
        ],
      ),
    ),
  );
}

IconButton _button(WidgetTester tester, IconData icon) {
  return tester.widget<IconButton>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
  );
}

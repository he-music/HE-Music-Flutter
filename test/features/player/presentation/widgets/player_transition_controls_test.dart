import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/styles/cassette_player_palette.dart';
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

  testWidgets('cassette palette colors progress and playback controls', (
    tester,
  ) async {
    final palette = CassettePlayerPalette.fromBackdrop(const <Color>[
      Color(0xFF7E57C2),
      Color(0xFFFFCA28),
      Color(0xFF4527A0),
      Color(0xFF1A1230),
    ]);
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
    expect(sliderTheme.data.activeTrackColor, palette.accent);
    expect(sliderTheme.data.thumbColor, palette.foreground);

    final playButton = _button(tester, Icons.play_arrow_rounded);
    expect(
      playButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
      palette.foreground,
    );
    expect(
      playButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      palette.surfaceDeep.withValues(alpha: 0.72),
    );
  });
}

Widget _buildControls({
  required bool isTrackTransitioning,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
  required VoidCallback onOpenQueue,
  required VoidCallback onPlayPause,
  required VoidCallback onCyclePlayMode,
  required ValueChanged<Duration> onSeek,
  CassettePlayerPalette? palette,
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
            config: AppConfigState.initial.copyWith(localeCode: 'en'),
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

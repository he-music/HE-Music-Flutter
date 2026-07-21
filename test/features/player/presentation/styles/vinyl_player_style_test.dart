import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/styles/vinyl_player_stage.dart';

void main() {
  testWidgets('vinyl rotation pauses and resumes from the current angle', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        playerControllerProvider.overrideWith(_VinylTestController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller =
        container.read(playerControllerProvider.notifier)
            as _VinylTestController;

    await tester.pumpWidget(_buildStage(container, track: _trackA));
    controller.setPlaying(true);
    await tester.pump();

    double rotation() {
      return tester
          .widget<RotationTransition>(
            find.byKey(const ValueKey<String>('vinyl-record-rotation')),
          )
          .turns
          .value;
    }

    final initial = rotation();
    await tester.pump(const Duration(seconds: 1));
    final playing = rotation();
    expect(playing, isNot(closeTo(initial, 0.0001)));

    controller.setPlaying(false);
    await tester.pump();
    final paused = rotation();
    await tester.pump(const Duration(seconds: 1));
    expect(rotation(), closeTo(paused, 0.0001));

    controller.setPlaying(true);
    await tester.pump();
    expect(rotation(), closeTo(paused, 0.0001));
    await tester.pump(const Duration(seconds: 1));
    expect(rotation(), isNot(closeTo(paused, 0.0001)));

    expect(find.byType(IgnorePointer), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('vinyl lifts the tonearm before replacing the center label', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        playerControllerProvider.overrideWith(_VinylTestController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller =
        container.read(playerControllerProvider.notifier)
            as _VinylTestController;
    controller.setPlaying(true);
    final track = ValueNotifier<PlayerTrack>(_trackA);
    addTearDown(track.dispose);

    await tester.pumpWidget(_buildDynamicStage(container, track));
    await tester.pump(const Duration(milliseconds: 420));
    expect(
      find.byKey(const ValueKey<String>('vinyl-center-label-track-a')),
      findsOneWidget,
    );

    track.value = _trackB;
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('vinyl-center-label-track-a')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('vinyl-center-label-track-b')),
      findsOneWidget,
    );
  });

  testWidgets('playback changes do not cancel a pending center label update', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        playerControllerProvider.overrideWith(_VinylTestController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller =
        container.read(playerControllerProvider.notifier)
            as _VinylTestController;
    controller.setPlaying(true);
    final track = ValueNotifier<PlayerTrack>(_trackA);
    addTearDown(track.dispose);

    await tester.pumpWidget(_buildDynamicStage(container, track));
    await tester.pump(const Duration(milliseconds: 420));

    track.value = _trackB;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    controller.setPlaying(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey<String>('vinyl-center-label-track-b')),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion keeps vinyl in a static playing state', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        playerControllerProvider.overrideWith(_VinylTestController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller =
        container.read(playerControllerProvider.notifier)
            as _VinylTestController;
    controller.setPlaying(true);

    await tester.pumpWidget(
      _buildStage(container, track: _trackA, disableAnimations: true),
    );
    final rotation = tester
        .widget<RotationTransition>(
          find.byKey(const ValueKey<String>('vinyl-record-rotation')),
        )
        .turns;
    final initial = rotation.value;
    await tester.pump(const Duration(seconds: 1));

    expect(rotation.value, initial);
  });
}

Widget _buildDynamicStage(
  ProviderContainer container,
  ValueNotifier<PlayerTrack> track,
) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 320,
            child: ValueListenableBuilder<PlayerTrack>(
              valueListenable: track,
              builder: (context, value, child) {
                return VinylPlayerStage(track: value);
              },
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildStage(
  ProviderContainer container, {
  required PlayerTrack track,
  bool disableAnimations = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 320,
              child: VinylPlayerStage(track: track),
            ),
          ),
        ),
      ),
    ),
  );
}

const PlayerTrack _trackA = PlayerTrack(id: 'track-a', title: 'Track A');
const PlayerTrack _trackB = PlayerTrack(id: 'track-b', title: 'Track B');

class _VinylTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[_trackA, _trackB]);
  }

  void setPlaying(bool value) {
    state = state.copyWith(isPlaying: value);
  }
}

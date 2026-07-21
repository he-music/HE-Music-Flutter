import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/styles/cassette_player_stage.dart';

void main() {
  test('cassette tape progress normalizes and clamps playback timing', () {
    expect(
      resolveCassetteTapeProgress(
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      ),
      0.25,
    );
    expect(
      resolveCassetteTapeProgress(
        const Duration(seconds: 150),
        const Duration(seconds: 120),
      ),
      1,
    );
    expect(
      resolveCassetteTapeProgress(
        const Duration(seconds: -10),
        const Duration(seconds: 120),
      ),
      0,
    );
    expect(
      resolveCassetteTapeProgress(const Duration(seconds: 30), Duration.zero),
      0,
    );
  });

  testWidgets('cassette reels pause and resume from the current angle', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    final controller = _readController(container);

    await tester.pumpWidget(_buildStage(container));
    controller.setPlaying(true);
    await tester.pump();

    List<double> reelTurns() {
      return tester
          .widgetList<RotationTransition>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('cassette-player-stage')),
              matching: find.byType(RotationTransition),
            ),
          )
          .map((widget) => widget.turns.value)
          .toList();
    }

    final initial = reelTurns();
    await tester.pump(const Duration(seconds: 1));
    final playing = reelTurns();
    expect(playing, hasLength(2));
    expect(playing[0], closeTo(playing[1], 0.0001));
    expect(playing[0], isNot(closeTo(initial[0], 0.0001)));

    controller.setPlaying(false);
    await tester.pump();
    final paused = reelTurns();
    await tester.pump(const Duration(seconds: 1));
    expect(reelTurns()[0], closeTo(paused[0], 0.0001));

    controller.setPlaying(true);
    await tester.pump();
    expect(reelTurns()[0], closeTo(paused[0], 0.0001));
    await tester.pump(const Duration(seconds: 1));
    expect(reelTurns()[0], isNot(closeTo(paused[0], 0.0001)));

    expect(
      find.byKey(const ValueKey<String>('cassette-stage-ignore-pointer')),
      findsOneWidget,
    );
  });

  testWidgets('cassette tape amount interpolates after a playback seek', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    final controller = _readController(container);

    await tester.pumpWidget(_buildStage(container));

    double tapeProgress() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey<String>('cassette-shell-painter')),
      );
      return (paint.painter! as CassetteShellPainter).tapeProgress;
    }

    expect(tapeProgress(), 0);
    controller.setTiming(
      position: const Duration(seconds: 90),
      duration: const Duration(seconds: 120),
    );
    await tester.pump();
    expect(tapeProgress(), 0);

    await tester.pump(const Duration(milliseconds: 140));
    expect(tapeProgress(), inExclusiveRange(0, 0.75));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tapeProgress(), closeTo(0.75, 0.001));
  });

  testWidgets('reduced motion keeps cassette reels static', (tester) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    _readController(container).setPlaying(true);

    await tester.pumpWidget(_buildStage(container, disableAnimations: true));
    final rotation = tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('cassette-left-reel')),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns;
    final initial = rotation.value;
    await tester.pump(const Duration(seconds: 1));

    expect(rotation.value, initial);
  });
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: [
      playerControllerProvider.overrideWith(_CassetteTestController.new),
    ],
  );
}

_CassetteTestController _readController(ProviderContainer container) {
  return container.read(playerControllerProvider.notifier)
      as _CassetteTestController;
}

Widget _buildStage(
  ProviderContainer container, {
  bool disableAnimations = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 355,
              height: 240,
              child: CassettePlayerStage(track: _track),
            ),
          ),
        ),
      ),
    ),
  );
}

const PlayerTrack _track = PlayerTrack(
  id: 'cassette-track',
  title: 'Cassette Track',
  artist: 'Cassette Artist',
);

class _CassetteTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[_track]);
  }

  void setPlaying(bool value) {
    state = state.copyWith(isPlaying: value);
  }

  void setTiming({required Duration position, required Duration duration}) {
    state = state.copyWith(position: position, duration: duration);
  }
}

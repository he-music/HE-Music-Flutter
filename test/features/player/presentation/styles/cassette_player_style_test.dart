import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/styles/cassette_player_palette.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/styles/cassette_player_stage.dart';

void main() {
  test('cassette palette keeps artwork hue and readable foreground', () {
    final palette = CassettePlayerPalette.fromBackdrop(const <Color>[
      Color(0xFF1E88E5),
      Color(0xFFFFA726),
      Color(0xFF0D47A1),
      Color(0xFF10243A),
    ]);

    final edge = HSLColor.fromColor(palette.edge);
    expect(edge.hue, inInclusiveRange(195, 220));
    expect(edge.saturation, inInclusiveRange(0.52, 0.82));
    expect(
      _contrastRatio(palette.foreground, palette.surfaceDeep),
      greaterThan(4.5),
    );
  });

  test('cassette palette uses stable fallback without artwork colors', () {
    expect(
      CassettePlayerPalette.fromBackdrop(const <Color>[]),
      CassettePlayerPalette.fallback,
    );
  });

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

    expect(find.text('SIDE A'), findsOneWidget);
    expect(find.text(_track.title), findsNothing);
    expect(find.text('Cassette Artist'), findsNothing);

    final initialStage = tester.widget<Stack>(
      find.byKey(const ValueKey<String>('cassette-player-stage')),
    );
    final initialLabel = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('cassette-track-label')),
    );
    final initialPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('cassette-shell-painter')),
    );

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

    expect(
      tester.widget<Stack>(
        find.byKey(const ValueKey<String>('cassette-player-stage')),
      ),
      same(initialStage),
    );
    expect(
      tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('cassette-track-label')),
      ),
      same(initialLabel),
    );
    expect(
      tester.widget<CustomPaint>(
        find.byKey(const ValueKey<String>('cassette-shell-painter')),
      ),
      isNot(same(initialPaint)),
    );
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

  testWidgets('cassette metadata label remains interactive above the painter', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildStage(
        container,
        label: const Text(
          'Cassette Track',
          key: ValueKey<String>('cassette-interactive-label'),
        ),
      ),
    );

    final label = find.byKey(
      const ValueKey<String>('cassette-interactive-label'),
    );
    expect(label, findsOneWidget);
    expect(
      find.ancestor(
        of: label,
        matching: find.byKey(
          const ValueKey<String>('cassette-stage-ignore-pointer'),
        ),
      ),
      findsNothing,
    );
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
  Widget? label,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 355,
              height: 240,
              child: CassettePlayerStage(track: _track, label: label),
            ),
          ),
        ),
      ),
    ),
  );
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
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

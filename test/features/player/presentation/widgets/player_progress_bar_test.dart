import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_progress_bar.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';

void main() {
  testWidgets('scrubbing previews locally and commits once on release', (
    tester,
  ) async {
    final seeks = <Duration>[];
    final completion = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerProgressBar(
            position: const Duration(seconds: 10),
            duration: const Duration(minutes: 3),
            onSeek: (position) {
              seeks.add(position);
              return completion.future;
            },
          ),
        ),
      ),
    );
    final sliderFinder = find.byType(Slider);
    final rect = tester.getRect(sliderFinder);
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width * .3, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.left + rect.width * .7, rect.center.dy));
    await tester.pump();
    final preview = tester.widget<Slider>(sliderFinder).value;
    expect(preview, greaterThan(90000));
    expect(seeks, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(seeks, hasLength(1));
    expect(seeks.single.inMilliseconds, closeTo(preview, 1));
    expect(tester.widget<Slider>(sliderFinder).value, closeTo(preview, 1));
    completion.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('new track cancels an in-flight preview', (tester) async {
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PlayerProgressBar(
                position: const Duration(seconds: 10),
                duration: const Duration(minutes: 3),
                enabled: enabled,
                onSeek: (_) {},
              );
            },
          ),
        ),
      ),
    );
    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeStart!(60000);
    slider.onChanged!(90000);
    await tester.pump();
    update(() => enabled = false);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 10000);
    expect(slider.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('progress keeps the player controls white across scene themes', (
    tester,
  ) async {
    final scene = const PlayerScenePalette(
      surface: Colors.white,
      surfaceDeep: Colors.white,
      surfaceRaised: Colors.white,
      edge: Colors.black12,
      accent: Colors.deepPurple,
      foreground: Colors.black,
      secondaryForeground: Color(0xFF424242),
      onAccent: Colors.white,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [scene]),
        home: Scaffold(
          body: PlayerProgressBar(
            position: const Duration(seconds: 10),
            duration: const Duration(minutes: 3),
            onSeek: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final slider = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(slider.data.activeTrackColor, Colors.white);
    expect(
      tester.widget<Text>(find.text('00:10')).style!.color,
      Colors.white.withValues(alpha: 0.74),
    );
  });
}

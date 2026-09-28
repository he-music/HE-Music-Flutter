import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_progress_bar.dart';

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
}

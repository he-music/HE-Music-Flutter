import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_control_bar.dart';

void main() {
  for (final width in [240.0, 320.0, 390.0]) {
    testWidgets(
      'player controls retain touch targets and named actions at width $width',
      (tester) async {
        var previous = 0;
        var next = 0;
        var play = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: PlayerControlBar(
                    localeCode: 'zh',
                    isPlaying: false,
                    playMode: PlayerPlayMode.sequence,
                    compact: true,
                    onOpenQueue: () {},
                    onCyclePlayMode: () {},
                    onPrevious: () => previous++,
                    onNext: () => next++,
                    onPlayPause: () => play++,
                  ),
                ),
              ),
            ),
          ),
        );
        for (final element in find.byType(IconButton).evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        await tester.tap(find.byTooltip('上一首'));
        await tester.tap(find.byTooltip('下一首'));
        await tester.tap(find.byTooltip('播放'));
        expect((previous, next, play), (1, 1, 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('playing control exposes pause label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerControlBar(
            localeCode: 'en',
            isPlaying: true,
            playMode: PlayerPlayMode.sequence,
            onOpenQueue: () {},
            onCyclePlayMode: () {},
            onPrevious: () {},
            onNext: () {},
            onPlayPause: () {},
          ),
        ),
      ),
    );
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Play'), findsNothing);
  });
}

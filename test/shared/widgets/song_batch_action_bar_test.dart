import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/song_batch_action_bar.dart';

void main() {
  testWidgets('batch action bar opens bottom sheet actions', (tester) async {
    var playTapped = false;
    var addToQueueTapped = false;
    var addToPlaylistTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: SongBatchActionBar(
              enabled: true,
              onPlayPressed: () {
                playTapped = true;
              },
              onAddToQueuePressed: () {
                addToQueueTapped = true;
              },
              onAddToPlaylistPressed: () {
                addToPlaylistTapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Batch'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    expect(find.text('Play'), findsNothing);

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add to Queue'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(playTapped, isTrue);

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Queue'));
    await tester.pumpAndSettle();
    expect(addToQueueTapped, isTrue);

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Playlist'));
    await tester.pumpAndSettle();
    expect(addToPlaylistTapped, isTrue);
  });

  testWidgets('batch action bar uses anchored context menu on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: SongBatchActionBar(
              enabled: true,
              onPlayPressed: null,
              onAddToQueuePressed: null,
              onAddToPlaylistPressed: null,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(PopupMenuItem<VoidCallback>), findsWidgets);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add to Queue'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/song_batch_action_bar.dart';

void main() {
  testWidgets('batch action bar exposes actions directly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.text('Batch'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add to Queue'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(playTapped, isTrue);

    await tester.tap(find.text('Add to Queue'));
    await tester.pump();
    expect(addToQueueTapped, isTrue);

    await tester.tap(find.text('Add to Playlist'));
    await tester.pump();
    expect(addToPlaylistTapped, isTrue);
  });

  testWidgets('batch action bar fits four actions on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var removeTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 568)),
          child: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: SongBatchActionBar(
              enabled: true,
              onPlayPressed: null,
              onAddToQueuePressed: null,
              onAddToPlaylistPressed: null,
              onRemoveFromPlaylistPressed: () {
                removeTapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add to Queue'), findsOneWidget);
    expect(find.text('Remove from Playlist'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Remove from Playlist'));
    await tester.pump();

    expect(removeTapped, isTrue);
  });
}

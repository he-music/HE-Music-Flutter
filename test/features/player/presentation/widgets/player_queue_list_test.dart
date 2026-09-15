import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_list.dart';

void main() {
  for (final removedIndex in [1, 45]) {
    testWidgets(
      'removing track $removedIndex preserves manual scroll position',
      (tester) async {
        var queue = _queue();
        var currentIndex = 40;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return PlayerQueueList(
                    config: AppConfigState.initial,
                    queue: queue,
                    currentIndex: currentIndex,
                    onPlayAt: (_) {},
                    onRemoveAt: (index) {
                      update(() {
                        queue = [...queue]..removeAt(index);
                        if (index < currentIndex) currentIndex--;
                      });
                    },
                    onReorder: (_, _) async {},
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Song 41').hitTestable(), findsOneWidget);

        final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        final scroll = list.scrollController!;
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        tester
            .widget<PlayerQueueList>(find.byType(PlayerQueueList))
            .onRemoveAt!(removedIndex);
        await tester.pumpAndSettle();

        expect(scroll.offset, 0);
        expect(queue[currentIndex].id, 'song-41');
        expect(find.text('Song 1').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('changing the playing track scrolls to its new position', (
    tester,
  ) async {
    final queue = _queue();
    await tester.pumpWidget(_app(queue, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(queue, 40));
    await tester.pumpAndSettle();

    expect(find.text('Song 41').hitTestable(), findsOneWidget);
    expect(find.text('Song 1').hitTestable(), findsNothing);
  });

  testWidgets('reordering the playing track preserves manual scroll position', (
    tester,
  ) async {
    final queue = _queue();
    await tester.pumpWidget(_app(queue, 40));
    await tester.pumpAndSettle();
    final scroll = tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .scrollController!;
    scroll.jumpTo(0);
    await tester.pumpAndSettle();

    final reordered = [...queue];
    reordered.insert(30, reordered.removeAt(40));
    await tester.pumpWidget(_app(reordered, 30));
    await tester.pumpAndSettle();

    expect(scroll.offset, 0);
    expect(find.text('Song 1').hitTestable(), findsOneWidget);
  });
}

List<PlayerTrack> _queue() => List.generate(
  50,
  (index) => PlayerTrack(id: 'song-${index + 1}', title: 'Song ${index + 1}'),
);

Widget _app(List<PlayerTrack> queue, int currentIndex) => MaterialApp(
  home: Scaffold(
    body: PlayerQueueList(
      config: AppConfigState.initial,
      queue: queue,
      currentIndex: currentIndex,
      onPlayAt: (_) {},
      onReorder: (_, _) async {},
    ),
  ),
);

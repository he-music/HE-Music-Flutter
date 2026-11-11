import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_extractor.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_song_artwork_provider.dart';
import 'package:he_music_flutter/features/music_library/presentation/widgets/local_song_list_item.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';

void main() {
  testWidgets('large lists read only mounted rows and release unused artwork', (
    tester,
  ) async {
    final harness = _Harness();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      harness.app(
        ListView.builder(
          controller: scroll,
          itemExtent: 100,
          itemCount: 1000,
          itemBuilder: (_, index) => _row(_song(index)),
        ),
      ),
    );
    final initialPaths = harness.extractor.requests.keys.toSet();
    expect(initialPaths, isNotEmpty);
    expect(initialPaths.length, lessThan(20));
    harness.extractor.complete(initialPaths.first, _png);
    await tester.pump();
    expect(harness.builds, 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ListView)),
    );
    scroll.jumpTo(50000);
    await tester.pump();
    await tester.pump();
    expect(harness.extractor.requests, contains('/song500.mp3'));
    expect(harness.extractor.requests.length, lessThan(40));
    for (final path in initialPaths) {
      expect(container.exists(localSongArtworkProvider(path)), isFalse);
    }
    await harness.close(tester);
  });

  testWidgets(
    'matching rows share bytes and a completed cover only rebuilds its row',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(
        harness.app(
          Column(children: [_row(_song(0)), _row(_song(0)), _row(_song(1))]),
        ),
      );
      expect(harness.extractor.requests, hasLength(2));
      final otherRow = tester
          .widgetList<SongListItem>(find.byType(SongListItem))
          .last;
      harness.extractor.complete('/song0.mp3', _png);
      await tester.pump();
      final rows = tester
          .widgetList<SongListItem>(find.byType(SongListItem))
          .toList();
      expect(rows[0].data.coverBytes, same(_png));
      expect(rows[1].data.coverBytes, same(_png));
      expect(rows[2], same(otherRow));
      expect(harness.builds, 1);
      await harness.close(tester);
    },
  );

  testWidgets(
    'metadata changes retain reads and replacement paths reject late bytes',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app(_row(_song(0))));
      await tester.pumpWidget(harness.app(_row(_song(0, title: 'Updated'))));
      expect(harness.extractor.requests, hasLength(1));
      harness.extractor.complete('/song0.mp3', _png);
      await tester.idle();
      await tester.pump();
      expect(
        tester.widget<SongListItem>(find.byType(SongListItem)).data.title,
        'Updated',
      );
      expect(
        tester.widget<SongListItem>(find.byType(SongListItem)).data.coverBytes,
        same(_png),
      );

      await tester.pumpWidget(harness.app(_row(_song(1))));
      await tester.pumpWidget(
        harness.app(_row(_song(1, path: '/replacement.mp3'))),
      );
      harness.extractor.complete('/song1.mp3', _png);
      await tester.pump();
      expect(
        tester.widget<SongListItem>(find.byType(SongListItem)).data.coverBytes,
        isNull,
      );
      harness.extractor.complete('/replacement.mp3', _png);
      await tester.idle();
      await tester.pump();
      expect(
        tester.widget<SongListItem>(find.byType(SongListItem)).data.coverBytes,
        same(_png),
      );
      await harness.close(tester);
    },
  );

  testWidgets('supplied artwork and songs without artwork skip reads', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(
      harness.app(
        Column(
          children: [
            _row(_song(0, hasArtwork: false)),
            _row(_song(1, bytes: _png)),
            LocalSongListItem(
              song: _song(2),
              data: SongListItemData(
                title: 'Supplied',
                artistAlbumText: 'artist',
                subtitleText: '',
                coverBytes: _png,
              ),
            ),
          ],
        ),
      ),
    );
    expect(harness.extractor.requests, isEmpty);
    final rows = tester
        .widgetList<SongListItem>(find.byType(SongListItem))
        .toList();
    expect(rows[0].data.coverBytes, isNull);
    expect(rows[1].data.coverBytes, same(_png));
    expect(rows[2].data.coverBytes, same(_png));
    await harness.close(tester);
  });

  testWidgets('failed and empty reads fall back without affecting other rows', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(
      harness.app(
        Column(
          children: [
            for (var index = 0; index < 4; index++) _row(_song(index)),
          ],
        ),
      ),
    );
    harness.extractor.requests['/song0.mp3']!.completeError(
      StateError('unreadable'),
    );
    harness.extractor.complete('/song1.mp3', []);
    harness.extractor.complete('/song2.mp3', null);
    harness.extractor.complete('/song3.mp3', _png);
    await tester.pump();
    final rows = tester
        .widgetList<SongListItem>(find.byType(SongListItem))
        .toList();
    expect(rows.take(3).every((row) => row.data.coverBytes == null), isTrue);
    expect(rows.last.data.coverBytes, same(_png));
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets(
    'progress leaves rows intact while current song changes update them',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app(_row(_song(0))));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LocalSongListItem)),
      );
      final player = container.read(playerControllerProvider.notifier);
      final row = tester.widget<SongListItem>(find.byType(SongListItem));
      player.state = player.state.copyWith(
        position: const Duration(seconds: 1),
      );
      await tester.pump();
      expect(tester.widget<SongListItem>(find.byType(SongListItem)), same(row));
      player.state = PlayerPlaybackState.initial(const [
        PlayerTrack(
          id: 'local-0',
          title: 'song',
          path: '/song0.mp3',
          platform: 'local',
        ),
      ]);
      await tester.pump();
      expect(
        tester.widget<SongListItem>(find.byType(SongListItem)).data.isCurrent,
        isTrue,
      );
      expect(harness.builds, 1);
      await harness.close(tester);
    },
  );
}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aU1kAAAAASUVORK5CYII=',
);

LocalSong _song(
  int index, {
  String? title,
  String? path,
  bool hasArtwork = true,
  Uint8List? bytes,
}) => LocalSong(
  id: '$index',
  title: title ?? 'song $index',
  filePath: path ?? '/song$index.mp3',
  artist: 'artist',
  album: 'album',
  duration: const Duration(minutes: 3),
  mimeType: 'audio/mpeg',
  size: 1024,
  hasArtwork: hasArtwork,
  artworkBytes: bytes,
);

Widget _row(LocalSong song) => LocalSongListItem(
  song: song,
  data: SongListItemData(
    title: song.title,
    artistAlbumText: song.artist,
    subtitleText: song.filePath,
  ),
);

class _Harness {
  final extractor = _DeferredExtractor();
  int builds = 0;
  Widget app(Widget child) => ProviderScope(
    overrides: [
      localArtworkExtractorProvider.overrideWithValue(extractor),
      playerControllerProvider.overrideWith(_Player.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (_) {
            builds++;
            return child;
          },
        ),
      ),
    ),
  );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (final request in extractor.requests.values) {
      if (!request.isCompleted) request.complete(null);
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const []);
}

class _DeferredExtractor implements LocalArtworkExtractor {
  final requests = <String, Completer<List<int>?>>{};
  @override
  Future<List<int>?> getArtworkBytes(String path) {
    final completer = Completer<List<int>?>();
    if (requests.containsKey(path)) throw StateError('duplicate read: $path');
    requests[path] = completer;
    return completer.future;
  }

  void complete(String path, List<int>? bytes) =>
      requests[path]!.complete(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

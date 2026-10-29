import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/models/song_list_page.dart';
import 'package:he_music_flutter/shared/models/song_list_pagination.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cursor = SongListPagination(
  path: '/v1/playlist/songs',
  parameters: {'id': 'a', 'platform': 'qq'},
  nextPageIndex: 2,
  pageSize: 1000,
  hasMore: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'prefetch starts with three songs remaining and does not drain all pages',
    () async {
      final requests = <SongListPagination>[];
      final handler = _handler((cursor) async {
        requests.add(cursor);
        return SongListPage(
          songs: List.generate(10, (i) => _song('new-$i')),
          hasMore: true,
        );
      });
      await handler.setQueueData(_tracks(10), pagination: _cursor);
      await _flush();
      expect(requests, isEmpty);
      await handler.playIndex(6);
      await handler.queue.firstWhere((items) => items.length == 20);
      expect(requests.map((item) => item.nextPageIndex), [2]);
      expect(handler.mediaItem.value?.id, 'song-6');
      expect(handler.queue.value.first.id, 'song-0');
    },
  );

  test(
    'starting at the last loaded song plays immediately while its page is pending',
    () async {
      final pending = Completer<SongListPage>();
      final requested = Completer<void>();
      final handler = _handler((_) {
        requested.complete();
        return pending.future;
      });
      await handler.setQueueData(
        _tracks(5),
        initialIndex: 4,
        pagination: _cursor,
      );
      await requested.future;
      expect(handler.mediaItem.value?.id, 'song-4');
      expect(handler.queue.value, hasLength(5));
      pending.complete(SongListPage(songs: [_song('next')], hasMore: false));
      await handler.queue.firstWhere((items) => items.length == 6);
    },
  );

  test(
    'manual next and prefetch share one pending page and continue across the boundary',
    () async {
      var requests = 0;
      final page = Completer<SongListPage>();
      final handler = _handler((_) {
        requests++;
        return page.future;
      });
      await handler.setQueueData(_tracks(1), pagination: _cursor);
      await handler.skipToNext();
      await handler.skipToNext();
      page.complete(SongListPage(songs: [_song('next')], hasMore: false));
      await handler.mediaItem.firstWhere((item) => item?.id == 'next');
      expect(requests, 1);
      expect(handler.playbackState.value.queueIndex, 1);
    },
  );

  test(
    'automatic completion waits for the pending page instead of looping early',
    () async {
      var requests = 0;
      final page = Completer<SongListPage>();
      final handler = _handler((_) {
        requests++;
        return page.future;
      });
      await handler.setQueueData(_tracks(1), pagination: _cursor);
      final completion = handler.handlePlaybackCompletedForTesting();
      page.complete(SongListPage(songs: [_song('next')], hasMore: false));
      await completion;
      expect(requests, 1);
      expect(handler.mediaItem.value?.id, 'next');
    },
  );

  for (final sameSource in [false, true]) {
    test(
      'replacing a queue discards its old pending page (same source=$sameSource)',
      () async {
        final pending = Completer<SongListPage>();
        final requested = Completer<void>();
        final handler = _handler((_) {
          if (!requested.isCompleted) requested.complete();
          return pending.future;
        });
        await handler.setQueueData(
          _tracks(5),
          initialIndex: 4,
          pagination: _cursor,
        );
        await requested.future;
        await handler.setQueueData(
          _tracks(9),
          pagination: sameSource ? _cursor.advance(hasMore: false) : null,
        );
        pending.complete(SongListPage(songs: [_song('stale')], hasMore: false));
        await _flush();
        expect(
          handler.queue.value.map((item) => item.id),
          _tracks(9).map((item) => item.id),
        );
      },
    );
  }

  test(
    'reentering uses the supplied 1000, 2000 or 900 songs exactly',
    () async {
      final handler = _handler(
        (_) async => const SongListPage(songs: [], hasMore: false),
      );
      await handler.setQueueData(
        _tracks(2000),
        pagination: _cursor.advance(hasMore: false),
      );
      await handler.setQueueData(_tracks(1000), pagination: _cursor);
      expect(handler.queue.value, hasLength(1000));
      await handler.setQueueData(
        _tracks(2000),
        initialIndex: 1499,
        pagination: _cursor.advance(hasMore: false),
      );
      expect(handler.queue.value, hasLength(2000));
      expect(handler.mediaItem.value?.id, 'song-1499');
      await handler.setQueueData(_tracks(900));
      expect(handler.queue.value, hasLength(900));
      expect(handler.queue.value.any((item) => item.id == 'song-999'), isFalse);
    },
  );

  test(
    'ordinary lists retain their beginning when they exceed the radio cap',
    () async {
      final handler = _handler(
        (_) async => SongListPage(
          songs: List.generate(1000, (i) => _song('tail-$i')),
          hasMore: false,
        ),
      );
      await handler.setQueueData(
        _tracks(1000),
        initialIndex: 998,
        pagination: _cursor,
      );
      await handler.queue.firstWhere((items) => items.length == 2000);
      expect(handler.queue.value.first.id, 'song-0');
      expect(handler.mediaItem.value?.id, 'song-998');
      expect(handler.playbackState.value.queueIndex, 998);
    },
  );

  test(
    'deduplication handles overlaps and duplicates within an incoming page',
    () async {
      final handler = _handler(
        (_) async => SongListPage(
          songs: [_song('song-4'), _song('next'), _song('next')],
          hasMore: false,
        ),
      );
      await handler.setQueueData(
        _tracks(5),
        initialIndex: 4,
        pagination: _cursor,
      );
      await handler.queue.firstWhere((items) => items.length == 6);
      expect(
        handler.queue.value.where((item) => item.id == 'next'),
        hasLength(1),
      );
    },
  );

  test(
    'hasMore=false prevents further requests after reaching the end',
    () async {
      var requests = 0;
      final handler = _handler((_) async {
        requests++;
        return SongListPage(songs: [_song('next')], hasMore: false);
      });
      await handler.setQueueData(_tracks(1), pagination: _cursor);
      await handler.queue.firstWhere((items) => items.length == 2);
      await handler.playIndex(1);
      await handler.handlePlaybackCompletedForTesting();
      await _flush();
      expect(requests, 1);
      expect(handler.mediaItem.value?.id, 'song-0');
    },
  );

  test(
    'an exhausted empty page ends pagination rather than failing playback',
    () async {
      final handler = _handler(
        (_) async => const SongListPage(songs: [], hasMore: false),
      );
      await handler.setQueueData(_tracks(1), pagination: _cursor);
      await _flush();
      await handler.handlePlaybackCompletedForTesting();
      expect(handler.mediaItem.value?.id, 'song-0');
    },
  );

  test(
    'a failed prefetch preserves the cursor and manual next can retry',
    () async {
      var attempts = 0;
      var failing = true;
      final finishedAttempts = Completer<void>();
      final errors = <dynamic>[];
      final handler = _handler((cursor) async {
        expect(cursor.nextPageIndex, 2);
        attempts++;
        if (failing) {
          if (attempts == 3) finishedAttempts.complete();
          throw StateError('temporary failure');
        }
        return SongListPage(songs: [_song('next')], hasMore: false);
      });
      final subscription = handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'playbackTransitionError') {
          errors.add(event);
        }
      });
      addTearDown(subscription.cancel);
      await handler.setQueueData(_tracks(1), pagination: _cursor);
      await finishedAttempts.future;
      await _flush();
      expect(handler.mediaItem.value?.id, 'song-0');
      expect(errors, isEmpty);
      failing = false;
      await handler.skipToNext();
      await handler.mediaItem.firstWhere((item) => item?.id == 'next');
      expect(attempts, 4);
    },
  );

  test(
    'shuffle appends new indices without dropping already loaded songs',
    () async {
      final handler = _handler(
        (_) async => SongListPage(
          songs: List.generate(10, (i) => _song('tail-$i')),
          hasMore: false,
        ),
      );
      await handler.setQueueData(_tracks(5), pagination: _cursor);
      await handler.setShuffleModeEnabled(true);
      await handler.playIndex(4);
      await handler.queue.firstWhere((items) => items.length == 15);
      expect(handler.queue.value.map((item) => item.id).toSet(), hasLength(15));
      expect(handler.mediaItem.value?.id, 'song-4');
    },
  );
}

HeAudioHandler _handler(
  Future<SongListPage> Function(SongListPagination) loader,
) {
  final handler = HeAudioHandler(
    fetchSongListPageOverride: loader,
    fetchSongUrlOverride:
        ({required songId, required platform, quality, format}) async => {
          'url': 'https://example.com/$songId.mp3',
        },
    fetchLyricsOverride: ({required trackId, platform, localPath}) async =>
        const LyricDocument.empty(),
    setAudioSourceOverride: (source, player) async => null,
    playOverride: (player) async {},
    disposeOverride: (player) async {},
    randomOverride: Random(5),
  );
  addTearDown(handler.disposeHandler);
  return handler;
}

List<AudioTrack> _tracks(int count) => List.generate(
  count,
  (i) => AudioTrack(id: 'song-$i', title: 'Song $i', url: '', platform: 'qq'),
);

SongInfo _song(String id) => SongInfo(
  name: id,
  subtitle: '',
  id: id,
  duration: 180,
  mvId: '',
  album: null,
  artists: const [],
  links: const [],
  platform: 'qq',
  cover: '',
);

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_quality_manager.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_queue_manager.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  final manager = PlayerQueueManager(
    dataSource: const PlayerQueueDataSource(),
    qualityManager: PlayerQualityManager(
      platformsReader: () => [],
      configReader: () => throw UnimplementedError(),
    ),
    fetchRadioSongs: (_, _, _) async => [],
  );
  const source = PlayerQueueSource(
    routePath: '/playlist',
    queryParameters: {'id': 'playlist'},
    title: 'Playlist',
  );
  PlayerPlaybackState state(List<PlayerTrack> tracks) => PlayerPlaybackState(
    queue: tracks,
    currentIndex: 0,
    historyCount: 0,
    isPlaying: false,
    isLoading: false,
    isPlaybackSessionActive: false,
    position: Duration.zero,
    duration: Duration.zero,
    volume: 1,
    speed: 1,
    playMode: PlayerPlayMode.sequence,
    currentAvailableQualities: const [],
    queueSource: source,
    isRadioMode: false,
  );

  test(
    'source reorder identities distinguish platforms and delimiter characters',
    () {
      final current = state(const [
        PlayerTrack(id: 'same', title: 'QQ', platform: 'qq'),
        PlayerTrack(id: 'same', title: 'Netease', platform: 'netease'),
        PlayerTrack(id: 'a|b', title: 'First', platform: 'c'),
        PlayerTrack(id: 'a', title: 'Second', platform: 'b|c'),
      ]);
      expect(
        manager.sourceReorderIndices(current, [
          IdPlatformInfo(id: ' a ', platform: ' b|c '),
          IdPlatformInfo(id: 'a|b', platform: 'c'),
          IdPlatformInfo(id: 'same', platform: 'netease'),
          IdPlatformInfo(id: 'same', platform: 'qq'),
        ], source),
        [3, 2, 1, 0],
      );
    },
  );

  test(
    'source reorder rejects empty queue, empty identities and invalid sources',
    () {
      expect(manager.sourceReorderIndices(state([]), [], source), isNull);
      expect(
        manager.sourceReorderIndices(
          state(const [PlayerTrack(id: ' ', title: 'Invalid', platform: 'qq')]),
          [IdPlatformInfo(id: '', platform: 'qq')],
          source,
        ),
        isNull,
      );
      expect(
        manager.sourceReorderIndices(
          state(const [PlayerTrack(id: 'song', title: 'Song', platform: 'qq')]),
          [IdPlatformInfo(id: 'song', platform: 'qq')],
          const PlayerQueueSource(
            routePath: '',
            queryParameters: {},
            title: 'Invalid',
          ),
        ),
        isNull,
      );
    },
  );

  const resolved = PlayerTrack(
    id: 'song',
    title: 'Song',
    platform: 'qq',
    url: 'https://example.com/song.mp3',
    links: [
      LinkInfo(
        name: '320k',
        quality: 320,
        format: 'mp3',
        size: '100',
        url: 'https://example.com/link.mp3',
      ),
    ],
    albumId: 'original-album',
    mvId: 'original-mv',
  );
  test('queue acknowledgement compares resolved links by value', () {
    final decoded = resolved.copyWith(
      links: [
        LinkInfo.fromMap({
          'name': '320k',
          'quality': 320,
          'format': 'mp3',
          'size': '100',
          'url': 'https://example.com/link.mp3',
        }),
      ],
    );
    expect(manager.hasSameAudioData(resolved, decoded), isTrue);
    expect(
      manager.hasSameAudioData(
        resolved,
        resolved.copyWith(albumId: 'other', mvId: 'other'),
      ),
      isTrue,
    );
    expect(
      manager.hasSameAudioData(
        resolved,
        resolved.copyWith(url: 'https://example.com/refreshed.mp3'),
      ),
      isFalse,
    );
    expect(
      manager.hasSameAudioData(resolved, resolved.copyWith(links: const [])),
      isFalse,
    );
    expect(
      manager.hasSameAudioData(
        resolved,
        resolved.copyWith(
          links: const [
            LinkInfo(
              name: '320k',
              quality: 320,
              format: 'mp3',
              size: '100',
              url: 'https://example.com/refreshed-link.mp3',
            ),
          ],
        ),
      ),
      isFalse,
    );
  });
}

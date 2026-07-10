import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_history_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_history_item.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_history_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  test('build should load history list', () async {
    final container = ProviderContainer(
      overrides: [
        playerHistoryDataSourceProvider.overrideWithValue(
          _FakeHistoryDataSource(
            items: const <PlayerHistoryItem>[
              PlayerHistoryItem(
                id: 'song-1',
                title: 'Song 1',
                artist: 'Artist 1',
                album: 'Album 1',
                artworkUrl: '',
                url: 'https://example.com/1.mp3',
                playedAt: 1,
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(myHistoryControllerProvider.future);
    expect(state.length, 1);
    expect(state.first.id, 'song-1');
  });

  test('reopening history should reload entries added after leaving', () async {
    final dataSource = _FakeHistoryDataSource(
      items: const <PlayerHistoryItem>[],
    );
    final container = ProviderContainer(
      overrides: [
        playerHistoryDataSourceProvider.overrideWithValue(dataSource),
      ],
    );
    addTearDown(container.dispose);

    final firstSubscription = container.listen(
      myHistoryControllerProvider,
      (_, _) {},
    );
    expect(await container.read(myHistoryControllerProvider.future), isEmpty);

    firstSubscription.close();
    await container.pump();
    dataSource.add(
      const PlayerHistoryItem(
        id: 'song-1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        artworkUrl: '',
        url: 'https://example.com/1.mp3',
        playedAt: 1,
      ),
    );

    final secondSubscription = container.listen(
      myHistoryControllerProvider,
      (_, _) {},
    );
    final state = await container.read(myHistoryControllerProvider.future);
    secondSubscription.close();

    expect(state.map((item) => item.id), <String>['song-1']);
    expect(dataSource.listHistoryCallCount, 2);
  });

  test('clear should reset history list', () async {
    final dataSource = _FakeHistoryDataSource(
      items: const <PlayerHistoryItem>[
        PlayerHistoryItem(
          id: 'song-1',
          title: 'Song 1',
          artist: 'Artist 1',
          album: 'Album 1',
          artworkUrl: '',
          url: 'https://example.com/1.mp3',
          playedAt: 1,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        playerHistoryDataSourceProvider.overrideWithValue(dataSource),
        playerControllerProvider.overrideWith(_TestPlayerController.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myHistoryControllerProvider.future);
    await container.read(myHistoryControllerProvider.notifier).clear();
    final state = container.read(myHistoryControllerProvider);

    expect(state.value, isEmpty);
    expect(container.read(playerControllerProvider).historyCount, 0);
  });

  test('clear failure should keep player history count', () async {
    final container = ProviderContainer(
      overrides: [
        playerHistoryDataSourceProvider.overrideWithValue(
          _FakeHistoryDataSource(
            items: const <PlayerHistoryItem>[],
            clearError: StateError('clear failed'),
          ),
        ),
        playerControllerProvider.overrideWith(_TestPlayerController.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myHistoryControllerProvider.future);
    await container.read(myHistoryControllerProvider.notifier).clear();

    expect(container.read(myHistoryControllerProvider).hasError, isTrue);
    expect(container.read(playerControllerProvider).historyCount, 1);
  });
}

class _FakeHistoryDataSource extends PlayerHistoryDataSource {
  _FakeHistoryDataSource({
    required List<PlayerHistoryItem> items,
    this.clearError,
  }) : _items = items.toList(growable: true);

  final List<PlayerHistoryItem> _items;
  final Object? clearError;
  int listHistoryCallCount = 0;

  void add(PlayerHistoryItem item) {
    _items.add(item);
  }

  @override
  Future<List<PlayerHistoryItem>> listHistory() async {
    listHistoryCallCount += 1;
    return _items.toList(growable: false);
  }

  @override
  Future<void> clearHistory() async {
    if (clearError case final error?) {
      throw error;
    }
    _items.clear();
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(
      const <PlayerTrack>[],
    ).copyWith(historyCount: 1);
  }
}

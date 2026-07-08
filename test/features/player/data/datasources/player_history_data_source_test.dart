import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_history_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('appendTrack should increase history count', () async {
    const dataSource = PlayerHistoryDataSource();
    final count = await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-1',
        title: 'Song 1',
        artist: 'Artist 1',
        url: 'https://example.com/1.mp3',
      ),
    );

    expect(count, 1);
    expect(await dataSource.getCount(), 1);
  });

  test('appendTrack should deduplicate same track key', () async {
    const dataSource = PlayerHistoryDataSource();
    const track = PlayerTrack(
      id: 'song-2',
      title: 'Song 2',
      artist: 'Artist 2',
      url: 'https://example.com/2.mp3',
    );

    await dataSource.appendTrack(track);
    final count = await dataSource.appendTrack(track);

    expect(count, 1);
    expect(await dataSource.getCount(), 1);
  });

  test('listHistory should keep latest track first', () async {
    const dataSource = PlayerHistoryDataSource();
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-1',
        title: 'Song 1',
        artist: 'Artist 1',
        url: 'https://example.com/1.mp3',
      ),
    );
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-2',
        title: 'Song 2',
        artist: 'Artist 2',
        url: 'https://example.com/2.mp3',
      ),
    );

    final list = await dataSource.listHistory();
    expect(list.length, 2);
    expect(list.first.id, 'song-2');
  });

  test('clearHistory should remove all items', () async {
    const dataSource = PlayerHistoryDataSource();
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-1',
        title: 'Song 1',
        artist: 'Artist 1',
        url: 'https://example.com/1.mp3',
      ),
    );

    await dataSource.clearHistory();

    expect(await dataSource.getCount(), 0);
    expect(await dataSource.listHistory(), isEmpty);
  });

  test('appendTrack should persist radio context', () async {
    const dataSource = PlayerHistoryDataSource();
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-radio-1',
        title: 'Radio Song',
        artist: 'Artist 1',
        url: 'https://example.com/radio.mp3',
        platform: 'qq',
      ),
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 3,
      previousPlayModeBeforeRadio: PlayerPlayMode.shuffle,
    );

    final list = await dataSource.listHistory();
    expect(list.single.isRadioMode, isTrue);
    expect(list.single.currentRadioId, 'radio-1');
    expect(list.single.currentRadioPlatform, 'qq');
    expect(list.single.currentRadioPageIndex, 3);
    expect(list.single.previousPlayModeBeforeRadio, PlayerPlayMode.shuffle);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_history_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_history_item.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller_callback.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_history_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试用 ControllerCallback，记录状态更新。
class _FakeCallback implements PlayerControllerCallback {
  PlayerPlaybackState _state = PlayerPlaybackState.initial(const []);

  PlayerPlaybackState? lastUpdatedState;

  @override
  PlayerPlaybackState get currentState => _state;

  @override
  void updateState(
    PlayerPlaybackState Function(PlayerPlaybackState current) updater,
  ) {
    _state = updater(_state);
    lastUpdatedState = _state;
  }
}

const _t1 = PlayerTrack(id: 's1', title: 'Song 1', url: 'https://a.com/1.mp3');
const _t2 = PlayerTrack(id: 's2', title: 'Song 2', url: 'https://a.com/2.mp3');

void main() {
  group('PlayerHistoryManager', () {
    late PlayerHistoryManager manager;
    late _FakeCallback callback;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      manager = PlayerHistoryManager(
        dataSource: const PlayerHistoryDataSource(),
      );
      callback = _FakeCallback();
    });

    group('hydrateHistoryCount', () {
      test('初始状态水合 count 为 0', () async {
        await manager.hydrateHistoryCount(callback);
        expect(callback.lastUpdatedState?.historyCount, 0);
      });

      test('有历史记录时水合正确 count', () async {
        final ds = const PlayerHistoryDataSource();
        await ds.appendTrack(_t1);
        await ds.appendTrack(_t2);

        await manager.hydrateHistoryCount(callback);
        expect(callback.lastUpdatedState?.historyCount, 2);
      });
    });

    group('recordCurrentTrackHistory', () {
      test('track 为 null 返回 false', () async {
        final result = await manager.recordCurrentTrackHistory(
          callback: callback,
          track: null,
          isRadioMode: false,
        );
        expect(result, isFalse);
      });

      test('首次记录返回 true', () async {
        final result = await manager.recordCurrentTrackHistory(
          callback: callback,
          track: _t1,
          isRadioMode: false,
        );
        expect(result, isTrue);
        expect(callback.lastUpdatedState?.historyCount, 1);
      });

      test('重复 track key 返回 false（去重）', () async {
        await manager.recordCurrentTrackHistory(
          callback: callback,
          track: _t1,
          isRadioMode: false,
        );

        final result = await manager.recordCurrentTrackHistory(
          callback: callback,
          track: _t1,
          isRadioMode: false,
        );
        expect(result, isFalse);
      });

      test('不同 track 返回 true', () async {
        await manager.recordCurrentTrackHistory(
          callback: callback,
          track: _t1,
          isRadioMode: false,
        );

        final result = await manager.recordCurrentTrackHistory(
          callback: callback,
          track: _t2,
          isRadioMode: false,
        );
        expect(result, isTrue);
      });

      test('同 id 不同 platform 视为不同 track', () async {
        const trackA = PlayerTrack(
          id: 's1',
          title: 'Song',
          platform: 'netease',
        );
        const trackB = PlayerTrack(id: 's1', title: 'Song', platform: 'qq');

        await manager.recordCurrentTrackHistory(
          callback: callback,
          track: trackA,
          isRadioMode: false,
        );
        final result = await manager.recordCurrentTrackHistory(
          callback: callback,
          track: trackB,
          isRadioMode: false,
        );
        expect(result, isTrue);
      });
    });

    group('historyItemToTrack', () {
      test('基本字段正确映射', () {
        final item = PlayerHistoryItem(
          id: 'h1',
          title: 'History Song',
          artist: 'Artist',
          album: 'Album',
          artworkUrl: 'https://img/cover.jpg',
          url: 'https://cdn/song.mp3',
          playedAt: DateTime.now().millisecondsSinceEpoch,
          platform: 'netease',
        );

        final track = manager.historyItemToTrack(item);

        expect(track.id, 'h1');
        expect(track.title, 'History Song');
        expect(track.artist, 'Artist');
        expect(track.album, 'Album');
        expect(track.artworkUrl, 'https://img/cover.jpg');
        expect(track.platform, 'netease');
      });

      test('album 为空时返回 null', () {
        final item = PlayerHistoryItem(
          id: 'h2',
          title: 'Song',
          artist: 'A',
          album: '',
          artworkUrl: 'https://img/c.jpg',
          url: '',
          playedAt: 0,
        );
        final track = manager.historyItemToTrack(item);
        expect(track.album, isNull);
      });

      test('albumId 为空时返回 null', () {
        final item = PlayerHistoryItem(
          id: 'h3',
          title: 'Song',
          artist: 'A',
          album: 'Alb',
          albumId: '  ',
          artworkUrl: '',
          url: '',
          playedAt: 0,
        );
        final track = manager.historyItemToTrack(item);
        expect(track.albumId, isNull);
      });

      test('artworkUrl 为空时返回 null', () {
        final item = PlayerHistoryItem(
          id: 'h4',
          title: 'Song',
          artist: 'A',
          album: 'Alb',
          artworkUrl: '',
          url: '',
          playedAt: 0,
        );
        final track = manager.historyItemToTrack(item);
        expect(track.artworkUrl, isNull);
      });

      test('platform 为 local 时保留 url', () {
        final item = PlayerHistoryItem(
          id: 'h5',
          title: 'Local',
          artist: 'A',
          album: '',
          artworkUrl: '',
          url: '/music/local.mp3',
          playedAt: 0,
          platform: 'local',
        );
        final track = manager.historyItemToTrack(item);
        expect(track.url, '/music/local.mp3');
      });

      test('platform 非 local 时 url 清空', () {
        final item = PlayerHistoryItem(
          id: 'h6',
          title: 'Online',
          artist: 'A',
          album: '',
          artworkUrl: '',
          url: 'https://cdn/song.mp3',
          playedAt: 0,
          platform: 'netease',
        );
        final track = manager.historyItemToTrack(item);
        expect(track.url, isEmpty);
      });

      test('platform 为空时返回 null', () {
        final item = PlayerHistoryItem(
          id: 'h7',
          title: 'Song',
          artist: 'A',
          album: '',
          artworkUrl: '',
          url: '',
          playedAt: 0,
        );
        final track = manager.historyItemToTrack(item);
        expect(track.platform, isNull);
      });

      test('title 为空时用 id 代替', () {
        final item = PlayerHistoryItem(
          id: 'h8',
          title: '',
          artist: 'A',
          album: '',
          artworkUrl: '',
          url: '',
          playedAt: 0,
        );
        final track = manager.historyItemToTrack(item);
        expect(track.title, 'h8');
      });
    });
  });
}

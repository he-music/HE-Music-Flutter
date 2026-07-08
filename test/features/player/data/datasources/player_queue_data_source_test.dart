import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_snapshot.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const track1 = PlayerTrack(
    id: 's1',
    title: 'Song 1',
    url: 'https://a.com/1.mp3',
  );
  const track2 = PlayerTrack(
    id: 's2',
    title: 'Song 2',
    url: 'https://a.com/2.mp3',
  );
  const track3 = PlayerTrack(
    id: 's3',
    title: 'Song 3',
    url: 'https://a.com/3.mp3',
  );

  const source = PlayerQueueSource(
    routePath: '/playlist',
    queryParameters: {'id': 'p1'},
    title: 'My Playlist',
  );

  group('PlayerQueueDataSource', () {
    test('saveQueue + readQueue 往返应保留完整快照', () async {
      const ds = PlayerQueueDataSource();
      await ds.saveQueue(
        queue: [track1, track2],
        currentIndex: 1,
        playMode: PlayerPlayMode.shuffle,
        isRadioMode: false,
        source: source,
      );

      final result = await ds.readQueue();
      expect(result, isNotNull);
      expect(result!.queue, hasLength(2));
      expect(result.queue.first.id, 's1');
      expect(result.queue.last.id, 's2');
      expect(result.currentIndex, 1);
      expect(result.playMode, PlayerPlayMode.shuffle);
      expect(result.isRadioMode, isFalse);
      expect(result.source, isNotNull);
      expect(result.source!.routePath, '/playlist');
      expect(result.source!.title, 'My Playlist');
    });

    test('readQueue 在无数据时返回 null', () async {
      const ds = PlayerQueueDataSource();
      final result = await ds.readQueue();
      expect(result, isNull);
    });

    test('空队列且无 previousSnapshot 时应清除存储', () async {
      const ds = PlayerQueueDataSource();
      // 先写入数据
      await ds.saveQueue(
        queue: [track1],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );
      expect(await ds.readQueue(), isNotNull);

      // 写入空队列
      await ds.saveQueue(
        queue: [],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );
      expect(await ds.readQueue(), isNull);
    });

    test('clearQueue 应清除所有数据', () async {
      const ds = PlayerQueueDataSource();
      await ds.saveQueue(
        queue: [track1],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );

      await ds.clearQueue();
      expect(await ds.readQueue(), isNull);
    });

    test('currentIndex 超出范围时应夹紧到有效范围', () async {
      const ds = PlayerQueueDataSource();
      await ds.saveQueue(
        queue: [track1, track2],
        currentIndex: 99,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );

      final result = await ds.readQueue();
      expect(result!.currentIndex, 1); // clamp(0, 1)
    });

    test('负 currentIndex 应夹紧到 0', () async {
      const ds = PlayerQueueDataSource();
      await ds.saveQueue(
        queue: [track1],
        currentIndex: -5,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );

      final result = await ds.readQueue();
      expect(result!.currentIndex, 0);
    });

    test('radio 模式字段应正确往返', () async {
      const ds = PlayerQueueDataSource();
      await ds.saveQueue(
        queue: [track1],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: true,
        currentRadioId: 'radio-1',
        currentRadioPlatform: 'qq',
        currentRadioPageIndex: 3,
        previousPlayModeBeforeRadio: PlayerPlayMode.shuffle,
      );

      final result = await ds.readQueue();
      expect(result!.isRadioMode, isTrue);
      expect(result.currentRadioId, 'radio-1');
      expect(result.currentRadioPlatform, 'qq');
      expect(result.currentRadioPageIndex, 3);
      expect(result.previousPlayModeBeforeRadio, PlayerPlayMode.shuffle);
    });

    test('previousSnapshot 应递归保存和恢复', () async {
      const ds = PlayerQueueDataSource();
      final previous = PlayerQueueSnapshot(
        queue: [track3],
        currentIndex: 0,
        playMode: PlayerPlayMode.single,
        isRadioMode: false,
      );
      await ds.saveQueue(
        queue: [track1, track2],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: true,
        previousSnapshot: previous,
      );

      final result = await ds.readQueue();
      expect(result!.previousSnapshot, isNotNull);
      expect(result.previousSnapshot!.queue, hasLength(1));
      expect(result.previousSnapshot!.queue.first.id, 's3');
      expect(result.previousSnapshot!.playMode, PlayerPlayMode.single);
    });

    test('Track 含完整字段时应正确往返', () async {
      const ds = PlayerQueueDataSource();
      const fullTrack = PlayerTrack(
        id: 'full-1',
        title: 'Full Song',
        url: 'https://a.com/full.mp3',
        path: '/local/path.mp3',
        duration: Duration(minutes: 3, seconds: 30),
        artist: 'Artist',
        album: 'Album',
        albumId: 'alb-1',
        mvId: 'mv-1',
        artworkUrl: 'https://a.com/cover.jpg',
        platform: 'qq',
      );

      await ds.saveQueue(
        queue: [fullTrack],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );

      final result = await ds.readQueue();
      final restored = result!.queue.first;
      expect(restored.id, 'full-1');
      expect(restored.title, 'Full Song');
      expect(restored.path, '/local/path.mp3');
      expect(restored.duration, const Duration(minutes: 3, seconds: 30));
      expect(restored.artist, 'Artist');
      expect(restored.album, 'Album');
      expect(restored.albumId, 'alb-1');
      expect(restored.mvId, 'mv-1');
      expect(restored.artworkUrl, 'https://a.com/cover.jpg');
      expect(restored.platform, 'qq');
    });

    test('损坏的 JSON 应返回 null 而非抛异常', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'player_queue_v1': '{invalid json!!!',
      });
      const ds = PlayerQueueDataSource();
      final result = await ds.readQueue();
      expect(result, isNull);
    });

    test('readQueue 应过滤掉缺少 id 或 title 的 track', () async {
      const ds = PlayerQueueDataSource();
      // 写入一条有效 track
      await ds.saveQueue(
        queue: [track1],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );

      // 手动注入包含无效 track 的 JSON
      final prefs = await SharedPreferences.getInstance();
      final raw =
          '{"current_index":0,"play_mode":"sequence","is_radio_mode":false,'
          '"queue":[{"id":"","title":"Empty ID","url":""},{"id":"valid","title":"","url":""},'
          '{"id":"s1","title":"Song 1","url":"https://a.com/1.mp3"}]}';
      await prefs.setString('player_queue_v1', raw);

      final result = await ds.readQueue();
      expect(result, isNotNull);
      expect(result!.queue, hasLength(1));
      expect(result.queue.first.id, 's1');
    });

    test('未知 playMode 应回退到 sequence', () async {
      const ds = PlayerQueueDataSource();
      final prefs = await SharedPreferences.getInstance();
      final raw =
          '{"current_index":0,"play_mode":"unknown_mode","is_radio_mode":false,'
          '"queue":[{"id":"s1","title":"Song 1","url":""}]}';
      await prefs.setString('player_queue_v1', raw);

      final result = await ds.readQueue();
      expect(result!.playMode, PlayerPlayMode.sequence);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_snapshot.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';

void main() {
  group('PlayerQueueSource', () {
    const source = PlayerQueueSource(
      routePath: '/playlist',
      queryParameters: {'id': 'p1', 'type': 'album'},
      title: 'My Playlist',
    );

    test('toMap 应正确序列化所有字段', () {
      final map = source.toMap();
      expect(map['route_path'], '/playlist');
      expect(map['query_parameters'], {'id': 'p1', 'type': 'album'});
      expect(map['title'], 'My Playlist');
    });

    test('fromMap 应正确反序列化', () {
      final result = PlayerQueueSource.fromMap({
        'route_path': '/playlist',
        'query_parameters': {'id': 'p1'},
        'title': 'Test',
      });
      expect(result.routePath, '/playlist');
      expect(result.queryParameters, {'id': 'p1'});
      expect(result.title, 'Test');
    });

    test('toMap + fromMap 往返应保持数据一致', () {
      final map = source.toMap();
      final restored = PlayerQueueSource.fromMap(map);
      expect(restored.routePath, source.routePath);
      expect(restored.queryParameters, source.queryParameters);
      expect(restored.title, source.title);
    });

    test('fromMap 应处理缺失字段（默认空值）', () {
      final result = PlayerQueueSource.fromMap(<String, dynamic>{});
      expect(result.routePath, '');
      expect(result.queryParameters, isEmpty);
      expect(result.title, '');
    });

    test('fromMap 应过滤空 key 和空 value 的 queryParameter', () {
      final result = PlayerQueueSource.fromMap({
        'route_path': '/test',
        'query_parameters': {
          'valid': 'yes',
          '': 'empty-key',
          'empty-value': '',
          'spaces': '  ',
        },
        'title': 'T',
      });
      expect(result.queryParameters, {'valid': 'yes'});
    });

    test('fromMap 应处理非 Map 类型的 query_parameters（忽略）', () {
      final result = PlayerQueueSource.fromMap({
        'route_path': '/test',
        'query_parameters': 'not-a-map',
        'title': 'T',
      });
      expect(result.queryParameters, isEmpty);
    });

    test('isValid 应在 routePath 非空时返回 true', () {
      expect(source.isValid, isTrue);
    });

    test('isValid 应在 routePath 为空时返回 false', () {
      const empty = PlayerQueueSource(
        routePath: '',
        queryParameters: {},
        title: 'T',
      );
      expect(empty.isValid, isFalse);
    });

    test('isValid 应在 routePath 为纯空格时返回 false', () {
      const spaces = PlayerQueueSource(
        routePath: '   ',
        queryParameters: {},
        title: 'T',
      );
      expect(spaces.isValid, isFalse);
    });
  });

  group('PlayerQualityOption', () {
    test('sizeLabel 应在 sizeBytes 为 null 时返回空字符串', () {
      const option = PlayerQualityOption(
        name: '标准',
        quality: 128,
        format: 'mp3',
        url: 'https://a.com/1.mp3',
      );
      expect(option.sizeLabel, '');
    });

    test('sizeLabel 应在 sizeBytes 为 0 时返回空字符串', () {
      const option = PlayerQualityOption(
        name: '标准',
        quality: 128,
        format: 'mp3',
        url: 'https://a.com/1.mp3',
        sizeBytes: 0,
      );
      expect(option.sizeLabel, '');
    });

    test('sizeLabel 应正确格式化字节 (B)', () {
      const option = PlayerQualityOption(
        name: '标准',
        quality: 128,
        format: 'mp3',
        url: 'https://a.com/1.mp3',
        sizeBytes: 512,
      );
      expect(option.sizeLabel, '512 B');
    });

    test('sizeLabel 应正确格式化千字节 (KB)', () {
      const option = PlayerQualityOption(
        name: '标准',
        quality: 128,
        format: 'mp3',
        url: 'https://a.com/1.mp3',
        sizeBytes: 51200, // 50 KB
      );
      expect(option.sizeLabel, '50.0 KB');
    });

    test('sizeLabel 应正确格式化兆字节 (MB) 带一位小数', () {
      // 5 * 1024 * 1024 = 5242880
      const option = PlayerQualityOption(
        name: '高品质',
        quality: 320,
        format: 'mp3',
        url: 'https://a.com/1.mp3',
        sizeBytes: 5242880,
      );
      expect(option.sizeLabel, '5.0 MB');
    });

    test('sizeLabel 应正确格式化吉字节 (GB)', () {
      // 1.5 * 1024^3
      const option = PlayerQualityOption(
        name: '无损',
        quality: 1411,
        format: 'flac',
        url: 'https://a.com/1.flac',
        sizeBytes: 1610612736,
      );
      expect(option.sizeLabel, '1.5 GB');
    });

    test('sizeLabel 当值 >= 100 时应取整', () {
      // 100.5 KB → 应显示整数
      const option = PlayerQualityOption(
        name: '标准',
        quality: 128,
        format: 'mp3',
        url: 'https://a.com/1.mp3',
        sizeBytes: 102912, // ~100.5 KB
      );
      expect(option.sizeLabel, '101 KB');
    });
  });

  group('PlayerTrack', () {
    const track = PlayerTrack(
      id: 's1',
      title: 'Song',
      url: 'https://a.com/1.mp3',
      artist: 'Artist',
      album: 'Album',
      platform: 'netease',
    );

    test('copyWith 应只覆盖指定字段', () {
      final updated = track.copyWith(title: 'New Title');
      expect(updated.id, 's1');
      expect(updated.title, 'New Title');
      expect(updated.artist, 'Artist');
      expect(updated.platform, 'netease');
    });

    test('copyWith 不传参应保持原值', () {
      final copy = track.copyWith();
      expect(copy.id, track.id);
      expect(copy.title, track.title);
      expect(copy.url, track.url);
    });

    test('默认值应正确', () {
      const minimal = PlayerTrack(id: 'x', title: 'T');
      expect(minimal.url, '');
      expect(minimal.path, isNull);
      expect(minimal.links, isEmpty);
      expect(minimal.platform, isNull);
    });
  });

  group('PlayerPlaybackState', () {
    final tracks = [
      const PlayerTrack(id: 's1', title: 'Song 1'),
      const PlayerTrack(id: 's2', title: 'Song 2'),
      const PlayerTrack(id: 's3', title: 'Song 3'),
    ];

    test('initial 应创建正确的初始状态', () {
      final state = PlayerPlaybackState.initial(tracks);
      expect(state.queue, tracks);
      expect(state.currentIndex, 0);
      expect(state.isPlaying, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.position, Duration.zero);
      expect(state.volume, 1.0);
      expect(state.speed, 1.0);
      expect(state.playMode, PlayerPlayMode.sequence);
      expect(state.isRadioMode, isFalse);
    });

    test('currentTrack 应返回当前索引对应的曲目', () {
      final state = PlayerPlaybackState.initial(tracks);
      expect(state.currentTrack?.id, 's1');
    });

    test('currentTrack 应在索引越界时返回 null', () {
      final state = PlayerPlaybackState.initial(
        tracks,
      ).copyWith(currentIndex: 99);
      expect(state.currentTrack, isNull);
    });

    test('currentTrack 应在队列为空时返回 null', () {
      final state = PlayerPlaybackState.initial([]);
      expect(state.currentTrack, isNull);
    });

    test('currentTrack 应在 currentIndex 为负数时返回 null', () {
      final state = PlayerPlaybackState.initial(
        tracks,
      ).copyWith(currentIndex: -1);
      expect(state.currentTrack, isNull);
    });

    test('copyWith 应正确覆盖字段', () {
      final state = PlayerPlaybackState.initial(tracks);
      final updated = state.copyWith(
        isPlaying: true,
        position: const Duration(seconds: 30),
        volume: 0.8,
      );
      expect(updated.isPlaying, isTrue);
      expect(updated.position, const Duration(seconds: 30));
      expect(updated.volume, 0.8);
      // 未指定的字段应保持原值
      expect(updated.queue, tracks);
      expect(updated.currentIndex, 0);
    });

    test('copyWith clear 标志应将可选字段置为 null', () {
      final state = PlayerPlaybackState.initial(tracks).copyWith(
        queueSource: const PlayerQueueSource(
          routePath: '/p',
          queryParameters: {},
          title: 'T',
        ),
        errorMessage: 'error',
      );
      expect(state.queueSource, isNotNull);
      expect(state.errorMessage, 'error');

      final cleared = state.copyWith(clearQueueSource: true, clearError: true);
      expect(cleared.queueSource, isNull);
      expect(cleared.errorMessage, isNull);
    });

    test('copyWith 应支持清除所有可选字段', () {
      final state = PlayerPlaybackState.initial(tracks).copyWith(
        currentSelectedQualityName: 'hq',
        currentRadioId: 'r1',
        currentRadioPlatform: 'netease',
        currentRadioPageIndex: 2,
        previousPlayModeBeforeRadio: PlayerPlayMode.shuffle,
      );
      final cleared = state.copyWith(
        clearCurrentSelectedQuality: true,
        clearCurrentRadioId: true,
        clearCurrentRadioPlatform: true,
        clearCurrentRadioPageIndex: true,
        clearPreviousPlayModeBeforeRadio: true,
      );
      expect(cleared.currentSelectedQualityName, isNull);
      expect(cleared.currentRadioId, isNull);
      expect(cleared.currentRadioPlatform, isNull);
      expect(cleared.currentRadioPageIndex, isNull);
      expect(cleared.previousPlayModeBeforeRadio, isNull);
    });
  });

  group('PlayerPlayMode', () {
    test('应包含三个枚举值', () {
      expect(PlayerPlayMode.values, hasLength(3));
      expect(PlayerPlayMode.values, contains(PlayerPlayMode.sequence));
      expect(PlayerPlayMode.values, contains(PlayerPlayMode.shuffle));
      expect(PlayerPlayMode.values, contains(PlayerPlayMode.single));
    });
  });

  group('PlayerQueueSnapshot', () {
    test('isEmpty 应在队列为空时返回 true', () {
      const snapshot = PlayerQueueSnapshot(
        queue: [],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );
      expect(snapshot.isEmpty, isTrue);
    });

    test('isEmpty 应在队列非空时返回 false', () {
      final snapshot = PlayerQueueSnapshot(
        queue: [const PlayerTrack(id: 's1', title: 'Song')],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );
      expect(snapshot.isEmpty, isFalse);
    });
  });
}

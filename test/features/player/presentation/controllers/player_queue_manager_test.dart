import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller_callback.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_queue_manager.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_quality_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlayerQueueManager _buildManager({
  Future<dynamic> Function(String, String, int)? fetchRadioSongs,
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final qualityManager = PlayerQualityManager(
    platformsReader: () => [],
    configReader: () => throw UnimplementedError(),
  );
  return PlayerQueueManager(
    dataSource: const PlayerQueueDataSource(),
    qualityManager: qualityManager,
    fetchRadioSongs: fetchRadioSongs ?? (a, b, c) async => [],
  );
}

const _t1 = PlayerTrack(id: 's1', title: 'Song 1', url: 'https://a.com/1.mp3');
const _t2 = PlayerTrack(id: 's2', title: 'Song 2', url: 'https://a.com/2.mp3');
const _t3 = PlayerTrack(id: 's3', title: 'Song 3', url: 'https://a.com/3.mp3');
const _localTrack = PlayerTrack(
  id: 'ls1',
  title: 'Local',
  path: '/music/local.mp3',
  platform: 'local',
);

PlayerPlaybackState _state({
  List<PlayerTrack> queue = const [_t1, _t2, _t3],
  int currentIndex = 0,
  PlayerPlayMode playMode = PlayerPlayMode.sequence,
  bool isRadioMode = false,
  String? radioId,
  String? radioPlatform,
  int? radioPageIndex,
  PlayerPlayMode? previousPlayMode,
  Duration duration = Duration.zero,
}) {
  return PlayerPlaybackState(
    queue: queue,
    currentIndex: currentIndex,
    historyCount: 0,
    isPlaying: false,
    isLoading: false,
    position: Duration.zero,
    duration: duration,
    volume: 1.0,
    speed: 1.0,
    playMode: playMode,
    currentAvailableQualities: const [],
    isRadioMode: isRadioMode,
    currentRadioId: radioId,
    currentRadioPlatform: radioPlatform,
    currentRadioPageIndex: radioPageIndex,
    previousPlayModeBeforeRadio: previousPlayMode,
  );
}

void main() {
  group('PlayerQueueManager', () {
    late PlayerQueueManager manager;

    setUp(() {
      manager = _buildManager();
    });

    group('trackKey', () {
      test('在线曲目应返回 id|platform', () {
        final key = manager.trackKey(
          const PlayerTrack(id: 's1', title: 'T', platform: 'netease'),
        );
        expect(key, 's1|netease');
      });

      test('本地曲目应返回 id', () {
        final key = manager.trackKey(_localTrack);
        expect(key, 'ls1');
      });

      test('无 platform 应返回 id', () {
        final key = manager.trackKey(const PlayerTrack(id: 's1', title: 'T'));
        expect(key, 's1');
      });

      test('空 id 应返回空字符串', () {
        final key = manager.trackKey(const PlayerTrack(id: '  ', title: 'T'));
        expect(key, '');
      });
    });

    group('resolveTrack', () {
      test('有效索引应返回对应曲目', () {
        expect(manager.resolveTrack([_t1, _t2], 1)?.id, 's2');
      });

      test('负索引应返回 null', () {
        expect(manager.resolveTrack([_t1], -1), isNull);
      });

      test('越界索引应返回 null', () {
        expect(manager.resolveTrack([_t1], 5), isNull);
      });
    });

    group('safeCurrentIndex', () {
      test('空队列应返回 0', () {
        expect(manager.safeCurrentIndex(_state(), 0), 0);
      });

      test('有效索引应保持原值', () {
        expect(manager.safeCurrentIndex(_state(currentIndex: 2), 3), 2);
      });

      test('越界索引应回退到 0', () {
        expect(manager.safeCurrentIndex(_state(currentIndex: 99), 3), 0);
      });

      test('负索引应回退到 0', () {
        expect(manager.safeCurrentIndex(_state(currentIndex: -1), 3), 0);
      });
    });

    group('validateQueueInput', () {
      test('空队列应抛出 ValidationFailure', () {
        expect(
          () => manager.validateQueueInput([], 0),
          throwsA(isA<AppException>()),
        );
      });

      test('startIndex 越界应抛出 ValidationFailure', () {
        expect(
          () => manager.validateQueueInput([_t1], 5),
          throwsA(isA<AppException>()),
        );
      });

      test('有效输入不应抛出', () {
        expect(
          () => manager.validateQueueInput([_t1, _t2], 1),
          returnsNormally,
        );
      });
    });

    group('isSameQueueContext', () {
      test('相同队列和来源应返回 true', () {
        const source = PlayerQueueSource(
          routePath: '/p',
          queryParameters: {'id': '1'},
          title: 'T',
        );
        final state = _state().copyWith(queueSource: source);
        expect(
          manager.isSameQueueContext(state, [_t1, _t2, _t3], source),
          isTrue,
        );
      });

      test('不同队列长度应返回 false', () {
        expect(manager.isSameQueueContext(_state(), [_t1, _t2], null), isFalse);
      });

      test('空队列应返回 false', () {
        expect(
          manager.isSameQueueContext(_state(queue: []), [], null),
          isFalse,
        );
      });
    });

    group('isSameRadioContext', () {
      test('两者均非电台模式应返回 true', () {
        expect(
          manager.isSameRadioContext(_state(), isRadioMode: false),
          isTrue,
        );
      });

      test('相同电台参数应返回 true', () {
        final state = _state(
          isRadioMode: true,
          radioId: 'r1',
          radioPlatform: 'qq',
          radioPageIndex: 2,
        );
        expect(
          manager.isSameRadioContext(
            state,
            isRadioMode: true,
            currentRadioId: 'r1',
            currentRadioPlatform: 'qq',
            currentRadioPageIndex: 2,
          ),
          isTrue,
        );
      });

      test('不同电台 id 应返回 false', () {
        final state = _state(
          isRadioMode: true,
          radioId: 'r1',
          radioPlatform: 'qq',
        );
        expect(
          manager.isSameRadioContext(
            state,
            isRadioMode: true,
            currentRadioId: 'r2',
            currentRadioPlatform: 'qq',
          ),
          isFalse,
        );
      });
    });

    group('resolveNextPlayMode', () {
      test('进入电台应返回 sequence', () {
        expect(
          manager.resolveNextPlayMode(
            _state(playMode: PlayerPlayMode.shuffle),
            isRadioMode: true,
          ),
          PlayerPlayMode.sequence,
        );
      });

      test('退出电台应恢复之前的播放模式', () {
        final state = _state(
          isRadioMode: true,
          playMode: PlayerPlayMode.sequence,
          previousPlayMode: PlayerPlayMode.shuffle,
        );
        expect(
          manager.resolveNextPlayMode(state, isRadioMode: false),
          PlayerPlayMode.shuffle,
        );
      });

      test('非电台模式应保持当前播放模式', () {
        expect(
          manager.resolveNextPlayMode(
            _state(playMode: PlayerPlayMode.single),
            isRadioMode: false,
          ),
          PlayerPlayMode.single,
        );
      });
    });

    group('resolvePreviousPlayModeBeforeRadio', () {
      test('进入电台（首次）应记录当前播放模式', () {
        expect(
          manager.resolvePreviousPlayModeBeforeRadio(
            _state(playMode: PlayerPlayMode.shuffle),
            isRadioMode: true,
          ),
          PlayerPlayMode.shuffle,
        );
      });

      test('已在电台模式应保持之前的记录', () {
        final state = _state(
          isRadioMode: true,
          previousPlayMode: PlayerPlayMode.single,
        );
        expect(
          manager.resolvePreviousPlayModeBeforeRadio(state, isRadioMode: true),
          PlayerPlayMode.single,
        );
      });

      test('非电台模式应返回 null', () {
        expect(
          manager.resolvePreviousPlayModeBeforeRadio(
            _state(),
            isRadioMode: false,
          ),
          isNull,
        );
      });
    });

    group('normalizeRadioValue', () {
      test('null 应返回 null', () {
        expect(manager.normalizeRadioValue(null), isNull);
      });

      test('空字符串应返回 null', () {
        expect(manager.normalizeRadioValue(''), isNull);
      });

      test('纯空格应返回 null', () {
        expect(manager.normalizeRadioValue('   '), isNull);
      });

      test('有值应返回 trimmed 结果', () {
        expect(manager.normalizeRadioValue('  r1  '), 'r1');
      });
    });

    group('normalizeRadioPageIndex', () {
      test('null 应返回 null', () {
        expect(manager.normalizeRadioPageIndex(null), isNull);
      });

      test('0 应返回 null', () {
        expect(manager.normalizeRadioPageIndex(0), isNull);
      });

      test('负数应返回 null', () {
        expect(manager.normalizeRadioPageIndex(-1), isNull);
      });

      test('正数应返回原值', () {
        expect(manager.normalizeRadioPageIndex(3), 3);
      });
    });

    group('buildCurrentQueueSnapshot', () {
      test('空队列应返回 null', () {
        expect(manager.buildCurrentQueueSnapshot(_state(queue: [])), isNull);
      });

      test('非空队列应构建正确快照', () {
        final state = _state(currentIndex: 1);
        final snapshot = manager.buildCurrentQueueSnapshot(state);
        expect(snapshot, isNotNull);
        expect(snapshot!.queue, hasLength(3));
        expect(snapshot.currentIndex, 1);
        expect(snapshot.playMode, PlayerPlayMode.sequence);
      });
    });

    group('hydrateQueue', () {
      test('恢复非空队列时不覆盖音频流已写入的时长', () async {
        await manager.persistQueueState(_FakeCallback(_state(currentIndex: 1)));
        final callback = _FakeCallback(
          _state(queue: const [], duration: const Duration(minutes: 2)),
        );

        final snapshot = await manager.hydrateQueue(callback);

        expect(snapshot?.currentIndex, 1);
        expect(callback.currentState.duration, const Duration(minutes: 2));
      });
    });
  });
}

class _FakeCallback implements PlayerControllerCallback {
  _FakeCallback(this._state);

  PlayerPlaybackState _state;

  @override
  PlayerPlaybackState get currentState => _state;

  @override
  void updateState(
    PlayerPlaybackState Function(PlayerPlaybackState current) updater,
  ) {
    _state = updater(_state);
  }
}

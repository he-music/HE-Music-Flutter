import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/audio_handler_player_adapter.dart';
import 'package:he_music_flutter/core/audio/audio_player_port.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_history_item.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_playback_api_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/radio/presentation/providers/radio_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('并发初始化期间应保持持久化歌曲且只绑定一次播放流', () async {
    const queueDataSource = PlayerQueueDataSource();
    await queueDataSource.saveQueue(
      queue: _buildQueue(),
      currentIndex: 1,
      playMode: PlayerPlayMode.sequence,
      isRadioMode: false,
    );
    final pendingQueueLoad = Completer<void>();
    final audioPlayer = _ReplayingStartupAudioPlayerPort()
      ..setQueueCompleter = pendingQueueLoad;
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(audioPlayer.dispose);
    final controller = container.read(playerControllerProvider.notifier);

    final first = controller.initialize();
    await audioPlayer.setQueueStarted.future;
    expect(container.read(playerControllerProvider).currentTrack?.id, 'song-2');
    final visibleTrackIds = <String?>[];
    final subscription = container.listen(playerControllerProvider, (
      previous,
      next,
    ) {
      visibleTrackIds.add(next.currentTrack?.id);
    });
    addTearDown(subscription.close);

    final second = controller.initialize();
    expect(identical(first, second), isTrue);
    pendingQueueLoad.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(audioPlayer.currentIndexListenCount, 1);
    expect(audioPlayer.setShuffleCallCount, 2);
    expect(audioPlayer.setQueueCallCount, 1);
    expect(visibleTrackIds, isNot(contains('song-1')));
    expect(visibleTrackIds, isNot(contains(null)));
    expect(container.read(playerControllerProvider).currentTrack?.id, 'song-2');
  });

  test(
    'playAt should ignore stale failure from previous track switch',
    () async {
      final apiClient = _FakeOnlineApiClient(
        handlers: <String, Future<Map<String, dynamic>> Function()>{
          'song-1': () async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            throw Exception('stale network error');
          },
          'song-2': () async => const <String, dynamic>{
            'url': 'https://example.com/song-2.mp3',
          },
        },
      );
      final audioPlayer = _FakeAudioPlayerPort();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          audioPlayerPortProvider.overrideWithValue(audioPlayer),
          playerPlaybackApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.replaceQueue(
        _buildQueue(),
        startIndex: 1,
        autoplay: false,
      );

      final staleFuture = controller.playAt(0).catchError((Object _) {});
      final latestFuture = controller.playAt(1);

      await latestFuture;
      await staleFuture;

      final state = container.read(playerControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.currentTrack?.id, 'song-2');
      expect(state.currentTrack?.url, isEmpty);
      expect(state.errorMessage, isNull);
      expect(audioPlayer.lastQueueInitialIndex, 1);
      expect(audioPlayer.lastQueueTracks[1].url, isEmpty);
    },
  );

  test('replaceQueue 应同步未解析的远程轨道给音频层', () async {
    final apiClient = _FakeOnlineApiClient(
      handlers: <String, _SongUrlHandler>{},
    );
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
        playerPlaybackApiClientProvider.overrideWithValue(apiClient),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueue(
      _buildQueue(),
      startIndex: 0,
      autoplay: false,
    );

    expect(apiClient.requests, isEmpty);
    expect(audioPlayer.lastQueueTracks.first.platform, 'qq');
    expect(audioPlayer.lastQueueTracks.first.url, isEmpty);
  });

  test('playAt 在底层队列装载成功前保留正式 currentIndex', () async {
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueue(
      _buildQueue(),
      startIndex: 0,
      autoplay: false,
    );
    audioPlayer.emitDuration(const Duration(minutes: 2));
    await Future<void>.delayed(Duration.zero);
    final pendingLoad = Completer<void>();
    audioPlayer.setQueueCompleter = pendingLoad;

    final switching = controller.playAt(1);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(playerControllerProvider).currentIndex, 0);
    expect(container.read(playerControllerProvider).currentTrack?.id, 'song-1');

    audioPlayer.emitDuration(null);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(playerControllerProvider).duration,
      const Duration(minutes: 2),
    );

    audioPlayer.emitPlaying(true);
    audioPlayer.emitDuration(const Duration(minutes: 3));
    await Future<void>.delayed(Duration.zero);

    pendingLoad.complete();
    await switching;

    final state = container.read(playerControllerProvider);
    expect(state.currentIndex, 1);
    expect(state.currentTrack?.id, 'song-2');
    expect(state.isPlaying, isTrue);
    expect(state.duration, const Duration(minutes: 3));
  });

  test('currentIndex 切换时保留时长直到音频流报告新值', () async {
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueue(
      _buildQueue(),
      startIndex: 0,
      autoplay: false,
    );
    audioPlayer.emitCurrentIndex(0);
    audioPlayer.emitDuration(const Duration(minutes: 2));
    await Future<void>.delayed(Duration.zero);

    audioPlayer.emitCurrentIndex(1);
    audioPlayer.emitDuration(null);
    audioPlayer.emitDuration(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    var state = container.read(playerControllerProvider);
    expect(state.currentIndex, 1);
    expect(state.duration, const Duration(minutes: 2));

    audioPlayer.emitDuration(const Duration(minutes: 3));
    await Future<void>.delayed(Duration.zero);
    state = container.read(playerControllerProvider);
    expect(state.duration, const Duration(minutes: 3));
  });

  group('manualSkipTarget', () {
    test('pending 立即更新展示歌曲但不改变正式歌曲', () async {
      final harness = await _createTargetPreviewHarness();

      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 10, targetIndex: 1),
      );
      await Future<void>.delayed(Duration.zero);

      final state = harness.container.read(playerControllerProvider);
      expect(state.currentIndex, 0);
      expect(state.currentTrack?.id, 'song-1');
      expect(state.requestedTrackIndex, 1);
      expect(state.requestedTrack?.id, 'song-2');
      expect(state.displayTrack?.id, 'song-2');
      expect(state.requestedTransitionId, 10);
      expect(state.isTrackTransitioning, isTrue);
    });

    test('同一 transition 可从未知目标更新为准确目标', () async {
      final harness = await _createTargetPreviewHarness();

      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 11),
      );
      await Future<void>.delayed(Duration.zero);
      var state = harness.container.read(playerControllerProvider);
      expect(state.requestedTrackIndex, isNull);
      expect(state.requestedTransitionId, 11);
      expect(state.displayTrack?.id, 'song-1');

      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 11, targetIndex: 2),
      );
      await Future<void>.delayed(Duration.zero);
      state = harness.container.read(playerControllerProvider);
      expect(state.requestedTrackIndex, 2);
      expect(state.displayTrack?.id, 'song-3');
    });

    test('新 transition 替换旧目标且陈旧 pending 和 clear 均被忽略', () async {
      final harness = await _createTargetPreviewHarness();

      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 20, targetIndex: 1),
      );
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 21, targetIndex: 2),
      );
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 20, targetIndex: 0),
      );
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 20, status: 'cleared'),
      );
      await Future<void>.delayed(Duration.zero);

      final state = harness.container.read(playerControllerProvider);
      expect(state.requestedTransitionId, 21);
      expect(state.requestedTrackIndex, 2);
      expect(state.displayTrack?.id, 'song-3');
    });

    test('非法状态、transition、索引和歌曲身份不会污染当前目标', () async {
      final harness = await _createTargetPreviewHarness();
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 30, targetIndex: 1),
      );
      await Future<void>.delayed(Duration.zero);

      final invalidEvents = <Map<String, dynamic>>[
        _manualSkipTargetEvent(
          transitionId: 31,
          targetIndex: 2,
          status: 'loading',
        ),
        <String, dynamic>{
          ..._manualSkipTargetEvent(transitionId: 31, targetIndex: 2),
          'transitionId': '31',
        },
        _manualSkipTargetEvent(transitionId: -1, targetIndex: 2),
        _manualSkipTargetEvent(transitionId: 31, targetIndex: -1),
        _manualSkipTargetEvent(transitionId: 31, targetIndex: 99),
        <String, dynamic>{
          ..._manualSkipTargetEvent(transitionId: 31, targetIndex: 2),
          'targetTrackId': 'other-song',
        },
        <String, dynamic>{
          ..._manualSkipTargetEvent(transitionId: 31, targetIndex: 2),
          'targetTrackPlatform': 'netease',
        },
        <String, dynamic>{
          ..._manualSkipTargetEvent(transitionId: 31),
          'targetTrackId': 'song-3',
        },
      ];
      for (final event in invalidEvents) {
        harness.audioPlayer.emitCustomEvent(event);
      }
      await Future<void>.delayed(Duration.zero);

      final state = harness.container.read(playerControllerProvider);
      expect(state.requestedTransitionId, 30);
      expect(state.requestedTrackIndex, 1);
      expect(state.displayTrack?.id, 'song-2');
    });

    test('同代及更新代 clear 会回退正式歌曲并阻止同代目标复活', () async {
      final harness = await _createTargetPreviewHarness();
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 40, targetIndex: 1),
      );
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 40, status: 'cleared'),
      );
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 40, targetIndex: 2),
      );
      await Future<void>.delayed(Duration.zero);

      var state = harness.container.read(playerControllerProvider);
      expect(state.requestedTrackIndex, isNull);
      expect(state.requestedTransitionId, isNull);
      expect(state.displayTrack?.id, 'song-1');

      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 41, targetIndex: 2),
      );
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 42, status: 'cleared'),
      );
      await Future<void>.delayed(Duration.zero);
      state = harness.container.read(playerControllerProvider);
      expect(state.isTrackTransitioning, isFalse);
      expect(state.displayTrack?.id, 'song-1');
    });

    test('活跃 queueState 保留 pending，正式提交原子更新并清理', () async {
      final harness = await _createTargetPreviewHarness();
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 50, targetIndex: 2),
      );
      await Future<void>.delayed(Duration.zero);

      harness.audioPlayer.emitCustomEvent(
        _queueStateEvent(
          transitionId: 50,
          currentIndex: 0,
          manualSkipTargetActive: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      var state = harness.container.read(playerControllerProvider);
      expect(state.currentTrack?.id, 'song-1');
      expect(state.displayTrack?.id, 'song-3');
      expect(state.isTrackTransitioning, isTrue);

      harness.audioPlayer.emitCustomEvent(
        _queueStateEvent(
          transitionId: 50,
          currentIndex: 2,
          manualSkipTargetActive: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      state = harness.container.read(playerControllerProvider);
      expect(state.currentIndex, 2);
      expect(state.currentTrack?.id, 'song-3');
      expect(state.displayTrack?.id, 'song-3');
      expect(state.requestedTransitionId, isNull);
      expect(state.isTrackTransitioning, isFalse);

      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 50, targetIndex: 1),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        harness.container.read(playerControllerProvider).displayTrack?.id,
        'song-3',
      );
    });

    test('pending 期间的播放流状态在 queueState 提交后保持最新值', () async {
      final harness = await _createTargetPreviewHarness();
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 60, targetIndex: 1),
      );
      harness.audioPlayer.emitPlaying(true);
      harness.audioPlayer.emitLoading(true);
      harness.audioPlayer.emitPosition(const Duration(milliseconds: 500));
      harness.audioPlayer.emitPosition(const Duration(seconds: 18));
      harness.audioPlayer.emitDuration(const Duration(minutes: 4));
      await Future<void>.delayed(Duration.zero);

      harness.audioPlayer.emitCustomEvent(
        _queueStateEvent(
          transitionId: 60,
          currentIndex: 1,
          manualSkipTargetActive: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = harness.container.read(playerControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.isPlaying, isTrue);
      expect(state.isLoading, isTrue);
      expect(state.position, const Duration(seconds: 18));
      expect(state.duration, const Duration(minutes: 4));
    });

    test('currentIndex 正式提交会清理目标并拒绝同代迟到事件', () async {
      final harness = await _createTargetPreviewHarness();
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 70, targetIndex: 1),
      );
      await Future<void>.delayed(Duration.zero);
      harness.audioPlayer.emitCurrentIndex(1);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      var state = harness.container.read(playerControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.requestedTransitionId, isNull);
      expect(state.displayTrack?.id, 'song-2');

      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 70, targetIndex: 2),
      );
      await Future<void>.delayed(Duration.zero);
      state = harness.container.read(playerControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.requestedTransitionId, isNull);
      expect(state.displayTrack?.id, 'song-2');
    });

    test('空队列正式快照安全清理请求目标和展示歌曲', () async {
      final harness = await _createTargetPreviewHarness();
      harness.audioPlayer.emitCustomEvent(
        _manualSkipTargetEvent(transitionId: 80, targetIndex: 1),
      );
      await Future<void>.delayed(Duration.zero);

      harness.audioPlayer.emitCustomEvent(
        _queueStateEvent(
          transitionId: 80,
          currentIndex: 0,
          manualSkipTargetActive: false,
          tracks: const <Map<String, dynamic>>[],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = harness.container.read(playerControllerProvider);
      expect(state.queue, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.currentTrack, isNull);
      expect(state.requestedTrack, isNull);
      expect(state.displayTrack, isNull);
      expect(state.isTrackTransitioning, isFalse);
    });
  });

  test('切换音质时应委托音频层刷新 source，而不是在 controller 重新请求链接', () async {
    final apiClient = _FakeOnlineApiClient(
      handlers: <String, _SongUrlHandler>{},
    );
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
        playerPlaybackApiClientProvider.overrideWithValue(apiClient),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueue(
      _buildQualityQueue(),
      startIndex: 0,
      autoplay: false,
    );
    await controller.switchCurrentQualityByName('FLAC');

    expect(apiClient.requests, isEmpty);
    expect(audioPlayer.setSourceCallCount, 1);
    expect(audioPlayer.lastSetSourceTrack?.url, isEmpty);
    expect(
      container.read(playerControllerProvider).currentSelectedQualityName,
      'FLAC',
    );
  });

  test(
    'playAt should ignore stale success from previous track switch',
    () async {
      final apiClient = _FakeOnlineApiClient(
        handlers: <String, Future<Map<String, dynamic>> Function()>{
          'song-1': () async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return const <String, dynamic>{
              'url': 'https://example.com/song-1.mp3',
            };
          },
        },
      );
      final audioPlayer = _FakeAudioPlayerPort();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          audioPlayerPortProvider.overrideWithValue(audioPlayer),
          playerPlaybackApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.replaceQueue(
        _buildQueue(),
        startIndex: 1,
        autoplay: false,
      );

      final staleFuture = controller.playAt(0);
      final latestFuture = controller.playAt(1);

      await Future.wait(<Future<void>>[staleFuture, latestFuture]);

      final state = container.read(playerControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.currentTrack?.id, 'song-2');
      expect(state.currentTrack?.url, isEmpty);
      expect(state.errorMessage, isNull);
      expect(audioPlayer.lastQueueInitialIndex, 1);
      expect(audioPlayer.lastQueueTracks[1].id, 'song-2');
      expect(audioPlayer.lastQueueTracks[1].url, isEmpty);
    },
  );

  test(
    'replaceQueue should force sequence in radio mode and restore on exit',
    () async {
      final apiClient = _FakeOnlineApiClient(
        handlers: <String, Future<Map<String, dynamic>> Function()>{
          'song-1': () async => const <String, dynamic>{
            'url': 'https://example.com/song-1.mp3',
          },
          'song-2': () async => const <String, dynamic>{
            'url': 'https://example.com/song-2.mp3',
          },
          'song-3': () async => const <String, dynamic>{
            'url': 'https://example.com/song-3.mp3',
          },
        },
      );
      final audioPlayer = _FakeAudioPlayerPort();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          audioPlayerPortProvider.overrideWithValue(audioPlayer),
          playerPlaybackApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.setPlayMode(PlayerPlayMode.shuffle);
      await controller.replaceQueue(
        _buildQueue(),
        startIndex: 0,
        autoplay: false,
        isRadioMode: true,
        currentRadioId: 'radio-1',
        currentRadioPlatform: 'qq',
        currentRadioPageIndex: 1,
      );

      var state = container.read(playerControllerProvider);
      expect(state.isRadioMode, isTrue);
      expect(state.playMode, PlayerPlayMode.sequence);
      expect(state.previousPlayModeBeforeRadio, PlayerPlayMode.shuffle);

      await controller.insertNextTrack(
        const PlayerTrack(id: 'song-3', title: '第三首', platform: 'qq'),
      );

      state = container.read(playerControllerProvider);
      expect(state.isRadioMode, isFalse);
      expect(state.playMode, PlayerPlayMode.shuffle);
      expect(state.previousPlayModeBeforeRadio, isNull);
    },
  );

  test('radio completion on last track should append next page once', () async {
    final apiClient = _FakeOnlineApiClient(
      handlers: <String, Future<Map<String, dynamic>> Function()>{
        'song-1': () async => const <String, dynamic>{
          'url': 'https://example.com/song-1.mp3',
        },
        'song-2': () async => const <String, dynamic>{
          'url': 'https://example.com/song-2.mp3',
        },
        'song-3': () async => const <String, dynamic>{
          'url': 'https://example.com/song-3.mp3',
        },
      },
    );
    final radioApiClient = _FakeRadioApiClient(
      pages: <int, List<SongInfo>>{
        2: const <SongInfo>[
          SongInfo(
            name: '第三首',
            subtitle: '',
            id: 'song-3',
            duration: 1000,
            mvId: '',
            album: null,
            artists: <SongInfoArtistInfo>[
              SongInfoArtistInfo(id: 'a-1', name: '歌手'),
            ],
            links: <LinkInfo>[],
            platform: 'qq',
            cover: '',
            sublist: <SongInfo>[],
            originalType: 0,
          ),
        ],
      },
    );
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
        playerPlaybackApiClientProvider.overrideWithValue(apiClient),
        radioApiClientProvider.overrideWithValue(radioApiClient),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueue(
      _buildQueue(),
      startIndex: 1,
      autoplay: false,
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );

    audioPlayer.emitCompleted(true);
    audioPlayer.emitCompleted(true);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(playerControllerProvider);
    expect(radioApiClient.requestedPages, <int>[2]);
    expect(state.currentRadioPageIndex, 2);
    expect(state.queue.map((track) => track.id), <String>[
      'song-1',
      'song-2',
      'song-3',
    ]);
  });

  test('replaceQueue radio mode passes radio params to audio player', () async {
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueue(
      _buildQueue(),
      startIndex: 0,
      autoplay: false,
      isRadioMode: true,
      currentRadioId: 'radio-42',
      currentRadioPlatform: 'netease',
      currentRadioPageIndex: 3,
    );

    expect(audioPlayer.lastSetQueueIsRadioMode, isTrue);
    expect(audioPlayer.lastSetQueueRadioId, 'radio-42');
    expect(audioPlayer.lastSetQueueRadioPlatform, 'netease');
    expect(audioPlayer.lastSetQueueRadioPageIndex, 3);
  });

  test('audio handler adapter 模式下电台预取应由 handler 执行一次', () async {
    final radioRequestPages = <int>[];
    final audioPlayer = AudioHandlerPlayerAdapter(
      HeAudioHandler(
        fetchSongUrlOverride:
            ({
              required String songId,
              required String platform,
              int? quality,
              String? format,
            }) async => <String, dynamic>{
              'url': 'https://example.com/$songId.mp3',
            },
        fetchRadioSongsOverride:
            ({
              required String id,
              required String platform,
              int pageIndex = 1,
              int pageSize = 50,
            }) async {
              radioRequestPages.add(pageIndex);
              return const <SongInfo>[];
            },
        setAudioSourceOverride: (source, player) async => null,
        playOverride: (player) async {},
        disposeOverride: (player) async {},
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.replaceQueue(
      _buildQueue(),
      startIndex: 1,
      autoplay: false,
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );

    await controller.initialize();

    expect(radioRequestPages, <int>[2]);
  });

  test('playHistoryItem should restore radio queue and radio mode', () async {
    final apiClient = _FakeOnlineApiClient(
      handlers: <String, Future<Map<String, dynamic>> Function()>{
        'song-10': () async => const <String, dynamic>{
          'url': 'https://example.com/song-10.mp3',
        },
        'song-11': () async => const <String, dynamic>{
          'url': 'https://example.com/song-11.mp3',
        },
      },
    );
    final radioApiClient = _FakeRadioApiClient(
      pages: <int, List<SongInfo>>{
        3: const <SongInfo>[
          SongInfo(
            name: '历史歌一',
            subtitle: '',
            id: 'song-10',
            duration: 1000,
            mvId: '',
            album: null,
            artists: <SongInfoArtistInfo>[
              SongInfoArtistInfo(id: 'a-1', name: '歌手'),
            ],
            links: <LinkInfo>[],
            platform: 'qq',
            cover: '',
            sublist: <SongInfo>[],
            originalType: 0,
          ),
          SongInfo(
            name: '历史歌二',
            subtitle: '',
            id: 'song-11',
            duration: 1000,
            mvId: '',
            album: null,
            artists: <SongInfoArtistInfo>[
              SongInfoArtistInfo(id: 'a-1', name: '歌手'),
            ],
            links: <LinkInfo>[],
            platform: 'qq',
            cover: '',
            sublist: <SongInfo>[],
            originalType: 0,
          ),
        ],
      },
    );
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        audioPlayerPortProvider.overrideWithValue(audioPlayer),
        playerPlaybackApiClientProvider.overrideWithValue(apiClient),
        radioApiClientProvider.overrideWithValue(radioApiClient),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.setPlayMode(PlayerPlayMode.shuffle);
    await controller.playHistoryItem(
      const PlayerHistoryItem(
        id: 'song-11',
        title: '历史歌二',
        artist: '歌手',
        album: '',
        artworkUrl: '',
        url: '',
        playedAt: 1,
        platform: 'qq',
        isRadioMode: true,
        currentRadioId: 'radio-2',
        currentRadioPlatform: 'qq',
        currentRadioPageIndex: 3,
      ),
    );

    final state = container.read(playerControllerProvider);
    expect(state.isRadioMode, isTrue);
    expect(state.currentRadioId, 'radio-2');
    expect(state.currentRadioPageIndex, 3);
    expect(state.currentIndex, 1);
    expect(state.playMode, PlayerPlayMode.sequence);
    expect(state.previousPlayModeBeforeRadio, PlayerPlayMode.shuffle);
  });
}

List<PlayerTrack> _buildQueue() {
  return const <PlayerTrack>[
    PlayerTrack(id: 'song-1', title: '第一首', platform: 'qq'),
    PlayerTrack(
      id: 'song-2',
      title: '第二首',
      platform: 'qq',
      url: 'https://example.com/song-2.mp3',
    ),
  ];
}

List<PlayerTrack> _buildQualityQueue() {
  return const <PlayerTrack>[
    PlayerTrack(
      id: 'song-3',
      title: '第三首',
      platform: 'qq',
      links: <LinkInfo>[
        LinkInfo(
          name: '320k',
          quality: 320,
          format: 'mp3',
          size: '0',
          url: 'https://cdn.example.com/song-3-320.mp3',
        ),
        LinkInfo(
          name: 'FLAC',
          quality: 999,
          format: 'flac',
          size: '0',
          url: 'https://cdn.example.com/song-3.flac',
        ),
      ],
    ),
  ];
}

List<PlayerTrack> _buildTargetPreviewQueue() {
  return const <PlayerTrack>[
    PlayerTrack(id: 'song-1', title: '第一首', platform: 'qq'),
    PlayerTrack(id: 'song-2', title: '第二首', platform: 'qq'),
    PlayerTrack(id: 'song-3', title: '第三首', platform: 'qq'),
  ];
}

Future<({ProviderContainer container, _FakeAudioPlayerPort audioPlayer})>
_createTargetPreviewHarness() async {
  final audioPlayer = _FakeAudioPlayerPort();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      audioPlayerPortProvider.overrideWithValue(audioPlayer),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(audioPlayer.dispose);
  await container
      .read(playerControllerProvider.notifier)
      .replaceQueue(_buildTargetPreviewQueue(), startIndex: 0, autoplay: false);
  return (container: container, audioPlayer: audioPlayer);
}

Map<String, dynamic> _manualSkipTargetEvent({
  required int transitionId,
  int? targetIndex,
  String status = 'pending',
}) {
  final queue = _buildTargetPreviewQueue();
  final target =
      targetIndex == null || targetIndex < 0 || targetIndex >= queue.length
      ? null
      : queue[targetIndex];
  return <String, dynamic>{
    'type': 'manualSkipTarget',
    'transitionId': transitionId,
    'status': status,
    'targetIndex': targetIndex,
    'targetTrackId': target?.id,
    'targetTrackPlatform': target?.platform,
  };
}

Map<String, dynamic> _queueStateEvent({
  required int transitionId,
  required int currentIndex,
  required bool manualSkipTargetActive,
  List<Map<String, dynamic>>? tracks,
}) {
  return <String, dynamic>{
    'type': 'queueState',
    'transitionId': transitionId,
    'manualSkipTargetActive': manualSkipTargetActive,
    'tracks': tracks ?? _buildTargetPreviewQueue().map(_trackEventMap).toList(),
    'currentIndex': currentIndex,
  };
}

Map<String, dynamic> _trackEventMap(PlayerTrack track) {
  return <String, dynamic>{
    'id': track.id,
    'title': track.title,
    'url': track.url,
    'path': track.path,
    'durationMs': track.duration?.inMilliseconds,
    'artist': track.artist,
    'album': track.album,
    'artworkUrl': track.artworkUrl,
    'platform': track.platform,
    'links': const <Map<String, dynamic>>[],
  };
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh-CN');
  }
}

class _FakeAudioPlayerPort implements AudioPlayerPort {
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _loadingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<int?> _currentIndexController =
      StreamController<int?>.broadcast();
  final StreamController<dynamic> _customEventController =
      StreamController<dynamic>.broadcast();

  List<AudioTrack> lastQueueTracks = const <AudioTrack>[];
  int? lastQueueInitialIndex;
  AudioTrack? lastSetSourceTrack;
  int setSourceCallCount = 0;
  bool lastSetQueueIsRadioMode = false;
  String? lastSetQueueRadioId;
  String? lastSetQueueRadioPlatform;
  int? lastSetQueueRadioPageIndex;
  Completer<void>? setQueueCompleter;
  final Completer<void> setQueueStarted = Completer<void>();
  int setQueueCallCount = 0;
  bool hasLoadedQueue = false;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<bool> get loadingStream => _loadingController.stream;

  @override
  Stream<bool> get completedStream => _completedController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Stream<dynamic> get customEventStream => _customEventController.stream;

  @override
  Future<CurrentLyricStateSnapshot> getCurrentLyricState() async {
    return const CurrentLyricStateSnapshot();
  }

  @override
  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    setQueueCallCount += 1;
    hasLoadedQueue = false;
    lastQueueTracks = List<AudioTrack>.from(tracks);
    lastQueueInitialIndex = initialIndex;
    lastSetQueueIsRadioMode = isRadioMode;
    lastSetQueueRadioId = currentRadioId;
    lastSetQueueRadioPlatform = currentRadioPlatform;
    lastSetQueueRadioPageIndex = currentRadioPageIndex;
    if (!setQueueStarted.isCompleted) {
      setQueueStarted.complete();
    }
    await setQueueCompleter?.future;
    hasLoadedQueue = true;
  }

  @override
  Future<void> setSource(AudioTrack track) async {
    setSourceCallCount += 1;
    lastSetSourceTrack = track;
    lastQueueTracks = <AudioTrack>[track];
    lastQueueInitialIndex = 0;
  }

  @override
  Future<void> playAt(int index) async {
    lastQueueInitialIndex = index;
  }

  @override
  Future<void> seekToNext() async {}

  @override
  Future<void> seekToPrevious() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setSingleLoop(bool enabled) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _loadingController.close();
    await _completedController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentIndexController.close();
    await _customEventController.close();
  }

  void emitCompleted(bool value) {
    _completedController.add(value);
  }

  void emitCurrentIndex(int? index) {
    _currentIndexController.add(index);
  }

  void emitPlaying(bool value) {
    _playingController.add(value);
  }

  void emitLoading(bool value) {
    _loadingController.add(value);
  }

  void emitPosition(Duration value) {
    _positionController.add(value);
  }

  void emitDuration(Duration? value) {
    _durationController.add(value);
  }

  void emitCustomEvent(Map<String, dynamic> event) {
    _customEventController.add(event);
  }
}

class _ReplayingStartupAudioPlayerPort extends _FakeAudioPlayerPort {
  int currentIndexListenCount = 0;
  int setShuffleCallCount = 0;

  @override
  Stream<int?> get currentIndexStream {
    currentIndexListenCount += 1;
    return Stream<int?>.value(0);
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    setShuffleCallCount += 1;
    if (hasLoadedQueue) {
      return;
    }
    emitCustomEvent(<String, dynamic>{
      'type': 'queueState',
      'transitionId': setShuffleCallCount,
      'manualSkipTargetActive': false,
      'tracks': const <Map<String, dynamic>>[],
      'currentIndex': 0,
    });
  }
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient({required this.handlers}) : super(Dio());

  final Map<String, _SongUrlHandler> handlers;
  final List<_SongUrlRequest> requests = <_SongUrlRequest>[];

  @override
  Future<Map<String, dynamic>> fetchSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) {
    requests.add(
      _SongUrlRequest(
        songId: songId,
        platform: platform,
        quality: quality,
        format: format,
      ),
    );
    final handler = handlers[songId];
    if (handler == null) {
      throw StateError('缺少 $songId 的测试响应');
    }
    return handler();
  }
}

typedef _SongUrlHandler = Future<Map<String, dynamic>> Function();

class _SongUrlRequest {
  const _SongUrlRequest({
    required this.songId,
    required this.platform,
    required this.quality,
    required this.format,
  });

  final String songId;
  final String platform;
  final int? quality;
  final String? format;
}

class _FakeRadioApiClient extends RadioApiClient {
  _FakeRadioApiClient({required this.pages}) : super(Dio());

  final Map<int, List<SongInfo>> pages;
  final List<int> requestedPages = <int>[];

  @override
  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    requestedPages.add(pageIndex);
    return pages[pageIndex] ?? const <SongInfo>[];
  }
}

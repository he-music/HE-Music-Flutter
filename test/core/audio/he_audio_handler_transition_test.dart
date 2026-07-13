import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('目标音源装载成功前不提交正式索引', () async {
    final targetLoad = Completer<Duration?>();
    final handler = _buildLocalHandler(
      setAudioSource: (source, player) {
        return _sourceId(source) == 'song-1'
            ? targetLoad.future
            : Future<Duration?>.value(null);
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_localQueue(2));

    final switching = handler.playIndex(1);
    await Future<void>.delayed(Duration.zero);

    expect(handler.mediaItem.value?.id, 'song-0');
    expect(handler.playbackState.value.queueIndex, 0);

    targetLoad.complete(const Duration(minutes: 3));
    await switching;

    expect(handler.mediaItem.value?.id, 'song-1');
    expect(handler.playbackState.value.queueIndex, 1);
  });

  test('同一音源代次的重复 completed 只推进一次', () async {
    final nextLoad = Completer<Duration?>();
    final handler = _buildLocalHandler(
      setAudioSource: (source, player) {
        return _sourceId(source) == 'song-1'
            ? nextLoad.future
            : Future<Duration?>.value(null);
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_localQueue(3));

    final first = handler.handlePlaybackCompletedForTesting();
    final duplicate = handler.handlePlaybackCompletedForTesting();
    await duplicate;
    nextLoad.complete(null);
    await first;

    expect(handler.mediaItem.value?.id, 'song-1');
    expect(handler.playbackState.value.queueIndex, 1);
  });

  test('手动下一曲取消正在准备的自动切歌并越过自动目标', () async {
    final automaticLoad = Completer<Duration?>();
    final handler = _buildLocalHandler(
      setAudioSource: (source, player) {
        return _sourceId(source) == 'song-1'
            ? automaticLoad.future
            : Future<Duration?>.value(null);
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_localQueue(4));

    final automatic = handler.handlePlaybackCompletedForTesting();
    await Future<void>.delayed(Duration.zero);
    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(handler.mediaItem.value?.id, 'song-2');
    expect(handler.playbackState.value.queueIndex, 2);

    automaticLoad.complete(null);
    await automatic;
    expect(handler.mediaItem.value?.id, 'song-2');
  });

  test('500ms 批次内五次下一曲只提交最终目标', () async {
    final loadedIds = <String>[];
    final handler = _buildLocalHandler(
      setAudioSource: (source, player) async {
        loadedIds.add(_sourceId(source));
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_localQueue(7));

    for (var index = 0; index < 5; index += 1) {
      await handler.skipToNext();
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(handler.mediaItem.value?.id, 'song-5');
    expect(loadedIds, <String>['song-0', 'song-5']);
  });

  test('下一下一上一从 B 聚合到 C', () async {
    final loadedIds = <String>[];
    final handler = _buildLocalHandler(
      setAudioSource: (source, player) async {
        loadedIds.add(_sourceId(source));
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_localQueue(5), initialIndex: 1);

    await handler.skipToNext();
    await handler.skipToNext();
    await handler.skipToPrevious();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(handler.mediaItem.value?.id, 'song-2');
    expect(loadedIds, <String>['song-1', 'song-2']);
  });

  test('预加载与正式切歌共享同一个 URL in-flight', () async {
    final secondUrl = Completer<Map<String, dynamic>>();
    final requestCounts = <String, int>{};
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) {
            requestCounts.update(
              songId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
            if (songId == 'song-1') {
              return secondUrl.future;
            }
            return Future<Map<String, dynamic>>.value(<String, dynamic>{
              'url': 'https://audio.example.com/$songId.mp3',
            });
          },
      setAudioSourceOverride: (source, player) async => null,
      playOverride: (player) async {},
      disposeOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_remoteQueue(2));
    await Future<void>.delayed(Duration.zero);

    expect(requestCounts['song-1'], 1);
    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 170));
    expect(requestCounts['song-1'], 1);

    secondUrl.complete(<String, dynamic>{
      'url': 'https://audio.example.com/song-1.mp3',
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(handler.mediaItem.value?.id, 'song-1');
    expect(requestCounts['song-1'], 1);
  });

  test('全局网络失败停留目标且不扫描后续歌曲', () async {
    final requestedIds = <String>[];
    final errors = <Map<dynamic, dynamic>>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            requestedIds.add(songId);
            if (songId == 'song-1') {
              throw DioException(
                requestOptions: RequestOptions(path: '/v1/song/url'),
                type: DioExceptionType.connectionError,
              );
            }
            return <String, dynamic>{
              'url': 'https://audio.example.com/$songId.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async => null,
      playOverride: (player) async {},
      disposeOverride: (player) async {},
    );
    final subscription = handler.customEvent.listen((event) {
      if (event is Map && event['type'] == 'playbackTransitionError') {
        errors.add(event);
      }
    });
    addTearDown(subscription.cancel);
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_remoteQueue(3));
    await Future<void>.delayed(Duration.zero);

    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(handler.mediaItem.value?.id, 'song-0');
    expect(requestedIds, isNot(contains('song-2')));
    expect(errors.last['code'], 'globalTransient');
  });

  test('电台队尾 completed 复用补页请求并继续播放', () async {
    final radioPage = Completer<List<SongInfo>>();
    final requestedPages = <int>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async => <String, dynamic>{
            'url': 'https://audio.example.com/$songId.mp3',
          },
      fetchRadioSongsOverride:
          ({
            required String id,
            required String platform,
            int pageIndex = 1,
            int pageSize = 50,
          }) {
            requestedPages.add(pageIndex);
            return radioPage.future;
          },
      setAudioSourceOverride: (source, player) async => null,
      playOverride: (player) async {},
      disposeOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(
      _remoteQueue(1),
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );
    await Future<void>.delayed(Duration.zero);

    final completion = handler.handlePlaybackCompletedForTesting();
    radioPage.complete(const <SongInfo>[
      SongInfo(
        name: '下一页歌曲',
        subtitle: '',
        id: 'song-1',
        duration: 1000,
        mvId: '',
        album: null,
        artists: <SongInfoArtistInfo>[],
        links: <LinkInfo>[],
        platform: 'qq',
        cover: '',
        sublist: <SongInfo>[],
        originalType: 0,
      ),
    ]);
    await completion;

    expect(requestedPages.where((page) => page == 2), hasLength(1));
    expect(handler.mediaItem.value?.id, 'song-1');
    expect(handler.playbackState.value.queueIndex, 1);
  });

  test('诊断日志包含事务字段但不包含完整 URL 或凭证', () async {
    final logs = <String>[];
    final handler = HeAudioHandler(
      logOverride: logs.add,
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async => <String, dynamic>{
            'url': 'https://audio.example.com/$songId.mp3?token=secret-token',
          },
      setAudioSourceOverride: (source, player) async => null,
      disposeOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);

    await handler.setQueueData(_remoteQueue(1));

    final output = logs.join('\n');
    expect(output, contains('transitionId='));
    expect(output, contains('sourceGeneration='));
    expect(output, isNot(contains('https://')));
    expect(output, isNot(contains('secret-token')));
    expect(output, isNot(contains('Bearer')));
  });

  test('play Future 不完成也不阻塞切歌事务提交', () async {
    final playCompleter = Completer<void>();
    final handler = _buildLocalHandler(
      setAudioSource: (source, player) async => null,
      play: (player) => playCompleter.future,
    );
    addTearDown(handler.disposeHandler);
    await handler.setQueueData(_localQueue(2));

    await handler.playIndex(1).timeout(const Duration(milliseconds: 100));

    expect(handler.mediaItem.value?.id, 'song-1');
    expect(playCompleter.isCompleted, isFalse);
  });
}

HeAudioHandler _buildLocalHandler({
  required HeAudioHandlerSetAudioSource setAudioSource,
  HeAudioHandlerPlay? play,
}) {
  return HeAudioHandler(
    setAudioSourceOverride: setAudioSource,
    playOverride: play ?? (player) async {},
    disposeOverride: (player) async {},
  );
}

List<AudioTrack> _localQueue(int length) {
  return List<AudioTrack>.generate(
    length,
    (index) => AudioTrack(
      id: 'song-$index',
      title: '歌曲 $index',
      url: '',
      path: '/tmp/song-$index.mp3',
      platform: 'local',
    ),
  );
}

List<AudioTrack> _remoteQueue(int length) {
  return List<AudioTrack>.generate(
    length,
    (index) => AudioTrack(
      id: 'song-$index',
      title: '歌曲 $index',
      url: '',
      platform: 'qq',
    ),
  );
}

String _sourceId(AudioSource source) {
  return ((source as UriAudioSource).tag as MediaItem).id;
}

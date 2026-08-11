import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('离线解析快速失败且不消耗 URL 请求', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.offline);
    var fetchCount = 0;
    final handler = _handler(
      network: network,
      fetchSongUrl:
          ({required songId, required platform, quality, format}) async {
            fetchCount += 1;
            return const <String, dynamic>{'url': 'https://audio/song.mp3'};
          },
    );
    addTearDown(handler.disposeHandler);
    final events = <Map<dynamic, dynamic>>[];
    final subscription = handler.customEvent.listen((event) {
      if (event is Map && event['type'] == 'playbackTransitionError') {
        events.add(event);
      }
    });
    addTearDown(subscription.cancel);
    await _syncConfig(handler);

    await expectLater(
      handler.setQueueData(const <AudioTrack>[
        AudioTrack(id: 'song-1', title: '歌曲', url: '', platform: 'qq'),
      ]),
      throwsA(anything),
    );

    await Future<void>.delayed(Duration.zero);
    expect(fetchCount, 0);
    expect(events, hasLength(1));
    expect(events.single['code'], 'networkUnavailable');
    expect(events.single['retryable'], isTrue);
    expect(events.single['transitionId'], isA<int>());
  });

  test('初始网络查询的旧结果不覆盖较新的断网事件', () async {
    final initialCurrent = Completer<NetworkConnectionType>();
    final network = _FakeNetworkStatusPort(
      NetworkConnectionType.wifi,
      currentFuture: initialCurrent.future,
    );
    var fetchCount = 0;
    final handler = _handler(
      network: network,
      fetchSongUrl:
          ({required songId, required platform, quality, format}) async {
            fetchCount += 1;
            return const <String, dynamic>{'url': 'https://audio/song.mp3'};
          },
    );
    addTearDown(handler.disposeHandler);

    network.emit(NetworkConnectionType.offline);
    initialCurrent.complete(NetworkConnectionType.wifi);
    await Future<void>.delayed(Duration.zero);
    await _syncConfig(handler);

    await expectLater(
      handler.setQueueData(const <AudioTrack>[
        AudioTrack(id: 'song-1', title: '歌曲', url: '', platform: 'qq'),
      ]),
      throwsA(anything),
    );
    expect(fetchCount, 0);
  });

  test('URL 请求失败期间断网后不继续自动重试', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    var fetchCount = 0;
    final handler = _handler(
      network: network,
      fetchSongUrl: ({required songId, required platform, quality, format}) {
        fetchCount += 1;
        network.emit(NetworkConnectionType.offline);
        throw DioException(
          requestOptions: RequestOptions(path: '/song/url'),
          type: DioExceptionType.connectionError,
        );
      },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);

    await expectLater(
      handler.setQueueData(const <AudioTrack>[
        AudioTrack(id: 'song-1', title: '歌曲', url: '', platform: 'qq'),
      ]),
      throwsA(anything),
    );

    expect(fetchCount, 1);
  });

  test('断网失败后联网强刷 URL、恢复进度并尊重暂停意图', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    var fetchCount = 0;
    var playCount = 0;
    var sourceCount = 0;
    var currentPosition = const Duration(seconds: 42);
    final seeks = <Duration>[];
    final recovered = Completer<void>();
    final handler = _handler(
      network: network,
      fetchSongUrl:
          ({required songId, required platform, quality, format}) async {
            fetchCount += 1;
            return <String, dynamic>{
              'url': 'https://audio/song-$fetchCount.mp3',
            };
          },
      setAudioSource: (source, player) async {
        sourceCount += 1;
        if (sourceCount == 2 && !recovered.isCompleted) {
          recovered.complete();
        }
        return null;
      },
      play: (player) async {
        playCount += 1;
      },
      pause: (player) async {},
      position: (player) => currentPosition,
      seek: (position, player) async {
        seeks.add(position);
        currentPosition = position;
      },
    );
    addTearDown(handler.disposeHandler);
    final recoveryEvents = <Map<dynamic, dynamic>>[];
    final recoverySubscription = handler.customEvent.listen((event) {
      if (event is Map && event['type'] == 'playbackTransitionRecovered') {
        recoveryEvents.add(event);
      }
    });
    addTearDown(recoverySubscription.cancel);
    await _syncConfig(handler);
    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '歌曲', url: '', platform: 'qq'),
    ]);
    await handler.play();
    await Future<void>.delayed(Duration.zero);
    expect(playCount, 1);

    network.emit(NetworkConnectionType.offline);
    handler.handlePlaybackErrorForTesting(StateError('stream failed'));
    await handler.pause();
    network.emit(NetworkConnectionType.wifi);
    await recovered.future;
    await Future<void>.delayed(Duration.zero);

    expect(fetchCount, 2);
    expect(sourceCount, 2);
    expect(seeks, <Duration>[const Duration(seconds: 42)]);
    expect(playCount, 1);
    expect(recoveryEvents, hasLength(1));
    expect(recoveryEvents.single['transitionId'], isA<int>());
  });

  test('联网恢复和重复手动重试共享一个加载 Future', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    var fetchCount = 0;
    final recoveryPayload = Completer<Map<String, dynamic>>();
    final handler = _handler(
      network: network,
      fetchSongUrl: ({required songId, required platform, quality, format}) {
        fetchCount += 1;
        if (fetchCount == 1) {
          return Future<Map<String, dynamic>>.value(const <String, dynamic>{
            'url': 'https://audio/first.mp3',
          });
        }
        return recoveryPayload.future;
      },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);
    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '歌曲', url: '', platform: 'qq'),
    ]);

    network.emit(NetworkConnectionType.offline);
    handler.handlePlaybackErrorForTesting(StateError('stream failed'));
    network.emit(NetworkConnectionType.wifi);
    final first = handler.retryCurrentPlayback();
    final second = handler.retryCurrentPlayback();

    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(fetchCount, 2);
    recoveryPayload.complete(const <String, dynamic>{
      'url': 'https://audio/recovered.mp3',
    });
    await first;
    expect(fetchCount, 2);
  });

  test('手动恢复失败向调用方传递并保留后续重试机会', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    var fetchCount = 0;
    final handler = _handler(
      network: network,
      fetchSongUrl: ({required songId, required platform, quality, format}) {
        fetchCount += 1;
        if (fetchCount == 1) {
          return Future<Map<String, dynamic>>.value(const <String, dynamic>{
            'url': 'https://audio/first.mp3',
          });
        }
        throw StateError('recovery failed');
      },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);
    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '歌曲', url: '', platform: 'qq'),
    ]);

    network.emit(NetworkConnectionType.offline);
    handler.handlePlaybackErrorForTesting(StateError('stream failed'));
    network.emit(NetworkConnectionType.wifi);

    await expectLater(handler.retryCurrentPlayback(), throwsStateError);
    expect(fetchCount, 2);
  });

  test('切歌后新恢复不被旧歌曲未完成的恢复阻塞', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    final oldRecovery = Completer<Map<String, dynamic>>();
    final newRecovery = Completer<Map<String, dynamic>>();
    final requests = <String>[];
    final handler = _handler(
      network: network,
      fetchSongUrl: ({required songId, required platform, quality, format}) {
        requests.add(songId);
        final requestCount = requests.where((id) => id == songId).length;
        if (requestCount == 1) {
          return Future<Map<String, dynamic>>.value(<String, dynamic>{
            'url': 'https://audio/$songId-first.mp3',
          });
        }
        return songId == 'song-1' ? oldRecovery.future : newRecovery.future;
      },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);
    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '歌曲 1', url: '', platform: 'qq'),
    ]);

    network.emit(NetworkConnectionType.offline);
    handler.handlePlaybackErrorForTesting(StateError('stream failed'));
    network.emit(NetworkConnectionType.wifi);
    await Future<void>.delayed(Duration.zero);
    expect(requests, <String>['song-1', 'song-1']);

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-2', title: '歌曲 2', url: '', platform: 'qq'),
    ]);
    network.emit(NetworkConnectionType.offline);
    handler.handlePlaybackErrorForTesting(StateError('stream failed'));
    network.emit(NetworkConnectionType.wifi);
    final retry = handler.retryCurrentPlayback();
    await Future<void>.delayed(Duration.zero);

    expect(requests, <String>['song-1', 'song-1', 'song-2', 'song-2']);
    newRecovery.complete(const <String, dynamic>{
      'url': 'https://audio/song-2-recovered.mp3',
    });
    await retry;
    oldRecovery.complete(const <String, dynamic>{
      'url': 'https://audio/song-1-stale.mp3',
    });
    await Future<void>.delayed(Duration.zero);
  });

  test('离线状态不阻止本地音源加载', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.offline);
    var sourceCount = 0;
    final handler = _handler(
      network: network,
      fetchSongUrl:
          ({required songId, required platform, quality, format}) async =>
              throw StateError('不应请求远程 URL'),
      setAudioSource: (source, player) async {
        sourceCount += 1;
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'local-1', title: '本地歌曲', url: '', path: '/tmp/song.mp3'),
    ]);

    expect(sourceCount, 1);
  });

  test('网络切换不重载当前歌曲，后续强刷使用对应音质', () async {
    final network = _FakeNetworkStatusPort(NetworkConnectionType.cellular);
    final requestedQualities = <int?>[];
    final handler = _handler(
      network: network,
      fetchSongUrl:
          ({required songId, required platform, quality, format}) async {
            requestedQualities.add(quality);
            return <String, dynamic>{
              'url': 'https://audio/$quality.${format ?? 'mp3'}',
            };
          },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(
      handler,
      wifiQuality: AppOnlineAudioQuality.flac,
      cellularQuality: AppOnlineAudioQuality.mp3128,
    );
    const track = AudioTrack(
      id: 'song-1',
      title: '歌曲',
      url: '',
      platform: 'qq',
      links: <LinkInfo>[
        LinkInfo(name: '128k', quality: 128, format: 'mp3', size: '1', url: ''),
        LinkInfo(
          name: 'FLAC',
          quality: 999,
          format: 'flac',
          size: '1',
          url: '',
        ),
      ],
    );

    await handler.setQueueData(const <AudioTrack>[track]);
    network.emit(NetworkConnectionType.wifi);
    await Future<void>.delayed(Duration.zero);
    expect(requestedQualities, <int?>[128]);

    await handler.setQueueData(const <AudioTrack>[
      track,
    ], forceReloadCurrent: true);
    expect(requestedQualities, <int?>[128, 999]);
  });
}

HeAudioHandler _handler({
  required _FakeNetworkStatusPort network,
  required HeAudioHandlerFetchSongUrl fetchSongUrl,
  HeAudioHandlerSetAudioSource? setAudioSource,
  HeAudioHandlerPlay? play,
  HeAudioHandlerPause? pause,
  HeAudioHandlerPosition? position,
  HeAudioHandlerSeek? seek,
}) {
  return HeAudioHandler(
    networkStatusPort: network,
    fetchSongUrlOverride: fetchSongUrl,
    fetchLyricsOverride:
        ({
          required String trackId,
          String? platform,
          String? localPath,
        }) async => const LyricDocument.empty(),
    setAudioSourceOverride: setAudioSource ?? (source, player) async => null,
    playOverride: play ?? (player) async {},
    pauseOverride: pause,
    positionOverride: position,
    seekOverride: seek,
    disposeOverride: (player) async {},
  );
}

Future<void> _syncConfig(
  HeAudioHandler handler, {
  AppOnlineAudioQuality wifiQuality = AppOnlineAudioQuality.auto,
  AppOnlineAudioQuality cellularQuality = AppOnlineAudioQuality.mp3320,
}) {
  return handler.syncConfig(
    apiBaseUrl: 'https://api.test',
    authToken: null,
    wifiQualityPreference: wifiQuality,
    cellularQualityPreference: cellularQuality,
    lastSelectedQualityName: null,
    enableDesktopLyric: false,
    enableDesktopLyricLock: false,
    lyricHighlightMode: AppLyricHighlightMode.preset,
    lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color.toARGB32(),
    lyricHighlightCustomColorValue: null,
    lyricFontPresetIndex: AppLyricFontPreset.medium.index,
    enableWordByWordLyric: false,
  );
}

class _FakeNetworkStatusPort implements NetworkStatusPort {
  _FakeNetworkStatusPort(
    this._current, {
    Future<NetworkConnectionType>? currentFuture,
  }) : _currentFuture = currentFuture;

  final StreamController<NetworkConnectionType> _controller =
      StreamController<NetworkConnectionType>.broadcast(sync: true);
  final Future<NetworkConnectionType>? _currentFuture;
  NetworkConnectionType _current;

  @override
  Stream<NetworkConnectionType> get changes => _controller.stream;

  @override
  Future<NetworkConnectionType> current() async =>
      await (_currentFuture ?? Future<NetworkConnectionType>.value(_current));

  @override
  NetworkConnectionType get lastKnown => _current;

  void emit(NetworkConnectionType value) {
    _current = value;
    _controller.add(value);
  }
}

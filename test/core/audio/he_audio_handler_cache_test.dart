// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'native_audio_test_support.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_disk_capacity_port.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_key.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_source_plan.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_store.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('playing cached remote source can stop and switch queues', () async {
    _installNativePlatform();
    final fixture = await _CacheFixture.create();
    addTearDown(fixture.dispose);
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    addTearDown(network.dispose);
    final player = AudioPlayer(handleAudioSessionActivation: false);
    final handler = _handler(
      fixture: fixture,
      network: network,
      loaded: [],
      player: player,
      realNative: true,
      play: (player) => player.play(),
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);
    await handler.setQueueData([_track()]);
    await handler.play();
    await player.playingStream.firstWhere((playing) => playing);
    await handler.stop().timeout(const Duration(seconds: 3));
    await handler
        .setQueueData([_track(id: 'B')])
        .timeout(const Duration(seconds: 3));
    await handler.play();
    expect(handler.mediaItem.value?.id, 'B');
    expect(player.playing, isTrue);
  });

  test(
    'held cache invalidation cannot reload old A over committed B',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      await fixture.publish(_key());
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      final fetches = <String>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        fetch: ({required songId, required platform, quality, format}) async {
          fetches.add(songId);
          return {'url': 'https://audio.invalid/$songId.mp3', 'format': 'mp3'};
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      await handler.setQueueData([_track()]);
      final invalidating = Completer<void>();
      final gate = Completer<void>();
      fixture.store.beforeInvalidate = (_) async {
        invalidating.complete();
        await gate.future;
      };
      handler.handlePlaybackErrorForTesting(PlayerException(1, 'decode', 0));
      await invalidating.future;
      await handler.setQueueData([_track(id: 'B')]);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(handler.mediaItem.value?.id, 'B');
      expect(fetches, ['B']);
      expect(loaded, hasLength(2));
      expect(handler.currentSourceNeedsReloadForTesting, isFalse);
    },
  );

  test('held A stop continuation leaves new B owner intact', () async {
    final fixture = await _CacheFixture.create();
    addTearDown(fixture.dispose);
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    addTearDown(network.dispose);
    final player = _HeldStopPlayer();
    addTearDown(player.dispose);
    final sources = <_ControlledCachingSource>[];
    final released = <AudioSource>[];
    final handler = _handler(
      fixture: fixture,
      network: network,
      loaded: [],
      player: player,
      cachingSources: sources,
      released: released,
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);
    await handler.setQueueData([_track()]);
    final stopGate = Completer<void>();
    player.stopGate = stopGate;
    final stopping = handler.stop();
    await player.stopStarted.future;
    await handler.setQueueData([_track(id: 'B')]);
    stopGate.complete();
    await stopping;
    expect(handler.mediaItem.value?.id, 'B');
    expect(handler.currentSourceNeedsReloadForTesting, isFalse);
    expect(sources.last.cancelCount, 0);
    expect(released, isNot(contains(sources.last)));
  });

  test(
    'reconnected cache recovery refreshes policy but freezes actual identity',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      await fixture.publish(_key(quality: 999, format: 'flac'));
      final network = _FakeNetworkStatusPort(NetworkConnectionType.offline);
      addTearDown(network.dispose);
      final requests = <({int? quality, String? format})>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: [],
        fetch: ({required songId, required platform, quality, format}) async {
          requests.add((quality: quality, format: format));
          return {
            'url': 'https://audio.invalid/song.$format',
            'format': format,
          };
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler, wifiQuality: AppOnlineAudioQuality.mp3320);
      await handler.setQueueData([_track(links: _twoQualities)]);
      network.emit(NetworkConnectionType.wifi);
      await fixture.runtime.updatePolicy(
        const AudioCachePolicy(enabled: false),
      );
      handler.handlePlaybackErrorForTesting(PlayerException(1, 'decode', 0));
      await _waitUntil(
        () =>
            handler.currentSourceKindForTesting == AudioSourceKind.plainRemote,
      );
      expect(requests, [(quality: 999, format: 'flac')]);
      expect(fixture.store.admitKeys, isEmpty);
      expect(handler.currentSourceNeedsReloadForTesting, isFalse);
    },
  );

  test(
    'precommit filesystem terminal behind PlayerException reloads same URL once',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final sources = <_ControlledCachingSource>[];
      final loaded = <AudioSource>[];
      var fetches = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        cachingSources: sources,
        fetch: ({required songId, required platform, quality, format}) async {
          fetches++;
          return {'url': 'https://audio.invalid/same.mp3', 'format': 'mp3'};
        },
        setSource: (source, _) async {
          loaded.add(source);
          if (source is _ControlledCachingSource) {
            source.fail(LockCachingAudioSourceFailure.fileSystem);
            throw PlayerException(500, 'proxy response', 0);
          }
          return null;
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      await handler.setQueueData([_track()]);
      expect(fetches, 1);
      expect(loaded, hasLength(2));
      expect(
        (loaded.last as UriAudioSource).uri.toString(),
        'https://audio.invalid/same.mp3',
      );
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
      expect(fixture.runtime.snapshot.entryCount, 0);
      expect(fixture.runtime.writeHealth, AudioCacheWriteHealth.ready);
    },
  );

  test(
    'real vendor errorStream delivers native cached decode failure once',
    () async {
      final native = _installNativePlatform();
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      await fixture.publish(_key());
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final player = AudioPlayer(handleAudioSessionActivation: false);
      var invalidations = 0;
      fixture.store.beforeInvalidate = (_) async {
        invalidations++;
      };
      var fetches = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: [],
        player: player,
        realNative: true,
        fetch: ({required songId, required platform, quality, format}) async {
          fetches++;
          return {'url': 'https://audio.invalid/remote.mp3', 'format': 'mp3'};
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      await handler.setQueueData([_track()]);
      native.current.emitError(100);
      native.current.emitError(100);
      await _waitUntil(
        () =>
            handler.currentSourceKindForTesting == AudioSourceKind.plainRemote,
      );
      expect(invalidations, 1);
      expect(fetches, 1);
      expect(fixture.runtime.snapshot.entryCount, 0);
    },
  );

  test(
    'native error during pending replacement cannot recover or fail the new generation',
    () async {
      final native = _installNativePlatform();
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      await fixture.publish(_key());
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      var invalidations = 0;
      fixture.store.beforeInvalidate = (_) async {
        invalidations++;
      };
      final errors = <Map<dynamic, dynamic>>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: [],
        player: AudioPlayer(handleAudioSessionActivation: false),
        realNative: true,
      );
      addTearDown(handler.disposeHandler);
      final subscription = handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'playbackTransitionError') {
          errors.add(event);
        }
      });
      addTearDown(subscription.cancel);
      await _syncConfig(handler);
      await handler.setQueueData([_track()]);
      final started = Completer<void>();
      final gate = Completer<void>();
      native.current.beforeLoad = (_) async {
        started.complete();
        await gate.future;
      };
      final switching = handler.setQueueData([_track(id: 'B')]);
      await started.future;
      native.current.emitError(101);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(invalidations, 0);
      expect(errors, isEmpty);
      gate.complete();
      await switching;
      native.current.emitError(102);
      await _waitUntil(() => errors.isNotEmpty);
      expect(errors, hasLength(1));
      expect(handler.mediaItem.value?.id, 'B');
      expect(invalidations, 0);
    },
  );

  test(
    'stale native load response converges without detaching committed B',
    () async {
      final native = _installNativePlatform();
      final started = Completer<void>();
      final gate = Completer<void>();
      native.afterLoad = (_) async {
        if (!started.isCompleted) {
          started.complete();
          await gate.future;
        }
      };
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      final released = <AudioSource>[];
      final player = AudioPlayer(handleAudioSessionActivation: false);
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        released: released,
        player: player,
        realNative: true,
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      final loadingA = handler.setQueueData([_track()]);
      await started.future;
      await handler.setQueueData([_track(id: 'B')]);
      final nativeB = native.current;
      expect(handler.mediaItem.value?.id, 'B');
      gate.complete();
      await loadingA;
      await _waitUntil(() => released.contains(loaded.first));
      expect(handler.mediaItem.value?.id, 'B');
      expect(player.audioSource, same(loaded.last));
      expect(nativeB.disposed, isFalse);
      expect(handler.currentSourceNeedsReloadForTesting, isFalse);
    },
  );

  test(
    'failed B proxy init retains cleared A until native disposal finishes',
    () async {
      final native = _installNativePlatform();
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      await fixture.publish(_key());
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      final logs = <String>[];
      final player = AudioPlayer(handleAudioSessionActivation: false);
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        player: player,
        realNative: true,
        logs: logs,
        setSource: (source, player) {
          loaded.add(source);
          return source is LockCachingAudioSource
              ? IOOverrides.runWithIOOverrides(
                  () => player.setAudioSource(source),
                  _FailingBindOverrides(),
                )
              : player.setAudioSource(source);
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      await handler.setQueueData([_track()]);
      final first = loaded.single as UriAudioSource;
      final file = File.fromUri(first.uri);
      final oldNative = native.current;
      await fixture.runtime.clear();
      final disposing = Completer<void>();
      final detachGate = Completer<void>();
      native.beforeDispose = () async {
        if (!disposing.isCompleted) {
          disposing.complete();
          await detachGate.future;
        }
      };
      final switching = handler.setQueueData([_track(id: 'B')]);
      await disposing.future;
      expect(player.audioSource, isNot(same(first)));
      expect(oldNative.disposed, isFalse);
      expect(await file.exists(), isTrue);
      detachGate.complete();
      await switching;
      expect(oldNative.disposed, isTrue);
      expect(await file.exists(), isFalse, reason: logs.join('\n'));
      expect(handler.mediaItem.value?.id, 'B');
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
    },
  );

  test(
    'real proxy sink failure and native 500 wrapper reuse URL without refresh',
    () async {
      final native = _installNativePlatform();
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => origin.close(force: true));
      origin.listen((request) async {
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.contentLength = 32;
        request.response.add(List.filled(32, 1));
        await request.response.close();
      });
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      LockCachingAudioSource? source;
      var fetches = 0;
      var proxyFailures = 0;
      native.beforeLoad = (request) async {
        if (loaded.last is! LockCachingAudioSource) return;
        final message =
            (request.audioSourceMessage as ConcatenatingAudioSourceMessage)
                    .children
                    .single
                as UriAudioSourceMessage;
        final client = HttpClient();
        try {
          final response = await (await client.getUrl(
            Uri.parse(message.uri),
          )).close();
          expect(response.statusCode, 500);
          await response.drain<void>();
          proxyFailures++;
          throw PlatformException(code: '500', message: 'native proxy failure');
        } finally {
          client.close(force: true);
        }
      };
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        player: AudioPlayer(handleAudioSessionActivation: false),
        realNative: true,
        realCachingBuilder:
            ({required uri, required cacheFile, required tag}) =>
                source = LockCachingAudioSource(
                  uri,
                  cacheFile: cacheFile,
                  tag: tag,
                  sinkFactory: (_) =>
                      throw const FileSystemException('injected sink failure'),
                ),
        fetch: ({required songId, required platform, quality, format}) async {
          fetches++;
          return {
            'url': 'http://127.0.0.1:${origin.port}/audio',
            'format': 'mp3',
          };
        },
      );
      final messages = <Map<dynamic, dynamic>>[];
      final subscription = handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'playbackTransitionError') {
          messages.add(event);
        }
      });
      addTearDown(subscription.cancel);
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      await HttpOverrides.runZoned(
        () => handler.setQueueData([_track()]),
        createHttpClient: _RealHttpOverrides().createHttpClient,
      );
      expect(fetches, 1);
      expect(proxyFailures, 1);
      await Future<void>.delayed(Duration.zero);
      expect(
        messages,
        isEmpty,
        reason: 'cache failure must not reach the user error channel',
      );
      expect(loaded, hasLength(2));
      expect(source!.downloadState, LockCachingAudioSourceState.failed);
      expect(source!.debugActiveResourceCount, 0);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
      expect(fixture.runtime.snapshot.entryCount, 0);
      expect(fixture.runtime.writeHealth, AudioCacheWriteHealth.ready);
    },
  );

  test(
    'exact cache hit precedes offline guard and survives stop/replay',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final key = _key();
      await fixture.publish(key);
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.offline);
      addTearDown(network.dispose);
      var fetchCount = 0;
      var playCount = 0;
      final loaded = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/song.mp3',
            'format': 'mp3',
          };
        },
        play: (_) async {
          playCount++;
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track()]);

      expect(fetchCount, 0);
      expect(fixture.store.lookupKeys, <AudioCacheKey>[key]);
      expect(fixture.store.admitKeys, isEmpty);
      expect((loaded.single as UriAudioSource).uri.scheme, 'file');
      expect(
        handler.currentSourceKindForTesting,
        AudioSourceKind.localCacheHit,
      );
      expect(handler.currentSourceRequiresNetworkForTesting, isFalse);
      expect(handler.currentCacheKeyForTesting, key);

      await handler.play();
      await handler.stop();
      expect(handler.currentSourceNeedsReloadForTesting, isFalse);
      await handler.play();

      expect(fetchCount, 0);
      expect(playCount, 2);
    },
  );

  test(
    'offline fallback commits actual quality without changing preference',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final fallbackKey = _key(quality: 999, format: 'flac');
      await fixture.publish(fallbackKey);
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.offline);
      addTearDown(network.dispose);
      final requests = <({String id, int? quality, String? format})>[];
      final queueEvents = <Map<dynamic, dynamic>>[];
      final loaded = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        fetch: ({required songId, required platform, quality, format}) async {
          requests.add((id: songId, quality: quality, format: format));
          return <String, dynamic>{
            'url': 'https://audio.invalid/$songId.$format',
            'format': format,
          };
        },
      );
      addTearDown(handler.disposeHandler);
      final subscription = handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'queueState') {
          queueEvents.add(event);
        }
      });
      addTearDown(subscription.cancel);
      await _syncConfig(handler, wifiQuality: AppOnlineAudioQuality.mp3320);

      await handler.setQueueData(<AudioTrack>[_track(links: _twoQualities)]);

      expect(requests, isEmpty);
      expect(handler.currentCacheKeyForTesting, fallbackKey);
      expect(handler.currentSourceRequiresNetworkForTesting, isFalse);
      final serialized = (queueEvents.last['tracks'] as List).single as Map;
      expect(serialized['format'], 'flac');
      expect(serialized['bitrate'], 999);
      expect((loaded.single as UriAudioSource).uri.scheme, 'file');

      await fixture.runtime.updatePolicy(
        const AudioCachePolicy(enabled: false),
      );
      network.emit(NetworkConnectionType.wifi);
      await handler.setQueueData(<AudioTrack>[
        _track(id: 'song-2', links: _twoQualities),
      ]);
      expect(requests.single.quality, 320);
      expect(requests.single.format, 'mp3');
    },
  );

  test('online exact miss does not use another cached quality', () async {
    final fixture = await _CacheFixture.create(
      policy: const AudioCachePolicy(enabled: false),
    );
    addTearDown(fixture.dispose);
    await fixture.publish(_key(quality: 999, format: 'flac'));
    fixture.store.resetCalls();
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    addTearDown(network.dispose);
    final requests = <({int? quality, String? format})>[];
    final loaded = <AudioSource>[];
    final handler = _handler(
      fixture: fixture,
      network: network,
      loaded: loaded,
      fetch: ({required songId, required platform, quality, format}) async {
        requests.add((quality: quality, format: format));
        return const <String, dynamic>{
          'url': 'https://audio.invalid/online.mp3',
          'format': 'mp3',
        };
      },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler, wifiQuality: AppOnlineAudioQuality.mp3320);

    await handler.setQueueData(<AudioTrack>[_track(links: _twoQualities)]);

    expect(requests.single.quality, 320);
    expect(requests.single.format, 'mp3');
    expect((loaded.single as UriAudioSource).uri.scheme, 'https');
    expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
    expect(handler.currentCacheKeyForTesting, isNull);
  });

  test(
    'missing stable LinkInfo fields never create lookup or write identity',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final requests = <({int? quality, String? format})>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        fetch: ({required songId, required platform, quality, format}) async {
          requests.add((quality: quality, format: format));
          return const <String, dynamic>{
            'url': 'https://audio.invalid/plain.mp3',
            'format': 'mp3',
          };
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      for (final track in <AudioTrack>[
        _track(id: 'no-link', links: const <LinkInfo>[]),
        _track(
          id: 'no-quality',
          links: const <LinkInfo>[
            LinkInfo(
              name: 'unknown',
              quality: 0,
              format: 'mp3',
              size: '10KB',
              url: '',
            ),
          ],
        ),
        _track(
          id: 'no-format',
          links: const <LinkInfo>[
            LinkInfo(
              name: '320k',
              quality: 320,
              format: '',
              size: '10KB',
              url: '',
            ),
          ],
        ),
      ]) {
        await handler.setQueueData(<AudioTrack>[track]);
        expect(
          handler.currentSourceKindForTesting,
          AudioSourceKind.plainRemote,
        );
        expect(handler.currentCacheKeyForTesting, isNull);
      }

      expect(fixture.store.lookupKeys, isEmpty);
      expect(fixture.store.admitKeys, isEmpty);
      expect(requests.first, (quality: 320, format: 'mp3'));
    },
  );

  test('invalid size allows an existing hit but never admits a miss', () async {
    final fixture = await _CacheFixture.create();
    addTearDown(fixture.dispose);
    final key = _key();
    await fixture.publish(key);
    fixture.store.resetCalls();
    final network = _FakeNetworkStatusPort(NetworkConnectionType.offline);
    addTearDown(network.dispose);
    var fetchCount = 0;
    final invalidSizeTrack = _track(
      links: const <LinkInfo>[
        LinkInfo(
          name: '320k',
          quality: 320,
          format: 'mp3',
          size: 'unknown',
          url: '',
        ),
      ],
    );
    final handler = _handler(
      fixture: fixture,
      network: network,
      loaded: <AudioSource>[],
      fetch: ({required songId, required platform, quality, format}) async {
        fetchCount++;
        return const <String, dynamic>{
          'url': 'https://audio.invalid/plain.mp3',
        };
      },
    );
    addTearDown(handler.disposeHandler);
    await _syncConfig(handler);

    await handler.setQueueData(<AudioTrack>[invalidSizeTrack]);
    expect(handler.currentSourceKindForTesting, AudioSourceKind.localCacheHit);
    expect(fetchCount, 0);

    await fixture.runtime.invalidate(key);
    network.emit(NetworkConnectionType.wifi);
    await handler.setQueueData(<AudioTrack>[
      _track(id: 'miss', links: invalidSizeTrack.links),
    ]);
    expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
    expect(fixture.store.admitKeys, isEmpty);
  });

  test(
    'preload resolves only typed URL payload and formal load owns cache work',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final secondPayload = Completer<Map<String, dynamic>>();
      final requests = <String>[];
      final loaded = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        fetch: ({required songId, required platform, quality, format}) {
          requests.add('$songId|$quality|$format');
          if (songId == 'song-2') {
            return secondPayload.future;
          }
          return Future<Map<String, dynamic>>.value(<String, dynamic>{
            'url': 'https://audio.invalid/$songId.mp3',
            'format': 'mp3',
          });
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[
        _track(id: 'song-1'),
        _track(id: 'song-2'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(requests, <String>['song-1|320|mp3', 'song-2|320|mp3']);
      expect(fixture.store.lookupKeys.map((key) => key.trackId), <String>[
        'song-1',
      ]);
      expect(fixture.store.admitKeys, isEmpty);
      expect(fixture.runtime.snapshot.activeLeaseCount, 0);

      final loadingSecond = handler.playIndex(1);
      await Future<void>.delayed(Duration.zero);
      expect(fixture.store.lookupKeys.map((key) => key.trackId), <String>[
        'song-1',
        'song-2',
      ]);
      expect(
        requests.where((value) => value.startsWith('song-2|')),
        hasLength(1),
      );
      secondPayload.complete(const <String, dynamic>{
        'url': 'https://audio.invalid/song-2.mp3',
        'format': 'mp3',
      });
      await loadingSecond;
      expect(loaded, hasLength(2));
    },
  );

  test(
    'clear revokes a pending hit and reloads one plain remote source',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      await fixture.publish(_key());
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final heldSet = Completer<Duration?>();
      final firstSet = Completer<void>();
      final loaded = <AudioSource>[];
      final released = <AudioSource>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        released: released,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/fallback.mp3',
            'format': 'mp3',
          };
        },
        setSource: (source, _) {
          loaded.add(source);
          if (loaded.length == 1) {
            firstSet.complete();
            return heldSet.future;
          }
          return Future<Duration?>.value(null);
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      final loading = handler.setQueueData(<AudioTrack>[_track()]);
      await firstSet.future;
      await fixture.runtime.clear();
      heldSet.complete(null);
      await loading;

      expect(loaded, hasLength(2));
      expect((loaded.first as UriAudioSource).uri.scheme, 'file');
      expect(
        (loaded.last as UriAudioSource).uri.toString(),
        'https://audio.invalid/fallback.mp3',
      );
      expect(released, contains(loaded.first));
      expect(fetchCount, 1);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
      expect(fixture.runtime.snapshot.activeLeaseCount, 0);
    },
  );

  test(
    'clear revokes a pending write and reuses the same URL only once',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final heldSet = Completer<Duration?>();
      final firstSet = Completer<void>();
      final loaded = <AudioSource>[];
      final cachingSources = <_ControlledCachingSource>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        cachingSources: cachingSources,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/one-url.mp3',
            'format': 'mp3',
          };
        },
        setSource: (source, _) {
          loaded.add(source);
          if (loaded.length == 1) {
            firstSet.complete();
            return heldSet.future;
          }
          return Future<Duration?>.value(null);
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      final loading = handler.setQueueData(<AudioTrack>[_track()]);
      await firstSet.future;
      expect(loaded.single, isA<LockCachingAudioSource>());
      await fixture.runtime.clear();
      heldSet.complete(null);
      await loading;

      expect(fetchCount, 1);
      expect(cachingSources, hasLength(1));
      expect(cachingSources.single.cancelCount, 1);
      expect(loaded, hasLength(2));
      expect(
        (loaded.last as UriAudioSource).uri.toString(),
        'https://audio.invalid/one-url.mp3',
      );
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
      expect(fixture.runtime.snapshot.activeLeaseCount, 0);
    },
  );

  test(
    'completed format mismatch serves current source then releases on stop',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        cachingSources: cachingSources,
        fetch: ({required songId, required platform, quality, format}) async =>
            const <String, dynamic>{
              'url': 'https://audio.invalid/fallback.flac',
              'format': 'flac',
            },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track()]);
      final source = cachingSources.single;
      await source.succeed(bytes: 32);
      await _waitUntil(
        () => handler.currentSourceRequiresNetworkForTesting == false,
      );

      expect(
        handler.currentSourceKindForTesting,
        AudioSourceKind.cachingRemote,
      );
      expect(fixture.runtime.snapshot.entryCount, 0);
      expect(await source.targetFile.exists(), isTrue);
      await handler.stop();
      expect(handler.currentSourceNeedsReloadForTesting, isTrue);
      expect(await source.targetFile.exists(), isFalse);
    },
  );

  test(
    'filesystem cache failure reloads plain at position with the same URL once',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      final loaded = <AudioSource>[];
      final errors = <Map<dynamic, dynamic>>[];
      final seeks = <Duration>[];
      var fetchCount = 0;
      var playCount = 0;
      final plainReloaded = Completer<void>();
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        cachingSources: cachingSources,
        position: (_) => const Duration(seconds: 41),
        seek: (position, _) async {
          seeks.add(position);
        },
        play: (_) async {
          playCount++;
        },
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/stable.mp3?token=secret',
            'format': 'mp3',
          };
        },
        setSource: (source, _) async {
          loaded.add(source);
          if (source is UriAudioSource && !plainReloaded.isCompleted) {
            plainReloaded.complete();
          }
          return null;
        },
      );
      addTearDown(handler.disposeHandler);
      final subscription = handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'playbackTransitionError') {
          errors.add(event);
        }
      });
      addTearDown(subscription.cancel);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track()]);
      final failedGeneration = handler.currentSourceGenerationForTesting!;
      await handler.play();
      cachingSources.single.fail(LockCachingAudioSourceFailure.fileSystem);
      await plainReloaded.future.timeout(const Duration(seconds: 2));
      await _waitUntil(
        () =>
            handler.currentSourceKindForTesting == AudioSourceKind.plainRemote,
      );

      expect(fetchCount, 1);
      expect(loaded, hasLength(2));
      expect(cachingSources, hasLength(1));
      expect(
        (loaded.last as UriAudioSource).uri.toString(),
        'https://audio.invalid/stable.mp3?token=secret',
      );
      expect(seeks, <Duration>[const Duration(seconds: 41)]);
      expect(playCount, 2);
      expect(errors, isEmpty);
      handler.handlePlaybackErrorForTesting(
        const FileSystemException('late'),
        sourceGeneration: failedGeneration,
      );
      await Future<void>.delayed(Duration.zero);
      expect(loaded, hasLength(2));
    },
  );

  test(
    'cached source set failure invalidates and falls back without URL shortcut',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final key = _key();
      await fixture.publish(key);
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/recovered.mp3',
            'format': 'mp3',
          };
        },
        setSource: (source, _) async {
          loaded.add(source);
          if (loaded.length == 1) {
            throw StateError('cached decode failed');
          }
          return null;
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track()]);

      expect(loaded, hasLength(2));
      expect((loaded.first as UriAudioSource).uri.scheme, 'file');
      expect((loaded.last as UriAudioSource).uri.scheme, 'https');
      expect(fetchCount, 1);
      expect(fixture.runtime.snapshot.entryCount, 0);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
    },
  );

  test(
    'cached source mid-play failure invalidates and recovers only while online',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final key = _key();
      await fixture.publish(key);
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/recovered.mp3',
            'format': 'mp3',
          };
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      await handler.setQueueData(<AudioTrack>[_track()]);

      handler.handlePlaybackErrorForTesting(StateError('decode failed'));
      await _waitUntil(
        () =>
            handler.currentSourceKindForTesting == AudioSourceKind.plainRemote,
      );

      expect(loaded, hasLength(2));
      expect(fetchCount, 1);
      expect(fixture.runtime.snapshot.entryCount, 0);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
    },
  );

  test(
    'unfinished write stops, cleans up, and reloads on the next play',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        cachingSources: cachingSources,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return <String, dynamic>{
            'url': 'https://audio.invalid/reload-$fetchCount.mp3',
            'format': 'mp3',
          };
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track()]);
      await handler.stop();

      expect(cachingSources.first.cancelCount, 1);
      expect(handler.currentSourceNeedsReloadForTesting, isTrue);
      expect(fixture.runtime.snapshot.activeLeaseCount, 0);

      await handler.play();
      expect(fetchCount, 2);
      expect(cachingSources, hasLength(2));
      expect(handler.currentSourceNeedsReloadForTesting, isFalse);
    },
  );

  test(
    'clear during active write suppresses publish but keeps current source',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      final loaded = <AudioSource>[];
      final seeks = <Duration>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        cachingSources: cachingSources,
        seek: (position, _) async {
          seeks.add(position);
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);
      await handler.setQueueData(<AudioTrack>[_track()]);
      final source = cachingSources.single;

      final clearResult = await fixture.runtime.clear();
      expect(clearResult.hasDeferredData, isTrue);
      await source.succeed(bytes: 32);
      await _waitUntil(
        () => handler.currentSourceRequiresNetworkForTesting == false,
      );

      expect(fixture.runtime.snapshot.entryCount, 0);
      expect(await source.targetFile.exists(), isTrue);
      await handler.pause();
      await handler.seek(const Duration(seconds: 7));
      await handler.setSingleLoopMode(true);
      expect(loaded, hasLength(1));
      expect(seeks, <Duration>[const Duration(seconds: 7)]);

      await handler.stop();
      expect(handler.currentSourceNeedsReloadForTesting, isTrue);
      expect(await source.targetFile.exists(), isFalse);
    },
  );

  test(
    'remote set retry releases failed staging before owning replacement',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      final loaded = <AudioSource>[];
      final released = <AudioSource>[];
      final errors = <Map<dynamic, dynamic>>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        released: released,
        cachingSources: cachingSources,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return <String, dynamic>{
            'url': 'https://audio.invalid/retry-$fetchCount.mp3',
            'format': 'mp3',
          };
        },
        setSource: (source, _) async {
          loaded.add(source);
          if (loaded.length == 1) {
            throw StateError('first load failed');
          }
          return null;
        },
      );
      addTearDown(handler.disposeHandler);
      final subscription = handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'playbackTransitionError') {
          errors.add(event);
        }
      });
      addTearDown(subscription.cancel);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track()]);

      expect(fetchCount, 2);
      expect(cachingSources, hasLength(2));
      expect(cachingSources.first.cancelCount, 1);
      expect(
        released.where((source) => identical(source, loaded.first)),
        hasLength(1),
      );
      expect(fixture.runtime.snapshot.activeLeaseCount, 1);
      expect(
        handler.currentSourceKindForTesting,
        AudioSourceKind.cachingRemote,
      );
      expect(errors, isEmpty);
    },
  );

  test(
    'oversized expected metadata creates plain source without proxy',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      final loaded = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        cachingSources: cachingSources,
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[
        _track(
          links: const <LinkInfo>[
            LinkInfo(
              name: '320k',
              quality: 320,
              format: 'mp3',
              size: '3GB',
              url: '',
            ),
          ],
        ),
      ]);

      expect(fixture.store.admitKeys, <AudioCacheKey>[_key()]);
      expect(cachingSources, isEmpty);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
      expect((loaded.single as UriAudioSource).uri.scheme, 'https');
    },
  );

  test(
    'API endpoint change keeps cache identity and performs no URL fetch',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final key = _key();
      await fixture.publish(key);
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/not-used.mp3',
          };
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler, apiBaseUrl: 'https://official.example');
      await handler.setQueueData(<AudioTrack>[_track()]);

      await _syncConfig(handler, apiBaseUrl: 'https://self-hosted.example');
      await handler.setQueueData(<AudioTrack>[_track()]);

      expect(fetchCount, 0);
      expect(fixture.runtime.snapshot.entryCount, 1);
      expect(handler.currentCacheKeyForTesting, key);
      expect(fixture.store.lookupKeys, <AudioCacheKey>[key, key]);
    },
  );

  test(
    'request cache identity and write policy stay frozen during URL load',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final requestStarted = Completer<void>();
      final payload = Completer<Map<String, dynamic>>();
      final cachingSources = <_ControlledCachingSource>[];
      final requests = <({int? quality, String? format})>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        cachingSources: cachingSources,
        fetch: ({required songId, required platform, quality, format}) {
          requests.add((quality: quality, format: format));
          requestStarted.complete();
          return payload.future;
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler, wifiQuality: AppOnlineAudioQuality.mp3320);

      final loading = handler.setQueueData(<AudioTrack>[
        _track(links: _twoQualities),
      ]);
      await requestStarted.future;
      await _syncConfig(
        handler,
        wifiQuality: AppOnlineAudioQuality.flac,
        cellularQuality: AppOnlineAudioQuality.flac,
      );
      network.emit(NetworkConnectionType.cellular);
      payload.complete(const <String, dynamic>{
        'url': 'https://audio.invalid/frozen.mp3',
        'format': 'mp3',
      });
      await loading;

      expect(requests.single, (quality: 320, format: 'mp3'));
      expect(handler.currentCacheKeyForTesting, _key());
      expect(
        handler.currentSourceKindForTesting,
        AudioSourceKind.cachingRemote,
      );
      expect(cachingSources, hasLength(1));
    },
  );

  test('published source survives stop until clear defers deletion', () async {
    final fixture = await _CacheFixture.create();
    addTearDown(fixture.dispose);
    final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
    addTearDown(network.dispose);
    final cachingSources = <_ControlledCachingSource>[];
    final loaded = <AudioSource>[];
    final seeks = <Duration>[];
    final errors = <Map<dynamic, dynamic>>[];
    var fetchCount = 0;
    final handler = _handler(
      fixture: fixture,
      network: network,
      loaded: loaded,
      cachingSources: cachingSources,
      seek: (position, _) async {
        seeks.add(position);
      },
      fetch: ({required songId, required platform, quality, format}) async {
        fetchCount++;
        return const <String, dynamic>{
          'url': 'https://audio.invalid/published.mp3',
          'format': 'mp3',
        };
      },
    );
    addTearDown(handler.disposeHandler);
    final subscription = handler.customEvent.listen((event) {
      if (event is Map && event['type'] == 'playbackTransitionError') {
        errors.add(event);
      }
    });
    addTearDown(subscription.cancel);
    await _syncConfig(handler);
    await handler.setQueueData(<AudioTrack>[_track()]);
    final source = cachingSources.single;
    await source.succeed(bytes: 32);
    await _waitUntil(
      () =>
          handler.currentSourceRequiresNetworkForTesting == false &&
          fixture.runtime.snapshot.entryCount == 1,
    );

    await handler.stop();
    expect(handler.currentSourceNeedsReloadForTesting, isFalse);
    expect(await source.targetFile.exists(), isTrue);
    await handler.play();

    final clearResult = await fixture.runtime.clear();
    expect(clearResult.hasDeferredData, isTrue);
    expect(fixture.runtime.snapshot.entryCount, 0);
    await handler.pause();
    await handler.seek(const Duration(seconds: 5));
    await handler.setSingleLoopMode(true);
    expect(loaded, hasLength(1));
    expect(seeks, <Duration>[const Duration(seconds: 5)]);

    await handler.stop();
    expect(handler.currentSourceNeedsReloadForTesting, isTrue);
    expect(await source.targetFile.exists(), isFalse);
    network.emit(NetworkConnectionType.offline);
    await handler.play();
    await _waitUntil(() => errors.isNotEmpty);
    expect(fetchCount, 1);
    expect(loaded, hasLength(1));
  });

  test(
    'origin failure remains an ordinary playback failure without reload',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      final loaded = <AudioSource>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        cachingSources: cachingSources,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/origin.mp3',
            'format': 'mp3',
          };
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track()]);
      cachingSources.single.fail(LockCachingAudioSourceFailure.originStream);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fetchCount, 1);
      expect(loaded, hasLength(1));
      expect(
        handler.currentSourceKindForTesting,
        AudioSourceKind.cachingRemote,
      );
      expect(handler.currentSourceRequiresNetworkForTesting, isTrue);
    },
  );

  test(
    'offline cached playback error invalidates without remote fallback',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      await fixture.publish(_key());
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.offline);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      final errors = <Map<dynamic, dynamic>>[];
      var fetchCount = 0;
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        fetch: ({required songId, required platform, quality, format}) async {
          fetchCount++;
          return const <String, dynamic>{
            'url': 'https://audio.invalid/forbidden.mp3',
          };
        },
      );
      addTearDown(handler.disposeHandler);
      final subscription = handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'playbackTransitionError') {
          errors.add(event);
        }
      });
      addTearDown(subscription.cancel);
      await _syncConfig(handler);
      await handler.setQueueData(<AudioTrack>[_track()]);

      handler.handlePlaybackErrorForTesting(StateError('cached decode failed'));
      await _waitUntil(() => errors.isNotEmpty);

      expect(fetchCount, 0);
      expect(loaded, hasLength(1));
      expect(fixture.runtime.snapshot.entryCount, 0);
      expect(handler.currentSourceNeedsReloadForTesting, isTrue);
      expect(errors.last['code'], 'networkUnavailable');
    },
  );

  test(
    'stale in-flight source waits for native load before unregistering',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final firstSet = Completer<void>();
      final firstGate = Completer<Duration?>();
      final loaded = <AudioSource>[];
      final released = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        released: released,
        setSource: (source, _) {
          loaded.add(source);
          if (loaded.length == 1) {
            firstSet.complete();
            return firstGate.future;
          }
          return Future<Duration?>.value(null);
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      final firstLoad = handler.setQueueData(<AudioTrack>[
        _track(id: 'song-1'),
      ]);
      await firstSet.future;
      await handler.setQueueData(<AudioTrack>[_track(id: 'song-2')]);
      expect(handler.mediaItem.value?.id, 'song-2');
      expect(released, isEmpty);

      firstGate.complete(null);
      await firstLoad;
      await _waitUntil(() => released.isNotEmpty);
      expect(
        released.where((source) => identical(source, loaded.first)),
        hasLength(1),
      );
      expect(handler.mediaItem.value?.id, 'song-2');
    },
  );

  test(
    'dispose waits for pending native load then releases registration',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final setStarted = Completer<void>();
      final setGate = Completer<Duration?>();
      final released = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        released: released,
        setSource: (source, _) {
          setStarted.complete();
          return setGate.future;
        },
      );
      await _syncConfig(handler);

      final loading = handler.setQueueData(<AudioTrack>[_track()]);
      await setStarted.future;
      var disposeCompleted = false;
      final disposing = handler.disposeHandler().then((_) {
        disposeCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(disposeCompleted, isFalse);
      expect(released, isEmpty);

      setGate.complete(null);
      await Future.wait<void>(<Future<void>>[loading, disposing]);
      expect(released, hasLength(1));
    },
  );

  test(
    'cache initialization failure degrades to plain remote without hanging',
    () async {
      final directory = await Directory.systemTemp.createTemp('broken-cache-');
      final blocker = File('${directory.path}/not-a-directory');
      await blocker.writeAsString('blocked');
      final fileStore = FileAudioCacheStore(
        capacity: _CapacityPort(),
        applicationCacheDirectory: () async => Directory(blocker.path),
      );
      final store = _RecordingAudioCacheStore(fileStore);
      final runtime = AudioCacheRuntime(store: store, capabilityEnabled: true);
      await runtime.initialize();
      final fixture = _CacheFixture._(directory, fileStore, store, runtime);
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler
          .setQueueData(<AudioTrack>[_track()])
          .timeout(const Duration(seconds: 2));

      expect(runtime.readHealth, AudioCacheReadHealth.unavailable);
      expect(runtime.writeHealth, AudioCacheWriteHealth.unavailable);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
      expect((loaded.single as UriAudioSource).uri.scheme, 'https');
    },
  );

  test(
    'cache diagnostics identify decisions without URL path or raw key',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final logs = <String>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        logs: logs,
        fetch: ({required songId, required platform, quality, format}) async =>
            const <String, dynamic>{
              'url': 'https://audio.example/song.mp3?token=secret-token',
              'format': 'mp3',
            },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track(id: 'private-song-id')]);

      final output = logs.join('\n');
      final cacheOutput = logs
          .where((line) => line.startsWith('cache.'))
          .join('\n');
      expect(cacheOutput, contains('cache.lookup.miss'));
      expect(cacheOutput, contains('cache.write.rejected'));
      expect(cacheOutput, contains('cacheKey='));
      expect(cacheOutput, isNot(contains('private-song-id')));
      expect(output, isNot(contains('https://')));
      expect(output, isNot(contains('secret-token')));
      expect(output, isNot(contains(Directory.systemTemp.path)));
    },
  );

  test(
    'plain and local replacements release source registration exactly once',
    () async {
      final fixture = await _CacheFixture.create(
        policy: const AudioCachePolicy(enabled: false),
      );
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      final released = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        released: released,
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(const <AudioTrack>[
        AudioTrack(
          id: 'local-1',
          title: 'Local 1',
          url: '',
          path: '/tmp/1.mp3',
        ),
        AudioTrack(
          id: 'local-2',
          title: 'Local 2',
          url: '',
          path: '/tmp/2.mp3',
        ),
      ]);
      await handler.playIndex(1);
      await handler.setQueueData(const <AudioTrack>[]);

      expect(loaded, hasLength(2));
      expect(released, hasLength(2));
      expect(released.toSet(), loaded.toSet());
    },
  );

  test(
    'late completion from a replaced generation cannot publish or change state',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final cachingSources = <_ControlledCachingSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: <AudioSource>[],
        cachingSources: cachingSources,
        cachingSourceBuilder: (uri, file, tag) => _ControlledCachingSource(
          uri,
          targetFile: file,
          tag: tag,
          settleOnCancel: false,
        ),
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track(id: 'song-1')]);
      final old = cachingSources.single;
      await handler.setQueueData(<AudioTrack>[_track(id: 'song-2')]);
      final newGeneration = handler.currentSourceGenerationForTesting;
      expect(old.cancelCount, 1);

      await old.succeed(bytes: 32);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(handler.mediaItem.value?.id, 'song-2');
      expect(handler.currentSourceGenerationForTesting, newGeneration);
      expect(handler.currentSourceRequiresNetworkForTesting, isTrue);
      expect(fixture.runtime.snapshot.entryCount, 0);
    },
  );

  test(
    'write-only failure preserves cache reads and makes later misses plain',
    () async {
      final fixture = await _CacheFixture.create();
      addTearDown(fixture.dispose);
      final hitKey = _key(track: 'hit');
      await fixture.publish(hitKey);
      fixture.store.resetCalls();
      final network = _FakeNetworkStatusPort(NetworkConnectionType.wifi);
      addTearDown(network.dispose);
      final loaded = <AudioSource>[];
      final handler = _handler(
        fixture: fixture,
        network: network,
        loaded: loaded,
        cachingSourceBuilder: (uri, file, tag) {
          throw const SocketException(
            'bind failed',
            osError: OSError('not permitted', 13),
          );
        },
      );
      addTearDown(handler.disposeHandler);
      await _syncConfig(handler);

      await handler.setQueueData(<AudioTrack>[_track(id: 'miss')]);
      expect(fixture.runtime.writeHealth, AudioCacheWriteHealth.unavailable);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);

      await handler.setQueueData(<AudioTrack>[_track(id: 'hit')]);
      expect(
        handler.currentSourceKindForTesting,
        AudioSourceKind.localCacheHit,
      );
      expect((loaded.last as UriAudioSource).uri.scheme, 'file');
    },
  );
}

const _twoQualities = <LinkInfo>[
  LinkInfo(name: '320k', quality: 320, format: 'mp3', size: '10KB', url: ''),
  LinkInfo(name: 'FLAC', quality: 999, format: 'flac', size: '12KB', url: ''),
];

AudioTrack _track({
  String id = 'song',
  List<LinkInfo> links = const <LinkInfo>[
    LinkInfo(name: '320k', quality: 320, format: 'mp3', size: '10KB', url: ''),
  ],
}) {
  return AudioTrack(
    id: id,
    title: 'Track $id',
    url: '',
    platform: 'qq',
    links: links,
  );
}

AudioCacheKey _key({
  String track = 'song',
  int quality = 320,
  String format = 'mp3',
}) {
  return AudioCacheKey.tryCreate(
    platform: 'qq',
    trackId: track,
    quality: quality,
    requestedFormat: format,
  )!;
}

HeAudioHandler _handler({
  required _CacheFixture fixture,
  required _FakeNetworkStatusPort network,
  required List<AudioSource> loaded,
  List<AudioSource>? released,
  List<_ControlledCachingSource>? cachingSources,
  HeAudioHandlerFetchSongUrl? fetch,
  HeAudioHandlerSetAudioSource? setSource,
  HeAudioHandlerPlay? play,
  HeAudioHandlerPosition? position,
  HeAudioHandlerSeek? seek,
  _ControlledCachingSource Function(Uri, File, MediaItem)? cachingSourceBuilder,
  AudioPlayer? player,
  bool realNative = false,
  HeAudioHandlerCreateCachingSource? realCachingBuilder,
  List<String>? logs,
}) {
  return HeAudioHandler(
    player: player,
    audioCacheRuntime: fixture.runtime,
    networkStatusPort: network,
    fetchSongUrlOverride:
        fetch ??
        ({required songId, required platform, quality, format}) async =>
            <String, dynamic>{
              'url': 'https://audio.invalid/$songId.${format ?? 'mp3'}',
              'format': format ?? 'mp3',
            },
    setAudioSourceOverride:
        setSource ??
        (source, player) async {
          loaded.add(source);
          return realNative ? player.setAudioSource(source) : null;
        },
    createCachingSourceOverride:
        realCachingBuilder ??
        ({required uri, required cacheFile, required tag}) {
          final source =
              cachingSourceBuilder?.call(uri, cacheFile, tag) ??
              _ControlledCachingSource(uri, targetFile: cacheFile, tag: tag);
          cachingSources?.add(source);
          return source;
        },
    releaseAudioSourceOverride: (source, player) async {
      released?.add(source);
      if (realNative) await player.releaseAudioSource(source);
    },
    playOverride: play ?? (player) async {},
    positionOverride: position,
    seekOverride: seek,
    logOverride: logs?.add,
    disposeOverride: (player) async {
      if (realNative) await player.dispose();
    },
  );
}

Future<void> _syncConfig(
  HeAudioHandler handler, {
  String apiBaseUrl = 'https://api.test',
  AppOnlineAudioQuality wifiQuality = AppOnlineAudioQuality.auto,
  AppOnlineAudioQuality cellularQuality = AppOnlineAudioQuality.mp3320,
}) {
  return handler.syncConfig(
    apiBaseUrl: apiBaseUrl,
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

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition did not become true', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

NativeAudioTestPlatform _installNativePlatform() {
  final original = JustAudioPlatform.instance;
  final platform = NativeAudioTestPlatform();
  JustAudioPlatform.instance = platform;
  const channel = MethodChannel('com.ryanheise.audio_session');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => null);
  addTearDown(() {
    JustAudioPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  return platform;
}

class _RealHttpOverrides extends HttpOverrides {}

final class _FailingBindOverrides extends IOOverrides {
  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async {
    throw const SocketException(
      'injected bind failure',
      osError: OSError('denied', 13),
    );
  }
}

class _HeldStopPlayer extends AudioPlayer {
  Completer<void>? stopGate;
  final stopStarted = Completer<void>();

  @override
  Future<void> stop() async {
    final gate = stopGate;
    stopGate = null;
    if (gate != null) {
      stopStarted.complete();
      await gate.future;
    }
    await super.stop();
  }
}

final class _CacheFixture {
  _CacheFixture._(this.directory, this.fileStore, this.store, this.runtime);

  final Directory directory;
  final FileAudioCacheStore fileStore;
  final _RecordingAudioCacheStore store;
  final AudioCacheRuntime runtime;

  static Future<_CacheFixture> create({
    AudioCachePolicy policy = const AudioCachePolicy(),
  }) async {
    final directory = await Directory.systemTemp.createTemp('handler-cache-');
    final fileStore = FileAudioCacheStore(
      capacity: _CapacityPort(),
      applicationCacheDirectory: () async => directory,
    );
    final store = _RecordingAudioCacheStore(fileStore);
    final runtime = AudioCacheRuntime(
      store: store,
      capabilityEnabled: true,
      policy: policy,
    );
    await runtime.initialize();
    return _CacheFixture._(directory, fileStore, store, runtime);
  }

  Future<void> publish(AudioCacheKey key, {int bytes = 32}) async {
    final lease = await fileStore.admitAndBeginWrite(
      key: key,
      resolvedFormat: key.requestedFormat,
      expectedBytes: bytes,
      limitBytes: runtime.policy.limitBytes,
    );
    if (lease == null) {
      throw StateError('fixture admission failed');
    }
    await File(lease.path).writeAsBytes(List<int>.filled(bytes, 1));
    final publication = await fileStore.completeWrite(
      lease,
      mimeType: key.requestedFormat == 'flac' ? 'audio/flac' : 'audio/mpeg',
    );
    if (publication != AudioCachePublication.published) {
      throw StateError('fixture publication failed: $publication');
    }
    await lease.dispose();
  }

  Future<void> dispose() async {
    await fileStore.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class _CapacityPort implements AudioCacheDiskCapacityPort {
  @override
  Future<int?> availableBytes(String cachePath) async =>
      AudioCachePolicy.physicalFloorBytes + 100 * 1024 * 1024;
}

final class _RecordingAudioCacheStore implements AudioCacheStore {
  _RecordingAudioCacheStore(this.delegate);

  final AudioCacheStore delegate;
  final List<AudioCacheKey> lookupKeys = <AudioCacheKey>[];
  final List<AudioCacheKey> admitKeys = <AudioCacheKey>[];

  void resetCalls() {
    lookupKeys.clear();
    admitKeys.clear();
  }

  @override
  AudioCacheReadHealth get readHealth => delegate.readHealth;

  @override
  AudioCacheWriteHealth get writeHealth => delegate.writeHealth;

  @override
  AudioCacheSnapshot get snapshot => delegate.snapshot;

  @override
  Stream<AudioCacheSnapshot> get snapshots => delegate.snapshots;

  @override
  Future<void> initialize() => delegate.initialize();

  @override
  Future<AudioCacheSourceLease?> lookupAndPin(
    AudioCacheKey key, {
    bool offline = false,
  }) {
    lookupKeys.add(key);
    return delegate.lookupAndPin(key, offline: offline);
  }

  @override
  Future<AudioCacheSourceLease?> admitAndBeginWrite({
    required AudioCacheKey key,
    required String resolvedFormat,
    required int? expectedBytes,
    required int limitBytes,
  }) {
    admitKeys.add(key);
    return delegate.admitAndBeginWrite(
      key: key,
      resolvedFormat: resolvedFormat,
      expectedBytes: expectedBytes,
      limitBytes: limitBytes,
    );
  }

  @override
  Future<AudioCachePublication> completeWrite(
    AudioCacheSourceLease lease, {
    String? mimeType,
  }) => delegate.completeWrite(lease, mimeType: mimeType);

  @override
  Future<void> abort(AudioCacheSourceLease lease, {bool failed = false}) =>
      delegate.abort(lease, failed: failed);

  Future<void> Function(AudioCacheKey)? beforeInvalidate;

  @override
  Future<void> invalidate(AudioCacheKey key) async {
    await beforeInvalidate?.call(key);
    await delegate.invalidate(key);
  }

  @override
  Future<AudioCacheClearResult> clear() => delegate.clear();

  @override
  Future<void> setLimitBytes(int limitBytes) =>
      delegate.setLimitBytes(limitBytes);

  @override
  void markWriteUnavailable() => delegate.markWriteUnavailable();

  @override
  void markReadUnavailable() => delegate.markReadUnavailable();

  @override
  Future<void> dispose() => delegate.dispose();
}

final class _ControlledCachingSource extends LockCachingAudioSource {
  _ControlledCachingSource(
    super.uri, {
    required this.targetFile,
    required super.tag,
    this.settleOnCancel = true,
  }) : super(cacheFile: targetFile);

  final File targetFile;
  final bool settleOnCancel;
  final Completer<File> _terminal = Completer<File>();
  LockCachingAudioSourceState _controlledState =
      LockCachingAudioSourceState.active;
  int cancelCount = 0;

  @override
  Future<File> get completedFile => _terminal.future;

  @override
  LockCachingAudioSourceState get downloadState => _controlledState;

  Future<void> succeed({required int bytes}) async {
    await targetFile.writeAsBytes(List<int>.filled(bytes, 1));
    _controlledState = LockCachingAudioSourceState.completed;
    if (!_terminal.isCompleted) {
      _terminal.complete(targetFile);
    }
    await _terminal.future;
  }

  void fail(LockCachingAudioSourceFailure failure) {
    _controlledState = LockCachingAudioSourceState.failed;
    if (!_terminal.isCompleted) {
      _terminal.completeError(LockCachingAudioSourceException(failure));
    }
  }

  @override
  Future<void> cancelDownload() async {
    cancelCount++;
    if (_controlledState != LockCachingAudioSourceState.active) {
      return;
    }
    _controlledState = LockCachingAudioSourceState.cancelled;
    if (settleOnCancel && !_terminal.isCompleted) {
      _terminal.completeError(
        const LockCachingAudioSourceException(
          LockCachingAudioSourceFailure.cancelled,
        ),
      );
    }
  }
}

final class _FakeNetworkStatusPort implements NetworkStatusPort {
  _FakeNetworkStatusPort(this._current);

  final StreamController<NetworkConnectionType> _controller =
      StreamController<NetworkConnectionType>.broadcast(sync: true);
  NetworkConnectionType _current;

  @override
  Stream<NetworkConnectionType> get changes => _controller.stream;

  @override
  Future<NetworkConnectionType> current() async => _current;

  @override
  NetworkConnectionType get lastKnown => _current;

  void emit(NetworkConnectionType value) {
    _current = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}

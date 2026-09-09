import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/audio_cache_bootstrap.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_disk_capacity_port.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';

import '../core/audio/cache/cache_test_support.dart';
import '../core/audio/cache/phase4_cache_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bootstrap waits for persistence but does not await reconcile',
    () async {
      final configGate = Completer<AppConfigState>();
      final rootGate = Completer<Directory>();
      final directory = await Directory.systemTemp.createTemp(
        'cache-bootstrap-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final config = AppConfigState.initial.copyWith(
        enablePlaybackAudioCache: false,
        enableCellularAudioCache: true,
        audioCacheLimitBytes: AudioCachePolicy.limits.first,
      );
      final source = RecordingCacheConfigDataSource(
        config,
        hydration: configGate,
      );
      final store = FileAudioCacheStore(
        capacity: FakeCapacity(),
        applicationCacheDirectory: () => rootGate.future,
      );
      addTearDown(store.dispose);
      var creations = 0;
      final preparing = prepareAudioBootstrap(
        platform: TargetPlatform.android,
        dataSource: source,
        createStore: () {
          creations++;
          return store;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(creations, 0);
      configGate.complete(config);
      final audio = await preparing.timeout(const Duration(seconds: 1));
      expect(creations, 1);
      expect(audio.runtime!.store, same(store));
      expect(audio.runtime!.policy.enabled, isFalse);
      expect(audio.runtime!.policy.allowCellular, isTrue);
      expect(audio.runtime!.policy.limitBytes, AudioCachePolicy.limits.first);
      expect(audio.runtime!.readHealth, AudioCacheReadHealth.initializing);
      var lookupFinished = false;
      final lookup = audio.runtime!.lookupAndPin(cacheKey()).then((result) {
        lookupFinished = true;
        return result;
      });
      await Future<void>.delayed(Duration.zero);
      expect(lookupFinished, isFalse);
      rootGate.complete(directory);
      expect(await lookup, isNull);
      expect(audio.runtime!.readHealth, AudioCacheReadHealth.ready);
      final handlerConfig = await loadHeAudioHandlerRuntimeConfig(
        dataSource: source,
        initialConfig: audio.config,
      );
      expect(
        handlerConfig.wifiQualityPreference,
        config.wifiOnlineAudioQualityPreference,
      );
      expect(source.loads, 1);
    },
  );

  test(
    'bootstrap failed root reaches unavailable and lookups finish',
    () async {
      final store = FileAudioCacheStore(
        capacity: FakeCapacity(),
        applicationCacheDirectory: () async =>
            throw const FileSystemException('root'),
      );
      addTearDown(store.dispose);
      final source = RecordingCacheConfigDataSource(AppConfigState.initial);
      final audio = await prepareAudioBootstrap(
        platform: TargetPlatform.macOS,
        dataSource: source,
        createStore: () => store,
      );
      expect(
        await audio.runtime!
            .lookupAndPin(cacheKey())
            .timeout(const Duration(seconds: 1)),
        isNull,
      );
      expect(audio.runtime!.readHealth, AudioCacheReadHealth.unavailable);
      expect(audio.runtime!.writeHealth, AudioCacheWriteHealth.unavailable);
      expect(source.saved, isEmpty);
      expect(audio.config.enablePlaybackAudioCache, isTrue);
    },
  );

  for (final platform in TargetPlatform.values) {
    test('production capability for $platform is independent', () async {
      final store = RecordingAudioCacheStore();
      addTearDown(store.dispose);
      var creations = 0;
      final audio = await prepareAudioBootstrap(
        platform: platform,
        dataSource: RecordingCacheConfigDataSource(AppConfigState.initial),
        createStore: () {
          creations++;
          return store;
        },
      );
      final supported =
          platform == TargetPlatform.android ||
          platform == TargetPlatform.macOS;
      expect(creations, supported ? 1 : 0);
      expect(audio.runtime != null, supported);
    });
  }

  test('web and an unverified Android gate never construct a store', () async {
    for (final web in [true, false]) {
      final audio = await prepareAudioBootstrap(
        platform: TargetPlatform.android,
        isWeb: web,
        capability: AudioCacheCapability(
          androidReleaseVerified: web,
          macosReleaseVerified: true,
        ),
        dataSource: RecordingCacheConfigDataSource(AppConfigState.initial),
        createStore: () => throw StateError('must not construct'),
      );
      expect(audio.runtime, isNull);
    }
  });
}

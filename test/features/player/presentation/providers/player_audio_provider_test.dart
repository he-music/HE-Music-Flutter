import 'package:he_music_flutter/app/config/app_lyric_auxiliary_mode.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/audio_handler_player_adapter.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_provider.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_source_plan.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/audio/cache/phase4_cache_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'held hydration cannot overwrite disabled bootstrap policy on first play',
    () async {
      final persisted = AppConfigState.initial.copyWith(
        enablePlaybackAudioCache: false,
      );
      final gate = Completer<AppConfigState>();
      final source = RecordingCacheConfigDataSource(persisted, hydration: gate);
      final store = RecordingAudioCacheStore();
      addTearDown(store.dispose);
      final runtime = AudioCacheRuntime(
        store: store,
        capabilityEnabled: true,
        policy: persisted.audioCachePolicy,
      );
      final loaded = <AudioSource>[];
      final handler = HeAudioHandler(
        initialConfig: persisted,
        configDataSourceOverride: source,
        audioCacheRuntime: runtime,
        networkStatusPort: _WifiNetwork(),
        fetchSongUrlOverride:
            ({required songId, required platform, quality, format}) async => {
              'url': 'https://audio.invalid/song.mp3',
              'format': 'mp3',
            },
        fetchLyricsOverride: ({required trackId, platform, localPath}) async =>
            const LyricDocument.empty(),
        setAudioSourceOverride: (audioSource, _) async {
          loaded.add(audioSource);
          return null;
        },
        playOverride: (_) async {},
        releaseAudioSourceOverride: (_, _) async {},
      );
      addTearDown(handler.disposeHandler);
      final adapter = _RecordingAdapter(handler);
      final container = ProviderContainer(
        overrides: [
          appConfigDataSourceProvider.overrideWithValue(source),
          audioCacheRuntimeProvider.overrideWithValue(runtime),
          audioHandlerPlayerAdapterProvider.overrideWithValue(adapter),
          onlinePlatformsProvider.overrideWith(_NoPlatforms.new),
        ],
      );
      addTearDown(container.dispose);
      container.read(audioPlayerPortProvider);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(appConfigProvider).enablePlaybackAudioCache,
        isTrue,
      );
      expect(adapter.synced, isEmpty);
      expect(store.limits, isEmpty);
      expect(runtime.policy.enabled, isFalse);
      await handler.setQueueData([
        const AudioTrack(
          id: 'song',
          title: 'Song',
          url: '',
          platform: 'qq',
          links: [
            LinkInfo(
              name: '320k',
              quality: 320,
              format: 'mp3',
              size: '10KB',
              url: '',
            ),
          ],
        ),
      ]);
      expect(handler.currentSourceKindForTesting, AudioSourceKind.plainRemote);
      expect(store.lookupCalls, 1);
      expect(store.admissionCalls, 0);
      expect(loaded, hasLength(1));
      expect(source.loads, 1);
      gate.complete(persisted);
      await container.read(appConfigProvider.notifier).waitUntilHydrated();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.synced, hasLength(1));
      expect(adapter.synced.single.enablePlaybackAudioCache, isFalse);
      expect(runtime.policy.enabled, isFalse);
      final controller = container.read(appConfigProvider.notifier);
      final limitUpdates = store.limits.length;
      controller.setLocaleCode('en');
      await Future<void>.delayed(Duration.zero);
      expect(store.limits.length, limitUpdates);
      expect(adapter.synced, hasLength(1));
      controller.setEnablePlaybackAudioCache(true);
      controller.setEnableCellularAudioCache(true);
      controller.setAudioCacheLimitBytes(AudioCachePolicy.limits.first);
      await Future<void>.delayed(Duration.zero);
      expect(runtime.policy.enabled, isTrue);
      expect(runtime.policy.allowCellular, isTrue);
      expect(runtime.policy.limitBytes, AudioCachePolicy.limits.first);
      expect(adapter.synced, hasLength(1));
      expect(loaded, hasLength(1));
      expect(store.admissionCalls, 0);
      await handler.setQueueData([
        const AudioTrack(
          id: 'next',
          title: 'Next',
          url: '',
          platform: 'qq',
          links: [
            LinkInfo(
              name: '320k',
              quality: 320,
              format: 'mp3',
              size: '10KB',
              url: '',
            ),
          ],
        ),
      ]);
      expect(store.admissionCalls, 1);
    },
  );

  test(
    'auxiliary preference synchronizes to the handler independently of audio cache policy',
    () async {
      final handler = HeAudioHandler(
        initialConfig: AppConfigState.initial,
        networkStatusPort: _WifiNetwork(),
      );
      addTearDown(handler.disposeHandler);
      final adapter = _RecordingAdapter(handler);
      final container = ProviderContainer(
        overrides: [
          appConfigDataSourceProvider.overrideWithValue(
            RecordingCacheConfigDataSource(AppConfigState.initial),
          ),
          audioCacheRuntimeProvider.overrideWithValue(null),
          audioHandlerPlayerAdapterProvider.overrideWithValue(adapter),
          onlinePlatformsProvider.overrideWith(_NoPlatforms.new),
        ],
      );
      addTearDown(container.dispose);
      container.read(audioPlayerPortProvider);
      await container.read(appConfigProvider.notifier).waitUntilHydrated();
      await Future<void>.delayed(Duration.zero);
      final previousCount = adapter.synced.length;
      container
          .read(appConfigProvider.notifier)
          .setLyricAuxiliaryMode(AppLyricAuxiliaryMode.romanization);
      await Future<void>.delayed(Duration.zero);
      expect(adapter.synced.length, previousCount + 1);
      expect(
        adapter.synced.last.lyricAuxiliaryMode,
        AppLyricAuxiliaryMode.romanization,
      );
    },
  );

  test('disposed provider does not sync after held hydration', () async {
    final gate = Completer<AppConfigState>();
    final store = RecordingAudioCacheStore();
    addTearDown(store.dispose);
    final handler = HeAudioHandler(
      initialConfig: AppConfigState.initial,
      networkStatusPort: _WifiNetwork(),
    );
    addTearDown(handler.disposeHandler);
    final adapter = _RecordingAdapter(handler);
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          RecordingCacheConfigDataSource(
            AppConfigState.initial,
            hydration: gate,
          ),
        ),
        audioHandlerPlayerAdapterProvider.overrideWithValue(adapter),
        audioCacheRuntimeProvider.overrideWithValue(
          AudioCacheRuntime(store: store, capabilityEnabled: true),
        ),
        onlinePlatformsProvider.overrideWith(_NoPlatforms.new),
      ],
    );
    container.read(audioPlayerPortProvider);
    container.dispose();
    gate.complete(AppConfigState.initial);
    await Future<void>.delayed(Duration.zero);
    expect(adapter.synced, isEmpty);
    expect(store.limits, isEmpty);
  });
}

class _RecordingAdapter extends AudioHandlerPlayerAdapter {
  _RecordingAdapter(super.handler);
  final synced = <AppConfigState>[];
  @override
  Future<void> syncConfig(AppConfigState config) {
    synced.add(config);
    return super.syncConfig(config);
  }
}

class _NoPlatforms extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async => [];
}

class _WifiNetwork implements NetworkStatusPort {
  @override
  NetworkConnectionType get lastKnown => NetworkConnectionType.wifi;
  @override
  Stream<NetworkConnectionType> get changes => const Stream.empty();
  @override
  Future<NetworkConnectionType> current() async => lastKnown;
}

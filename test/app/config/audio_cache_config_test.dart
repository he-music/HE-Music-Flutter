import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/cache/phase4_cache_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const dataSource = AppConfigDataSource();

  test('cache defaults load without migrating old configurations', () async {
    SharedPreferences.setMockInitialValues({});
    final config = await dataSource.load();
    expect(config.enablePlaybackAudioCache, isTrue);
    expect(config.enableCellularAudioCache, isFalse);
    expect(config.audioCacheLimitBytes, AudioCachePolicy.defaultLimitBytes);
  });

  for (final invalid in <Object>['true', 12, <String>[], -1, 0, 2.0]) {
    test('invalid persisted cache policy falls back: $invalid', () async {
      SharedPreferences.setMockInitialValues({
        'app_config.enable_playback_audio_cache': invalid,
        'app_config.enable_cellular_audio_cache': invalid,
        'app_config.audio_cache_limit_bytes': invalid,
      });
      final config = await dataSource.load();
      expect(config.enablePlaybackAudioCache, isTrue);
      expect(config.enableCellularAudioCache, isFalse);
      expect(config.audioCacheLimitBytes, AudioCachePolicy.defaultLimitBytes);
    });
  }

  for (final limit in AudioCachePolicy.limits) {
    test('cache settings round trip target $limit', () async {
      SharedPreferences.setMockInitialValues({});
      await dataSource.save(
        AppConfigState.initial.copyWith(
          enablePlaybackAudioCache: false,
          enableCellularAudioCache: true,
          audioCacheLimitBytes: limit,
        ),
      );
      final config = await dataSource.load();
      expect(config.enablePlaybackAudioCache, isFalse);
      expect(config.enableCellularAudioCache, isTrue);
      expect(config.audioCacheLimitBytes, limit);
      expect(config.audioCachePolicy.enabled, isFalse);
      expect(config.audioCachePolicy.allowCellular, isTrue);
      expect(config.audioCachePolicy.limitBytes, limit);
    });
  }

  test(
    'controller hydrates and persists policy while preserving child value',
    () async {
      final gate = Completer<AppConfigState>();
      final source = RecordingCacheConfigDataSource(
        AppConfigState.initial,
        hydration: gate,
      );
      final container = ProviderContainer(
        overrides: [appConfigDataSourceProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appConfigProvider.notifier);
      expect(
        container.read(appConfigProvider).enablePlaybackAudioCache,
        isTrue,
      );
      gate.complete(
        AppConfigState.initial.copyWith(
          enablePlaybackAudioCache: false,
          enableCellularAudioCache: true,
        ),
      );
      await controller.waitUntilHydrated();
      expect(
        container.read(appConfigProvider).enablePlaybackAudioCache,
        isFalse,
      );
      controller.setEnablePlaybackAudioCache(true);
      controller.setEnablePlaybackAudioCache(false);
      controller.setAudioCacheLimitBytes(AudioCachePolicy.limits.first);
      controller.setAudioCacheLimitBytes(-1);
      await Future<void>.delayed(Duration.zero);
      expect(source.saved.last.enableCellularAudioCache, isTrue);
      expect(source.saved.last.enablePlaybackAudioCache, isFalse);
      expect(
        source.saved.last.audioCacheLimitBytes,
        AudioCachePolicy.limits.first,
      );
      controller.setEnableCellularAudioCache(false);
      await Future<void>.delayed(Duration.zero);
      expect(source.saved.last.enableCellularAudioCache, isFalse);
    },
  );

  test('bootstrap config hydration reuses the persisted snapshot', () async {
    final source = RecordingCacheConfigDataSource(AppConfigState.initial);
    final config = AppConfigState.initial.copyWith(
      enablePlaybackAudioCache: false,
    );
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(source),
        bootstrapAppConfigProvider.overrideWithValue(config),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appConfigProvider.notifier).waitUntilHydrated();
    expect(source.loads, 0);
    expect(container.read(appConfigProvider).enablePlaybackAudioCache, isFalse);
  });
}

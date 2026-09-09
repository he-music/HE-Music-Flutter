import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../core/audio/audio_handler_player_adapter.dart';
import '../../../../core/audio/audio_player_port.dart';
import '../../../../core/audio/audio_sleep_timer.dart';
import '../../../../core/audio/audio_spectrum_port.dart';
import '../../../../core/audio/he_audio_handler.dart';
import '../../../../core/audio/cache/audio_cache_provider.dart';
import '../../../online/presentation/providers/online_providers.dart';

final audioHandlerPlayerAdapterProvider = Provider<AudioHandlerPlayerAdapter>(
  (ref) => AudioHandlerPlayerAdapter(globalHeAudioHandler),
);

final audioPlayerPortProvider = Provider<AudioPlayerPort>((ref) {
  final adapter = ref.watch(audioHandlerPlayerAdapterProvider);
  final runtime = ref.read(audioCacheRuntimeProvider);
  var hydrated = false;

  void syncConfig() {
    if (hydrated) unawaited(adapter.syncConfig(ref.read(appConfigProvider)));
  }

  void syncCachePolicy() {
    if (hydrated && runtime != null) {
      unawaited(
        runtime.updatePolicy(ref.read(appConfigProvider).audioCachePolicy),
      );
    }
  }

  Future<void> syncAfterHydration() async {
    await ref.read(appConfigProvider.notifier).waitUntilHydrated();
    if (!ref.mounted) return;
    hydrated = true;
    syncConfig();
    syncCachePolicy();
  }

  void syncCoverPlatforms() {
    final platforms = ref.read(onlinePlatformsProvider).value;
    if (platforms != null) {
      unawaited(adapter.syncCoverPlatforms(platforms));
    }
  }

  unawaited(syncAfterHydration());
  syncCoverPlatforms();
  ref.listen(
    appConfigProvider.select(
      (config) => (
        config.enablePlaybackAudioCache,
        config.enableCellularAudioCache,
        config.audioCacheLimitBytes,
      ),
    ),
    (_, _) => syncCachePolicy(),
  );
  ref.listen(
    appConfigProvider.select(
      (config) => (
        apiBaseUrl: config.apiBaseUrl,
        authToken: config.authToken,
        wifiOnlineAudioQualityPreference:
            config.wifiOnlineAudioQualityPreference,
        cellularOnlineAudioQualityPreference:
            config.cellularOnlineAudioQualityPreference,
        lastSelectedOnlineAudioQualityName:
            config.lastSelectedOnlineAudioQualityName,
        enableDesktopLyric: config.enableDesktopLyric,
        enableDesktopLyricLock: config.enableDesktopLyricLock,
        lyricHighlightMode: config.lyricHighlightMode,
        lyricHighlightPreset: config.lyricHighlightPreset,
        lyricHighlightCustomColor: config.lyricHighlightCustomColor,
        lyricFontPreset: config.lyricFontPreset,
        enableWordByWordLyric: config.enableWordByWordLyric,
        lyricAuxiliaryMode: config.lyricAuxiliaryMode,
      ),
    ),
    (_, _) => syncConfig(),
  );
  ref.listen(
    onlinePlatformsProvider.select((platforms) => platforms.value),
    (_, _) => syncCoverPlatforms(),
  );
  return adapter;
});

final audioSpectrumPortProvider = Provider<AudioSpectrumPort?>((ref) {
  final player = ref.watch(audioPlayerPortProvider);
  return switch (player) {
    AudioSpectrumPort spectrumPort => spectrumPort,
    _ => null,
  };
});

final sleepTimerAudioPortProvider = Provider<SleepTimerAudioPort?>((ref) {
  final player = ref.watch(audioPlayerPortProvider);
  return switch (player) {
    SleepTimerAudioPort sleepTimerPort => sleepTimerPort,
    _ => null,
  };
});

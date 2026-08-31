import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../core/audio/audio_handler_player_adapter.dart';
import '../../../../core/audio/audio_player_port.dart';
import '../../../../core/audio/audio_sleep_timer.dart';
import '../../../../core/audio/audio_spectrum_port.dart';
import '../../../../core/audio/he_audio_handler.dart';
import '../../../online/presentation/providers/online_providers.dart';

final audioPlayerPortProvider = Provider<AudioPlayerPort>((ref) {
  final adapter = AudioHandlerPlayerAdapter(globalHeAudioHandler);

  void syncConfig() {
    unawaited(adapter.syncConfig(ref.read(appConfigProvider)));
  }

  void syncCoverPlatforms() {
    final platforms = ref.read(onlinePlatformsProvider).value;
    if (platforms != null) {
      unawaited(adapter.syncCoverPlatforms(platforms));
    }
  }

  syncConfig();
  syncCoverPlatforms();
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

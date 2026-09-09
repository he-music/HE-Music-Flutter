import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/audio/cache/audio_cache_disk_capacity_port.dart';
import '../core/audio/cache/audio_cache_runtime.dart';
import '../core/audio/cache/audio_cache_store.dart';
import '../core/audio/cache/file_audio_cache_store.dart';
import 'config/app_config_data_source.dart';
import 'config/app_config_state.dart';
import 'audio_cache_simulator_guard.dart';

// Independent source/proxy and capacity Release gates: task research/phase-1-
// results.md and phase-2-results.md. iOS has no Release device gate.
const playbackAudioCacheCapability = AudioCacheCapability(
  androidReleaseVerified: true,
  macosReleaseVerified: true,
);

Future<({AppConfigState config, AudioCacheRuntime? runtime})>
prepareAudioBootstrap({
  AppConfigDataSource dataSource = const AppConfigDataSource(),
  AudioCacheCapability capability = playbackAudioCacheCapability,
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
  AudioCacheStore Function()? createStore,
  bool debugIosSimulatorCache = false,
}) async {
  if (debugIosSimulatorCache) await requireAudioCacheDebugSimulator();
  final config = await dataSource.load();
  AudioCacheRuntime? runtime;
  if (debugIosSimulatorCache ||
      capability.supports(platform ?? defaultTargetPlatform, isWeb: isWeb)) {
    runtime = AudioCacheRuntime(
      store:
          createStore?.call() ??
          FileAudioCacheStore(
            capacity: const MethodChannelAudioCacheDiskCapacityPort(),
          ),
      capabilityEnabled: true,
      policy: config.audioCachePolicy,
    );
    // First lookup awaits the store's terminal initialization, not the first frame.
    unawaited(runtime.initialize());
  }
  return (config: config, runtime: runtime);
}

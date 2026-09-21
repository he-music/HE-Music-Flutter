import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'config/app_environment.dart';
import 'config/app_config_controller.dart';
import 'config/app_config_data_source.dart';
import 'config/app_config_state.dart';
import '../core/audio/cache/audio_cache_store.dart';
import '../core/audio/cache/audio_cache_runtime.dart';
import 'audio_cache_bootstrap.dart';
import 'audio_cache_simulator_guard.dart';
import '../core/audio/cache/audio_cache_provider.dart';
import '../core/audio/he_audio_handler.dart';
import 'app.dart';
import 'theme/glass/app_glass_scope.dart';

Future<void> bootstrap({
  AppConfigDataSource dataSource = const AppConfigDataSource(),
  AudioCacheStore Function()? createAudioCacheStore,
  HeAudioHandler Function(AppConfigState?, AudioCacheRuntime?)?
  createAudioHandler,
  Widget Function(AppConfigState, AudioCacheRuntime?)? createApp,
  bool debugIosSimulatorCache = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final glassEnabled = await AppGlassScope.initialize();
  if (debugIosSimulatorCache) await requireAudioCacheDebugSimulator();
  MediaKit.ensureInitialized();
  await AppEnvironment.initialize();
  _setupHttpOverrides();
  final audio = await prepareAudioBootstrap(
    dataSource: dataSource,
    createStore: createAudioCacheStore,
    debugIosSimulatorCache: debugIosSimulatorCache,
  );
  await initHeAudioHandler(
    config: audio.config,
    audioCacheRuntime: audio.runtime,
    createHandler: createAudioHandler,
  );
  await _enableSystemStatusBar();
  runApp(
    ProviderScope(
      overrides: [
        bootstrapAppConfigProvider.overrideWithValue(audio.config),
        audioCacheRuntimeProvider.overrideWithValue(audio.runtime),
      ],
      child: AppGlassScope.wrap(
        enabled: glassEnabled,
        adaptiveQuality: false,
        child: AppGlassPreferences(
          available: glassEnabled,
          child:
              createApp?.call(audio.config, audio.runtime) ??
              const HeMusicApp(),
        ),
      ),
    ),
  );
}

Future<void> _enableSystemStatusBar() async {
  if (kIsWeb) {
    return;
  }
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
}

void _setupHttpOverrides() {
  if (kIsWeb) {
    return;
  }
  HttpOverrides.global = _AppHttpOverrides();
}

class _AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent =
        'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    return client;
  }
}

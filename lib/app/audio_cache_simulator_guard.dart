import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const audioCacheSimulatorBundle = 'com.hemusic.music.flutter.cachesim';
const _channel = MethodChannel('com.hemusic/audio_cache_capacity');

/// This is test authorization, never Release capability evidence.
Future<void> requireAudioCacheDebugSimulator() async {
  if (!kDebugMode ||
      !Platform.isIOS ||
      !const bool.fromEnvironment('AUDIO_CACHE_IOS_SIMULATOR')) {
    throw StateError('simulator_opt_in_required');
  }
  final identity = await _channel.invokeMethod<Object?>('simulatorIdentity');
  if (!audioCacheSimulatorIdentityAllowed(identity)) {
    throw StateError('simulator_identity_refused');
  }
}

@visibleForTesting
bool audioCacheSimulatorIdentityAllowed(Object? identity) =>
    identity is Map &&
    identity['simulator'] == true &&
    identity['bundle'] == audioCacheSimulatorBundle;

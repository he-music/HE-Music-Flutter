import 'dart:async';

import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_key.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_store.dart';

class RecordingCacheConfigDataSource extends AppConfigDataSource {
  RecordingCacheConfigDataSource(this.config, {this.hydration});
  AppConfigState config;
  final Completer<AppConfigState>? hydration;
  int loads = 0;
  final saved = <AppConfigState>[];

  @override
  Future<AppConfigState> load() async {
    loads++;
    return hydration == null ? config : await hydration!.future;
  }

  @override
  Future<void> save(AppConfigState state) async {
    config = state;
    saved.add(state);
  }
}

class RecordingAudioCacheStore implements AudioCacheStore {
  final controller = StreamController<AudioCacheSnapshot>.broadcast(sync: true);
  final limits = <int>[];
  int clearCalls = 0;
  int lookupCalls = 0;
  int admissionCalls = 0;
  bool deferred = false;
  bool failClear = false;
  AudioCacheSnapshot currentSnapshot = const AudioCacheSnapshot(
    readHealth: AudioCacheReadHealth.ready,
    writeHealth: AudioCacheWriteHealth.ready,
  );

  void emit(AudioCacheSnapshot value) {
    currentSnapshot = value;
    controller.add(value);
  }

  @override
  AudioCacheSnapshot get snapshot => currentSnapshot;
  @override
  Stream<AudioCacheSnapshot> get snapshots => controller.stream;
  @override
  AudioCacheReadHealth get readHealth => snapshot.readHealth;
  @override
  AudioCacheWriteHealth get writeHealth => snapshot.writeHealth;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> setLimitBytes(int limitBytes) async => limits.add(limitBytes);
  @override
  Future<AudioCacheClearResult> clear() async {
    clearCalls++;
    if (failClear) throw StateError('clear');
    emit(AudioCacheSnapshot(clearEpoch: clearCalls));
    return AudioCacheClearResult(hasDeferredData: deferred);
  }

  @override
  Future<AudioCacheSourceLease?> lookupAndPin(
    AudioCacheKey key, {
    bool offline = false,
  }) async {
    lookupCalls++;
    return null;
  }

  @override
  Future<AudioCacheSourceLease?> admitAndBeginWrite({
    required AudioCacheKey key,
    required String resolvedFormat,
    required int? expectedBytes,
    required int limitBytes,
  }) async {
    admissionCalls++;
    return null;
  }

  @override
  void markReadUnavailable() => emit(
    const AudioCacheSnapshot(
      readHealth: AudioCacheReadHealth.unavailable,
      writeHealth: AudioCacheWriteHealth.unavailable,
    ),
  );
  @override
  void markWriteUnavailable() => emit(
    AudioCacheSnapshot(
      readHealth: readHealth,
      writeHealth: AudioCacheWriteHealth.unavailable,
    ),
  );
  @override
  Future<void> dispose() => controller.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

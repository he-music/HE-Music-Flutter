import 'dart:async';
import 'dart:io';

import '../../network/network_status_port.dart';
import 'audio_cache_entry.dart';
import 'audio_cache_key.dart';
import 'audio_cache_policy.dart';
import 'audio_cache_source_plan.dart';
import 'audio_cache_store.dart';

/// Shared process ownership boundary for playback and settings.
final class AudioCacheRuntime {
  AudioCacheRuntime({
    required this.store,
    required this.capabilityEnabled,
    AudioCachePolicy policy = const AudioCachePolicy(),
  }) : _policy = policy;

  final AudioCacheStore store;
  final bool capabilityEnabled;
  AudioCachePolicy _policy;
  AudioCachePolicy get policy => _policy;
  AudioCacheReadHealth get readHealth =>
      capabilityEnabled ? store.readHealth : AudioCacheReadHealth.unavailable;
  AudioCacheWriteHealth get writeHealth =>
      capabilityEnabled ? store.writeHealth : AudioCacheWriteHealth.unavailable;
  AudioCacheSnapshot get snapshot => store.snapshot;
  Stream<AudioCacheSnapshot> get snapshots => store.snapshots;

  Future<void> initialize() async {
    if (!capabilityEnabled) return;
    try {
      await store.initialize();
      await store.setLimitBytes(_policy.limitBytes);
    } catch (_) {
      store.markReadUnavailable();
    }
  }

  Future<void> updatePolicy(AudioCachePolicy policy) async {
    _policy = policy;
    if (capabilityEnabled) {
      try {
        await store.setLimitBytes(policy.limitBytes);
      } catch (_) {
        store.markReadUnavailable();
      }
    }
  }

  Future<AudioCacheSourceLease?> lookupAndPin(
    AudioCacheKey key, {
    bool offline = false,
  }) async =>
      capabilityEnabled ? store.lookupAndPin(key, offline: offline) : null;

  /// Pass a snapshot captured at source selection, never reread network/policy
  /// after URL resolution. Partial factory construction owns its native cleanup.
  Future<PlaybackSourceLease?> createCachingSource({
    required AudioCacheKey key,
    required String resolvedFormat,
    required int? expectedBytes,
    required AudioCachePolicy frozenPolicy,
    required NetworkConnectionType frozenNetwork,
    required FutureOr<PlaybackSourceLease> Function(AudioCacheSourceLease lease)
    factory,
  }) async {
    if (!capabilityEnabled || !frozenPolicy.allowsWrite(frozenNetwork)) {
      return null;
    }
    final lease = await store.admitAndBeginWrite(
      key: key,
      resolvedFormat: resolvedFormat,
      expectedBytes: expectedBytes,
      limitBytes: frozenPolicy.limitBytes,
    );
    if (lease == null) return null;
    PlaybackSourceLease? source;
    try {
      source = await factory(lease);
      if (!identical(source.cacheLease, lease)) {
        throw StateError('Factory lost data ownership');
      }
      return source;
    } catch (_) {
      // Factory failures do not imply a structural writer failure. The source
      // adapter explicitly calls markWriteUnavailable for a bind/init failure.
      await source?.dispose();
      await store.abort(lease);
      await lease.dispose();
      return null;
    }
  }

  /// Attach immediately to the vendor terminal Future. This consumes failure
  /// and leaves playback recovery decisions with HeAudioHandler (Phase 3).
  Future<AudioCachePublication> observeWriteCompletion(
    AudioCacheSourceLease lease,
    Future<File> completedFile,
  ) async {
    try {
      final file = await completedFile;
      if (file.path != lease.path) {
        await store.abort(lease, failed: true);
        return AudioCachePublication.rejected;
      }
      return await store.completeWrite(lease);
    } catch (_) {
      await store.abort(lease, failed: true);
      return AudioCachePublication.rejected;
    }
  }

  Future<void> invalidate(AudioCacheKey key) =>
      capabilityEnabled ? store.invalidate(key) : Future.value();

  void markWriteUnavailable() => store.markWriteUnavailable();
  Future<AudioCacheClearResult> clear() => capabilityEnabled
      ? store.clear()
      : Future.value(const AudioCacheClearResult(hasDeferredData: false));
}

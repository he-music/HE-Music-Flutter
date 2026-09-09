import 'audio_cache_entry.dart';
import 'audio_cache_key.dart';

abstract interface class AudioCacheStore {
  Future<void> initialize();
  AudioCacheReadHealth get readHealth;
  AudioCacheWriteHealth get writeHealth;
  AudioCacheSnapshot get snapshot;
  Stream<AudioCacheSnapshot> get snapshots;
  Future<AudioCacheSourceLease?> lookupAndPin(
    AudioCacheKey key, {
    bool offline = false,
  });
  Future<AudioCacheSourceLease?> admitAndBeginWrite({
    required AudioCacheKey key,
    required String resolvedFormat,
    required int? expectedBytes,
    required int limitBytes,
  });

  /// Only invoke after the transport's verified success terminal. The store
  /// validates file/metadata, not HTTP status or response-body completeness.
  Future<AudioCachePublication> completeWrite(
    AudioCacheSourceLease lease, {
    String? mimeType,
  });

  /// Native must no longer read this session and transport must be closed.
  Future<void> abort(AudioCacheSourceLease lease, {bool failed = false});
  Future<void> invalidate(AudioCacheKey key);

  /// Fences lookup immediately; storage/cleanup failure must not report success.
  /// Owned data may remain until its native playback lease is released.
  Future<AudioCacheClearResult> clear();
  Future<void> setLimitBytes(int limitBytes);
  void markWriteUnavailable();
  void markReadUnavailable();
  Future<void> dispose();
}

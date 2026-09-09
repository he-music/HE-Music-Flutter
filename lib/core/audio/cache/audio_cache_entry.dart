import 'audio_cache_key.dart';

enum AudioCacheReadHealth { initializing, ready, unavailable }

enum AudioCacheWriteHealth { initializing, ready, unavailable }

enum AudioCacheLeaseState {
  pinnedData,
  activeWrite,
  retainedData,
  cancelled,
  failed,
  disposed,
}

enum AudioCachePublication { none, published, suppressed, rejected }

abstract interface class AudioCacheSourceLease {
  AudioCacheKey get key;
  String get path;
  String get resolvedFormat;
  int get acquisitionEpoch;
  AudioCacheLeaseState get state;
  AudioCachePublication get publication;
  bool get committedForPlayback;
  int? get playbackGeneration;
  bool get commitRevoked;
  bool get clearedDeferred;
  bool get publishSuppressed;
  bool get canRetainOnStop;

  Future<bool> commitForPlayback(int generation);
  Future<void> touchAfterSourceCommit();

  /// First detach native use and close the transport through the playback owner.
  Future<void> dispose();
}

final class AudioCacheMetadata {
  const AudioCacheMetadata({
    required this.key,
    required this.fileName,
    required this.resolvedFormat,
    required this.actualBytes,
    required this.completedAtMs,
  });

  final AudioCacheKey key;
  final String fileName;
  final String resolvedFormat;
  final int actualBytes;
  final int completedAtMs;

  Map<String, Object> toJson() => {
    'schema': key.schema,
    'key': key.toJson(),
    'file_name': fileName,
    'resolved_format': resolvedFormat,
    'actual_bytes': actualBytes,
    'completed_at_ms': completedAtMs,
  };

  static AudioCacheMetadata? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final schema = value['schema'];
    final rawKey = value['key'];
    final name = value['file_name'];
    final format = value['resolved_format'];
    final bytes = value['actual_bytes'];
    final completed = value['completed_at_ms'];
    if (schema is! int ||
        rawKey is! Map<String, dynamic> ||
        rawKey['platform'] is! String ||
        rawKey['track_id'] is! String ||
        rawKey['quality'] is! int ||
        rawKey['requested_format'] is! String ||
        name is! String ||
        format is! String ||
        bytes is! int ||
        bytes <= 0 ||
        completed is! int ||
        completed < 0) {
      return null;
    }
    final key = AudioCacheKey.tryCreate(
      schema: schema,
      platform: rawKey['platform'] as String,
      trackId: rawKey['track_id'] as String,
      quality: rawKey['quality'] as int,
      requestedFormat: rawKey['requested_format'] as String,
    );
    if (key == null ||
        format != key.requestedFormat ||
        !audioCacheFormats.contains(format) ||
        !RegExp(
          '^${key.digest}\\.[a-zA-Z0-9_-]+\\.${RegExp.escape(format)}\$',
        ).hasMatch(name)) {
      return null;
    }
    return AudioCacheMetadata(
      key: key,
      fileName: name,
      resolvedFormat: format,
      actualBytes: bytes,
      completedAtMs: completed,
    );
  }
}

const audioCacheFormats = <String>{
  'mp3',
  'flac',
  'm4a',
  'aac',
  'ogg',
  'opus',
  'wav',
  'aiff',
  'alac',
};

enum AudioCacheMimeValidation { matches, conflict, unverified }

bool audioCacheMimeMatches(String format, String? mime) =>
    validateAudioCacheMime(format, mime) != AudioCacheMimeValidation.conflict;

AudioCacheMimeValidation validateAudioCacheMime(String format, String? mime) {
  final normalized = mime?.split(';').first.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return AudioCacheMimeValidation.unverified;
  }
  const known = <String, Set<String>>{
    'audio/mpeg': {'mp3'},
    'audio/mp3': {'mp3'},
    'audio/flac': {'flac'},
    'audio/x-flac': {'flac'},
    'audio/mp4': {'m4a', 'alac'},
    'audio/x-m4a': {'m4a', 'alac'},
    'audio/aac': {'aac'},
    'audio/aacp': {'aac'},
    'audio/ogg': {'ogg', 'opus'},
    'application/ogg': {'ogg', 'opus'},
    'audio/opus': {'ogg', 'opus'},
    'audio/wav': {'wav'},
    'audio/wave': {'wav'},
    'audio/x-wav': {'wav'},
    'audio/aiff': {'aiff'},
    'audio/x-aiff': {'aiff'},
  };
  final formats = known[normalized];
  if (formats != null) {
    return formats.contains(format)
        ? AudioCacheMimeValidation.matches
        : AudioCacheMimeValidation.conflict;
  }
  // Unknown/generic types are not evidence of a conflicting representation.
  return normalized.startsWith('text/') ||
          normalized.startsWith('image/') ||
          normalized.startsWith('video/') ||
          normalized == 'application/json' ||
          normalized == 'application/xml'
      ? AudioCacheMimeValidation.conflict
      : AudioCacheMimeValidation.unverified;
}

final class AudioCacheSnapshot {
  const AudioCacheSnapshot({
    this.publishedBytes = 0,
    this.managedFootprintBytes = 0,
    this.entryCount = 0,
    this.activeLeaseCount = 0,
    this.clearEpoch = 0,
    this.readHealth = AudioCacheReadHealth.initializing,
    this.writeHealth = AudioCacheWriteHealth.initializing,
  });

  final int publishedBytes;
  final int managedFootprintBytes;
  final int entryCount;
  final int activeLeaseCount;
  final int clearEpoch;
  final AudioCacheReadHealth readHealth;
  final AudioCacheWriteHealth writeHealth;
}

final class AudioCacheClearException implements Exception {
  const AudioCacheClearException();

  @override
  String toString() => 'Audio cache could not be cleared';
}

final class AudioCacheClearResult {
  const AudioCacheClearResult({required this.hasDeferredData});
  final bool hasDeferredData;
}

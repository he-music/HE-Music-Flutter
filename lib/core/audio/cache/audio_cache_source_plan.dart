import 'package:just_audio/just_audio.dart';

import 'audio_cache_entry.dart';
import 'audio_cache_key.dart';

enum AudioSourceKind { localTrack, localCacheHit, cachingRemote, plainRemote }

/// The sole source-lifetime owner, including sources without cache data.
final class PlaybackSourceLease {
  PlaybackSourceLease({
    required this.source,
    required Future<void> Function() releaseNative,
    required Future<void> Function() cancelTransport,
    required Future<void> Function() releaseSourceRegistration,
    this.cacheLease,
  }) : _releaseNative = releaseNative,
       _cancelTransport = cancelTransport,
       _releaseSourceRegistration = releaseSourceRegistration;

  final AudioSource source;
  final AudioCacheSourceLease? cacheLease;

  /// Must await native detach/replacement/stop, including an in-flight set.
  /// This is mandatory even for local/plain sources; a no-op requires the
  /// caller to already possess proof that native no longer uses the source.
  final Future<void> Function() _releaseNative;
  final Future<void> Function() _cancelTransport;
  final Future<void> Function() _releaseSourceRegistration;
  bool _nativeReleased = false;
  bool _transportCancelled = false;
  bool _dataReleased = false;
  bool _registrationReleased = false;
  Future<void>? _disposal;

  bool get isDisposed => _registrationReleased;

  Future<void> dispose() {
    final current = _disposal;
    if (current != null) return current;
    final attempt = _dispose();
    _disposal = attempt;
    // A failed native fence must not release data. Permit an explicit retry.
    attempt.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        _disposal = null;
      },
    );
    return attempt;
  }

  Future<void> _dispose() async {
    if (!_nativeReleased) {
      await _releaseNative();
      _nativeReleased = true;
    }
    if (!_transportCancelled) {
      await _cancelTransport();
      _transportCancelled = true;
    }
    if (!_dataReleased) {
      await cacheLease?.dispose();
      _dataReleased = true;
    }
    if (!_registrationReleased) {
      await _releaseSourceRegistration();
      _registrationReleased = true;
    }
  }
}

/// A pending owner. The handler must check its transition immediately before
/// commit and after awaiting it; a returned lease is then its sole ownership.
final class ResolvedAudioSourcePlan {
  ResolvedAudioSourcePlan({
    required this.cacheKey,
    required this.requestedQuality,
    required this.requestedFormat,
    required this.resolvedFormat,
    required this.expectedBytes,
    required this.kind,
    required this.requiresNetwork,
    required PlaybackSourceLease sourceLease,
  }) : _sourceLease = sourceLease {
    final cache = sourceLease.cacheLease;
    if ((kind == AudioSourceKind.localCacheHit ||
            kind == AudioSourceKind.cachingRemote) &&
        (cache == null || cache.key != cacheKey)) {
      throw ArgumentError('Cache plans require their actual owned key');
    }
    if ((kind == AudioSourceKind.localTrack ||
            kind == AudioSourceKind.plainRemote) &&
        cache != null) {
      throw ArgumentError('Plain sources cannot own cache data');
    }
  }

  final AudioCacheKey? cacheKey;
  final int requestedQuality;
  final String requestedFormat;
  final String resolvedFormat;
  final int? expectedBytes;
  final AudioSourceKind kind;
  final bool requiresNetwork;
  final PlaybackSourceLease _sourceLease;
  bool _commitAttempted = false;
  bool _disposeRequested = false;
  bool _transferred = false;
  Future<PlaybackSourceLease?>? _commitFuture;

  AudioSource get source => _sourceLease.source;
  bool get isTransferred => _transferred;

  /// Null means the clear fence revoked this plan. The caller must not commit
  /// handler state and may reload plain remote with writes disabled for that
  /// transition. Native cleanup is awaited here, never inside the store queue.
  Future<PlaybackSourceLease?> commit(int generation) {
    if (_commitAttempted || _disposeRequested) {
      throw StateError('Plan already settled');
    }
    _commitAttempted = true;
    return _commitFuture = _commit(generation);
  }

  Future<PlaybackSourceLease?> _commit(int generation) async {
    final cache = _sourceLease.cacheLease;
    final accepted = cache == null || await cache.commitForPlayback(generation);
    if (!accepted || _disposeRequested) {
      await _sourceLease.dispose();
      return null;
    }
    _transferred = true;
    return _sourceLease;
  }

  Future<void> dispose() async {
    _disposeRequested = true;
    try {
      await _commitFuture;
    } finally {
      if (!_transferred) await _sourceLease.dispose();
    }
  }
}

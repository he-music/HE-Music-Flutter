import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/config/app_config_data_source.dart';
import '../../app/config/app_environment.dart';
import '../../app/config/app_lyric_font_preset.dart';
import '../../app/config/app_lyric_highlight_color.dart';
import '../../app/config/app_lyric_highlight_mode.dart';
import '../../app/config/app_config_state.dart';
import '../../app/config/app_online_audio_quality.dart';
import '../../features/lyrics/data/datasources/demo_lyric_data_source.dart';
import '../../features/lyrics/data/datasources/online_lyric_data_source.dart';
import '../../features/lyrics/data/repositories/lyric_repository_impl.dart';
import '../../features/lyrics/domain/entities/lyric_document.dart';
import '../../features/lyrics/domain/entities/lyric_request.dart';
import '../../features/lyrics/domain/repositories/lyric_repository.dart';
import '../../features/lyrics_overlay/application/overlay_lyrics_service.dart';
import '../../features/lyrics_overlay/domain/services/overlay_channel_service.dart';
import '../../features/online/data/online_api_client.dart';
import '../../features/online/domain/entities/online_platform.dart';
import '../../shared/models/he_music_models.dart';
import '../../shared/utils/cover_resolver.dart';
import '../../shared/utils/audio_quality_selector.dart';
import '../network/token_refresh_interceptor.dart';
import 'audio_player_port.dart';
import 'audio_player_factory.dart';
import 'audio_track.dart';
import 'local_audio_metadata_reader.dart';

class HeAudioHandlerRuntimeConfig {
  const HeAudioHandlerRuntimeConfig({
    required this.apiBaseUrl,
    required this.authToken,
    required this.qualityPreference,
    required this.lastSelectedQualityName,
    required this.enableDesktopLyric,
    required this.enableDesktopLyricLock,
    required this.lyricHighlightMode,
    required this.lyricHighlightPresetColorValue,
    required this.lyricHighlightCustomColorValue,
    required this.lyricFontPresetIndex,
    required this.enableWordByWordLyric,
  });

  final String apiBaseUrl;
  final String? authToken;
  final AppOnlineAudioQuality qualityPreference;
  final String? lastSelectedQualityName;
  final bool enableDesktopLyric;
  final bool enableDesktopLyricLock;
  final AppLyricHighlightMode lyricHighlightMode;
  final int lyricHighlightPresetColorValue;
  final int? lyricHighlightCustomColorValue;
  final int lyricFontPresetIndex;
  final bool enableWordByWordLyric;
}

typedef HeAudioHandlerFetchSongUrl =
    Future<Map<String, dynamic>> Function({
      required String songId,
      required String platform,
      int? quality,
      String? format,
    });

typedef HeAudioHandlerSetAudioSource =
    Future<Duration?> Function(AudioSource source, AudioPlayer player);
typedef HeAudioHandlerPlay = Future<void> Function(AudioPlayer player);
typedef HeAudioHandlerDispose = Future<void> Function(AudioPlayer player);
typedef HeAudioHandlerNow = DateTime Function();
typedef HeAudioHandlerLog = void Function(String message);

typedef HeAudioHandlerFetchRadioSongs =
    Future<List<SongInfo>> Function({
      required String id,
      required String platform,
      int pageIndex,
      int pageSize,
    });

typedef HeAudioHandlerFetchLyrics =
    Future<LyricDocument> Function({
      required String trackId,
      String? platform,
      String? localPath,
    });

@visibleForTesting
Future<HeAudioHandlerRuntimeConfig> loadHeAudioHandlerRuntimeConfig({
  AppConfigDataSource dataSource = const AppConfigDataSource(),
}) async {
  final config = await dataSource.load();
  return HeAudioHandlerRuntimeConfig(
    apiBaseUrl: config.apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
    authToken: config.authToken?.trim(),
    qualityPreference: config.onlineAudioQualityPreference,
    lastSelectedQualityName: config.lastSelectedOnlineAudioQualityName?.trim(),
    enableDesktopLyric: config.enableDesktopLyric,
    enableDesktopLyricLock: config.enableDesktopLyricLock,
    lyricHighlightMode: config.lyricHighlightMode,
    lyricHighlightPresetColorValue: config.lyricHighlightPreset.color
        .toARGB32(),
    lyricHighlightCustomColorValue: config.lyricHighlightCustomColor,
    lyricFontPresetIndex: config.lyricFontPreset.index,
    enableWordByWordLyric: config.enableWordByWordLyric,
  );
}

@visibleForTesting
bool shouldRefreshRemotePlaybackUrl(AudioTrack track) {
  final localPath = track.path?.trim() ?? '';
  if (localPath.isNotEmpty) {
    return false;
  }
  final sourceUrl = track.url.trim();
  final parsedUrl = Uri.tryParse(sourceUrl);
  if (parsedUrl != null && parsedUrl.scheme == 'file') {
    return false;
  }
  final platform = track.platform?.trim() ?? '';
  return platform.isNotEmpty;
}

class HeAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static const Duration _overlayPositionPeriod = Duration(milliseconds: 33);
  static const Duration _positionStreamPeriod = Duration(milliseconds: 33);

  HeAudioHandler({
    AudioPlayer? player,
    HeAudioHandlerFetchSongUrl? fetchSongUrlOverride,
    HeAudioHandlerFetchRadioSongs? fetchRadioSongsOverride,
    HeAudioHandlerFetchLyrics? fetchLyricsOverride,
    HeAudioHandlerSetAudioSource? setAudioSourceOverride,
    HeAudioHandlerPlay? playOverride,
    HeAudioHandlerDispose? disposeOverride,
    HeAudioHandlerNow? nowOverride,
    HeAudioHandlerLog? logOverride,
    Random? randomOverride,
    OverlayChannelService? overlayLyricsServiceOverride,
  }) : _player = player ?? createHeAudioPlayer(),
       _fetchSongUrlOverride = fetchSongUrlOverride,
       _fetchRadioSongsOverride = fetchRadioSongsOverride,
       _fetchLyricsOverride = fetchLyricsOverride,
       _setAudioSourceOverride = setAudioSourceOverride,
       _playOverride = playOverride,
       _disposeOverride = disposeOverride,
       _now = nowOverride ?? DateTime.now,
       _logOverride = logOverride,
       _random = randomOverride ?? Random(),
       _overlayLyricsService =
           overlayLyricsServiceOverride ?? OverlayLyricsService() {
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleChanged,
    );
    _player.playerStateStream.listen((_) {
      _refreshDurationFromPlayer();
      _broadcastPlaybackState();
    });
    _player.durationStream.listen((duration) {
      _refreshDuration(duration);
    });
    _player.playbackEventStream.listen((_) {
      _refreshDurationFromPlayer();
      _broadcastPlaybackState();
    });
    _player
        .createPositionStream(
          minPeriod: _overlayPositionPeriod,
          maxPeriod: _overlayPositionPeriod,
        )
        .listen((position) {
          unawaited(_syncOverlayPosition(position));
        });
    _player.playerStateStream.listen((state) {
      if (state.processingState != ProcessingState.completed) {
        return;
      }
      final generation = _sourceGeneration;
      unawaited(_handlePlaybackCompleted(generation));
    });
  }

  static const int _fetchSongUrlMaxAttempts = 3;
  static const int _setSourceMaxAttempts = 2;
  static const int _radioQueueCap = 1000;
  static const int _radioFetchMaxAttempts = 3;
  static const Duration _radioFetchBaseDelay = Duration(seconds: 5);
  static const Duration _preloadedPlaybackUrlTtl = Duration(minutes: 8);
  static const Duration _manualSkipDebounce = Duration(milliseconds: 150);
  static const Duration _manualSkipMaxBatch = Duration(milliseconds: 500);
  // 熄屏场景下缩短超时，快速失败以便重试
  static const Duration _radioConnectTimeout = Duration(seconds: 10);
  static const Duration _radioReceiveTimeout = Duration(seconds: 15);
  static const Duration _radioSendTimeout = Duration(seconds: 10);

  final AudioPlayer _player;
  final HeAudioHandlerFetchSongUrl? _fetchSongUrlOverride;
  final HeAudioHandlerFetchRadioSongs? _fetchRadioSongsOverride;
  final HeAudioHandlerFetchLyrics? _fetchLyricsOverride;
  final HeAudioHandlerSetAudioSource? _setAudioSourceOverride;
  final HeAudioHandlerPlay? _playOverride;
  final HeAudioHandlerDispose? _disposeOverride;
  final HeAudioHandlerNow _now;
  final HeAudioHandlerLog? _logOverride;
  final OverlayChannelService _overlayLyricsService;
  final Random _random;
  late final AppLifecycleListener _appLifecycleListener;

  List<AudioTrack> _tracks = const <AudioTrack>[];
  final Map<String, _ResolvedPlaybackUrl> _resolvedPlaybackUrls =
      <String, _ResolvedPlaybackUrl>{};
  final Map<String, _InFlightPlaybackUrl> _inFlightPlaybackUrls =
      <String, _InFlightPlaybackUrl>{};
  final Map<String, int> _playbackUrlVersions = <String, int>{};
  List<int> _shuffleOrder = const <int>[];
  int _shuffleCursor = 0;
  int _committedIndex = 0;
  int? _desiredIndex;
  int? _pendingIndex;
  List<int>? _pendingShuffleOrder;
  int? _pendingShuffleCursor;
  int _sourceGeneration = 0;
  int? _armedSourceGeneration;
  int? _handledCompletionGeneration;
  int _transitionId = 0;
  Timer? _manualSkipDebounceTimer;
  Timer? _manualSkipMaxBatchTimer;
  List<int>? _desiredShuffleOrder;
  int? _desiredShuffleCursor;
  int _desiredDirection = 1;
  Duration? _duration;
  bool _shuffleEnabled = false;
  bool _singleLoopEnabled = false;
  bool _isRadioMode = false;
  Future<bool>? _radioNextPageFuture;
  String? _radioNextPageRequestKey;
  bool _configRecovered = false;
  Future<void>? _recoveringConfigFuture;
  String? _currentRadioId;
  String? _currentRadioPlatform;
  int? _currentRadioPageIndex;
  LyricRequest? _currentLyricRequest;
  LyricDocument _currentLyricDocument = const LyricDocument.empty();
  bool _isLyricLoading = false;
  String? _currentLyricErrorMessage;
  bool _enableDesktopLyric = false;
  bool _enableDesktopLyricLock = false;
  AppLyricHighlightMode _lyricHighlightMode =
      AppConfigState.initial.lyricHighlightMode;
  int _lyricHighlightPresetColorValue = AppLyricHighlightColor.sky.color
      .toARGB32();
  int? _lyricHighlightCustomColorValue;
  int? _autoLyricHighlightColorValue;
  int _lyricFontPresetIndex = 0;
  bool _enableWordByWordLyric = false;
  List<OnlinePlatform> _coverPlatforms = const <OnlinePlatform>[];

  String _apiBaseUrl = AppEnvironment.apiBaseUrl;
  String? _authToken = AppConfigState.initial.authToken;
  AppOnlineAudioQuality _qualityPreference = AppOnlineAudioQuality.auto;
  String? _lastSelectedQualityName;

  Future<void> syncConfig({
    required String apiBaseUrl,
    required String? authToken,
    required AppOnlineAudioQuality qualityPreference,
    required String? lastSelectedQualityName,
    required bool enableDesktopLyric,
    required bool enableDesktopLyricLock,
    required AppLyricHighlightMode lyricHighlightMode,
    required int lyricHighlightPresetColorValue,
    required int? lyricHighlightCustomColorValue,
    required int lyricFontPresetIndex,
    required bool enableWordByWordLyric,
  }) async {
    final shouldOpenOverlay = !_enableDesktopLyric && enableDesktopLyric;
    final shouldCloseOverlay = _enableDesktopLyric && !enableDesktopLyric;
    _apiBaseUrl = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _authToken = authToken?.trim();
    globalTokenHolder.accessToken = _authToken;
    _qualityPreference = qualityPreference;
    _lastSelectedQualityName = lastSelectedQualityName?.trim();
    _enableDesktopLyric = enableDesktopLyric;
    _enableDesktopLyricLock = enableDesktopLyricLock;
    _lyricHighlightMode = lyricHighlightMode;
    _lyricHighlightPresetColorValue = lyricHighlightPresetColorValue;
    _lyricHighlightCustomColorValue = lyricHighlightCustomColorValue;
    _lyricFontPresetIndex = lyricFontPresetIndex;
    _enableWordByWordLyric = enableWordByWordLyric;
    _configRecovered = true;
    if (shouldCloseOverlay) {
      await _overlayLyricsService.close();
    }
    if (shouldOpenOverlay) {
      await _overlayLyricsService.open();
    }
    await _syncOverlayConfig();
    if (_enableDesktopLyric) {
      await _syncOverlayCurrentState();
    }
  }

  Future<void> syncCoverPlatforms(List<OnlinePlatform> platforms) async {
    _coverPlatforms = List<OnlinePlatform>.unmodifiable(
      platforms
          .map(
            (item) => OnlinePlatform(
              id: item.id,
              name: item.name,
              shortName: item.shortName,
              status: item.status,
              featureSupportFlag: item.featureSupportFlag,
              imageSizes: item.imageSizes,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> syncAutoLyricHighlightColor({
    required String trackId,
    required String? platform,
    required int? colorValue,
  }) async {
    if (_lyricHighlightMode != AppLyricHighlightMode.auto) {
      return;
    }
    final currentTrack = _safeTrack(_committedIndex);
    if (currentTrack == null ||
        currentTrack.id.trim() != trackId.trim() ||
        (currentTrack.platform?.trim() ?? '') != (platform?.trim() ?? '')) {
      return;
    }
    _autoLyricHighlightColorValue = colorValue;
    await _syncOverlayConfig();
  }

  Future<void> setQueueData(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    final transitionId = _beginTransition();
    final previousIndex = _committedIndex;
    final previousCurrent = _safeTrack(_committedIndex);
    final stagedTracks = List<AudioTrack>.unmodifiable(tracks);
    final targetIndex = tracks.isEmpty
        ? 0
        : initialIndex.clamp(0, tracks.length - 1).toInt();
    final queueContext = _QueueContext(
      isRadioMode: isRadioMode,
      radioId: _normalizeValue(currentRadioId),
      radioPlatform: _normalizeValue(currentRadioPlatform),
      radioPageIndex: _normalizePageIndex(currentRadioPageIndex),
    );
    if (stagedTracks.isEmpty) {
      _guardTransition(transitionId);
      _tracks = const <AudioTrack>[];
      _committedIndex = 0;
      _applyQueueContext(queueContext);
      _syncShuffleCursor(0, forceRebuild: true);
      _autoLyricHighlightColorValue = null;
      await _player.stop();
      _duration = null;
      _clearLyricState();
      queue.add(const <MediaItem>[]);
      _broadcastQueueState();
      _broadcastMediaItem();
      _broadcastPlaybackState();
      return;
    }
    final nextCurrent = stagedTracks[targetIndex];
    final sameCurrentTrack =
        previousCurrent != null && _isSameTrack(previousCurrent, nextCurrent);
    if (sameCurrentTrack &&
        previousIndex == targetIndex &&
        !forceReloadCurrent &&
        _player.audioSource != null &&
        _player.processingState != ProcessingState.idle) {
      _guardTransition(transitionId);
      _tracks = stagedTracks;
      _committedIndex = targetIndex;
      _applyQueueContext(queueContext);
      _syncShuffleCursor(_committedIndex, forceRebuild: true);
      queue.add(_tracks.map(_toMediaItem).toList(growable: false));
      _broadcastQueueState();
      _broadcastMediaItem();
      _broadcastPlaybackState();
      await _loadLyricsForCurrentTrack(force: false);
      return;
    }
    try {
      await _loadTrackAt(
        targetIndex,
        autoplay: false,
        transitionId: transitionId,
        sourceTracks: stagedTracks,
        queueContext: queueContext,
        forceShuffleRebuild: true,
        forceUrlRefresh: forceReloadCurrent,
      );
    } on _StaleTransitionException {
      return;
    }
  }

  Future<void> replaceCurrentTrack(AudioTrack track) async {
    if (_tracks.isEmpty) {
      await setQueueData(<AudioTrack>[track], initialIndex: 0);
      return;
    }
    final transitionId = _beginTransition();
    final next = <AudioTrack>[..._tracks];
    next[_committedIndex] = track;
    final resumePosition = _player.position;
    final wasPlaying = _player.playing;
    try {
      await _loadTrackAt(
        _committedIndex,
        autoplay: false,
        transitionId: transitionId,
        sourceTracks: List<AudioTrack>.unmodifiable(next),
        forceUrlRefresh: true,
      );
    } on _StaleTransitionException {
      return;
    }
    try {
      _guardTransition(transitionId);
    } on _StaleTransitionException {
      return;
    }
    if (resumePosition > Duration.zero) {
      await _player.seek(resumePosition);
    }
    if (wasPlaying) {
      _requestPlay(transitionId);
    }
  }

  Future<void> playIndex(int index) async {
    if (_tracks.isEmpty) {
      return;
    }
    final transitionId = _beginTransition();
    await _ensureRadioNextPageIfNeeded(targetIndex: index);
    try {
      _guardTransition(transitionId);
      final targetIndex = index.clamp(0, _tracks.length - 1).toInt();
      await _loadTrackAt(
        targetIndex,
        autoplay: true,
        transitionId: transitionId,
      );
    } on _StaleTransitionException {
      return;
    }
  }

  Future<void> setSingleLoopMode(bool enabled) async {
    _singleLoopEnabled = enabled;
    await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    _broadcastPlaybackState();
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    _shuffleEnabled = enabled;
    _syncShuffleCursor(_committedIndex, forceRebuild: true);
    _broadcastQueueState();
    _broadcastPlaybackState();
  }

  Future<void> setVolumeValue(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> setSpeedValue(double speed) async {
    await _player.setSpeed(speed);
    _broadcastPlaybackState();
  }

  Stream<int?> get queueIndexStream =>
      playbackState.map((state) => state.queueIndex).distinct();

  Stream<bool> get loadingStream => playbackState
      .map(
        (state) =>
            state.processingState == AudioProcessingState.loading ||
            state.processingState == AudioProcessingState.buffering,
      )
      .distinct();

  Stream<bool> get completedStream => playbackState
      .map((state) => state.processingState == AudioProcessingState.completed)
      .distinct();

  Stream<bool> get playingStream =>
      playbackState.map((state) => state.playing).distinct();

  Stream<Duration?> get durationStream =>
      mediaItem.map((item) => item?.duration).distinct();

  Stream<Duration> get positionStream => _player.createPositionStream(
    minPeriod: _positionStreamPeriod,
    maxPeriod: _positionStreamPeriod,
  );

  @override
  Future<void> play() async {
    _requestPlay(_transitionId);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _beginTransition();
    await _player.stop();
    _broadcastPlaybackState();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_tracks.isEmpty) {
      return;
    }
    if (_isRadioMode && _committedIndex >= _tracks.length - 1) {
      final transitionId = _beginTransition();
      unawaited(_playNextRadioTrack(transitionId));
      return;
    }
    _scheduleManualSkip(1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_tracks.isEmpty) {
      return;
    }
    _scheduleManualSkip(-1);
  }

  @override
  Future<void> skipToQueueItem(int index) => playIndex(index);

  void _scheduleManualSkip(int direction) {
    final transitionId = _beginTransition(
      cancelManualIntent: false,
      preservePending: true,
    );
    _desiredDirection = direction;
    if (_shuffleEnabled) {
      _advanceDesiredShuffle(direction);
    } else {
      final baseIndex = _desiredIndex ?? _pendingIndex ?? _committedIndex;
      _desiredIndex = direction > 0
          ? (baseIndex + 1) % _tracks.length
          : (baseIndex - 1 + _tracks.length) % _tracks.length;
    }
    _pendingIndex = null;
    _pendingShuffleOrder = null;
    _pendingShuffleCursor = null;
    _manualSkipDebounceTimer?.cancel();
    _manualSkipDebounceTimer = Timer(
      _manualSkipDebounce,
      () => _flushManualIntent(transitionId),
    );
    _manualSkipMaxBatchTimer ??= Timer(
      _manualSkipMaxBatch,
      () => _flushManualIntent(_transitionId),
    );
    _logTransition('manual.intent', transitionId);
  }

  void _advanceDesiredShuffle(int direction) {
    if (_desiredShuffleOrder == null || _desiredShuffleCursor == null) {
      if (_pendingShuffleOrder != null && _pendingShuffleCursor != null) {
        _desiredShuffleOrder = <int>[..._pendingShuffleOrder!];
        _desiredShuffleCursor = _pendingShuffleCursor;
      } else {
        _syncShuffleCursor(_committedIndex);
        _desiredShuffleOrder = <int>[..._shuffleOrder];
        _desiredShuffleCursor = _shuffleCursor;
      }
    }
    var order = _desiredShuffleOrder!;
    var cursor = _desiredShuffleCursor!;
    if (direction > 0) {
      if (cursor >= order.length - 1) {
        order = _createShuffleOrder(order[cursor]);
        cursor = order.length <= 1 ? 0 : 1;
      } else {
        cursor += 1;
      }
    } else {
      cursor = cursor <= 0 ? order.length - 1 : cursor - 1;
    }
    _desiredShuffleOrder = order;
    _desiredShuffleCursor = cursor;
    _desiredIndex = order[cursor];
  }

  void _flushManualIntent(int transitionId) {
    if (transitionId != _transitionId || _desiredIndex == null) {
      return;
    }
    _manualSkipDebounceTimer?.cancel();
    _manualSkipMaxBatchTimer?.cancel();
    _manualSkipDebounceTimer = null;
    _manualSkipMaxBatchTimer = null;
    final targetIndex = _desiredIndex!;
    final shuffleOrder = _desiredShuffleOrder == null
        ? null
        : <int>[..._desiredShuffleOrder!];
    final shuffleCursor = _desiredShuffleCursor;
    final direction = _desiredDirection;
    unawaited(
      _executeManualIntent(
        targetIndex,
        transitionId: transitionId,
        direction: direction,
        shuffleOrder: shuffleOrder,
        shuffleCursor: shuffleCursor,
      ),
    );
  }

  Future<void> _executeManualIntent(
    int targetIndex, {
    required int transitionId,
    required int direction,
    required List<int>? shuffleOrder,
    required int? shuffleCursor,
  }) async {
    try {
      await _loadTrackAt(
        targetIndex,
        autoplay: true,
        transitionId: transitionId,
        shuffleOrder: shuffleOrder,
        shuffleCursor: shuffleCursor,
      );
    } on _StaleTransitionException {
      return;
    } catch (error) {
      if (direction > 0 &&
          _classifyPlaybackError(error) ==
              _PlaybackFailureCategory.trackUnavailable) {
        try {
          await _playNextAvailableFrom(targetIndex, transitionId);
          return;
        } on _StaleTransitionException {
          return;
        } catch (nextError) {
          _broadcastTransitionError(nextError, transitionId);
          return;
        }
      }
      _broadcastTransitionError(error, transitionId);
    }
  }

  void _cancelManualIntent({required bool clearDesired}) {
    _manualSkipDebounceTimer?.cancel();
    _manualSkipMaxBatchTimer?.cancel();
    _manualSkipDebounceTimer = null;
    _manualSkipMaxBatchTimer = null;
    if (clearDesired) {
      _desiredIndex = null;
      _desiredShuffleOrder = null;
      _desiredShuffleCursor = null;
    }
  }

  Future<void> _playNextRadioTrack(int transitionId) async {
    try {
      final sourceIndex = _committedIndex;
      final appended = await _ensureRadioNextPageAppended();
      _guardTransition(transitionId);
      if (!appended || _tracks.length <= sourceIndex + 1) {
        return;
      }
      await _loadTrackAt(
        sourceIndex + 1,
        autoplay: true,
        transitionId: transitionId,
      );
    } on _StaleTransitionException {
      return;
    } catch (error) {
      _broadcastTransitionError(error, transitionId);
    }
  }

  Future<void> disposeHandler() async {
    _beginTransition();
    _appLifecycleListener.dispose();
    final override = _disposeOverride;
    if (override != null) {
      await override(_player);
      return;
    }
    await _player.dispose();
  }

  Future<void> _loadTrackAt(
    int index, {
    required bool autoplay,
    required int transitionId,
    List<AudioTrack>? sourceTracks,
    _QueueContext? queueContext,
    List<int>? shuffleOrder,
    int? shuffleCursor,
    bool forceShuffleRebuild = false,
    bool forceUrlRefresh = false,
  }) async {
    final candidateTracks = sourceTracks ?? _tracks;
    final track = index < 0 || index >= candidateTracks.length
        ? null
        : candidateTracks[index];
    if (track == null) {
      return;
    }
    _guardTransition(transitionId);
    _pendingIndex = index;
    _pendingShuffleOrder = shuffleOrder == null ? null : <int>[...shuffleOrder];
    _pendingShuffleCursor = shuffleCursor;
    _logTransition('load.resolve.start', transitionId, track: track);
    try {
      var resolved = await _resolveTrack(track, forceRefresh: forceUrlRefresh);
      _guardTransition(transitionId);
      Object? lastError;
      for (var attempt = 1; attempt <= _setSourceMaxAttempts; attempt += 1) {
        try {
          final generation = ++_sourceGeneration;
          _logTransition(
            'load.source.start',
            transitionId,
            generation: generation,
            track: track,
          );
          final initialDuration = await _setAudioSource(_buildSource(resolved));
          _guardTransition(transitionId);
          _commitLoadedTrack(
            index: index,
            resolved: resolved,
            sourceTracks: candidateTracks,
            queueContext: queueContext,
            generation: generation,
            initialDuration: initialDuration,
            shuffleOrder: shuffleOrder,
            shuffleCursor: shuffleCursor,
            forceShuffleRebuild: forceShuffleRebuild,
          );
          _logTransition(
            'load.source.success',
            transitionId,
            generation: generation,
            track: track,
          );
          await _notifyTrackChanged(resolved);
          unawaited(_loadLyricsForCurrentTrack(force: true));
          unawaited(_preloadNextTrackUrl(index));
          if (autoplay) {
            _requestPlay(transitionId);
          }
          return;
        } on _StaleTransitionException {
          rethrow;
        } on PlayerInterruptedException {
          throw const _StaleTransitionException();
        } catch (error) {
          lastError = error;
          final shouldRetry =
              shouldRefreshRemotePlaybackUrl(track) &&
              attempt < _setSourceMaxAttempts;
          if (!shouldRetry) {
            rethrow;
          }
          final failedUrl = resolved.url.trim();
          resolved = await _resolveTrack(track, forceRefresh: true);
          _guardTransition(transitionId);
          if (resolved.url.trim() == failedUrl) {
            throw _UnchangedPlaybackUrlException(track.id);
          }
        }
      }
      throw lastError ?? StateError('Failed to load track.');
    } finally {
      if (transitionId == _transitionId && _pendingIndex == index) {
        _pendingIndex = null;
        _pendingShuffleOrder = null;
        _pendingShuffleCursor = null;
      }
    }
  }

  void _commitLoadedTrack({
    required int index,
    required AudioTrack resolved,
    required List<AudioTrack> sourceTracks,
    required int generation,
    required Duration? initialDuration,
    _QueueContext? queueContext,
    List<int>? shuffleOrder,
    int? shuffleCursor,
    bool forceShuffleRebuild = false,
  }) {
    final next = <AudioTrack>[...sourceTracks];
    next[index] = resolved;
    _tracks = List<AudioTrack>.unmodifiable(next);
    _committedIndex = index;
    if (queueContext != null) {
      _applyQueueContext(queueContext);
    }
    if (_shuffleEnabled && shuffleOrder != null && shuffleCursor != null) {
      _shuffleOrder = List<int>.unmodifiable(shuffleOrder);
      _shuffleCursor = shuffleCursor;
    } else {
      _syncShuffleCursor(index, forceRebuild: forceShuffleRebuild);
    }
    _duration = initialDuration ?? _player.duration;
    _autoLyricHighlightColorValue = null;
    _pendingIndex = null;
    _pendingShuffleOrder = null;
    _pendingShuffleCursor = null;
    _desiredIndex = null;
    _desiredShuffleOrder = null;
    _desiredShuffleCursor = null;
    _armedSourceGeneration = generation;
    _handledCompletionGeneration = null;
    queue.add(_tracks.map(_toMediaItem).toList(growable: false));
    _broadcastQueueState();
    _broadcastMediaItem();
    _broadcastPlaybackState();
  }

  int _beginTransition({
    bool cancelManualIntent = true,
    bool preservePending = false,
  }) {
    _transitionId += 1;
    if (!preservePending) {
      _pendingIndex = null;
      _pendingShuffleOrder = null;
      _pendingShuffleCursor = null;
    }
    if (cancelManualIntent) {
      _cancelManualIntent(clearDesired: true);
    }
    return _transitionId;
  }

  void _guardTransition(int transitionId) {
    if (transitionId != _transitionId) {
      throw const _StaleTransitionException();
    }
  }

  void _applyQueueContext(_QueueContext context) {
    _isRadioMode = context.isRadioMode;
    _currentRadioId = context.radioId;
    _currentRadioPlatform = context.radioPlatform;
    _currentRadioPageIndex = context.radioPageIndex;
  }

  void _requestPlay(int transitionId) {
    final override = _playOverride;
    final future = override == null ? _player.play() : override(_player);
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        if (transitionId == _transitionId) {
          _broadcastTransitionError(error, transitionId);
        }
      }),
    );
  }

  void _onAppLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDurationFromPlayer();
    }
  }

  void _refreshDurationFromPlayer() {
    _refreshDuration(_player.duration);
  }

  void _refreshDuration(Duration? duration) {
    if (_duration == duration) {
      return;
    }
    _duration = duration;
    _broadcastMediaItem();
    _broadcastPlaybackState();
  }

  Future<AudioTrack> _resolveTrack(
    AudioTrack track, {
    bool forceRefresh = false,
  }) async {
    await _ensureConfigRecovered();
    final localPath = track.path?.trim() ?? '';
    if (localPath.isNotEmpty) {
      return AudioTrack(
        id: track.id,
        title: track.title,
        url: _localPathToUrl(localPath),
        path: localPath,
        duration: track.duration,
        links: track.links,
        artist: track.artist,
        album: track.album,
        artworkUrl: track.artworkUrl,
        platform: track.platform,
      );
    }
    if (!shouldRefreshRemotePlaybackUrl(track)) {
      if (track.url.trim().isNotEmpty) {
        return track;
      }
      final matchedDirect =
          _resolvePreferredLink(track.links)?.url.trim() ?? '';
      if (matchedDirect.isNotEmpty) {
        return AudioTrack(
          id: track.id,
          title: track.title,
          url: matchedDirect,
          path: track.path,
          duration: track.duration,
          links: track.links,
          artist: track.artist,
          album: track.album,
          artworkUrl: track.artworkUrl,
          platform: track.platform,
        );
      }
      return track;
    }
    final matchedQuality = _resolvePreferredLink(track.links);
    final platform = track.platform?.trim() ?? '';
    if (platform.isEmpty) {
      return track;
    }
    final quality = _requestQuality(matchedQuality);
    final format = _requestFormat(matchedQuality);
    final cacheKey = _playbackUrlCacheKey(
      track,
      quality: quality,
      format: format,
    );
    if (forceRefresh) {
      _invalidatePlaybackUrl(cacheKey);
    }
    final url = await _resolvePlaybackUrl(
      cacheKey: cacheKey,
      songId: track.id,
      platform: platform,
      quality: quality,
      format: format,
    );
    return AudioTrack(
      id: track.id,
      title: track.title,
      url: url,
      path: track.path,
      duration: track.duration,
      links: track.links,
      artist: track.artist,
      album: track.album,
      artworkUrl: track.artworkUrl,
      platform: track.platform,
    );
  }

  Future<void> _preloadNextTrackUrl(int sourceIndex) async {
    // 电台模式先补足下一页，再解析下一首 URL，避免跨页时错过预加载。
    await _ensureRadioNextPageIfNeeded(targetIndex: sourceIndex + 1);
    if (_tracks.length < 2) {
      return;
    }
    final nextIndex = _resolveNextTrackIndex(sourceIndex, advance: false);
    final track = _safeTrack(nextIndex);
    if (track == null ||
        !shouldRefreshRemotePlaybackUrl(track) ||
        _hasFreshResolvedPlaybackUrl(track)) {
      return;
    }
    try {
      await _resolveTrack(track);
    } catch (error) {
      // 预加载失败不能影响当前播放；真正切歌时仍会按正常链路重试。
      _logTransition('url.preload.failure', _transitionId, track: track);
    }
  }

  bool _hasFreshResolvedPlaybackUrl(AudioTrack track) {
    final cacheKey = _playbackUrlCacheKey(track);
    final cached = _resolvedPlaybackUrls[cacheKey];
    if (cached == null) {
      return false;
    }
    return _now().difference(cached.resolvedAt) < _preloadedPlaybackUrlTtl;
  }

  Future<String> _resolvePlaybackUrl({
    required String cacheKey,
    required String songId,
    required String platform,
    required int? quality,
    required String? format,
  }) async {
    final version = _playbackUrlVersions[cacheKey] ?? 0;
    final cached = _resolvedPlaybackUrls[cacheKey];
    if (cached != null &&
        cached.version == version &&
        _now().difference(cached.resolvedAt) < _preloadedPlaybackUrlTtl) {
      _logTransition('url.cache.hit', _transitionId);
      return cached.url;
    }
    final pending = _inFlightPlaybackUrls[cacheKey];
    if (pending != null && pending.version == version) {
      _logTransition('url.inflight.join', _transitionId);
      return pending.future;
    }
    _logTransition('url.fetch.start', _transitionId);
    final future =
        _fetchSongUrlWithRetry(
          songId: songId,
          platform: platform,
          quality: quality,
          format: format,
        ).then((payload) {
          final url = '${payload['url'] ?? ''}'.trim();
          if (url.isEmpty) {
            throw _TrackUnavailableException(songId);
          }
          if ((_playbackUrlVersions[cacheKey] ?? 0) == version) {
            _resolvedPlaybackUrls[cacheKey] = _ResolvedPlaybackUrl(
              url: url,
              resolvedAt: _now(),
              version: version,
            );
          }
          return url;
        });
    final inFlight = _InFlightPlaybackUrl(version: version, future: future);
    _inFlightPlaybackUrls[cacheKey] = inFlight;
    try {
      return await future;
    } finally {
      if (identical(_inFlightPlaybackUrls[cacheKey], inFlight)) {
        _inFlightPlaybackUrls.remove(cacheKey);
      }
    }
  }

  void _invalidatePlaybackUrl(String cacheKey) {
    _resolvedPlaybackUrls.remove(cacheKey);
    _playbackUrlVersions[cacheKey] = (_playbackUrlVersions[cacheKey] ?? 0) + 1;
    _logTransition('url.cache.invalidated', _transitionId);
  }

  String _playbackUrlCacheKey(
    AudioTrack track, {
    int? quality,
    String? format,
  }) {
    final selectedQuality = _resolvePreferredLink(track.links);
    final resolvedQuality = quality ?? _requestQuality(selectedQuality) ?? 320;
    final resolvedFormat = format ?? _requestFormat(selectedQuality) ?? 'mp3';
    return '${track.platform ?? ''}|${track.id}|$resolvedQuality|$resolvedFormat';
  }

  Future<void> _ensureConfigRecovered() async {
    if (_configRecovered) {
      return;
    }
    final pending = _recoveringConfigFuture;
    if (pending != null) {
      await pending;
      return;
    }
    final future = _recoverConfig();
    _recoveringConfigFuture = future;
    try {
      await future;
    } finally {
      _recoveringConfigFuture = null;
    }
  }

  Future<void> _recoverConfig() async {
    final config = await loadHeAudioHandlerRuntimeConfig();
    _apiBaseUrl = config.apiBaseUrl;
    _authToken = config.authToken;
    _qualityPreference = config.qualityPreference;
    _lastSelectedQualityName = config.lastSelectedQualityName;
    _enableDesktopLyric = config.enableDesktopLyric;
    _enableDesktopLyricLock = config.enableDesktopLyricLock;
    _lyricHighlightMode = config.lyricHighlightMode;
    _lyricHighlightPresetColorValue = config.lyricHighlightPresetColorValue;
    _lyricHighlightCustomColorValue = config.lyricHighlightCustomColorValue;
    _lyricFontPresetIndex = config.lyricFontPresetIndex;
    _enableWordByWordLyric = config.enableWordByWordLyric;
    _configRecovered = true;
  }

  LinkInfo? _resolvePreferredLink(List<LinkInfo> links) {
    return selectPreferredAudioQuality(
      links,
      preference: _qualityPreference,
      lastSelectedQualityName: _lastSelectedQualityName,
      nameOf: (LinkInfo link) => link.name,
      formatOf: (LinkInfo link) => link.format,
      bitrateOf: (LinkInfo link) => link.quality,
    );
  }

  int? _requestQuality(LinkInfo? selectedQuality) {
    if (selectedQuality == null) {
      return null;
    }
    if (selectedQuality.quality > 0) {
      return selectedQuality.quality;
    }
    final numeric = RegExp(r'(\d+)').firstMatch(selectedQuality.name.trim());
    if (numeric == null) {
      return null;
    }
    return int.tryParse(numeric.group(1)!);
  }

  String? _requestFormat(LinkInfo? selectedQuality) {
    final linkFormat = selectedQuality?.format.trim();
    if (linkFormat != null && linkFormat.isNotEmpty) {
      return linkFormat;
    }
    final name = selectedQuality?.name.trim().toLowerCase() ?? '';
    if (name.contains('flac')) {
      return 'flac';
    }
    if (name.contains('ape')) {
      return 'ape';
    }
    if (name.contains('m4a')) {
      return 'm4a';
    }
    if (name.contains('ogg')) {
      return 'ogg';
    }
    if (name.contains('wav')) {
      return 'wav';
    }
    if (name.contains('aac')) {
      return 'aac';
    }
    if (name.contains('mp3')) {
      return 'mp3';
    }
    return null;
  }

  bool _isRetryableFetchError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          (error.response?.statusCode ?? 0) >= 500;
    }
    return false;
  }

  Future<Map<String, dynamic>> _fetchSongUrlWithRetry({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _fetchSongUrlMaxAttempts; attempt += 1) {
      try {
        final payload = await _fetchSongUrl(
          songId: songId,
          platform: platform,
          quality: quality,
          format: format,
        );
        final url = '${payload['url'] ?? ''}'.trim();
        if (url.isNotEmpty) {
          return payload;
        }
        throw _TrackUnavailableException(songId);
      } catch (error) {
        lastError = error;
        if (!_isRetryableFetchError(error) ||
            attempt == _fetchSongUrlMaxAttempts) {
          rethrow;
        }
      }
    }
    throw lastError ?? StateError('Failed to fetch playback url.');
  }

  Future<Map<String, dynamic>> _fetchSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    final override = _fetchSongUrlOverride;
    if (override != null) {
      return override(
        songId: songId,
        platform: platform,
        quality: quality,
        format: format,
      );
    }
    final token = globalTokenHolder.accessToken ?? _authToken;
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
        headers: <String, String>{
          'User-Agent': heAudioUserAgent,
          if ((token ?? '').isNotEmpty) ...<String, String>{
            'Authorization': 'Bearer $token',
          },
        },
      ),
    );
    try {
      final response = await dio.get(
        '/v1/song/url',
        queryParameters: <String, dynamic>{
          'id': songId,
          'platform': platform,
          'quality': quality ?? 320,
          'format': (format == null || format.trim().isEmpty) ? 'mp3' : format,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return const <String, dynamic>{};
    } finally {
      dio.close(force: true);
    }
  }

  Future<Duration?> _setAudioSource(AudioSource source) {
    final override = _setAudioSourceOverride;
    if (override != null) {
      return override(source, _player);
    }
    return _player.setAudioSource(source);
  }

  Future<void> _handlePlaybackCompleted(int generation) async {
    if (_tracks.isEmpty ||
        _singleLoopEnabled ||
        _pendingIndex != null ||
        _desiredIndex != null ||
        generation != _armedSourceGeneration ||
        generation == _handledCompletionGeneration) {
      _logTransition(
        'completion.ignored',
        _transitionId,
        generation: generation,
      );
      return;
    }
    _handledCompletionGeneration = generation;
    final transitionId = _beginTransition();
    _logTransition('completion.accepted', transitionId, generation: generation);
    try {
      if (_isRadioMode && _committedIndex >= _tracks.length - 1) {
        await _playNextRadioTrack(transitionId);
        return;
      }
      await _playNextAvailableFrom(_committedIndex, transitionId);
    } on _StaleTransitionException {
      return;
    } catch (error) {
      _broadcastTransitionError(error, transitionId);
    }
  }

  @visibleForTesting
  Future<void> handlePlaybackCompletedForTesting() {
    return _handlePlaybackCompleted(_sourceGeneration);
  }

  Future<void> _playNextAvailableFrom(int sourceIndex, int transitionId) async {
    final attemptedIndexes = <int>{};
    var cursorIndex = sourceIndex;
    var draftOrder = <int>[..._shuffleOrder];
    var draftCursor = _shuffleCursor;
    Object? lastError;
    final candidateCount = _tracks.length == 1 ? 1 : _tracks.length - 1;
    for (var attempt = 0; attempt < candidateCount; attempt += 1) {
      _guardTransition(transitionId);
      late final int nextIndex;
      if (_shuffleEnabled) {
        if (draftOrder.isEmpty || !draftOrder.contains(cursorIndex)) {
          draftOrder = _createShuffleOrder(cursorIndex);
          draftCursor = 0;
        } else {
          draftCursor = draftOrder.indexOf(cursorIndex);
        }
        if (draftOrder.length <= 1) {
          nextIndex = cursorIndex;
        } else if (draftCursor >= draftOrder.length - 1) {
          draftOrder = _createShuffleOrder(cursorIndex);
          draftCursor = 1;
          nextIndex = draftOrder[draftCursor];
        } else {
          draftCursor += 1;
          nextIndex = draftOrder[draftCursor];
        }
      } else {
        nextIndex = (cursorIndex + 1) % _tracks.length;
      }
      if (!attemptedIndexes.add(nextIndex)) {
        break;
      }
      try {
        await _loadTrackAt(
          nextIndex,
          autoplay: true,
          transitionId: transitionId,
          shuffleOrder: _shuffleEnabled ? draftOrder : null,
          shuffleCursor: _shuffleEnabled ? draftCursor : null,
        );
        return;
      } catch (error) {
        lastError = error;
        if (_classifyPlaybackError(error) !=
            _PlaybackFailureCategory.trackUnavailable) {
          rethrow;
        }
        cursorIndex = nextIndex;
      }
    }
    throw lastError ?? const _NoPlayableTrackException();
  }

  _PlaybackFailureCategory _classifyPlaybackError(Object error) {
    if (error is _StaleTransitionException ||
        error is PlayerInterruptedException) {
      return _PlaybackFailureCategory.cancelled;
    }
    if (error is _TrackUnavailableException) {
      return _PlaybackFailureCategory.trackUnavailable;
    }
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404 || statusCode == 410) {
        return _PlaybackFailureCategory.trackUnavailable;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          statusCode == 401 ||
          statusCode == 403 ||
          (statusCode ?? 0) >= 500) {
        return _PlaybackFailureCategory.globalTransient;
      }
    }
    return _PlaybackFailureCategory.unknown;
  }

  void _broadcastTransitionError(Object error, int transitionId) {
    if (transitionId != _transitionId ||
        _classifyPlaybackError(error) == _PlaybackFailureCategory.cancelled) {
      return;
    }
    final category = _classifyPlaybackError(error);
    _logTransition(
      'transition.failure',
      transitionId,
      failureCategory: category,
    );
    customEvent.add(<String, dynamic>{
      'type': 'playbackTransitionError',
      'code': category.name,
      'retryable': category != _PlaybackFailureCategory.trackUnavailable,
    });
  }

  void _logTransition(
    String event,
    int transitionId, {
    int? generation,
    AudioTrack? track,
    _PlaybackFailureCategory? failureCategory,
  }) {
    final message =
        '$event transitionId=$transitionId '
        'sourceGeneration=${generation ?? _sourceGeneration} '
        'track=${track == null ? '-' : _trackCacheKey(track)} '
        'failure=${failureCategory?.name ?? '-'}';
    final override = _logOverride;
    if (override != null) {
      override(message);
      return;
    }
    developer.log(message, name: 'HeAudioHandler');
  }

  MediaItem _toMediaItem(AudioTrack track) {
    final artwork = track.artworkUrl?.trim() ?? '';
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      artUri: artwork.isEmpty ? null : _localPathToUri(artwork),
      duration: _safeTrack(_committedIndex)?.id == track.id ? _duration : null,
    );
  }

  AudioSource _buildSource(AudioTrack track) {
    final sourceUrl = track.url.trim();
    final localPath = track.path?.trim() ?? '';
    return AudioSource.uri(
      localPath.isNotEmpty ? _localPathToUri(localPath) : Uri.parse(sourceUrl),
      tag: _toMediaItem(track),
    );
  }

  String _localPathToUrl(String localPath) {
    return _localPathToUri(localPath).toString();
  }

  Uri _localPathToUri(String localPath) {
    final normalized = localPath.trim();
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    return Uri.file(normalized);
  }

  void _broadcastMediaItem() {
    final current = _safeTrack(_committedIndex);
    mediaItem.add(current == null ? null : _toMediaItem(current));
  }

  void _broadcastQueueState() {
    final previewIndexes = _resolvePreviewTrackIndexes(_committedIndex);
    customEvent.add(<String, dynamic>{
      'type': 'queueState',
      'tracks': _tracks.map(_serializeTrack).toList(growable: false),
      'currentIndex': _committedIndex,
      'previousPreviewIndex': previewIndexes.previous,
      'nextPreviewIndex': previewIndexes.next,
      'isRadioMode': _isRadioMode,
      'currentRadioId': _currentRadioId,
      'currentRadioPlatform': _currentRadioPlatform,
      'currentRadioPageIndex': _currentRadioPageIndex,
    });
  }

  void _broadcastPlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _tracks.isEmpty ? 0 : _committedIndex,
        repeatMode: _singleLoopEnabled
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none,
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  AudioTrack? _safeTrack(int index) {
    if (index < 0 || index >= _tracks.length) {
      return null;
    }
    return _tracks[index];
  }

  ({int? previous, int? next}) _resolvePreviewTrackIndexes(int sourceIndex) {
    if (_tracks.length < 2) {
      return (previous: null, next: null);
    }
    return (
      previous: _peekPreviousTrackIndex(sourceIndex),
      next: _resolveNextTrackIndex(sourceIndex, advance: false),
    );
  }

  int _resolveNextTrackIndex(int sourceIndex, {required bool advance}) {
    if (_tracks.isEmpty) {
      return 0;
    }
    if (!_shuffleEnabled) {
      return (sourceIndex + 1) % _tracks.length;
    }
    _syncShuffleCursor(sourceIndex);
    if (_shuffleOrder.length <= 1) {
      return sourceIndex.clamp(0, _tracks.length - 1).toInt();
    }
    if (_shuffleCursor >= _shuffleOrder.length - 1) {
      _rebuildShuffleOrder(sourceIndex);
    }
    final nextCursor = (_shuffleCursor + 1).clamp(0, _shuffleOrder.length - 1);
    if (advance) {
      _shuffleCursor = nextCursor;
    }
    return _shuffleOrder[nextCursor];
  }

  int _peekPreviousTrackIndex(int sourceIndex) {
    if (_tracks.isEmpty) {
      return 0;
    }
    if (!_shuffleEnabled) {
      return (sourceIndex - 1 + _tracks.length) % _tracks.length;
    }
    _syncShuffleCursor(sourceIndex);
    if (_shuffleOrder.length <= 1) {
      return sourceIndex.clamp(0, _tracks.length - 1).toInt();
    }
    final previousCursor = _shuffleCursor <= 0
        ? _shuffleOrder.length - 1
        : _shuffleCursor - 1;
    return _shuffleOrder[previousCursor];
  }

  void _syncShuffleCursor(int currentIndex, {bool forceRebuild = false}) {
    if (!_shuffleEnabled || _tracks.isEmpty) {
      _shuffleOrder = const <int>[];
      _shuffleCursor = 0;
      return;
    }
    final safeIndex = currentIndex.clamp(0, _tracks.length - 1).toInt();
    final orderIsValid =
        !forceRebuild &&
        _shuffleOrder.length == _tracks.length &&
        _shuffleOrder.toSet().length == _tracks.length &&
        _shuffleOrder.every((index) => index >= 0 && index < _tracks.length);
    if (!orderIsValid) {
      _rebuildShuffleOrder(safeIndex);
      return;
    }
    final cursor = _shuffleOrder.indexOf(safeIndex);
    if (cursor < 0) {
      _rebuildShuffleOrder(safeIndex);
      return;
    }
    _shuffleCursor = cursor;
  }

  void _rebuildShuffleOrder(int currentIndex) {
    if (_tracks.isEmpty) {
      _shuffleOrder = const <int>[];
      _shuffleCursor = 0;
      return;
    }
    _shuffleOrder = List<int>.unmodifiable(_createShuffleOrder(currentIndex));
    _shuffleCursor = 0;
  }

  List<int> _createShuffleOrder(int currentIndex) {
    final safeIndex = currentIndex.clamp(0, _tracks.length - 1).toInt();
    final order = List<int>.generate(_tracks.length, (index) => index);
    for (var index = order.length - 1; index > 0; index -= 1) {
      final swapIndex = _random.nextInt(index + 1);
      final temp = order[index];
      order[index] = order[swapIndex];
      order[swapIndex] = temp;
    }
    order.remove(safeIndex);
    order.insert(0, safeIndex);
    return order;
  }

  bool _isSameTrack(AudioTrack left, AudioTrack right) {
    final leftId = left.id.trim();
    final rightId = right.id.trim();
    if (leftId.isEmpty || rightId.isEmpty || leftId != rightId) {
      return false;
    }
    final leftPlatform = left.platform?.trim() ?? '';
    final rightPlatform = right.platform?.trim() ?? '';
    if (leftPlatform == 'local' || rightPlatform == 'local') {
      return true;
    }
    return leftPlatform.isNotEmpty &&
        rightPlatform.isNotEmpty &&
        leftPlatform == rightPlatform;
  }

  Future<void> _notifyTrackChanged(AudioTrack track) async {
    if (!_enableDesktopLyric) {
      return;
    }
    await _syncOverlayConfig();
    await _overlayLyricsService.sendTrackChanged(
      title: track.title,
      artist: track.artist ?? '',
    );
  }

  Future<void> _loadLyricsForCurrentTrack({required bool force}) async {
    final track = _safeTrack(_committedIndex);
    if (track == null) {
      _clearLyricState();
      return;
    }
    final request = LyricRequest(
      trackId: track.id,
      platform: track.platform,
      localPath: track.path,
    );
    if (!force &&
        _currentLyricRequest == request &&
        !_isLyricLoading &&
        _currentLyricErrorMessage == null) {
      await _syncOverlayCurrentState();
      return;
    }
    _currentLyricRequest = request;
    _isLyricLoading = true;
    _currentLyricErrorMessage = null;
    _currentLyricDocument = const LyricDocument.empty();
    _broadcastLyricState();
    try {
      final document = await _fetchLyrics(
        trackId: request.trackId,
        platform: request.platform,
        localPath: request.localPath,
      );
      if (_currentLyricRequest != request) {
        return;
      }
      _currentLyricDocument = document;
      _isLyricLoading = false;
      _currentLyricErrorMessage = null;
      _broadcastLyricState();
      await _syncOverlayCurrentState();
    } catch (error) {
      if (_currentLyricRequest != request) {
        return;
      }
      _currentLyricDocument = const LyricDocument.empty();
      _isLyricLoading = false;
      _currentLyricErrorMessage = '$error';
      _broadcastLyricState();
    }
  }

  void _clearLyricState() {
    _currentLyricRequest = null;
    _currentLyricDocument = const LyricDocument.empty();
    _isLyricLoading = false;
    _currentLyricErrorMessage = null;
    _broadcastLyricState();
  }

  void _broadcastLyricState() {
    customEvent.add(<String, dynamic>{'type': 'lyricState'});
  }

  Future<CurrentLyricStateSnapshot> getCurrentLyricState() async {
    return CurrentLyricStateSnapshot(
      request: _currentLyricRequest,
      document: _currentLyricDocument,
      isLoading: _isLyricLoading,
      errorMessage: _currentLyricErrorMessage,
    );
  }

  static const int _radioPrefetchThreshold = 3;

  Future<void> _ensureRadioNextPageIfNeeded({required int targetIndex}) async {
    if (!_isRadioMode) {
      return;
    }
    if (_tracks.isEmpty) {
      return;
    }
    // 剩余歌曲不足阈值时提前加载，避免播完后才触发网络请求
    if (targetIndex < _tracks.length - _radioPrefetchThreshold) {
      return;
    }
    await _ensureRadioNextPageAppended();
  }

  Future<bool> _ensureRadioNextPageAppended() async {
    final requestKey =
        '$_currentRadioPlatform|$_currentRadioId|$_currentRadioPageIndex';
    final pending = _radioNextPageFuture;
    if (pending != null && _radioNextPageRequestKey == requestKey) {
      return pending;
    }
    if (!_isRadioMode ||
        _currentRadioId == null ||
        _currentRadioPlatform == null ||
        _currentRadioPageIndex == null) {
      return false;
    }
    final future = _loadRadioNextPage();
    _radioNextPageFuture = future;
    _radioNextPageRequestKey = requestKey;
    try {
      return await future;
    } finally {
      if (identical(_radioNextPageFuture, future)) {
        _radioNextPageFuture = null;
        _radioNextPageRequestKey = null;
      }
    }
  }

  Future<bool> _loadRadioNextPage() async {
    final radioId = _currentRadioId!;
    final radioPlatform = _currentRadioPlatform!;
    final sourcePageIndex = _currentRadioPageIndex!;
    final nextPageIndex = _currentRadioPageIndex! + 1;
    // 熄屏场景下网络容易失败，添加重试机制。
    List<SongInfo> songs = const <SongInfo>[];
    Object? lastError;
    for (var attempt = 1; attempt <= _radioFetchMaxAttempts; attempt += 1) {
      try {
        songs = await _fetchRadioSongs(
          id: radioId,
          platform: radioPlatform,
          pageIndex: nextPageIndex,
        );
        lastError = null;
        break;
      } catch (error) {
        lastError = error;
        if (attempt < _radioFetchMaxAttempts) {
          // 指数退避：第1次失败等5s，第2次等10s。
          await Future<void>.delayed(_radioFetchBaseDelay * attempt);
        }
      }
    }
    if (lastError != null ||
        songs.isEmpty ||
        _currentRadioId != radioId ||
        _currentRadioPlatform != radioPlatform ||
        _currentRadioPageIndex != sourcePageIndex) {
      return false;
    }
    final existingKeys = _tracks.map(_trackCacheKey).toSet();
    final appended = songs
        .map(_songToAudioTrack)
        .where((track) => !existingKeys.contains(_trackCacheKey(track)))
        .toList(growable: false);
    _currentRadioPageIndex = nextPageIndex;
    if (appended.isEmpty) {
      _broadcastQueueState();
      return false;
    }
    var merged = <AudioTrack>[..._tracks, ...appended];
    if (merged.length > _radioQueueCap) {
      final excess = merged.length - _radioQueueCap;
      merged = merged.sublist(excess);
      _committedIndex = (_committedIndex - excess).clamp(0, merged.length - 1);
    }
    _tracks = List<AudioTrack>.unmodifiable(merged);
    queue.add(_tracks.map(_toMediaItem).toList(growable: false));
    _broadcastQueueState();
    return true;
  }

  AudioTrack _songToAudioTrack(SongInfo song) {
    final localPath = song.path?.trim();
    final platformId = song.platform.trim();
    return AudioTrack(
      id: song.id,
      title: song.title,
      url: '',
      path: localPath == null || localPath.isEmpty ? null : localPath,
      duration: song.duration > 0
          ? Duration(milliseconds: song.duration)
          : null,
      links: song.links,
      artist: song.artist,
      album: song.album?.name,
      artworkUrl: _resolveTrackArtworkUrl(song),
      platform: platformId.isEmpty ? null : platformId,
    );
  }

  String? _resolveTrackArtworkUrl(SongInfo song) {
    final platformId = song.platform.trim();
    if (platformId.isEmpty) {
      final cover = song.cover.trim();
      return cover.isEmpty ? null : cover;
    }
    final url = resolveSongCoverUrl(
      baseUrl: _apiBaseUrl,
      token: _authToken ?? '',
      platforms: _coverPlatforms,
      platformId: platformId,
      songId: song.id,
      cover: song.cover,
      size: 300,
    ).trim();
    if (url.isNotEmpty) {
      return url;
    }
    final fallback = song.cover.trim();
    return fallback.isEmpty ? null : fallback;
  }

  Future<List<SongInfo>> _fetchRadioSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    final override = _fetchRadioSongsOverride;
    if (override != null) {
      return override(
        id: id,
        platform: platform,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );
    }
    final dio = _createApiDio(
      connectTimeout: _radioConnectTimeout,
      receiveTimeout: _radioReceiveTimeout,
      sendTimeout: _radioSendTimeout,
    );
    try {
      final response = await dio.get(
        '/v1/radio/songs',
        queryParameters: <String, dynamic>{
          'id': id,
          'platform': platform,
          'page_index': pageIndex <= 0 ? 1 : pageIndex,
          'page_size': pageSize <= 0 ? 50 : pageSize,
        },
      );
      final payload = _asMap(response.data);
      final songsRaw = payload['list'];
      if (songsRaw is! List) {
        return const <SongInfo>[];
      }
      return songsRaw
          .map(
            (item) =>
                SongInfo.fromMap(_asMap(item), fallbackPlatform: platform),
          )
          .toList(growable: false);
    } finally {
      dio.close(force: true);
    }
  }

  Future<LyricDocument> _fetchLyrics({
    required String trackId,
    String? platform,
    String? localPath,
  }) async {
    final override = _fetchLyricsOverride;
    if (override != null) {
      return override(
        trackId: trackId,
        platform: platform,
        localPath: localPath,
      );
    }
    final repository = _createLyricRepository();
    return repository.fetchLyrics(
      trackId: trackId,
      platform: platform,
      localPath: localPath,
    );
  }

  LyricRepository _createLyricRepository() {
    final dio = _createApiDio();
    return LyricRepositoryImpl(
      OnlineLyricDataSource(OnlineApiClient(dio)),
      DemoLyricDataSource(),
      const LocalAudioMetadataReader(),
    );
  }

  Dio _createApiDio({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    final token = globalTokenHolder.accessToken ?? _authToken;
    return Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: connectTimeout ?? const Duration(seconds: 20),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        sendTimeout: sendTimeout ?? const Duration(seconds: 30),
        responseType: ResponseType.json,
        headers: <String, String>{
          'User-Agent': heAudioUserAgent,
          if ((token ?? '').isNotEmpty) ...<String, String>{
            'Authorization': 'Bearer $token',
          },
        },
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  Future<void> _syncOverlayCurrentState() async {
    if (!_enableDesktopLyric) {
      return;
    }
    await _syncOverlayConfig();
    final track = _safeTrack(_committedIndex);
    if (track != null) {
      await _overlayLyricsService.sendTrackChanged(
        title: track.title,
        artist: track.artist ?? '',
      );
    }
    await _overlayLyricsService.sendDocument(
      _currentLyricDocument,
      _overlayConfigState,
      autoHighlightColorValue: _autoLyricHighlightColorValue,
    );
    await _overlayLyricsService.sendPosition(_player.position);
  }

  Future<void> _syncOverlayConfig() async {
    if (!_enableDesktopLyric) {
      return;
    }
    await _overlayLyricsService.sendStyleUpdate(
      _overlayConfigState,
      autoHighlightColorValue: _autoLyricHighlightColorValue,
    );
    if (_enableDesktopLyricLock) {
      await _overlayLyricsService.lock();
    } else {
      await _overlayLyricsService.unlock();
    }
  }

  Future<void> _syncOverlayPosition(Duration position) async {
    if (!_enableDesktopLyric) {
      return;
    }
    await _overlayLyricsService.sendPosition(position);
  }

  AppConfigState get _overlayConfigState {
    final initial = AppConfigState.initial;
    return initial.copyWith(
      lyricHighlightMode: _lyricHighlightMode,
      lyricHighlightPreset: _colorPresetFromValue(
        _lyricHighlightPresetColorValue,
      ),
      lyricHighlightCustomColor: _lyricHighlightCustomColorValue,
      clearLyricHighlightCustomColor: _lyricHighlightCustomColorValue == null,
      enableDesktopLyric: _enableDesktopLyric,
      enableDesktopLyricLock: _enableDesktopLyricLock,
      enableWordByWordLyric: _enableWordByWordLyric,
      lyricFontPreset:
          AppLyricFontPreset.values[_lyricFontPresetIndex.clamp(
            0,
            AppLyricFontPreset.values.length - 1,
          )],
    );
  }

  AppLyricHighlightColor _colorPresetFromValue(int value) {
    for (final preset in AppLyricHighlightColor.values) {
      if (preset.color.toARGB32() == value) {
        return preset;
      }
    }
    return AppLyricHighlightColor.sky;
  }

  String? _normalizeValue(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int? _normalizePageIndex(int? pageIndex) {
    if (pageIndex == null || pageIndex <= 0) {
      return null;
    }
    return pageIndex;
  }

  Map<String, dynamic> _serializeTrack(AudioTrack track) {
    return <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'url': track.url,
      'path': track.path,
      'durationMs': track.duration?.inMilliseconds,
      'artist': track.artist,
      'album': track.album,
      'artworkUrl': track.artworkUrl,
      'platform': track.platform,
      'links': track.links.map(_serializeLink).toList(growable: false),
    };
  }

  Map<String, dynamic> _serializeLink(LinkInfo link) {
    return <String, dynamic>{
      'name': link.name,
      'quality': link.quality,
      'format': link.format,
      'size': link.size,
      'url': link.url,
    };
  }

  String _trackCacheKey(AudioTrack track) {
    final platform = track.platform?.trim() ?? '';
    if (platform.isEmpty) {
      return track.id.trim();
    }
    return '${track.id.trim()}|$platform';
  }
}

enum _PlaybackFailureCategory {
  cancelled,
  globalTransient,
  trackUnavailable,
  unknown,
}

class _ResolvedPlaybackUrl {
  const _ResolvedPlaybackUrl({
    required this.url,
    required this.resolvedAt,
    required this.version,
  });

  final String url;
  final DateTime resolvedAt;
  final int version;
}

class _InFlightPlaybackUrl {
  const _InFlightPlaybackUrl({required this.version, required this.future});

  final int version;
  final Future<String> future;
}

class _QueueContext {
  const _QueueContext({
    required this.isRadioMode,
    required this.radioId,
    required this.radioPlatform,
    required this.radioPageIndex,
  });

  final bool isRadioMode;
  final String? radioId;
  final String? radioPlatform;
  final int? radioPageIndex;
}

class _StaleTransitionException implements Exception {
  const _StaleTransitionException();
}

class _TrackUnavailableException implements Exception {
  const _TrackUnavailableException(this.trackId);

  final String trackId;
}

class _UnchangedPlaybackUrlException implements Exception {
  const _UnchangedPlaybackUrlException(this.trackId);

  final String trackId;
}

class _NoPlayableTrackException implements Exception {
  const _NoPlayableTrackException();
}

late final HeAudioHandler globalHeAudioHandler;

Future<void> initHeAudioHandler() async {
  globalHeAudioHandler = await AudioService.init(
    builder: HeAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.hemusic.music.flutter.audio',
      androidNotificationChannelName: 'HE-Music 播放控制',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidResumeOnClick: true,
    ),
  );
}

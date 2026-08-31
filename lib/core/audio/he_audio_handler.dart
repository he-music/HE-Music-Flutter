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
import '../device/device_info_provider.dart';
import '../network/auth_token_interceptor.dart';
import '../network/network_status_port.dart';
import '../network/token_refresh_interceptor.dart';
import 'audio_sleep_timer.dart';
import 'audio_player_port.dart';
import 'audio_player_factory.dart';
import 'audio_spectrum_frame.dart';
import 'audio_spectrum_projector.dart';
import 'audio_track.dart';
import 'local_audio_metadata_reader.dart';

class HeAudioHandlerRuntimeConfig {
  const HeAudioHandlerRuntimeConfig({
    required this.apiBaseUrl,
    required this.authToken,
    required this.refreshToken,
    required this.tokenExpiresAt,
    required this.wifiQualityPreference,
    required this.cellularQualityPreference,
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
  final String? refreshToken;
  final int? tokenExpiresAt;
  final AppOnlineAudioQuality wifiQualityPreference;
  final AppOnlineAudioQuality cellularQualityPreference;
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
typedef HeAudioHandlerPause = Future<void> Function(AudioPlayer player);
typedef HeAudioHandlerSeek =
    Future<void> Function(Duration position, AudioPlayer player);
typedef HeAudioHandlerPosition = Duration Function(AudioPlayer player);
typedef HeAudioHandlerDispose = Future<void> Function(AudioPlayer player);
typedef HeAudioHandlerStartVisualizer =
    Future<void> Function(AudioPlayer player);
typedef HeAudioHandlerStopVisualizer =
    Future<void> Function(AudioPlayer player);
typedef HeAudioHandlerVisualizerFftStream =
    Stream<VisualizerFftCapture> Function(AudioPlayer player);
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
  AppConfigDataSource? dataSource,
}) async {
  final config = await (dataSource ?? const AppConfigDataSource()).load();
  return HeAudioHandlerRuntimeConfig(
    apiBaseUrl: config.apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
    authToken: config.authToken?.trim(),
    refreshToken: config.refreshToken?.trim(),
    tokenExpiresAt: config.tokenExpiresAt,
    wifiQualityPreference: config.wifiOnlineAudioQualityPreference,
    cellularQualityPreference: config.cellularOnlineAudioQualityPreference,
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
  static const Duration _spectrumProjectionPeriod = Duration(milliseconds: 33);

  HeAudioHandler({
    AudioPlayer? player,
    HeAudioHandlerFetchSongUrl? fetchSongUrlOverride,
    HeAudioHandlerFetchRadioSongs? fetchRadioSongsOverride,
    HeAudioHandlerFetchLyrics? fetchLyricsOverride,
    HeAudioHandlerSetAudioSource? setAudioSourceOverride,
    HeAudioHandlerPlay? playOverride,
    HeAudioHandlerPause? pauseOverride,
    HeAudioHandlerSeek? seekOverride,
    HeAudioHandlerPosition? positionOverride,
    HeAudioHandlerDispose? disposeOverride,
    HeAudioHandlerStartVisualizer? startVisualizerOverride,
    HeAudioHandlerStopVisualizer? stopVisualizerOverride,
    HeAudioHandlerVisualizerFftStream? visualizerFftStreamOverride,
    HeAudioHandlerNow? nowOverride,
    HeAudioHandlerLog? logOverride,
    DeviceInfoGetter? getDeviceInfoOverride,
    AppConfigDataSource? configDataSourceOverride,
    NetworkStatusPort? networkStatusPort,
    Random? randomOverride,
    OverlayChannelService? overlayLyricsServiceOverride,
  }) : _player = player ?? createHeAudioPlayer(),
       _fetchSongUrlOverride = fetchSongUrlOverride,
       _fetchRadioSongsOverride = fetchRadioSongsOverride,
       _fetchLyricsOverride = fetchLyricsOverride,
       _setAudioSourceOverride = setAudioSourceOverride,
       _playOverride = playOverride,
       _pauseOverride = pauseOverride,
       _seekOverride = seekOverride,
       _positionOverride = positionOverride,
       _disposeOverride = disposeOverride,
       _startVisualizerOverride = startVisualizerOverride,
       _stopVisualizerOverride = stopVisualizerOverride,
       _visualizerFftStreamOverride = visualizerFftStreamOverride,
       _now = nowOverride ?? DateTime.now,
       _logOverride = logOverride,
       _getDeviceInfoOverride = getDeviceInfoOverride,
       _configDataSource =
           configDataSourceOverride ?? const AppConfigDataSource(),
       _networkStatusPort = networkStatusPort ?? globalNetworkStatusPort,
       _random = randomOverride ?? Random(),
       _overlayLyricsService =
           overlayLyricsServiceOverride ?? OverlayLyricsService() {
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleChanged,
    );
    _networkConnectionType = _networkStatusPort.lastKnown;
    _networkStatusSubscription = _networkStatusPort.changes.listen(
      (next) {
        _networkStatusEventVersion += 1;
        _handleNetworkStatusChanged(next);
      },
      onError: (_, _) =>
          _logTransition('network.status.failure', _transitionId),
    );
    unawaited(_syncInitialNetworkStatus());
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
    }, onError: _handlePlaybackStreamError);
    _player
        .createPositionStream(
          minPeriod: _overlayPositionPeriod,
          maxPeriod: _overlayPositionPeriod,
        )
        .listen((position) {
          unawaited(_syncOverlayPosition(position));
          unawaited(_refreshNextTrackUrlNearEnd(position));
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
  static const Duration _preloadRefreshLeadTime = Duration(minutes: 1);
  static const Duration _preloadExpirySafetyMargin = Duration(seconds: 30);

  final AudioPlayer _player;
  final HeAudioHandlerFetchSongUrl? _fetchSongUrlOverride;
  final HeAudioHandlerFetchRadioSongs? _fetchRadioSongsOverride;
  final HeAudioHandlerFetchLyrics? _fetchLyricsOverride;
  final HeAudioHandlerSetAudioSource? _setAudioSourceOverride;
  final HeAudioHandlerPlay? _playOverride;
  final HeAudioHandlerPause? _pauseOverride;
  final HeAudioHandlerSeek? _seekOverride;
  final HeAudioHandlerPosition? _positionOverride;
  final HeAudioHandlerDispose? _disposeOverride;
  final HeAudioHandlerStartVisualizer? _startVisualizerOverride;
  final HeAudioHandlerStopVisualizer? _stopVisualizerOverride;
  final HeAudioHandlerVisualizerFftStream? _visualizerFftStreamOverride;
  final HeAudioHandlerNow _now;
  final HeAudioHandlerLog? _logOverride;
  final DeviceInfoGetter? _getDeviceInfoOverride;
  final AppConfigDataSource _configDataSource;
  final NetworkStatusPort _networkStatusPort;
  final OverlayChannelService _overlayLyricsService;
  final Random _random;
  late final AppLifecycleListener _appLifecycleListener;
  late final StreamSubscription<NetworkConnectionType>
  _networkStatusSubscription;
  final StreamController<AudioSpectrumFrame> _spectrumFrameController =
      StreamController<AudioSpectrumFrame>.broadcast();
  final AudioSpectrumProjector _spectrumProjector =
      const AudioSpectrumProjector();

  StreamSubscription<VisualizerFftCapture>? _visualizerFftSubscription;
  Timer? _spectrumProjectionTimer;
  VisualizerFftCapture? _latestVisualizerFftCapture;
  int? _latestVisualizerSourceGeneration;
  Future<void>? _spectrumCaptureConvergence;
  bool _spectrumCaptureTarget = false;
  bool _spectrumCaptureRunning = false;
  bool _spectrumDisposed = false;

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
  int? _nearEndPreloadRefreshGeneration;
  int _transitionId = 0;
  Timer? _manualSkipDebounceTimer;
  Timer? _manualSkipMaxBatchTimer;
  Timer? _sleepTimer;
  List<int>? _desiredShuffleOrder;
  int? _desiredShuffleCursor;
  int _desiredDirection = 1;
  bool _manualSkipTargetActive = false;
  DateTime? _sleepTimerDeadline;
  bool _sleepTimerStopAfterCurrent = false;
  bool _sleepTimerWaitingForTrackEnd = false;
  String? _sleepTimerTrackKey;
  int? _sleepTimerSourceGeneration;
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
  AppOnlineAudioQuality _wifiQualityPreference = AppOnlineAudioQuality.auto;
  AppOnlineAudioQuality _cellularQualityPreference =
      AppOnlineAudioQuality.mp3320;
  NetworkConnectionType _networkConnectionType = NetworkConnectionType.wifi;
  int _networkStatusEventVersion = 0;
  bool _playIntent = false;
  _PendingPlaybackRecovery? _pendingPlaybackRecovery;
  Future<void>? _playbackRecoveryFuture;
  String? _lastSelectedQualityName;

  Future<void> syncConfig({
    required String apiBaseUrl,
    required String? authToken,
    required AppOnlineAudioQuality wifiQualityPreference,
    required AppOnlineAudioQuality cellularQualityPreference,
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
    final previousActiveQuality =
        _networkConnectionType == NetworkConnectionType.cellular
        ? _cellularQualityPreference
        : _wifiQualityPreference;
    final previousLastSelectedQualityName = _lastSelectedQualityName;
    final normalizedLastSelectedQualityName = lastSelectedQualityName?.trim();
    final nextActiveQuality =
        _networkConnectionType == NetworkConnectionType.cellular
        ? cellularQualityPreference
        : wifiQualityPreference;
    final shouldRefreshPreload =
        previousActiveQuality != nextActiveQuality ||
        (nextActiveQuality.isAuto &&
            previousLastSelectedQualityName !=
                normalizedLastSelectedQualityName);
    _apiBaseUrl = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _authToken = authToken?.trim();
    _wifiQualityPreference = wifiQualityPreference;
    _cellularQualityPreference = cellularQualityPreference;
    _lastSelectedQualityName = normalizedLastSelectedQualityName;
    _enableDesktopLyric = enableDesktopLyric;
    _enableDesktopLyricLock = enableDesktopLyricLock;
    _lyricHighlightMode = lyricHighlightMode;
    _lyricHighlightPresetColorValue = lyricHighlightPresetColorValue;
    _lyricHighlightCustomColorValue = lyricHighlightCustomColorValue;
    _lyricFontPresetIndex = lyricFontPresetIndex;
    _enableWordByWordLyric = enableWordByWordLyric;
    _configRecovered = true;
    if (shouldRefreshPreload &&
        _networkConnectionType != NetworkConnectionType.offline &&
        _tracks.isNotEmpty) {
      unawaited(_preloadNextTrackUrl(_committedIndex));
    }
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
    _playIntent = false;
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
      final hadSleepTimer = _clearSleepTimerState();
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
      if (hadSleepTimer) {
        _broadcastSleepTimerState();
      }
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
    } catch (error) {
      _broadcastTransitionError(error, transitionId);
      rethrow;
    }
  }

  Future<void> replaceCurrentTrack(
    AudioTrack track, {
    String? forcedQualityName,
  }) async {
    if (_tracks.isEmpty) {
      await setQueueData(<AudioTrack>[track], initialIndex: 0);
      return;
    }
    final transitionId = _beginTransition();
    final next = <AudioTrack>[..._tracks];
    next[_committedIndex] = track;
    final resumePosition = _currentPosition;
    final wasPlaying = _player.playing;
    try {
      await _loadTrackAt(
        _committedIndex,
        autoplay: false,
        transitionId: transitionId,
        sourceTracks: List<AudioTrack>.unmodifiable(next),
        forceUrlRefresh: true,
        forcedQualityName: forcedQualityName,
      );
    } on _StaleTransitionException {
      return;
    } catch (error) {
      _broadcastTransitionError(error, transitionId);
      rethrow;
    }
    try {
      _guardTransition(transitionId);
    } on _StaleTransitionException {
      return;
    }
    if (resumePosition > Duration.zero) {
      await _seek(resumePosition);
    }
    if (wasPlaying) {
      _requestPlay(transitionId);
    }
  }

  Future<void> playIndex(int index) async {
    if (_tracks.isEmpty) {
      return;
    }
    _playIntent = true;
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
    } catch (error) {
      _broadcastTransitionError(error, transitionId);
      rethrow;
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

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<Duration> get positionStream => _player.createPositionStream(
    minPeriod: _positionStreamPeriod,
    maxPeriod: _positionStreamPeriod,
  );

  Stream<Duration> get bufferedPositionStream =>
      playbackState.map((state) => state.bufferedPosition).distinct();

  Stream<AudioSpectrumFrame> get spectrumFrameStream =>
      _spectrumFrameController.stream;

  SleepTimerState get currentSleepTimerState => SleepTimerState(
    deadline: _sleepTimerDeadline,
    stopAfterCurrent: _sleepTimerStopAfterCurrent,
    waitingForTrackEnd: _sleepTimerWaitingForTrackEnd,
  );

  Future<void> startSpectrumCapture() => _setSpectrumCaptureTarget(true);

  Future<void> stopSpectrumCapture() => _setSpectrumCaptureTarget(false);

  Future<void> setSleepTimer(
    Duration duration, {
    required bool stopAfterCurrent,
  }) async {
    if (duration <= Duration.zero) {
      await cancelSleepTimer();
      return;
    }
    _sleepTimer?.cancel();
    _sleepTimerDeadline = _now().add(duration);
    _sleepTimerStopAfterCurrent = stopAfterCurrent;
    _sleepTimerWaitingForTrackEnd = false;
    _sleepTimerTrackKey = null;
    _sleepTimerSourceGeneration = null;
    _sleepTimer = Timer(duration, () {
      unawaited(_handleSleepTimerExpired());
    });
    _broadcastSleepTimerState();
  }

  Future<void> cancelSleepTimer() async {
    _clearSleepTimerState();
    _broadcastSleepTimerState();
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case AudioSleepTimerActions.set:
        final durationMs = extras?[AudioSleepTimerFields.durationMs];
        if (durationMs is! int) {
          return currentSleepTimerState.toCustomEvent();
        }
        await setSleepTimer(
          Duration(milliseconds: durationMs),
          stopAfterCurrent:
              extras?[AudioSleepTimerFields.stopAfterCurrent] == true,
        );
        return currentSleepTimerState.toCustomEvent();
      case AudioSleepTimerActions.cancel:
        await cancelSleepTimer();
        return currentSleepTimerState.toCustomEvent();
      default:
        return super.customAction(name, extras);
    }
  }

  @visibleForTesting
  Future<void> expireSleepTimerForTesting() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    return _handleSleepTimerExpired();
  }

  Future<void> _handleSleepTimerExpired() async {
    if (_sleepTimerDeadline == null) {
      return;
    }
    _sleepTimer = null;
    if (_sleepTimerStopAfterCurrent) {
      final current = _safeTrack(_committedIndex);
      final generation = _armedSourceGeneration ?? _sourceGeneration;
      if (current != null && generation > 0) {
        _sleepTimerWaitingForTrackEnd = true;
        _sleepTimerTrackKey = _trackCacheKey(current);
        _sleepTimerSourceGeneration = generation;
        _broadcastSleepTimerState();
        return;
      }
    }
    await _pausePlaybackForSleepTimer();
  }

  Future<void> _pausePlaybackForSleepTimer() async {
    final transitionId = _beginTransition(clearExpiredSleepTimer: false);
    _playIntent = false;
    try {
      await _pausePlayer();
    } catch (error) {
      _logSleepTimerFailure('sleep.timer.pause.failed', error);
    } finally {
      _clearSleepTimerState();
      _broadcastPlaybackState();
      _broadcastSleepTimerState();
      _logTransition('sleep.timer.stopped', transitionId);
    }
  }

  bool _shouldStopAfterCurrentForSleepTimer(int generation) {
    if (!_sleepTimerStopAfterCurrent || !_sleepTimerWaitingForTrackEnd) {
      return false;
    }
    if (generation != _sleepTimerSourceGeneration) {
      return false;
    }
    final current = _safeTrack(_committedIndex);
    return current != null && _sleepTimerTrackKey == _trackCacheKey(current);
  }

  bool _clearSleepTimerState() {
    final hadState =
        _sleepTimer != null ||
        _sleepTimerDeadline != null ||
        _sleepTimerStopAfterCurrent ||
        _sleepTimerWaitingForTrackEnd ||
        _sleepTimerTrackKey != null ||
        _sleepTimerSourceGeneration != null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerDeadline = null;
    _sleepTimerStopAfterCurrent = false;
    _sleepTimerWaitingForTrackEnd = false;
    _sleepTimerTrackKey = null;
    _sleepTimerSourceGeneration = null;
    return hadState;
  }

  void _clearExpiredSleepTimerAfterTransition() {
    if (!_sleepTimerWaitingForTrackEnd) {
      return;
    }
    _clearSleepTimerState();
    _broadcastSleepTimerState();
  }

  Future<void> _setSpectrumCaptureTarget(bool target) {
    if (target && _spectrumDisposed) {
      return Future<void>.error(StateError('HeAudioHandler 已释放，无法启动频谱捕获。'));
    }
    _spectrumCaptureTarget = target;
    return _ensureSpectrumCaptureConvergence();
  }

  Future<void> _ensureSpectrumCaptureConvergence() {
    final activeConvergence = _spectrumCaptureConvergence;
    if (activeConvergence != null) {
      // 平台调用刚完成时目标仍可能变化；旧 Future 完成后必须再次核对最终目标。
      return activeConvergence.then((_) => _ensureSpectrumCaptureConvergence());
    }
    if (_spectrumCaptureRunning == _spectrumCaptureTarget) {
      return Future<void>.value();
    }

    late final Future<void> trackedConvergence;
    trackedConvergence = _convergeSpectrumCapture().whenComplete(() {
      if (identical(_spectrumCaptureConvergence, trackedConvergence)) {
        _spectrumCaptureConvergence = null;
      }
    });
    _spectrumCaptureConvergence = trackedConvergence;
    return trackedConvergence;
  }

  Future<void> _convergeSpectrumCapture() async {
    while (_spectrumCaptureRunning != _spectrumCaptureTarget) {
      if (_spectrumCaptureTarget) {
        await _startSpectrumCaptureInternal();
      } else {
        await _stopSpectrumCaptureInternal();
      }
    }
  }

  Future<void> _startSpectrumCaptureInternal() async {
    final captureGeneration = _sourceGeneration;
    final fftStream =
        _visualizerFftStreamOverride?.call(_player) ??
        _player.visualizerFftStream;
    _visualizerFftSubscription = fftStream.listen(
      (capture) => _acceptVisualizerFftCapture(capture, captureGeneration),
      onError: (Object error, StackTrace stackTrace) {
        _logSpectrumFailure('spectrum.stream.error', error);
      },
    );

    try {
      final override = _startVisualizerOverride;
      if (override != null) {
        await override(_player);
      } else {
        await _player.startVisualizer(
          enableWaveform: false,
          enableFft: true,
          captureRate: 30000,
          captureSize: 1024,
        );
      }
    } catch (error) {
      _spectrumCaptureTarget = false;
      await _clearSpectrumCaptureResources();
      _logSpectrumFailure('spectrum.start.failed', error);
      rethrow;
    }

    _spectrumCaptureRunning = true;
    _spectrumProjectionTimer = Timer.periodic(
      _spectrumProjectionPeriod,
      (_) => _projectLatestSpectrumFrame(),
    );
  }

  Future<void> _stopSpectrumCaptureInternal() async {
    _spectrumCaptureRunning = false;
    await _clearSpectrumCaptureResources();
    try {
      final override = _stopVisualizerOverride;
      if (override != null) {
        await override(_player);
      } else {
        await _player.stopVisualizer();
      }
    } catch (error) {
      _logSpectrumFailure('spectrum.stop.failed', error);
      rethrow;
    }
  }

  void _acceptVisualizerFftCapture(
    VisualizerFftCapture capture,
    int captureGeneration,
  ) {
    if (_spectrumDisposed ||
        !_spectrumCaptureTarget ||
        captureGeneration != _sourceGeneration) {
      return;
    }
    _latestVisualizerFftCapture = capture;
    _latestVisualizerSourceGeneration = captureGeneration;
  }

  void _projectLatestSpectrumFrame() {
    final capture = _latestVisualizerFftCapture;
    final generation = _latestVisualizerSourceGeneration;
    _latestVisualizerFftCapture = null;
    _latestVisualizerSourceGeneration = null;
    if (!_spectrumCaptureRunning ||
        capture == null ||
        generation != _sourceGeneration) {
      return;
    }

    try {
      final frame = _spectrumProjector.project(
        binCount: capture.length,
        magnitudeAt: capture.getMagnitude,
      );
      if (_spectrumCaptureRunning &&
          generation == _sourceGeneration &&
          !_spectrumFrameController.isClosed) {
        _spectrumFrameController.add(frame);
      }
    } catch (error) {
      _logSpectrumFailure('spectrum.project.failed', error);
    }
  }

  Future<void> _clearSpectrumCaptureResources() async {
    _spectrumProjectionTimer?.cancel();
    _spectrumProjectionTimer = null;
    _latestVisualizerFftCapture = null;
    _latestVisualizerSourceGeneration = null;
    final subscription = _visualizerFftSubscription;
    _visualizerFftSubscription = null;
    await subscription?.cancel();
  }

  @override
  Future<void> play() async {
    _playIntent = true;
    if (_pendingPlaybackRecovery != null) {
      await retryCurrentPlayback();
      return;
    }
    if (_isCurrentRemoteTrack &&
        _networkConnectionType == NetworkConnectionType.offline) {
      _rememberCurrentPlaybackRecovery();
      _broadcastTransitionError(
        const _NetworkUnavailableException(),
        _transitionId,
      );
      return;
    }
    _requestPlay(_transitionId);
  }

  @override
  Future<void> pause() async {
    _playIntent = false;
    await _pausePlayer();
    if (_sleepTimerWaitingForTrackEnd) {
      _clearSleepTimerState();
      _broadcastSleepTimerState();
    }
  }

  @override
  Future<void> stop() async {
    _playIntent = false;
    final hadSleepTimer = _clearSleepTimerState();
    _beginTransition();
    await _player.stop();
    _broadcastPlaybackState();
    if (hadSleepTimer) {
      _broadcastSleepTimerState();
    }
  }

  @override
  Future<void> seek(Duration position) => _seek(position);

  @override
  Future<void> skipToNext() async {
    if (_tracks.isEmpty) {
      return;
    }
    _playIntent = true;
    if (_isRadioMode && _committedIndex >= _tracks.length - 1) {
      _cancelManualIntent(clearDesired: true);
      final transitionId = _beginTransition(cancelManualIntent: false);
      _manualSkipTargetActive = true;
      _broadcastManualSkipTarget(transitionId: transitionId, targetIndex: null);
      unawaited(_playNextRadioTrack(transitionId, manual: true));
      return;
    }
    _scheduleManualSkip(1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_tracks.isEmpty) {
      return;
    }
    _playIntent = true;
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
    _manualSkipTargetActive = true;
    _broadcastManualSkipTarget(
      transitionId: transitionId,
      targetIndex: _desiredIndex,
    );
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
          _clearManualSkipTarget(transitionId);
          _broadcastTransitionError(nextError, transitionId);
          return;
        }
      }
      _clearManualSkipTarget(transitionId);
      _broadcastTransitionError(error, transitionId);
    }
  }

  void _cancelManualIntent({required bool clearDesired}) {
    final hadActiveTarget = _manualSkipTargetActive;
    _manualSkipDebounceTimer?.cancel();
    _manualSkipMaxBatchTimer?.cancel();
    _manualSkipDebounceTimer = null;
    _manualSkipMaxBatchTimer = null;
    if (clearDesired) {
      _desiredIndex = null;
      _desiredShuffleOrder = null;
      _desiredShuffleCursor = null;
    }
    _manualSkipTargetActive = false;
    if (hadActiveTarget) {
      _broadcastManualSkipTarget(
        transitionId: _transitionId,
        targetIndex: null,
        cleared: true,
      );
    }
  }

  Future<void> _playNextRadioTrack(
    int transitionId, {
    bool manual = false,
  }) async {
    try {
      final sourceIndex = _committedIndex;
      final appended = await _ensureRadioNextPageAppended();
      _guardTransition(transitionId);
      if (!appended || _tracks.length <= sourceIndex + 1) {
        if (manual) {
          _clearManualSkipTarget(transitionId);
        }
        return;
      }
      if (manual) {
        _broadcastManualSkipTarget(
          transitionId: transitionId,
          targetIndex: sourceIndex + 1,
        );
      }
      await _loadTrackAt(
        sourceIndex + 1,
        autoplay: true,
        transitionId: transitionId,
      );
    } on _StaleTransitionException {
      return;
    } catch (error) {
      if (manual) {
        _clearManualSkipTarget(transitionId);
      }
      _broadcastTransitionError(error, transitionId);
    }
  }

  Future<void> disposeHandler() async {
    _beginTransition();
    _clearSleepTimerState();
    _appLifecycleListener.dispose();
    await _networkStatusSubscription.cancel();
    _spectrumDisposed = true;
    _spectrumCaptureTarget = false;
    try {
      await _setSpectrumCaptureTarget(false);
    } catch (_) {
      // 停止失败已记录；仍需继续释放播放器及本地流资源。
    }
    await _clearSpectrumCaptureResources();
    await _spectrumFrameController.close();
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
    String? forcedQualityName,
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
      var resolved = await _resolveTrack(
        track,
        forceRefresh: forceUrlRefresh,
        forcedQualityName: forcedQualityName,
      );
      _guardTransition(transitionId);
      Object? lastError;
      for (var attempt = 1; attempt <= _setSourceMaxAttempts; attempt += 1) {
        if (_networkConnectionType == NetworkConnectionType.offline &&
            shouldRefreshRemotePlaybackUrl(track)) {
          throw const _NetworkUnavailableException();
        }
        try {
          final generation = ++_sourceGeneration;
          _latestVisualizerFftCapture = null;
          _latestVisualizerSourceGeneration = null;
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
          resolved = await _resolveTrack(
            track,
            forceRefresh: true,
            forcedQualityName: forcedQualityName,
          );
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
    _manualSkipTargetActive = false;
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
    bool clearExpiredSleepTimer = true,
  }) {
    _transitionId += 1;
    _pendingPlaybackRecovery = null;
    _playbackRecoveryFuture = null;
    if (!preservePending) {
      _pendingIndex = null;
      _pendingShuffleOrder = null;
      _pendingShuffleCursor = null;
    }
    if (cancelManualIntent) {
      _cancelManualIntent(clearDesired: true);
    }
    if (clearExpiredSleepTimer) {
      _clearExpiredSleepTimerAfterTransition();
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
    _playIntent = true;
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

  Future<void> _syncInitialNetworkStatus() async {
    final eventVersion = _networkStatusEventVersion;
    try {
      final current = await _networkStatusPort.current();
      if (eventVersion == _networkStatusEventVersion) {
        _handleNetworkStatusChanged(current);
      }
    } catch (_) {
      _logTransition('network.status.failure', _transitionId);
    }
  }

  void _handleNetworkStatusChanged(NetworkConnectionType next) {
    final previous = _networkConnectionType;
    _networkConnectionType = next;
    if (previous != next &&
        next != NetworkConnectionType.offline &&
        _tracks.isNotEmpty) {
      unawaited(_preloadNextTrackUrl(_committedIndex));
    }
    if (previous == NetworkConnectionType.offline &&
        next != NetworkConnectionType.offline &&
        _pendingPlaybackRecovery != null) {
      unawaited(_startPlaybackRecovery().catchError((_) {}));
    }
  }

  void _handlePlaybackStreamError(Object error, StackTrace stackTrace) {
    _broadcastTransitionError(error, _transitionId);
  }

  bool get _isCurrentRemoteTrack {
    final track = _safeTrack(_committedIndex);
    return track != null && shouldRefreshRemotePlaybackUrl(track);
  }

  void _rememberCurrentPlaybackRecovery() {
    final track = _safeTrack(_committedIndex);
    if (track == null || !shouldRefreshRemotePlaybackUrl(track)) {
      return;
    }
    final previous = _pendingPlaybackRecovery;
    final position = _currentPosition;
    _pendingPlaybackRecovery = _PendingPlaybackRecovery(
      transitionId: _transitionId,
      trackKey: _trackCacheKey(track),
      index: _committedIndex,
      position:
          previous != null &&
              previous.transitionId == _transitionId &&
              previous.trackKey == _trackCacheKey(track) &&
              previous.position > position
          ? previous.position
          : position,
    );
  }

  /// 强刷当前远程音源。通知栏、播放器按钮和联网恢复共享同一单飞入口。
  Future<void> retryCurrentPlayback() {
    _playIntent = true;
    _rememberCurrentPlaybackRecovery();
    if (_pendingPlaybackRecovery == null) {
      _requestPlay(_transitionId);
      return Future<void>.value();
    }
    return _startPlaybackRecovery();
  }

  Future<void> _startPlaybackRecovery() {
    final active = _playbackRecoveryFuture;
    if (active != null) {
      return active;
    }
    late final Future<void> future;
    future = _recoverPendingPlayback().whenComplete(() {
      if (identical(_playbackRecoveryFuture, future)) {
        _playbackRecoveryFuture = null;
      }
    });
    _playbackRecoveryFuture = future;
    return future;
  }

  Future<void> _recoverPendingPlayback() async {
    final snapshot = _pendingPlaybackRecovery;
    if (snapshot == null) {
      return;
    }
    if (_networkConnectionType == NetworkConnectionType.offline) {
      const error = _NetworkUnavailableException();
      _broadcastTransitionError(error, snapshot.transitionId);
      throw error;
    }
    final current = _safeTrack(_committedIndex);
    if (snapshot.transitionId != _transitionId ||
        current == null ||
        snapshot.index != _committedIndex ||
        snapshot.trackKey != _trackCacheKey(current)) {
      if (identical(_pendingPlaybackRecovery, snapshot)) {
        _pendingPlaybackRecovery = null;
      }
      return;
    }
    try {
      await _loadTrackAt(
        snapshot.index,
        autoplay: false,
        transitionId: snapshot.transitionId,
        forceUrlRefresh: true,
      );
      _guardTransition(snapshot.transitionId);
      if (snapshot.position > Duration.zero) {
        await _seek(snapshot.position);
        _guardTransition(snapshot.transitionId);
      }
      if (identical(_pendingPlaybackRecovery, snapshot)) {
        _pendingPlaybackRecovery = null;
      }
      customEvent.add(<String, dynamic>{
        'type': 'playbackTransitionRecovered',
        'transitionId': snapshot.transitionId,
      });
      if (_playIntent) {
        _requestPlay(snapshot.transitionId);
      }
    } on _StaleTransitionException {
      return;
    } catch (error) {
      _broadcastTransitionError(error, snapshot.transitionId);
      rethrow;
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
    String? forcedQualityName,
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
        format: track.format,
        bitrate: track.bitrate,
        sampleRate: track.sampleRate,
      );
    }
    if (!shouldRefreshRemotePlaybackUrl(track)) {
      if (track.url.trim().isNotEmpty) {
        return track;
      }
      final matchedDirect =
          _resolvePreferredLink(
            track.links,
            forcedQualityName: forcedQualityName,
          )?.url.trim() ??
          '';
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
          format: track.format,
          bitrate: track.bitrate,
          sampleRate: track.sampleRate,
        );
      }
      return track;
    }
    if (_networkConnectionType == NetworkConnectionType.offline) {
      throw const _NetworkUnavailableException();
    }
    final matchedQuality = _resolvePreferredLink(
      track.links,
      forcedQualityName: forcedQualityName,
    );
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
      format: track.format,
      bitrate: track.bitrate,
      sampleRate: track.sampleRate,
    );
  }

  Future<void> _preloadNextTrackUrl(
    int sourceIndex, {
    Duration minimumRemainingValidity = Duration.zero,
  }) async {
    AudioTrack? track;
    try {
      // 电台模式先补足下一页，再解析下一首 URL，避免跨页时错过预加载。
      await _ensureRadioNextPageIfNeeded(targetIndex: sourceIndex + 1);
      if (_tracks.length < 2) {
        return;
      }
      final nextIndex = _resolveNextTrackIndex(sourceIndex, advance: false);
      track = _safeTrack(nextIndex);
      if (track == null ||
          !shouldRefreshRemotePlaybackUrl(track) ||
          _hasFreshResolvedPlaybackUrl(
            track,
            minimumRemainingValidity: minimumRemainingValidity,
          )) {
        return;
      }
      final cacheKey = _playbackUrlCacheKey(track);
      await _resolveTrack(
        track,
        forceRefresh: _resolvedPlaybackUrls.containsKey(cacheKey),
      );
    } catch (error) {
      // 预加载失败不能影响当前播放；真正切歌时仍会按正常链路重试。
      _logTransition('url.preload.failure', _transitionId, track: track);
    }
  }

  bool _hasFreshResolvedPlaybackUrl(
    AudioTrack track, {
    Duration minimumRemainingValidity = Duration.zero,
  }) {
    final cacheKey = _playbackUrlCacheKey(track);
    final cached = _resolvedPlaybackUrls[cacheKey];
    if (cached == null) {
      return false;
    }
    final age = _now().difference(cached.resolvedAt);
    return age + minimumRemainingValidity < _preloadedPlaybackUrlTtl;
  }

  Future<void> _refreshNextTrackUrlNearEnd(Duration position) async {
    final duration = _duration;
    final committedSourceGeneration = _armedSourceGeneration;
    if (duration == null ||
        committedSourceGeneration == null ||
        committedSourceGeneration != _sourceGeneration ||
        duration <= _preloadRefreshLeadTime ||
        position < Duration.zero ||
        position >= duration) {
      return;
    }
    final remaining = duration - position;
    if (remaining > _preloadRefreshLeadTime ||
        _nearEndPreloadRefreshGeneration == committedSourceGeneration) {
      return;
    }
    _nearEndPreloadRefreshGeneration = committedSourceGeneration;
    await _preloadNextTrackUrl(
      _committedIndex,
      minimumRemainingValidity: remaining + _preloadExpirySafetyMargin,
    );
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
    final config = await loadHeAudioHandlerRuntimeConfig(
      dataSource: _configDataSource,
    );
    _apiBaseUrl = config.apiBaseUrl;
    _authToken = config.authToken;
    globalTokenHolder.accessToken ??= config.authToken;
    globalTokenHolder.refreshToken ??= config.refreshToken;
    globalTokenHolder.expiresAt ??= config.tokenExpiresAt;
    _wifiQualityPreference = config.wifiQualityPreference;
    _cellularQualityPreference = config.cellularQualityPreference;
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

  LinkInfo? _resolvePreferredLink(
    List<LinkInfo> links, {
    String? forcedQualityName,
  }) {
    final forced = forcedQualityName?.trim() ?? '';
    if (forced.isNotEmpty) {
      for (final link in links) {
        if (link.name.trim() == forced) {
          return link;
        }
      }
    }
    return selectPreferredAudioQuality(
      links,
      preference: _networkConnectionType == NetworkConnectionType.cellular
          ? _cellularQualityPreference
          : _wifiQualityPreference,
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
      if (_networkConnectionType == NetworkConnectionType.offline) {
        throw const _NetworkUnavailableException();
      }
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
    final dio = _createApiDio();
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

  Duration get _currentPosition {
    final override = _positionOverride;
    return override == null ? _player.position : override(_player);
  }

  Future<void> _seek(Duration position) {
    final override = _seekOverride;
    return override == null
        ? _player.seek(position)
        : override(position, _player);
  }

  Future<void> _pausePlayer() {
    final override = _pauseOverride;
    return override == null ? _player.pause() : override(_player);
  }

  Future<void> _handlePlaybackCompleted(int generation) async {
    if (_shouldStopAfterCurrentForSleepTimer(generation)) {
      _handledCompletionGeneration = generation;
      await _pausePlaybackForSleepTimer();
      return;
    }
    if (_tracks.isEmpty ||
        _singleLoopEnabled ||
        _pendingIndex != null ||
        _desiredIndex != null ||
        _manualSkipTargetActive ||
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

  @visibleForTesting
  void handlePlaybackErrorForTesting(Object error) {
    _broadcastTransitionError(error, _transitionId);
  }

  @visibleForTesting
  Future<void> refreshNextTrackUrlNearEndForTesting(Duration position) {
    return _refreshNextTrackUrlNearEnd(position);
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
      if (_manualSkipTargetActive) {
        _desiredIndex = nextIndex;
        _broadcastManualSkipTarget(
          transitionId: transitionId,
          targetIndex: nextIndex,
        );
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
    if (error is _NetworkUnavailableException ||
        _networkConnectionType == NetworkConnectionType.offline) {
      return _PlaybackFailureCategory.networkUnavailable;
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
    if (category == _PlaybackFailureCategory.networkUnavailable) {
      _rememberCurrentPlaybackRecovery();
    }
    _logTransition(
      'transition.failure',
      transitionId,
      failureCategory: category,
    );
    customEvent.add(<String, dynamic>{
      'type': 'playbackTransitionError',
      'transitionId': transitionId,
      'code': category.name,
      'retryable': category != _PlaybackFailureCategory.trackUnavailable,
    });
  }

  void _clearManualSkipTarget(int transitionId) {
    if (transitionId != _transitionId || !_manualSkipTargetActive) {
      return;
    }
    _cancelManualIntent(clearDesired: true);
  }

  void _broadcastManualSkipTarget({
    required int transitionId,
    required int? targetIndex,
    bool cleared = false,
  }) {
    final target = targetIndex == null ? null : _safeTrack(targetIndex);
    customEvent.add(<String, dynamic>{
      'type': 'manualSkipTarget',
      'transitionId': transitionId,
      'status': cleared ? 'cleared' : 'pending',
      'targetIndex': targetIndex,
      'targetTrackId': target?.id,
      'targetTrackPlatform': target?.platform,
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

  void _logSpectrumFailure(String event, Object error) {
    final message = '$event failure=${error.runtimeType}';
    final override = _logOverride;
    if (override != null) {
      override(message);
      return;
    }
    developer.log(message, name: 'HeAudioHandler');
  }

  void _logSleepTimerFailure(String event, Object error) {
    final message = '$event failure=${error.runtimeType}';
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
      'transitionId': _transitionId,
      'manualSkipTargetActive': _manualSkipTargetActive,
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

  void _broadcastSleepTimerState() {
    customEvent.add(currentSleepTimerState.toCustomEvent());
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
    if (_networkConnectionType == NetworkConnectionType.offline) {
      throw const _NetworkUnavailableException();
    }
    final radioId = _currentRadioId!;
    final radioPlatform = _currentRadioPlatform!;
    final sourcePageIndex = _currentRadioPageIndex!;
    final nextPageIndex = _currentRadioPageIndex! + 1;
    // 熄屏场景下网络容易失败，添加重试机制。
    List<SongInfo> songs = const <SongInfo>[];
    Object? lastError;
    for (var attempt = 1; attempt <= _radioFetchMaxAttempts; attempt += 1) {
      if (_networkConnectionType == NetworkConnectionType.offline) {
        throw const _NetworkUnavailableException();
      }
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
        if (_networkConnectionType == NetworkConnectionType.offline) {
          throw const _NetworkUnavailableException();
        }
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
      size: maxCoverSize,
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
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: connectTimeout ?? const Duration(seconds: 20),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        sendTimeout: sendTimeout ?? const Duration(seconds: 30),
        responseType: ResponseType.json,
        headers: const <String, String>{'User-Agent': heAudioUserAgent},
      ),
    );
    dio.interceptors.add(
      AuthTokenInterceptor(
        () => globalTokenHolder.accessToken ?? _authToken,
        () => '',
      ),
    );
    dio.interceptors.add(
      TokenRefreshInterceptor(
        tokenHolder: globalTokenHolder,
        baseUrl: _apiBaseUrl,
        refreshCoordinator: globalTokenRefreshCoordinator,
        getDeviceInfo: _loadDeviceInfoForRefresh,
        onTokensRefreshed: (accessToken, refreshToken, expiresAt) {
          return _configDataSource.saveTokens(
            accessToken,
            refreshToken,
            expiresAt,
          );
        },
      ),
    );
    return dio;
  }

  Future<Map<String, dynamic>> _loadDeviceInfoForRefresh() async {
    final override = _getDeviceInfoOverride;
    if (override != null) {
      return await override();
    }
    return (await loadDeviceInfoData()).toApiMap();
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
      'format': track.format,
      'bitrate': track.bitrate,
      'sampleRate': track.sampleRate,
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
  networkUnavailable,
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

class _NetworkUnavailableException implements Exception {
  const _NetworkUnavailableException();
}

class _PendingPlaybackRecovery {
  const _PendingPlaybackRecovery({
    required this.transitionId,
    required this.trackKey,
    required this.index,
    required this.position,
  });

  final int transitionId;
  final String trackKey;
  final int index;
  final Duration position;
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

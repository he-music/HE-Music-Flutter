import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../core/audio/audio_handler_player_adapter.dart';
import '../../../../core/audio/audio_player_port.dart';
import '../../../../core/audio/audio_track.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../core/network/network_status_port.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../lyrics_overlay/data/overlay_message.dart';
import '../../../lyrics_overlay/presentation/providers/overlay_lyrics_provider.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../music_library/data/providers/local_library_providers.dart';
import '../../../radio/presentation/providers/radio_providers.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_playback_failure.dart';
import '../../domain/entities/player_playback_state.dart';
import '../../domain/entities/player_quality_option.dart';
import '../../domain/entities/player_queue_source.dart';
import '../../domain/entities/player_track.dart';
import '../providers/player_audio_provider.dart';
import '../providers/player_history_provider.dart';
import '../providers/player_progress_provider.dart';
import '../providers/player_queue_provider.dart';
import '../helpers/player_lyric_highlight_color_helper.dart';
import 'player_controller_callback.dart';
import 'player_history_manager.dart';
import 'player_progress_manager.dart';
import 'player_quality_manager.dart';
import 'player_queue_manager.dart';
import 'player_stream_manager.dart';

class PlayerController extends Notifier<PlayerPlaybackState>
    implements PlayerControllerCallback {
  late AudioPlayerPort _audioPlayer;
  late PlayerHistoryManager _historyManager;
  late PlayerProgressManager _progressManager;
  late PlayerQualityManager _qualityManager;
  late PlayerQueueManager _queueManager;
  late PlayerStreamManager _streamManager;

  bool _initialized = false;
  Future<void>? _initializing;
  int _trackSwitchRequestId = 0;
  int _lyricHighlightColorRequestId = 0;
  int _latestManualSkipTransitionId = -1;
  int _settledManualSkipTransitionId = -1;
  int _playbackSessionTransitionId = 0;
  int? _protectedPlaybackSessionTransitionId;
  int _latestPlaybackFailureTransitionId = -1;
  Future<void>? _retryCurrentPlaybackFuture;

  @override
  PlayerPlaybackState get currentState => state;

  @override
  void updateState(
    PlayerPlaybackState Function(PlayerPlaybackState current) updater,
  ) {
    state = updater(state);
  }

  @override
  PlayerPlaybackState build() {
    _audioPlayer = ref.read(audioPlayerPortProvider);
    if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
      unawaited(
        _syncAudioHandlerConfig(
          adapter,
          ref.read(appConfigProvider),
          syncAutoColor: true,
        ),
      );
      final platforms = ref.read(onlinePlatformsProvider).value;
      if (platforms != null) {
        unawaited(adapter.syncCoverPlatforms(platforms));
      }
    }
    _progressManager = PlayerProgressManager(
      dataSource: ref.read(playerProgressDataSourceProvider),
    );
    _qualityManager = PlayerQualityManager(
      platformsReader: () =>
          ref.read(onlinePlatformsProvider).value ?? const [],
      configReader: () => ref.read(appConfigProvider),
      networkTypeReader: () => globalNetworkStatusPort.lastKnown,
    );
    _queueManager = PlayerQueueManager(
      dataSource: ref.read(playerQueueDataSourceProvider),
      qualityManager: _qualityManager,
      fetchRadioSongs: (id, platform, pageIndex) async {
        return ref
            .read(radioApiClientProvider)
            .fetchSongs(id: id, platform: platform, pageIndex: pageIndex);
      },
    );
    _historyManager = PlayerHistoryManager(
      dataSource: ref.read(playerHistoryDataSourceProvider),
    );
    ref.listen<AppConfigState>(appConfigProvider, (previous, next) {
      if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
        final shouldSyncAutoColor =
            next.enableDesktopLyric &&
            next.lyricHighlightMode == AppLyricHighlightMode.auto &&
            (previous == null ||
                !previous.enableDesktopLyric ||
                previous.lyricHighlightMode != AppLyricHighlightMode.auto);
        unawaited(
          _syncAudioHandlerConfig(
            adapter,
            next,
            syncAutoColor: shouldSyncAutoColor,
          ),
        );
      }
    });
    ref.listen<AsyncValue<List<OnlinePlatform>>>(onlinePlatformsProvider, (
      previous,
      next,
    ) {
      if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
        final platforms = next.value;
        if (platforms != null) {
          unawaited(adapter.syncCoverPlatforms(platforms));
        }
      }
    });
    _streamManager = PlayerStreamManager(
      audioPlayerReader: () => _audioPlayer,
      overlayMessageStreamReader: () =>
          ref.read(overlayLyricsServiceProvider).overlayToMainMessages,
      callbackReader: () => this,
      progressManager: _progressManager,
      onCurrentIndexChanged: _handleCurrentIndexChanged,
      onCustomEvent: _handleCustomEvent,
      onPlaybackCompleted: _handlePlaybackCompleted,
      onPlayingChanged: _handlePlayingChanged,
      onStreamError: _handleStreamError,
      onDurationChanged: _syncCurrentTrackDuration,
      onOverlayMessage: _handleOverlayMessage,
    );
    ref.onDispose(_streamManager.dispose);
    return const PlayerPlaybackState(
      queue: <PlayerTrack>[],
      currentIndex: 0,
      historyCount: 0,
      isPlaying: false,
      isLoading: false,
      isPlaybackSessionActive: false,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: Duration.zero,
      volume: defaultPlayerVolume,
      speed: defaultPlayerSpeed,
      playMode: PlayerPlayMode.sequence,
      currentAvailableQualities: <PlayerQualityOption>[],
      isRadioMode: false,
      previousPlayModeBeforeRadio: null,
    );
  }

  Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }
    final initializing = _initializing;
    if (initializing != null) {
      return initializing;
    }
    final future = _initialize();
    _initializing = future;
    return future;
  }

  Future<void> _initialize() async {
    try {
      _streamManager.bindStreams();
      await _historyManager.hydrateHistoryCount(this);
      await _applyPlayMode(state.playMode);
      final snapshot = await _queueManager.hydrateQueue(this);
      // 恢复本地歌曲封面（重启后 artworkBytes 丢失，从磁盘缓存重新加载）
      if (snapshot != null && state.queue.isNotEmpty) {
        await _restoreLocalArtwork();
        await _syncQueueToAudioPlayer(
          queue: state.queue,
          currentIndex: state.currentIndex,
          autoplay: false,
          restoreProgress: true,
        );
      }
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  void resetHistoryCount() {
    state = state.copyWith(historyCount: 0);
  }

  /// 从磁盘缓存恢复本地歌曲的封面字节数据。
  ///
  /// 本地歌曲的 artworkBytes 无法被 JSON 序列化，重启后丢失。
  /// 此方法从 LocalArtworkExtractor 的磁盘缓存重新加载。
  Future<void> _restoreLocalArtwork() async {
    final extractor = ref.read(localArtworkExtractorProvider);
    final queue = state.queue;
    var changed = false;
    final updated = <PlayerTrack>[];
    for (final track in queue) {
      if (track.platform == 'local' &&
          track.artworkBytes == null &&
          track.path != null &&
          track.path!.isNotEmpty) {
        final bytes = await extractor.getArtworkBytes(track.path!);
        if (bytes != null && bytes.isNotEmpty) {
          updated.add(track.copyWith(artworkBytes: Uint8List.fromList(bytes)));
          changed = true;
          continue;
        }
      }
      updated.add(track);
    }
    if (changed) {
      state = state.copyWith(queue: updated);
    }
  }

  Future<void> replaceQueue(
    List<PlayerTrack> queue, {
    int startIndex = PlayerQueueManager.defaultQueueIndex,
    bool autoplay = true,
    PlayerQueueSource? queueSource,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    _queueManager.validateQueueInput(queue, startIndex);
    await _ensureInitialized();
    if (_queueManager.isSameQueueContext(state, queue, queueSource) &&
        _queueManager.isSameRadioContext(
          state,
          isRadioMode: isRadioMode,
          currentRadioId: currentRadioId,
          currentRadioPlatform: currentRadioPlatform,
          currentRadioPageIndex: currentRadioPageIndex,
        )) {
      await playAt(startIndex);
      return;
    }
    final previousSnapshot = _queueManager.buildCurrentQueueSnapshot(state);
    final nextPlayMode = _queueManager.resolveNextPlayMode(
      state,
      isRadioMode: isRadioMode,
    );
    final nextPreviousPlayModeBeforeRadio = _queueManager
        .resolvePreviousPlayModeBeforeRadio(state, isRadioMode: isRadioMode);
    await _switchCurrentPlaybackContext(
      queue: queue,
      targetIndex: startIndex,
      autoplay: autoplay,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: queue,
              currentIndex: startIndex,
              position: Duration.zero,
              bufferedPosition: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              queueSource: queueSource,
              clearQueueSource: queueSource == null,
              previousQueueSnapshot: previousSnapshot,
              isRadioMode: isRadioMode,
              currentRadioId: isRadioMode
                  ? _queueManager.normalizeRadioValue(currentRadioId)
                  : null,
              clearCurrentRadioId: !isRadioMode,
              currentRadioPlatform: isRadioMode
                  ? _queueManager.normalizeRadioValue(currentRadioPlatform)
                  : null,
              clearCurrentRadioPlatform: !isRadioMode,
              currentRadioPageIndex: isRadioMode
                  ? _queueManager.normalizeRadioPageIndex(currentRadioPageIndex)
                  : null,
              clearCurrentRadioPageIndex: !isRadioMode,
              previousPlayModeBeforeRadio: nextPreviousPlayModeBeforeRadio,
              clearPreviousPlayModeBeforeRadio: !isRadioMode,
              clearError: true,
              clearPlaybackFailure: true,
            );
          },
      applyResolvedState: (TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
      },
    );
  }

  bool get hasPreviousQueue =>
      state.previousQueueSnapshot != null &&
      state.previousQueueSnapshot!.queue.isNotEmpty;

  Future<void> swapToPreviousQueue({
    int? startIndex,
    bool autoplay = true,
  }) async {
    await _ensureInitialized();
    final snapshot = state.previousQueueSnapshot;
    if (snapshot == null || snapshot.queue.isEmpty) {
      return;
    }
    final targetIndex = (startIndex ?? snapshot.currentIndex).clamp(
      0,
      snapshot.queue.length - 1,
    );
    final currentSnapshot = _queueManager.buildCurrentQueueSnapshot(state);
    await _switchCurrentPlaybackContext(
      queue: snapshot.queue,
      targetIndex: targetIndex,
      autoplay: autoplay,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: snapshot.queue,
              currentIndex: targetIndex,
              playMode: snapshot.playMode,
              position: Duration.zero,
              bufferedPosition: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              queueSource: snapshot.source,
              previousQueueSnapshot: currentSnapshot,
              isRadioMode: snapshot.isRadioMode,
              currentRadioId: snapshot.currentRadioId,
              clearCurrentRadioId: snapshot.currentRadioId == null,
              currentRadioPlatform: snapshot.currentRadioPlatform,
              clearCurrentRadioPlatform: snapshot.currentRadioPlatform == null,
              currentRadioPageIndex: snapshot.currentRadioPageIndex,
              clearCurrentRadioPageIndex:
                  snapshot.currentRadioPageIndex == null,
              previousPlayModeBeforeRadio: snapshot.previousPlayModeBeforeRadio,
              clearPreviousPlayModeBeforeRadio:
                  snapshot.previousPlayModeBeforeRadio == null,
              clearError: true,
              clearPlaybackFailure: true,
            );
          },
      applyResolvedState: (TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
      },
    );
  }

  Future<void> togglePlayPause() async {
    await _ensureInitialized();
    if (state.playbackFailure?.retryable == true) {
      await retryCurrentPlayback();
      return;
    }
    if (state.isPlaying) {
      _endPlaybackSession();
      await _execute(() async {
        await _audioPlayer.pause();
        await _progressManager.persistTrackProgress(
          callback: this,
          track: state.currentTrack,
          position: state.position,
          force: true,
        );
      });
      return;
    }
    final currentTrack = state.currentTrack;
    if (currentTrack == null) {
      return;
    }
    state = state.copyWith(isPlaybackSessionActive: true);
    try {
      await _execute(() async {
        await _audioPlayer.play();
        await _historyManager.recordCurrentTrackHistory(
          callback: this,
          track: state.currentTrack,
          isRadioMode: state.isRadioMode,
          currentRadioId: state.currentRadioId,
          currentRadioPlatform: state.currentRadioPlatform,
          currentRadioPageIndex: state.currentRadioPageIndex,
          previousPlayModeBeforeRadio: state.previousPlayModeBeforeRadio,
        );
      });
    } catch (_) {
      _endPlaybackSession();
      rethrow;
    }
  }

  Future<void> retryCurrentPlayback() {
    final active = _retryCurrentPlaybackFuture;
    if (active != null) {
      return active;
    }
    late final Future<void> future;
    future = _retryCurrentPlayback().whenComplete(() {
      if (identical(_retryCurrentPlaybackFuture, future)) {
        _retryCurrentPlaybackFuture = null;
      }
    });
    _retryCurrentPlaybackFuture = future;
    return future;
  }

  Future<void> _retryCurrentPlayback() async {
    await _ensureInitialized();
    final failure = state.playbackFailure;
    final track = state.currentTrack;
    if (failure == null || !failure.retryable || track == null) {
      return;
    }
    final resumePosition = state.position;
    final sessionTransitionId = _beginPlaybackSessionTransition();
    try {
      await _execute(() async {
        if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
          await adapter.retryCurrentPlayback();
        } else {
          await _audioPlayer.setQueue(
            state.queue.map(_toAudioTrack).toList(growable: false),
            initialIndex: state.currentIndex,
            forceReloadCurrent: true,
            isRadioMode: state.isRadioMode,
            currentRadioId: state.currentRadioId,
            currentRadioPlatform: state.currentRadioPlatform,
            currentRadioPageIndex: state.currentRadioPageIndex,
          );
          if (resumePosition > Duration.zero) {
            await _audioPlayer.seek(resumePosition);
          }
          await _audioPlayer.play();
        }
        state = state.copyWith(clearError: true, clearPlaybackFailure: true);
      });
    } catch (_) {
      state = state.copyWith(
        playbackFailure: failure,
        errorMessage: state.errorMessage ?? failure.message,
      );
      _failPlaybackSessionTransition(sessionTransitionId);
      rethrow;
    } finally {
      _finishPlaybackSessionTransition(sessionTransitionId);
    }
  }

  Future<void> playAt(int index) async {
    await _ensureInitialized();
    _queueManager.validateQueueInput(state.queue, index);
    await _switchCurrentPlaybackContext(
      queue: state.queue,
      targetIndex: index,
      autoplay: true,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              currentIndex: index,
              position: Duration.zero,
              bufferedPosition: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              clearError: true,
              clearPlaybackFailure: true,
            );
          },
      applyResolvedState: (TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
      },
    );
  }

  Future<void> playNext() async {
    await _ensureInitialized();
    if (state.queue.isEmpty) {
      return;
    }
    await _audioPlayer.seekToNext();
  }

  Future<void> playPrevious() async {
    await _ensureInitialized();
    if (state.queue.isEmpty) {
      return;
    }
    await _audioPlayer.seekToPrevious();
  }

  Future<void> insertNextAndPlay(PlayerTrack track) async {
    await _ensureInitialized();
    final currentQueue = state.queue;
    if (currentQueue.isEmpty) {
      await replaceQueue(<PlayerTrack>[track]);
      return;
    }
    final currentIndex = _queueManager.safeCurrentIndex(
      state,
      currentQueue.length,
    );
    final targetIndex = currentIndex + 1;
    final nextQueue = <PlayerTrack>[...currentQueue];
    nextQueue.insert(targetIndex, track);
    final nextPlayMode = _queueManager.resolveNextPlayMode(
      state,
      isRadioMode: false,
    );
    await _switchCurrentPlaybackContext(
      queue: nextQueue,
      targetIndex: targetIndex,
      autoplay: true,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: nextQueue,
              currentIndex: targetIndex,
              position: Duration.zero,
              bufferedPosition: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              isRadioMode: false,
              clearQueueSource: true,
              clearCurrentRadioId: true,
              clearCurrentRadioPlatform: true,
              clearCurrentRadioPageIndex: true,
              clearPreviousPlayModeBeforeRadio: true,
              clearError: true,
              clearPlaybackFailure: true,
            );
          },
      applyResolvedState: (TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
      },
    );
  }

  Future<void> insertNextTrack(PlayerTrack track) async {
    await _upsertQueueTrack(
      track: track,
      insertNext: true,
      autoplayWhenQueueEmpty: true,
    );
  }

  Future<void> appendTrack(PlayerTrack track) async {
    await _upsertQueueTrack(
      track: track,
      insertNext: false,
      autoplayWhenQueueEmpty: false,
    );
  }

  Future<void> removeTrackAt(int index) async {
    await _ensureInitialized();
    final queue = state.queue;
    if (index < 0 || index >= queue.length) {
      return;
    }
    if (queue.length == 1) {
      await clearQueue();
      return;
    }
    final currentIndex = _queueManager.safeCurrentIndex(state, queue.length);
    final wasPlaying = state.isPlaying;
    final nextQueue = <PlayerTrack>[...queue]..removeAt(index);
    if (index != currentIndex) {
      final nextCurrentIndex = index < currentIndex
          ? currentIndex - 1
          : currentIndex;
      state = state.copyWith(
        queue: nextQueue,
        currentIndex: nextCurrentIndex,
        playMode: _queueManager.resolveNextPlayMode(state, isRadioMode: false),
        isRadioMode: false,
        clearQueueSource: true,
        clearCurrentRadioId: true,
        clearCurrentRadioPlatform: true,
        clearCurrentRadioPageIndex: true,
        clearPreviousPlayModeBeforeRadio: true,
        clearError: true,
      );
      await _execute(() async {
        _streamManager.suppressNextCurrentIndexEvent(nextCurrentIndex);
        await _audioPlayer.setQueue(
          nextQueue.map(_toAudioTrack).toList(growable: false),
          initialIndex: nextCurrentIndex,
          forceReloadCurrent: false,
        );
        await _applyPlayMode(state.playMode);
      });
      await _queueManager.persistQueueState(this);
      return;
    }
    final targetIndex = index >= nextQueue.length
        ? nextQueue.length - 1
        : index;
    final nextPlayMode = _queueManager.resolveNextPlayMode(
      state,
      isRadioMode: false,
    );
    await _switchCurrentPlaybackContext(
      queue: nextQueue,
      targetIndex: targetIndex,
      autoplay: wasPlaying,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: nextQueue,
              currentIndex: targetIndex,
              position: Duration.zero,
              bufferedPosition: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              clearQueueSource: true,
              clearPreviousPlayModeBeforeRadio: true,
              clearError: true,
              clearPlaybackFailure: true,
            );
          },
      applyResolvedState: (TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          isRadioMode: false,
          clearCurrentRadioId: true,
          clearCurrentRadioPlatform: true,
          clearCurrentRadioPageIndex: true,
          clearError: true,
        );
      },
    );
  }

  Future<void> clearQueue() async {
    await _ensureInitialized();
    _endPlaybackSession();
    await _progressManager.persistTrackProgress(
      callback: this,
      track: state.currentTrack,
      position: state.position,
      force: true,
    );
    await _execute(() async {
      await _audioPlayer.stop();
      state = state.copyWith(
        queue: const <PlayerTrack>[],
        currentIndex: 0,
        isPlaying: false,
        isLoading: false,
        isPlaybackSessionActive: false,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: Duration.zero,
        currentAvailableQualities: const <PlayerQualityOption>[],
        isRadioMode: false,
        playMode: _queueManager.resolveNextPlayMode(state, isRadioMode: false),
        clearQueueSource: true,
        clearCurrentSelectedQuality: true,
        clearCurrentRadioId: true,
        clearCurrentRadioPlatform: true,
        clearCurrentRadioPageIndex: true,
        clearPreviousPlayModeBeforeRadio: true,
        clearError: true,
        clearPlaybackFailure: true,
      );
    });
    await _queueManager.persistQueueState(this);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _ensureInitialized();
    final queue = state.queue;
    if (oldIndex < 0 ||
        oldIndex >= queue.length ||
        newIndex < 0 ||
        newIndex > queue.length ||
        oldIndex == newIndex) {
      return;
    }
    final normalizedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    if (oldIndex == normalizedNewIndex) {
      return;
    }
    final currentTrack = state.currentTrack;
    final currentTrackKey = currentTrack == null
        ? null
        : _queueManager.trackKey(currentTrack);
    final nextQueue = <PlayerTrack>[...queue];
    final moved = nextQueue.removeAt(oldIndex);
    nextQueue.insert(normalizedNewIndex, moved);
    final nextCurrentIndex = currentTrackKey == null
        ? PlayerQueueManager.defaultQueueIndex
        : nextQueue.indexWhere(
            (track) => _queueManager.trackKey(track) == currentTrackKey,
          );
    state = state.copyWith(
      queue: nextQueue,
      currentIndex: nextCurrentIndex < 0
          ? PlayerQueueManager.defaultQueueIndex
          : nextCurrentIndex,
      playMode: _queueManager.resolveNextPlayMode(state, isRadioMode: false),
      isRadioMode: false,
      clearQueueSource: true,
      clearCurrentRadioId: true,
      clearCurrentRadioPlatform: true,
      clearCurrentRadioPageIndex: true,
      clearPreviousPlayModeBeforeRadio: true,
      clearError: true,
    );
    await _execute(() async {
      _streamManager.suppressNextCurrentIndexEvent(
        nextCurrentIndex < 0
            ? PlayerQueueManager.defaultQueueIndex
            : nextCurrentIndex,
      );
      await _audioPlayer.setQueue(
        nextQueue.map(_toAudioTrack).toList(growable: false),
        initialIndex: nextCurrentIndex < 0
            ? PlayerQueueManager.defaultQueueIndex
            : nextCurrentIndex,
        forceReloadCurrent: false,
      );
      await _applyPlayMode(state.playMode);
    });
    await _queueManager.persistQueueState(this);
  }

  Future<void> seek(Duration position) async {
    await _ensureInitialized();
    await _execute(() => _audioPlayer.seek(position));
  }

  Future<void> setVolume(double volume) async {
    await _ensureInitialized();
    state = state.copyWith(volume: volume, clearError: true);
    await _execute(() => _audioPlayer.setVolume(volume));
  }

  Future<void> setSpeed(double speed) async {
    await _ensureInitialized();
    state = state.copyWith(speed: speed, clearError: true);
    await _execute(() => _audioPlayer.setSpeed(speed));
  }

  Future<void> cyclePlayMode() async {
    await _ensureInitialized();
    if (state.isRadioMode) {
      return;
    }
    final nextMode = switch (state.playMode) {
      PlayerPlayMode.sequence => PlayerPlayMode.shuffle,
      PlayerPlayMode.shuffle => PlayerPlayMode.single,
      PlayerPlayMode.single => PlayerPlayMode.sequence,
    };
    await setPlayMode(nextMode);
  }

  Future<void> setPlayMode(PlayerPlayMode mode) async {
    await _ensureInitialized();
    if (state.isRadioMode) {
      return;
    }
    state = state.copyWith(playMode: mode, clearError: true);
    await _execute(() => _applyPlayMode(mode));
    await _queueManager.persistQueueState(this);
  }

  Future<void> switchCurrentQualityByName(String qualityName) async {
    await _ensureInitialized();
    final track = state.currentTrack;
    final normalized = qualityName.trim();
    if (track == null || normalized.isEmpty) {
      return;
    }
    final matchedOption = _qualityManager.findQualityOptionByName(
      state.currentAvailableQualities,
      normalized,
    );
    if (matchedOption == null) {
      return;
    }
    final index = _queueManager.safeCurrentIndex(state, state.queue.length);
    final wasPlaying = state.isPlaying;
    final resumePosition = state.position;
    await _progressManager.persistTrackProgress(
      callback: this,
      track: track,
      position: resumePosition,
      force: true,
    );
    final sessionTransitionId = state.isPlaybackSessionActive
        ? _beginPlaybackSessionTransition()
        : null;
    state = state.copyWith(
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      currentSelectedQualityName: matchedOption.name,
      clearError: true,
    );
    final requestId = _beginTrackSwitchRequest();
    try {
      await _execute(() async {
        _guardTrackSwitchRequest(requestId);
        final resolution = await _qualityManager.resolveTrackForPlayback(
          state.queue,
          index,
          forcedQualityName: matchedOption.name,
        );
        _guardTrackSwitchRequest(requestId);
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
        ref
            .read(appConfigProvider.notifier)
            .setLastSelectedOnlineAudioQualityName(matchedOption.name);
        await _syncAudioHandlerConfigFromState();
        _guardTrackSwitchRequest(requestId);
        await _queueManager.persistQueueState(this);
        _guardTrackSwitchRequest(requestId);
        await _audioPlayer.setSource(
          _toAudioTrack(resolution.track),
          forcedQualityName: matchedOption.name,
        );
        _guardTrackSwitchRequest(requestId);
        state = state.copyWith(clearPlaybackFailure: true);
        if (resumePosition > Duration.zero) {
          await _audioPlayer.seek(resumePosition);
          state = state.copyWith(position: resumePosition, clearError: true);
        }
        if (wasPlaying) {
          await _audioPlayer.play();
        }
      }, trackSwitchRequestId: requestId);
    } catch (_) {
      if (sessionTransitionId != null) {
        _failPlaybackSessionTransition(sessionTransitionId);
      }
      rethrow;
    } finally {
      if (sessionTransitionId != null) {
        _finishPlaybackSessionTransition(sessionTransitionId);
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await initialize();
  }

  Future<void> _interruptPlaybackForTrackSwitch() async {
    await _execute(() async {
      await _audioPlayer.stop();
      state = state.copyWith(
        isPlaying: false,
        isLoading: false,
        bufferedPosition: Duration.zero,
        clearError: true,
      );
    });
  }

  Future<void> _execute(
    Future<void> Function() action, {
    int? trackSwitchRequestId,
  }) async {
    try {
      state = state.copyWith(clearError: true);
      await action();
    } on _StaleTrackSwitchException {
      return;
    } catch (error) {
      if (trackSwitchRequestId != null &&
          trackSwitchRequestId != _trackSwitchRequestId) {
        return;
      }
      state = state.copyWith(errorMessage: _userFacingPlaybackError(error));
      rethrow;
    }
  }

  Future<TrackPlaybackResolution?> _reloadQueueAt({
    required List<PlayerTrack> queue,
    required int index,
    required bool autoplay,
    required PlayerPlaybackState playbackContext,
    required int requestId,
    required bool forceReloadCurrent,
    String? forcedQualityName,
  }) async {
    TrackPlaybackResolution? result;
    await _execute(() async {
      _guardTrackSwitchRequest(requestId);
      final resolution = await _qualityManager.resolveTrackForPlayback(
        queue,
        index,
        forcedQualityName: forcedQualityName,
      );
      _guardTrackSwitchRequest(requestId);
      await _syncQueueToAudioPlayer(
        queue: resolution.updatedQueue,
        currentIndex: index,
        autoplay: autoplay,
        restoreProgress: false,
        playbackContext: playbackContext,
        forceReloadCurrent: forceReloadCurrent,
      );
      _guardTrackSwitchRequest(requestId);
      result = resolution;
    }, trackSwitchRequestId: requestId);
    return result;
  }

  Future<void> _switchCurrentPlaybackContext({
    required List<PlayerTrack> queue,
    required int targetIndex,
    required bool autoplay,
    required PlayerPlaybackState Function({
      required List<PlayerQualityOption> availableQualities,
      required String? selectedQualityName,
    })
    buildState,
    required void Function(TrackPlaybackResolution resolution)
    applyResolvedState,
  }) async {
    final sessionTransitionId = autoplay
        ? _beginPlaybackSessionTransition()
        : null;
    final requestId = _beginTrackSwitchRequest();
    final previousState = state;
    if (!autoplay) {
      _endPlaybackSession();
    }
    try {
      await _progressManager.persistTrackProgress(
        callback: this,
        track: state.currentTrack,
        position: state.position,
        force: true,
      );
      await _interruptPlaybackForTrackSwitch();
      final currentTrack = queue[targetIndex];
      final forceReloadCurrent =
          state.currentTrack != null &&
          _queueManager.trackKey(state.currentTrack!) ==
              _queueManager.trackKey(currentTrack);
      final availableQualities = _qualityManager.resolveAvailableQualities(
        currentTrack,
      );
      final selectedQualityName = _qualityManager.resolveSelectedQualityName(
        availableQualities: availableQualities,
      );
      final playbackContext = buildState(
        availableQualities: availableQualities,
        selectedQualityName: selectedQualityName,
      );
      if (autoplay) {
        // 播放器正式索引仍指向已加载歌曲；展示索引先指向用户刚点击的目标。
        // 音源加载失败时会按 requestId 回滚，避免把未成功的歌曲当成当前歌曲。
        state = playbackContext.copyWith(
          currentIndex: state.currentIndex,
          isPlaying: state.isPlaying,
          isLoading: state.isLoading,
          isPlaybackSessionActive: state.isPlaybackSessionActive,
          position: state.position,
          duration: state.duration,
          bufferedPosition: state.bufferedPosition,
          requestedTrackIndex: targetIndex,
          requestedTransitionId: requestId,
        );
      }
      _streamManager.markFreshPositionPending();
      final resolution = await _reloadQueueAt(
        queue: queue,
        index: targetIndex,
        autoplay: autoplay,
        playbackContext: playbackContext,
        requestId: requestId,
        forceReloadCurrent: forceReloadCurrent,
      );
      if (resolution == null) {
        return;
      }
      final liveState = state;
      final committedState = buildState(
        availableQualities: availableQualities,
        selectedQualityName: selectedQualityName,
      );
      _settleManualSkipTransition(liveState.requestedTransitionId);
      // 装载期间播放流可能已更新，提交业务上下文时不能用旧快照覆盖。
      state = committedState.copyWith(
        isPlaying: liveState.isPlaying,
        isLoading: liveState.isLoading,
        isPlaybackSessionActive: liveState.isPlaybackSessionActive,
        position: liveState.position,
        duration: liveState.duration,
        bufferedPosition: liveState.bufferedPosition,
        clearRequestedTrackIndex: true,
        clearRequestedTransitionId: true,
      );
      applyResolvedState(resolution);
      unawaited(_syncAutoLyricHighlightColor());
      await _queueManager.persistQueueState(this);
    } catch (_) {
      if (autoplay &&
          requestId == _trackSwitchRequestId &&
          state.requestedTransitionId == requestId) {
        final liveState = state;
        state = previousState.copyWith(
          isPlaying: liveState.isPlaying,
          isLoading: liveState.isLoading,
          isPlaybackSessionActive: liveState.isPlaybackSessionActive,
          position: liveState.position,
          duration: liveState.duration,
          bufferedPosition: liveState.bufferedPosition,
          errorMessage: liveState.errorMessage,
          clearRequestedTrackIndex: true,
          clearRequestedTransitionId: true,
        );
      }
      if (sessionTransitionId != null) {
        _failPlaybackSessionTransition(sessionTransitionId);
      }
      rethrow;
    } finally {
      if (sessionTransitionId != null) {
        _finishPlaybackSessionTransition(sessionTransitionId);
      }
    }
  }

  void _handlePlayingChanged(bool isPlaying) {
    final preservesPlaybackSession =
        _protectedPlaybackSessionTransitionId != null ||
        state.requestedTransitionId != null;
    state = state.copyWith(
      isPlaying: isPlaying,
      isPlaybackSessionActive:
          isPlaying ||
          (state.isPlaybackSessionActive && preservesPlaybackSession),
    );
  }

  // 保护 token 只跨越业务发起的播放过渡，不改写底层 playing 流真值。
  int _beginPlaybackSessionTransition() {
    final transitionId = ++_playbackSessionTransitionId;
    _protectedPlaybackSessionTransitionId = transitionId;
    state = state.copyWith(isPlaybackSessionActive: true);
    return transitionId;
  }

  void _finishPlaybackSessionTransition(int transitionId) {
    if (_protectedPlaybackSessionTransitionId == transitionId) {
      _protectedPlaybackSessionTransitionId = null;
    }
  }

  void _failPlaybackSessionTransition(int transitionId) {
    if (_protectedPlaybackSessionTransitionId != transitionId) {
      return;
    }
    _protectedPlaybackSessionTransitionId = null;
    state = state.copyWith(isPlaybackSessionActive: false);
  }

  void _endPlaybackSession() {
    _protectedPlaybackSessionTransitionId = null;
    state = state.copyWith(isPlaybackSessionActive: false);
  }

  int _beginTrackSwitchRequest() {
    _trackSwitchRequestId += 1;
    return _trackSwitchRequestId;
  }

  void _guardTrackSwitchRequest(int requestId) {
    if (requestId != _trackSwitchRequestId) {
      throw const _StaleTrackSwitchException();
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    state = state.copyWith(errorMessage: _userFacingPlaybackError(error));
  }

  /// 处理 overlay 悬浮窗发回主进程的消息。
  /// overlay 关闭/锁定状态变更时同步更新 Riverpod 配置状态。
  void _handleOverlayMessage(OverlayMessage msg) {
    final notifier = ref.read(appConfigProvider.notifier);
    switch (msg) {
      case OverlayCloseMessage():
        notifier.setEnableDesktopLyric(false);
      case OverlayLockStateMessage(:final locked):
        notifier.setEnableDesktopLyricLock(locked);
      default:
        break;
    }
  }

  void _syncCurrentTrackDuration(Duration duration) {
    final queue = state.queue;
    if (queue.isEmpty) {
      return;
    }
    final index = _queueManager.safeCurrentIndex(state, queue.length);
    final current = queue[index];
    if (current.duration == duration) {
      return;
    }
    final nextQueue = <PlayerTrack>[...queue];
    nextQueue[index] = current.copyWith(duration: duration);
    state = state.copyWith(queue: nextQueue);
    unawaited(_queueManager.persistQueueState(this));
  }

  AudioTrack _toAudioTrack(PlayerTrack track) {
    return AudioTrack(
      id: track.id,
      title: track.title,
      duration: track.duration,
      links: track.links,
      artist: track.artist,
      album: track.album,
      url: track.url,
      path: track.path,
      artworkUrl: track.artworkUrl,
      platform: track.platform,
      format: track.format,
      bitrate: track.bitrate,
      sampleRate: track.sampleRate,
    );
  }

  void _handleCustomEvent(dynamic event) {
    if (event is! Map) {
      return;
    }
    final type = '${event['type'] ?? ''}'.trim();
    if (type == 'playbackTransitionError') {
      final transitionId = event['transitionId'];
      final code = '${event['code'] ?? ''}'.trim();
      final retryable = event['retryable'];
      if (transitionId is! int ||
          transitionId < 0 ||
          transitionId < _latestPlaybackFailureTransitionId ||
          code.isEmpty ||
          retryable is! bool) {
        return;
      }
      _latestPlaybackFailureTransitionId = transitionId;
      final message = _playbackFailureMessage(code);
      _endPlaybackSession();
      state = state.copyWith(
        errorMessage: message,
        playbackFailure: PlayerPlaybackFailure(
          transitionId: transitionId,
          code: code,
          retryable: retryable,
          message: message,
        ),
      );
      return;
    }
    if (type == 'playbackTransitionRecovered') {
      final transitionId = event['transitionId'];
      if (transitionId is int &&
          transitionId == state.playbackFailure?.transitionId) {
        state = state.copyWith(clearError: true, clearPlaybackFailure: true);
      }
      return;
    }
    if (type == 'manualSkipTarget') {
      _handleManualSkipTarget(event);
      return;
    }
    if (type != 'queueState') {
      return;
    }
    final tracksRaw = event['tracks'];
    if (tracksRaw is! List) {
      return;
    }
    final existingById = <String, PlayerTrack>{
      for (final t in state.queue) t.id: t,
    };
    final queue = tracksRaw
        .map((item) {
          final incoming = _playerTrackFromEventMap(_asMap(item));
          final existing = existingById[incoming.id];
          if (existing == null) return incoming;
          return incoming.copyWith(
            albumId: incoming.albumId ?? existing.albumId,
            artists: incoming.artists.isEmpty
                ? existing.artists
                : incoming.artists,
            mvId: incoming.mvId ?? existing.mvId,
            artworkBytes: incoming.artworkBytes ?? existing.artworkBytes,
          );
        })
        .toList(growable: false);
    final currentIndex = event['currentIndex'] is int
        ? event['currentIndex'] as int
        : state.currentIndex;
    final currentTrack =
        queue.isNotEmpty && currentIndex >= 0 && currentIndex < queue.length
        ? queue[currentIndex]
        : null;
    final previousTrack = state.currentTrack;
    final changedTrack =
        currentTrack == null ||
        previousTrack == null ||
        _queueManager.trackKey(currentTrack) !=
            _queueManager.trackKey(previousTrack);
    final availableQualities = currentTrack == null
        ? const <PlayerQualityOption>[]
        : _qualityManager.resolveAvailableQualities(currentTrack);
    final selectedQualityName = currentTrack == null
        ? null
        : _qualityManager.resolveSelectedQualityName(
            availableQualities: availableQualities,
          );
    final transitionId = event['transitionId'] is int
        ? event['transitionId'] as int
        : null;
    final manualSkipTargetActive = event['manualSkipTargetActive'] == true;
    final pendingTrack = state.requestedTrack;
    if (pendingTrack != null && !manualSkipTargetActive) {
      final pendingTrackKey = _queueManager.trackKey(pendingTrack);
      final incomingTrackKey = currentTrack == null
          ? null
          : _queueManager.trackKey(currentTrack);
      // 旧音源的预加载可能晚到；不能用旧 queueState 覆盖最新点击目标。
      if (queue.isNotEmpty &&
          incomingTrackKey != null &&
          incomingTrackKey != pendingTrackKey) {
        return;
      }
    }
    if (queue.isEmpty) {
      _endPlaybackSession();
    }
    if (!manualSkipTargetActive && transitionId != null && transitionId >= 0) {
      if (transitionId > _latestManualSkipTransitionId) {
        _latestManualSkipTransitionId = transitionId;
      }
      if (transitionId > _settledManualSkipTransitionId) {
        _settledManualSkipTransitionId = transitionId;
      }
    }
    state = state.copyWith(
      queue: queue,
      currentIndex: queue.isEmpty ? 0 : currentIndex.clamp(0, queue.length - 1),
      bufferedPosition: changedTrack ? Duration.zero : state.bufferedPosition,
      isPlaybackSessionActive: state.isPlaybackSessionActive,
      previousPreviewIndex: _previewIndexFromEvent(
        event['previousPreviewIndex'],
        queue.length,
      ),
      clearPreviousPreviewIndex: event['previousPreviewIndex'] == null,
      nextPreviewIndex: _previewIndexFromEvent(
        event['nextPreviewIndex'],
        queue.length,
      ),
      clearNextPreviewIndex: event['nextPreviewIndex'] == null,
      currentAvailableQualities: availableQualities,
      currentSelectedQualityName: selectedQualityName,
      isRadioMode: event['isRadioMode'] == true,
      currentRadioId: _nullableStringFromEvent(event['currentRadioId']),
      clearCurrentRadioId: event['currentRadioId'] == null,
      currentRadioPlatform: _nullableStringFromEvent(
        event['currentRadioPlatform'],
      ),
      clearCurrentRadioPlatform: event['currentRadioPlatform'] == null,
      currentRadioPageIndex: event['currentRadioPageIndex'] is int
          ? event['currentRadioPageIndex'] as int
          : null,
      clearCurrentRadioPageIndex: event['currentRadioPageIndex'] == null,
      clearRequestedTrackIndex: !manualSkipTargetActive,
      clearRequestedTransitionId: !manualSkipTargetActive,
      clearError: true,
      clearPlaybackFailure: changedTrack,
    );
  }

  String _playbackFailureMessage(String code) {
    final config = ref.read(appConfigProvider);
    return switch (code) {
      'networkUnavailable' => AppI18n.t(
        config,
        'player.playback.error.network_unavailable',
      ),
      'trackUnavailable' => AppI18n.t(
        config,
        'player.playback.error.track_unavailable',
      ),
      _ => AppI18n.t(config, 'player.playback.error.retryable'),
    };
  }

  void _handleManualSkipTarget(Map<dynamic, dynamic> event) {
    final transitionId = event['transitionId'];
    if (transitionId is! int ||
        transitionId < 0 ||
        transitionId < _latestManualSkipTransitionId ||
        transitionId <= _settledManualSkipTransitionId) {
      return;
    }
    final status = event['status'];
    if (status == 'cleared') {
      _latestManualSkipTransitionId = transitionId;
      _settledManualSkipTransitionId = transitionId;
      state = state.copyWith(
        clearRequestedTrackIndex: true,
        clearRequestedTransitionId: true,
      );
      return;
    }
    if (status != 'pending') {
      return;
    }
    final targetIndex = event['targetIndex'];
    if (targetIndex == null) {
      if (event['targetTrackId'] != null ||
          event['targetTrackPlatform'] != null) {
        return;
      }
      _latestManualSkipTransitionId = transitionId;
      state = state.copyWith(
        isPlaybackSessionActive: true,
        requestedTransitionId: transitionId,
        clearRequestedTrackIndex: true,
      );
      return;
    }
    if (targetIndex is! int ||
        targetIndex < 0 ||
        targetIndex >= state.queue.length) {
      return;
    }
    final target = state.queue[targetIndex];
    final targetTrackId = event['targetTrackId'];
    final targetTrackPlatform = event['targetTrackPlatform'];
    if (targetTrackId is! String ||
        targetTrackId.trim() != target.id.trim() ||
        (targetTrackPlatform is String ? targetTrackPlatform.trim() : '') !=
            (target.platform?.trim() ?? '')) {
      return;
    }
    _latestManualSkipTransitionId = transitionId;
    state = state.copyWith(
      isPlaybackSessionActive: true,
      requestedTrackIndex: targetIndex,
      requestedTransitionId: transitionId,
    );
  }

  void _settleManualSkipTransition(int? transitionId) {
    if (transitionId == null) {
      return;
    }
    if (transitionId > _latestManualSkipTransitionId) {
      _latestManualSkipTransitionId = transitionId;
    }
    if (transitionId > _settledManualSkipTransitionId) {
      _settledManualSkipTransitionId = transitionId;
    }
  }

  int? _previewIndexFromEvent(dynamic value, int queueLength) {
    if (value is! int || value < 0 || value >= queueLength) {
      return null;
    }
    return value;
  }

  Future<void> _syncAudioHandlerConfigFromState() async {
    if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
      await _syncAudioHandlerConfig(
        adapter,
        ref.read(appConfigProvider),
        syncAutoColor: true,
      );
    }
  }

  Future<void> _syncAudioHandlerConfig(
    AudioHandlerPlayerAdapter adapter,
    AppConfigState config, {
    bool syncAutoColor = false,
  }) async {
    await adapter.syncConfig(config);
    if (syncAutoColor) {
      await _syncAutoLyricHighlightColor();
    }
  }

  Future<void> _syncAutoLyricHighlightColor() async {
    final requestId = ++_lyricHighlightColorRequestId;
    final config = ref.read(appConfigProvider);
    final track = state.currentTrack;
    if (!config.enableDesktopLyric ||
        config.lyricHighlightMode != AppLyricHighlightMode.auto ||
        track == null ||
        _audioPlayer is! AudioHandlerPlayerAdapter) {
      return;
    }
    final color = await loadPlayerLyricHighlightColor(
      artworkUrl: track.artworkUrl,
      artworkBytes: track.artworkBytes,
    );
    if (requestId != _lyricHighlightColorRequestId) {
      return;
    }
    final adapter = _audioPlayer as AudioHandlerPlayerAdapter;
    await adapter.syncAutoLyricHighlightColor(
      trackId: track.id,
      platform: track.platform,
      colorValue: color?.toARGB32(),
    );
  }

  Future<void> _applyPlayMode(PlayerPlayMode mode) async {
    if (mode == PlayerPlayMode.single) {
      await _audioPlayer.setSingleLoop(true);
      await _audioPlayer.setShuffle(false);
      return;
    }
    await _audioPlayer.setSingleLoop(false);
    await _audioPlayer.setShuffle(mode == PlayerPlayMode.shuffle);
  }

  Future<void> _syncQueueToAudioPlayer({
    required List<PlayerTrack> queue,
    required int currentIndex,
    required bool autoplay,
    required bool restoreProgress,
    bool forceReloadCurrent = true,
    PlayerPlaybackState? playbackContext,
  }) async {
    final context = playbackContext ?? state;
    _streamManager.suppressNextCurrentIndexEvent(currentIndex);
    await _audioPlayer.setQueue(
      queue.map(_toAudioTrack).toList(growable: false),
      initialIndex: currentIndex,
      forceReloadCurrent: forceReloadCurrent,
      isRadioMode: context.isRadioMode,
      currentRadioId: context.currentRadioId,
      currentRadioPlatform: context.currentRadioPlatform,
      currentRadioPageIndex: context.currentRadioPageIndex,
    );
    await _applyPlayMode(context.playMode);
    if (restoreProgress) {
      final track = _queueManager.resolveTrack(queue, currentIndex);
      if (track != null) {
        final restoredPosition = await _progressManager.restoreTrackProgress(
          callback: this,
          track: track,
          currentDuration: context.duration,
        );
        if (restoredPosition != null) {
          await _audioPlayer.seek(restoredPosition);
          state = state.copyWith(position: restoredPosition, clearError: true);
        }
      }
    }
    if (autoplay) {
      await _audioPlayer.play();
      await _historyManager.recordCurrentTrackHistory(
        callback: this,
        track: _queueManager.resolveTrack(queue, currentIndex),
        isRadioMode: context.isRadioMode,
        currentRadioId: context.currentRadioId,
        currentRadioPlatform: context.currentRadioPlatform,
        currentRadioPageIndex: context.currentRadioPageIndex,
        previousPlayModeBeforeRadio: context.previousPlayModeBeforeRadio,
      );
    }
  }

  Future<void> _handleCurrentIndexChanged(int? nextIndex) async {
    if (nextIndex == null) {
      return;
    }
    if (_streamManager.checkAndClearSuppressedIndex(nextIndex)) {
      return;
    }
    if (state.queue.isEmpty) {
      return;
    }
    final safeIndex = nextIndex.clamp(0, state.queue.length - 1);
    final previousTrack = state.currentTrack;
    final previousTrackKey = previousTrack == null
        ? null
        : _queueManager.trackKey(previousTrack);
    final previousPosition = state.position;
    final previousDuration = state.duration;
    final track = _queueManager.resolveTrack(state.queue, safeIndex);
    if (track == null) {
      return;
    }
    final nextTrackKey = _queueManager.trackKey(track);
    if (previousTrackKey != null && previousTrackKey != nextTrackKey) {
      await _progressManager.persistTrackProgress(
        callback: this,
        track: previousTrack,
        position: previousPosition,
        durationOverride: previousDuration,
        force: true,
      );
    }
    final availableQualities = _qualityManager.resolveAvailableQualities(track);
    final selectedQualityName = _qualityManager.resolveSelectedQualityName(
      availableQualities: availableQualities,
    );
    _settleManualSkipTransition(state.requestedTransitionId);
    state = state.copyWith(
      currentIndex: safeIndex,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      currentAvailableQualities: availableQualities,
      currentSelectedQualityName: selectedQualityName,
      clearRequestedTrackIndex: true,
      clearRequestedTransitionId: true,
      clearError: true,
      clearPlaybackFailure: true,
    );
    unawaited(_syncAutoLyricHighlightColor());
    _streamManager.markFreshPositionPending();
    await _queueManager.persistQueueState(this);
    await _historyManager.recordCurrentTrackHistory(
      callback: this,
      track: track,
      isRadioMode: state.isRadioMode,
      currentRadioId: state.currentRadioId,
      currentRadioPlatform: state.currentRadioPlatform,
      currentRadioPageIndex: state.currentRadioPageIndex,
      previousPlayModeBeforeRadio: state.previousPlayModeBeforeRadio,
    );
  }

  String _userFacingPlaybackError(Object error) {
    final resolved = NetworkErrorMessage.resolve(error)?.trim() ?? '';
    if (resolved.isEmpty) {
      return '播放失败，请稍后重试';
    }
    final lower = resolved.toLowerCase();
    if (lower.contains('invalid /v1/song/url response') ||
        lower.contains('missing url')) {
      return '播放失败，暂时无法获取歌曲链接';
    }
    if (lower.contains('player track is missing') ||
        lower.contains('player queue cannot be empty') ||
        lower.contains('start index is out of range') ||
        lower.contains('initial index is out of range')) {
      return '播放失败，请稍后重试';
    }
    if (lower.contains('status code of 404') ||
        lower == '请求的内容不存在' ||
        lower.contains('not found')) {
      return '播放失败，当前资源不存在';
    }
    if (lower.contains('dioexception') ||
        lower.contains('source error') ||
        lower.contains('platformexception') ||
        lower.contains('failed to load') ||
        lower.contains('exception')) {
      return '播放失败，请稍后重试';
    }
    return resolved;
  }

  PlayerTrack _playerTrackFromEventMap(Map<String, dynamic> raw) {
    final durationMs = raw['durationMs'] as int?;
    final linksRaw = raw['links'];
    return PlayerTrack(
      id: '${raw['id'] ?? ''}',
      title: '${raw['title'] ?? ''}',
      url: '${raw['url'] ?? ''}',
      path: _nullableStringFromEvent(raw['path']),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      links: linksRaw is List
          ? linksRaw
                .map((item) => LinkInfo.fromMap(_asMap(item)))
                .toList(growable: false)
          : const <LinkInfo>[],
      artist: _nullableStringFromEvent(raw['artist']),
      album: _nullableStringFromEvent(raw['album']),
      artworkUrl: _nullableStringFromEvent(raw['artworkUrl']),
      platform: _nullableStringFromEvent(raw['platform']),
      format: _nullableStringFromEvent(raw['format']),
      bitrate: raw['bitrate'] as int?,
      sampleRate: raw['sampleRate'] as int?,
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

  String? _nullableStringFromEvent(dynamic value) {
    if (value == null) {
      return null;
    }
    final normalized = '$value'.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<void> _upsertQueueTrack({
    required PlayerTrack track,
    required bool insertNext,
    required bool autoplayWhenQueueEmpty,
  }) async {
    await _ensureInitialized();
    final currentQueue = state.queue;
    if (currentQueue.isEmpty) {
      await replaceQueue(
        <PlayerTrack>[track],
        startIndex: PlayerQueueManager.defaultQueueIndex,
        autoplay: autoplayWhenQueueEmpty,
      );
      return;
    }
    final currentIndex = _queueManager.safeCurrentIndex(
      state,
      currentQueue.length,
    );
    final nextQueue = <PlayerTrack>[...currentQueue];
    if (insertNext) {
      final targetIndex = (currentIndex + 1).clamp(0, nextQueue.length);
      nextQueue.insert(targetIndex, track);
    } else {
      nextQueue.add(track);
    }
    state = state.copyWith(
      queue: nextQueue,
      currentIndex: currentIndex,
      playMode: _queueManager.resolveNextPlayMode(state, isRadioMode: false),
      isRadioMode: false,
      clearQueueSource: true,
      clearCurrentRadioId: true,
      clearCurrentRadioPlatform: true,
      clearCurrentRadioPageIndex: true,
      clearPreviousPlayModeBeforeRadio: true,
      clearError: true,
    );
    await _execute(() async {
      await _audioPlayer.setQueue(
        nextQueue.map(_toAudioTrack).toList(growable: false),
        initialIndex: currentIndex,
        forceReloadCurrent: false,
      );
      await _applyPlayMode(state.playMode);
    });
    await _queueManager.persistQueueState(this);
  }

  Future<void> playHistoryItem(PlayerHistoryItem item) async {
    await _ensureInitialized();
    final track = _historyManager.historyItemToTrack(item);
    if (!item.isRadioMode) {
      await insertNextAndPlay(track);
      return;
    }
    final radioId = _queueManager.normalizeRadioValue(item.currentRadioId);
    final radioPlatform = _queueManager.normalizeRadioValue(
      item.currentRadioPlatform,
    );
    final radioPageIndex = _queueManager.normalizeRadioPageIndex(
      item.currentRadioPageIndex,
    );
    if (radioId == null || radioPlatform == null || radioPageIndex == null) {
      await insertNextAndPlay(track);
      return;
    }
    final songs = await ref
        .read(radioApiClientProvider)
        .fetchSongs(
          id: radioId,
          platform: radioPlatform,
          pageIndex: radioPageIndex,
        );
    if (songs.isEmpty) {
      await insertNextAndPlay(track);
      return;
    }
    final tracks = songs
        .map(
          (song) => _queueManager.historyItemToTrack(
            PlayerHistoryItem(
              id: song.id,
              title: song.title,
              artist: song.artist,
              album: song.album?.name ?? '',
              albumId: song.album?.id,
              artists: song.artists,
              url: '',
              artworkUrl: '',
              platform: song.platform,
              isRadioMode: false,
              playedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        )
        .toList(growable: false);
    var startIndex = tracks.indexWhere(
      (t) => _queueManager.trackKey(t) == _queueManager.trackKey(track),
    );
    if (startIndex < 0) {
      startIndex = 0;
    }
    await replaceQueue(
      tracks,
      startIndex: startIndex,
      isRadioMode: true,
      currentRadioId: radioId,
      currentRadioPlatform: radioPlatform,
      currentRadioPageIndex: radioPageIndex,
    );
  }

  Future<void> _handlePlaybackCompleted() async {
    if (!state.isRadioMode) {
      return;
    }
    final queue = state.queue;
    if (queue.isEmpty) {
      return;
    }
    final currentIndex = _queueManager.safeCurrentIndex(state, queue.length);
    if (currentIndex != queue.length - 1) {
      return;
    }
    final appended = await _queueManager.ensureRadioNextPageAppended(this);
    if (appended && state.queue.length > currentIndex + 1) {
      await playAt(currentIndex + 1);
    }
  }
}

class _StaleTrackSwitchException implements Exception {
  const _StaleTrackSwitchException();
}

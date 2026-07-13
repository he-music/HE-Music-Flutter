import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../core/audio/audio_handler_player_adapter.dart';
import '../../../../core/audio/audio_player_port.dart';
import '../../../../core/audio/audio_track.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../lyrics_overlay/data/overlay_message.dart';
import '../../../lyrics_overlay/presentation/providers/overlay_lyrics_provider.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../music_library/data/providers/local_library_providers.dart';
import '../../../radio/presentation/providers/radio_providers.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_play_mode.dart';
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
  int _trackSwitchRequestId = 0;
  int _lyricHighlightColorRequestId = 0;

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
      position: Duration.zero,
      duration: Duration.zero,
      volume: defaultPlayerVolume,
      speed: defaultPlayerSpeed,
      playMode: PlayerPlayMode.sequence,
      currentAvailableQualities: <PlayerQualityOption>[],
      isRadioMode: false,
      previousPlayModeBeforeRadio: null,
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
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
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              queueSource: queueSource,
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
              duration: Duration.zero,
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
    if (state.isPlaying) {
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
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              clearError: true,
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
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              clearQueueSource: true,
              clearPreviousPlayModeBeforeRadio: true,
              clearError: true,
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
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              clearQueueSource: true,
              clearPreviousPlayModeBeforeRadio: true,
              clearError: true,
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
        position: Duration.zero,
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
    state = state.copyWith(
      position: Duration.zero,
      duration: Duration.zero,
      currentSelectedQualityName: matchedOption.name,
      clearError: true,
    );
    final requestId = _beginTrackSwitchRequest();
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
      await _audioPlayer.setSource(_toAudioTrack(resolution.track));
      _guardTrackSwitchRequest(requestId);
      if (resumePosition > Duration.zero) {
        await _audioPlayer.seek(resumePosition);
        state = state.copyWith(position: resumePosition, clearError: true);
      }
      if (wasPlaying) {
        await _audioPlayer.play();
      }
    }, trackSwitchRequestId: requestId);
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
    String? forcedQualityName,
  }) async {
    final requestId = _beginTrackSwitchRequest();
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
    await _progressManager.persistTrackProgress(
      callback: this,
      track: state.currentTrack,
      position: state.position,
      force: true,
    );
    await _interruptPlaybackForTrackSwitch();
    final currentTrack = queue[targetIndex];
    final availableQualities = _qualityManager.resolveAvailableQualities(
      currentTrack,
    );
    final selectedQualityName = _qualityManager.resolveSelectedQualityName(
      availableQualities: availableQualities,
    );
    final nextState = buildState(
      availableQualities: availableQualities,
      selectedQualityName: selectedQualityName,
    );
    _streamManager.markFreshPositionPending();
    final resolution = await _reloadQueueAt(
      queue: queue,
      index: targetIndex,
      autoplay: autoplay,
      playbackContext: nextState,
    );
    if (resolution == null) {
      return;
    }
    state = nextState;
    applyResolvedState(resolution);
    unawaited(_syncAutoLyricHighlightColor());
    await _queueManager.persistQueueState(this);
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
    );
  }

  void _handleCustomEvent(dynamic event) {
    if (event is! Map) {
      return;
    }
    final type = '${event['type'] ?? ''}'.trim();
    if (type == 'playbackTransitionError') {
      final code = '${event['code'] ?? ''}'.trim();
      state = state.copyWith(
        errorMessage: code == 'trackUnavailable'
            ? '播放失败，当前歌曲暂无可用音源'
            : '播放失败，请检查网络后重试',
      );
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
    final availableQualities = currentTrack == null
        ? const <PlayerQualityOption>[]
        : _qualityManager.resolveAvailableQualities(currentTrack);
    final selectedQualityName = currentTrack == null
        ? null
        : _qualityManager.resolveSelectedQualityName(
            availableQualities: availableQualities,
          );
    state = state.copyWith(
      queue: queue,
      currentIndex: queue.isEmpty ? 0 : currentIndex.clamp(0, queue.length - 1),
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
      clearError: true,
    );
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
    PlayerPlaybackState? playbackContext,
  }) async {
    final context = playbackContext ?? state;
    _streamManager.suppressNextCurrentIndexEvent(currentIndex);
    await _audioPlayer.setQueue(
      queue.map(_toAudioTrack).toList(growable: false),
      initialIndex: currentIndex,
      forceReloadCurrent: true,
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
    state = state.copyWith(
      currentIndex: safeIndex,
      position: Duration.zero,
      duration: Duration.zero,
      currentAvailableQualities: availableQualities,
      currentSelectedQualityName: selectedQualityName,
      clearError: true,
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

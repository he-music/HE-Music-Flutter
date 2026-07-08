import 'dart:async';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../data/providers/player_queue_providers.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_playback_state.dart';
import '../../domain/entities/player_queue_snapshot.dart';
import '../../domain/entities/player_queue_source.dart';
import '../../domain/entities/player_track.dart';
import 'player_controller_callback.dart';
import 'player_quality_manager.dart';

/// 队列管理器。
///
/// 负责队列操作（增删改查重排）、队列持久化、电台队列逻辑。
/// 通过 [PlayerControllerCallback] 接口与 Controller 交互，
/// 不直接依赖 Riverpod。
class PlayerQueueManager {
  PlayerQueueManager({
    required PlayerQueueDataSource dataSource,
    required PlayerQualityManager qualityManager,
    required FutureOr<dynamic> Function(
      String id,
      String platform,
      int pageIndex,
    )
    fetchRadioSongs,
  }) : _dataSource = dataSource,
       _qualityManager = qualityManager,
       _fetchRadioSongs = fetchRadioSongs;

  final PlayerQueueDataSource _dataSource;
  final PlayerQualityManager _qualityManager;
  final FutureOr<dynamic> Function(String id, String platform, int pageIndex)
  _fetchRadioSongs;

  /// 默认队列索引。
  static const defaultQueueIndex = 0;

  /// 电台队列上限。
  static const radioQueueCap = 1000;

  /// 电台下一页是否正在加载。
  bool isLoadingRadioNextPage = false;

  /// 计算曲目的唯一标识。
  String trackKey(PlayerTrack track) {
    final id = track.id.trim();
    if (id.isEmpty) {
      return '';
    }
    final platform = (track.platform ?? '').trim();
    if (platform == 'local') {
      return id;
    }
    if (platform.isNotEmpty) {
      return '$id|$platform';
    }
    return id;
  }

  /// 安全获取队列中指定索引的曲目。
  PlayerTrack? resolveTrack(List<PlayerTrack> queue, int index) {
    if (index < 0 || index >= queue.length) {
      return null;
    }
    return queue[index];
  }

  /// 安全的 currentIndex 边界校验。
  int safeCurrentIndex(PlayerPlaybackState state, int queueLength) {
    if (queueLength <= 0) {
      return defaultQueueIndex;
    }
    final index = state.currentIndex;
    if (index < 0 || index >= queueLength) {
      return defaultQueueIndex;
    }
    return index;
  }

  /// 队列输入验证。
  void validateQueueInput(List<PlayerTrack> queue, int startIndex) {
    if (queue.isEmpty) {
      throw const AppException(
        ValidationFailure('Player queue cannot be empty.'),
      );
    }
    final maxIndex = queue.length - 1;
    if (startIndex < 0 || startIndex > maxIndex) {
      throw const AppException(
        ValidationFailure('Start index is out of range for the player queue.'),
      );
    }
  }

  /// 构建当前队列快照。
  PlayerQueueSnapshot? buildCurrentQueueSnapshot(PlayerPlaybackState state) {
    final queue = state.queue;
    if (queue.isEmpty) {
      return null;
    }
    return PlayerQueueSnapshot(
      queue: List<PlayerTrack>.unmodifiable(queue),
      currentIndex: safeCurrentIndex(state, queue.length),
      playMode: state.playMode,
      isRadioMode: state.isRadioMode,
      source: state.queueSource,
      previousSnapshot: state.previousQueueSnapshot,
      currentRadioId: state.currentRadioId,
      currentRadioPlatform: state.currentRadioPlatform,
      currentRadioPageIndex: state.currentRadioPageIndex,
      previousPlayModeBeforeRadio: state.previousPlayModeBeforeRadio,
    );
  }

  /// 判断新队列是否与当前队列相同。
  bool isSameQueueContext(
    PlayerPlaybackState state,
    List<PlayerTrack> nextQueue,
    PlayerQueueSource? nextSource,
  ) {
    final currentQueue = state.queue;
    if (currentQueue.length != nextQueue.length) {
      return false;
    }
    if (!_isSameQueueSource(state.queueSource, nextSource)) {
      return false;
    }
    for (var index = 0; index < currentQueue.length; index++) {
      if (trackKey(currentQueue[index]) != trackKey(nextQueue[index])) {
        return false;
      }
    }
    return currentQueue.isNotEmpty;
  }

  /// 判断电台上下文是否相同。
  bool isSameRadioContext(
    PlayerPlaybackState state, {
    required bool isRadioMode,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) {
    if (state.isRadioMode != isRadioMode) {
      return false;
    }
    if (!isRadioMode) {
      return true;
    }
    return state.currentRadioId == normalizeRadioValue(currentRadioId) &&
        state.currentRadioPlatform ==
            normalizeRadioValue(currentRadioPlatform) &&
        state.currentRadioPageIndex ==
            normalizeRadioPageIndex(currentRadioPageIndex);
  }

  /// 根据电台状态决定下一播放模式。
  PlayerPlayMode resolveNextPlayMode(
    PlayerPlaybackState state, {
    required bool isRadioMode,
  }) {
    if (isRadioMode) {
      return PlayerPlayMode.sequence;
    }
    if (state.isRadioMode) {
      return state.previousPlayModeBeforeRadio ?? state.playMode;
    }
    return state.playMode;
  }

  /// 记录进入电台前的播放模式。
  PlayerPlayMode? resolvePreviousPlayModeBeforeRadio(
    PlayerPlaybackState state, {
    required bool isRadioMode,
  }) {
    if (!isRadioMode) {
      return null;
    }
    if (state.isRadioMode) {
      return state.previousPlayModeBeforeRadio;
    }
    return state.playMode;
  }

  /// 归一化电台参数。
  String? normalizeRadioValue(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 归一化电台页码。
  int? normalizeRadioPageIndex(int? pageIndex) {
    if (pageIndex == null || pageIndex <= 0) {
      return null;
    }
    return pageIndex;
  }

  /// 将历史条目转换为 PlayerTrack。
  PlayerTrack historyItemToTrack(PlayerHistoryItem item) {
    final platform = item.platform?.trim() ?? '';
    return PlayerTrack(
      id: item.id,
      title: item.title.isEmpty ? item.id : item.title,
      artist: item.artist,
      album: item.album.isEmpty ? null : item.album,
      albumId: (item.albumId?.trim().isEmpty ?? true) ? null : item.albumId,
      artists: item.artists,
      url: platform == 'local' ? item.url : '',
      artworkUrl: item.artworkUrl.isEmpty ? null : item.artworkUrl,
      platform: platform.isEmpty ? null : platform,
    );
  }

  /// 持久化当前队列快照。
  Future<void> persistQueueState(PlayerControllerCallback callback) async {
    final state = callback.currentState;
    final queue = state.queue;
    final previousSnapshot = state.previousQueueSnapshot;
    final hasPreviousSnapshot =
        previousSnapshot != null && previousSnapshot.queue.isNotEmpty;
    if (queue.isEmpty && !hasPreviousSnapshot) {
      await _dataSource.clearQueue();
      return;
    }
    await _dataSource.saveQueue(
      queue: queue,
      currentIndex: queue.isEmpty ? 0 : safeCurrentIndex(state, queue.length),
      playMode: state.playMode,
      isRadioMode: state.isRadioMode,
      currentRadioId: state.currentRadioId,
      currentRadioPlatform: state.currentRadioPlatform,
      currentRadioPageIndex: state.currentRadioPageIndex,
      previousPlayModeBeforeRadio: state.previousPlayModeBeforeRadio,
      source: state.queueSource,
      previousSnapshot: previousSnapshot,
    );
  }

  /// 从存储恢复队列。
  ///
  /// 成功恢复时返回快照，无数据或异常时返回 null。
  Future<PlayerQueueSnapshot?> hydrateQueue(
    PlayerControllerCallback callback,
  ) async {
    try {
      final snapshot = await _dataSource.readQueue();
      if (snapshot == null) {
        return null;
      }
      if (snapshot.queue.isEmpty) {
        callback.updateState(
          (s) => s.copyWith(
            playMode: snapshot.playMode,
            isRadioMode: snapshot.isRadioMode,
            currentRadioId: snapshot.currentRadioId,
            clearCurrentRadioId: snapshot.currentRadioId == null,
            currentRadioPlatform: snapshot.currentRadioPlatform,
            clearCurrentRadioPlatform: snapshot.currentRadioPlatform == null,
            currentRadioPageIndex: snapshot.currentRadioPageIndex,
            clearCurrentRadioPageIndex: snapshot.currentRadioPageIndex == null,
            previousPlayModeBeforeRadio: snapshot.previousPlayModeBeforeRadio,
            clearPreviousPlayModeBeforeRadio:
                snapshot.previousPlayModeBeforeRadio == null,
            clearQueueSource: true,
            previousQueueSnapshot: snapshot.previousSnapshot,
            clearError: true,
          ),
        );
        return snapshot;
      }
      final currentTrack = snapshot.queue[snapshot.currentIndex];
      final availableQualities = _qualityManager.resolveAvailableQualities(
        currentTrack,
      );
      final selectedQualityName = _qualityManager.resolveSelectedQualityName(
        availableQualities: availableQualities,
      );
      callback.updateState(
        (s) => s.copyWith(
          queue: snapshot.queue,
          currentIndex: snapshot.currentIndex,
          playMode: snapshot.playMode,
          position: Duration.zero,
          duration: Duration.zero,
          currentAvailableQualities: availableQualities,
          currentSelectedQualityName: selectedQualityName,
          queueSource: snapshot.source,
          previousQueueSnapshot: snapshot.previousSnapshot,
          isRadioMode: snapshot.isRadioMode,
          currentRadioId: snapshot.currentRadioId,
          clearCurrentRadioId: snapshot.currentRadioId == null,
          currentRadioPlatform: snapshot.currentRadioPlatform,
          clearCurrentRadioPlatform: snapshot.currentRadioPlatform == null,
          currentRadioPageIndex: snapshot.currentRadioPageIndex,
          clearCurrentRadioPageIndex: snapshot.currentRadioPageIndex == null,
          previousPlayModeBeforeRadio: snapshot.previousPlayModeBeforeRadio,
          clearPreviousPlayModeBeforeRadio:
              snapshot.previousPlayModeBeforeRadio == null,
          clearError: true,
        ),
      );
      final resolution = await _qualityManager.resolveTrackForPlayback(
        snapshot.queue,
        snapshot.currentIndex,
      );
      callback.updateState(
        (s) => s.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        ),
      );
      return snapshot;
    } catch (error) {
      callback.updateState((s) => s.copyWith(errorMessage: '恢复队列失败'));
      return null;
    }
  }

  /// 电台模式下自动加载下一页歌曲。
  Future<bool> ensureRadioNextPageAppended(
    PlayerControllerCallback callback,
  ) async {
    if (isLoadingRadioNextPage) {
      return false;
    }
    final state = callback.currentState;
    final radioId = normalizeRadioValue(state.currentRadioId);
    final radioPlatform = normalizeRadioValue(state.currentRadioPlatform);
    final currentPageIndex = normalizeRadioPageIndex(
      state.currentRadioPageIndex,
    );
    if (!state.isRadioMode ||
        radioId == null ||
        radioPlatform == null ||
        currentPageIndex == null) {
      return false;
    }
    isLoadingRadioNextPage = true;
    try {
      final nextPageIndex = currentPageIndex + 1;
      final songs = await _fetchRadioSongs(
        radioId,
        radioPlatform,
        nextPageIndex,
      );
      if (songs == null || (songs is List && songs.isEmpty)) {
        return false;
      }
      final currentQueue = state.queue;
      final existingKeys = currentQueue.map(trackKey).toSet();
      final appendedTracks = (songs as List)
          .map((song) => _buildRadioTrack(song))
          .where((track) => !existingKeys.contains(trackKey(track)))
          .toList(growable: false);
      if (appendedTracks.isEmpty) {
        callback.updateState(
          (s) => s.copyWith(
            currentRadioPageIndex: nextPageIndex,
            clearError: true,
          ),
        );
        await persistQueueState(callback);
        return false;
      }
      var merged = <PlayerTrack>[...currentQueue, ...appendedTracks];
      var adjustedIndex = state.currentIndex;
      if (merged.length > radioQueueCap) {
        final excess = merged.length - radioQueueCap;
        merged = merged.sublist(excess);
        adjustedIndex = (adjustedIndex - excess).clamp(0, merged.length - 1);
      }
      callback.updateState(
        (s) => s.copyWith(
          queue: merged,
          currentIndex: adjustedIndex,
          currentRadioPageIndex: nextPageIndex,
          clearError: true,
        ),
      );
      await persistQueueState(callback);
      return true;
    } finally {
      isLoadingRadioNextPage = false;
    }
  }

  /// 将 SongInfo 转换为 PlayerTrack，含封面 URL 解析。
  PlayerTrack _buildRadioTrack(SongInfo song) {
    final platformId = song.platform.trim();
    final localPath = song.path?.trim();
    return PlayerTrack(
      id: song.id,
      title: song.title,
      path: localPath == null || localPath.isEmpty ? null : localPath,
      duration: song.duration > 0
          ? Duration(milliseconds: song.duration)
          : null,
      links: song.links,
      artist: song.artist,
      albumId: song.album?.id,
      album: song.album?.name,
      artists: song.artists,
      mvId: song.mvId,
      artworkUrl: null, // 封面 URL 需要异步解析，这里先设为 null
      platform: platformId,
    );
  }

  /// 判断队列来源是否相同。
  bool _isSameQueueSource(PlayerQueueSource? current, PlayerQueueSource? next) {
    if (current == null || next == null) {
      return false;
    }
    if (current.routePath != next.routePath) {
      return false;
    }
    if (current.queryParameters.length != next.queryParameters.length) {
      return false;
    }
    for (final entry in current.queryParameters.entries) {
      if (next.queryParameters[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

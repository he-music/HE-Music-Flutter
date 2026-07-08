import 'dart:async';

import '../../data/providers/player_progress_providers.dart';
import '../../domain/entities/player_track.dart';
import 'player_controller_callback.dart';

/// 播放进度持久化管理器。
///
/// 负责播放进度的节流保存、恢复和清除逻辑。
/// 通过 [PlayerControllerCallback] 接口与 Controller 交互，
/// 不直接依赖 Riverpod。
class PlayerProgressManager {
  PlayerProgressManager({required PlayerProgressDataSource dataSource})
    : _dataSource = dataSource;

  final PlayerProgressDataSource _dataSource;

  /// 进度持久化最小时间间隔（毫秒）。
  static const _minGapMs = 5000;

  /// 进度持久化最小位移（毫秒）。
  static const _minDeltaMs = 4000;

  /// 开始持久化的最小进度位置（毫秒）。
  static const _minPositionMs = 3000;

  /// 尾部清除进度的缓冲区（毫秒）。
  static const _tailBufferMs = 2000;

  DateTime? _lastPersistAt;
  int _lastPersistedPositionMs = 0;
  String? _lastPersistTrackKey;

  /// 节流保存当前播放进度。
  ///
  /// [force] 为 true 时跳过节流直接保存。
  Future<void> persistTrackProgress({
    required PlayerControllerCallback callback,
    required PlayerTrack? track,
    required Duration position,
    Duration? durationOverride,
    bool force = false,
  }) async {
    if (track == null) {
      return;
    }
    final positionMs = position.inMilliseconds;
    if (!force && positionMs < _minPositionMs) {
      return;
    }
    final durationMs =
        (durationOverride ?? callback.currentState.duration).inMilliseconds;
    if (durationMs > _minPositionMs &&
        positionMs >= durationMs - _tailBufferMs) {
      await _dataSource.clearProgress(track);
      return;
    }
    final trackKey = _computeTrackKey(track);
    final now = DateTime.now();
    if (!force && _lastPersistTrackKey == trackKey) {
      final lastAt = _lastPersistAt;
      final gapMs = lastAt == null
          ? _minGapMs
          : now.difference(lastAt).inMilliseconds;
      final deltaMs = (positionMs - _lastPersistedPositionMs).abs();
      if (gapMs < _minGapMs && deltaMs < _minDeltaMs) {
        return;
      }
    }
    try {
      await _dataSource.saveProgress(track: track, positionMs: positionMs);
      _lastPersistAt = now;
      _lastPersistedPositionMs = positionMs;
      _lastPersistTrackKey = trackKey;
    } catch (_) {
      // 忽略进度持久化失败，避免影响主播放链路。
    }
  }

  /// 恢复指定曲目的播放进度。
  ///
  /// 返回恢复的 position，null 表示无需恢复。
  Future<Duration?> restoreTrackProgress({
    required PlayerControllerCallback callback,
    required PlayerTrack track,
    required Duration currentDuration,
  }) async {
    try {
      final savedMs = await _dataSource.readProgress(track);
      if (savedMs == null || savedMs < _minPositionMs) {
        return null;
      }
      final durationMs = currentDuration.inMilliseconds;
      if (durationMs > _minPositionMs &&
          savedMs >= durationMs - _tailBufferMs) {
        await _dataSource.clearProgress(track);
        return null;
      }
      final safePosition = Duration(milliseconds: savedMs);
      _lastPersistTrackKey = _computeTrackKey(track);
      _lastPersistedPositionMs = savedMs;
      _lastPersistAt = DateTime.now();
      return safePosition;
    } catch (_) {
      // 恢复失败时保持从头播放。
      return null;
    }
  }

  /// Stream 位置更新时的入口（内部做 isPlaying 检查和节流）。
  void onPositionUpdateFromStream({
    required PlayerControllerCallback callback,
    required PlayerTrack? currentTrack,
    required Duration position,
    required bool isPlaying,
  }) {
    if (!isPlaying) {
      return;
    }
    unawaited(
      persistTrackProgress(
        callback: callback,
        track: currentTrack,
        position: position,
      ),
    );
  }

  /// 重置节流状态（切歌时调用）。
  void resetThrottle() {
    _lastPersistAt = null;
    _lastPersistedPositionMs = 0;
    _lastPersistTrackKey = null;
  }

  /// 计算曲目的唯一标识。
  static String _computeTrackKey(PlayerTrack track) {
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
}

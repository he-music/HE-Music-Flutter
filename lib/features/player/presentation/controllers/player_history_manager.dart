import '../../data/providers/player_history_providers.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_track.dart';
import 'player_controller_callback.dart';

/// 播放历史管理器。
///
/// 负责播放历史的水合和记录逻辑。
/// 通过 [PlayerControllerCallback] 接口与 Controller 交互，
/// 不直接依赖 Riverpod。
class PlayerHistoryManager {
  PlayerHistoryManager({required PlayerHistoryDataSource dataSource})
    : _dataSource = dataSource;

  final PlayerHistoryDataSource _dataSource;

  /// 上次记录历史的曲目 key（防重复）。
  String? _lastHistoryTrackKey;

  /// 水合历史计数到状态。
  Future<void> hydrateHistoryCount(PlayerControllerCallback callback) async {
    try {
      final count = await _dataSource.getCount();
      callback.updateState(
        (s) => s.copyWith(historyCount: count, clearError: true),
      );
    } catch (error) {
      callback.updateState((s) => s.copyWith(errorMessage: '获取历史记录失败'));
    }
  }

  /// 记录当前曲目到播放历史（带去重）。
  ///
  /// 返回是否实际写入。
  Future<bool> recordCurrentTrackHistory({
    required PlayerControllerCallback callback,
    required PlayerTrack? track,
    required bool isRadioMode,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
  }) async {
    if (track == null) {
      return false;
    }
    final historyKey = _computeTrackKey(track);
    if (_lastHistoryTrackKey == historyKey) {
      return false;
    }
    try {
      final count = await _dataSource.appendTrack(
        track,
        isRadioMode: isRadioMode,
        currentRadioId: currentRadioId,
        currentRadioPlatform: currentRadioPlatform,
        currentRadioPageIndex: currentRadioPageIndex,
        previousPlayModeBeforeRadio: previousPlayModeBeforeRadio,
      );
      _lastHistoryTrackKey = historyKey;
      callback.updateState(
        (s) => s.copyWith(historyCount: count, clearError: true),
      );
      return true;
    } catch (error) {
      callback.updateState((s) => s.copyWith(errorMessage: '记录播放历史失败'));
      return false;
    }
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

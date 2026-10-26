import '../../data/providers/player_history_providers.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_track.dart';
import 'player_controller_callback.dart';

/// 播放历史管理器，串行处理播放记录与后续时长补写。
class PlayerHistoryManager {
  PlayerHistoryManager({required PlayerHistoryDataSource dataSource})
    : _dataSource = dataSource;

  final PlayerHistoryDataSource _dataSource;
  String? _lastHistoryTrackKey;
  int? _lastHistoryDuration;
  Future<void> _operations = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

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

  Future<bool> recordCurrentTrackHistory({
    required PlayerControllerCallback callback,
    required PlayerTrack? track,
    required bool isRadioMode,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
  }) {
    if (track == null) return Future.value(false);
    return _enqueue(() async {
      final historyKey = _computeTrackKey(track);
      // 时长事件可能先于写入到达，仅采用同一首已提交歌曲的最新值。
      final current = callback.currentState.currentTrack;
      final duration =
          current != null &&
              _computeTrackKey(current) == historyKey &&
              (current.duration?.inSeconds ?? 0) > 0
          ? current.duration
          : track.duration;
      final entry = duration == track.duration
          ? track
          : track.copyWith(duration: duration);
      try {
        if (_lastHistoryTrackKey == historyKey) {
          await _updateTrackDuration(entry);
          return false;
        }
        final count = await _dataSource.appendTrack(
          entry,
          isRadioMode: isRadioMode,
          currentRadioId: currentRadioId,
          currentRadioPlatform: currentRadioPlatform,
          currentRadioPageIndex: currentRadioPageIndex,
          previousPlayModeBeforeRadio: previousPlayModeBeforeRadio,
        );
        _lastHistoryTrackKey = historyKey;
        _lastHistoryDuration = entry.duration?.inSeconds;
        callback.updateState(
          (s) => s.copyWith(historyCount: count, clearError: true),
        );
        return true;
      } catch (error) {
        callback.updateState((s) => s.copyWith(errorMessage: '记录播放历史失败'));
        return false;
      }
    });
  }

  Future<bool> updateTrackDuration(PlayerTrack track) =>
      _enqueue(() => _updateTrackDuration(track));

  Future<bool> _updateTrackDuration(PlayerTrack track) async {
    final seconds = track.duration?.inSeconds ?? 0;
    if (seconds <= 0) return false;
    final key = _computeTrackKey(track);
    if (key == _lastHistoryTrackKey && seconds == _lastHistoryDuration) {
      return false;
    }
    final updated = await _dataSource.updateTrackDuration(track);
    if (key == _lastHistoryTrackKey) _lastHistoryDuration = seconds;
    return updated;
  }

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
      duration: (item.duration ?? 0) > 0
          ? Duration(seconds: item.duration!)
          : null,
    );
  }

  static String _computeTrackKey(PlayerTrack track) {
    final id = track.id.trim();
    if (id.isEmpty) return '';
    final platform = (track.platform ?? '').trim();
    if (platform == 'local') return id;
    return platform.isEmpty ? id : '$id|$platform';
  }
}

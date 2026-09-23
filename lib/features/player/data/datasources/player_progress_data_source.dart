import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/player_track.dart';

const _resumeStorageKey = 'player_resume_v1';
const _legacyProgressKey = 'player_progress_v1';

/// One app-wide resume position. Writes are ordered to prevent a delayed write
/// for the previous song from overtaking a newer resume record.
class PlayerProgressDataSource {
  const PlayerProgressDataSource();

  static Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> saveProgress({
    required PlayerTrack track,
    required int positionMs,
    String? queueKey,
  }) => _serial(() async {
    if (track.id.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, track, positionMs, queueKey);
  });

  Future<void> _save(
    SharedPreferences prefs,
    PlayerTrack track,
    int positionMs,
    String? queueKey,
  ) async {
    final saved = await prefs.setString(
      _resumeStorageKey,
      jsonEncode({
        'track_key': _trackKey(track),
        'queue_key': queueKey,
        'position_ms': positionMs < 0 ? 0 : positionMs,
      }),
    );
    if (!saved) throw StateError('保存播放位置失败');
    if (prefs.containsKey(_legacyProgressKey)) {
      await prefs.remove(_legacyProgressKey);
    }
  }

  Future<int?> readProgress(PlayerTrack track, {String? queueKey}) =>
      _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final payload = prefs.getString(_resumeStorageKey);
        if (payload != null) {
          final raw = jsonDecode(payload) as Map<String, dynamic>;
          if (raw['track_key'] != _trackKey(track) ||
              raw['queue_key'] != queueKey) {
            return null;
          }
          return (raw['position_ms'] as num?)?.toInt();
        }
        final legacy = prefs.getString(_legacyProgressKey);
        if (legacy == null) return null;
        final raw = jsonDecode(legacy) as Map<String, dynamic>;
        final entry = raw[_trackKey(track)] as Map?;
        final position = (entry?['position_ms'] as num?)?.toInt();
        // Only the restored current song is imported, never the entire old map.
        await _save(prefs, track, position ?? 0, queueKey);
        return position;
      });

  Future<void> clearProgress(PlayerTrack track, {String? queueKey}) =>
      _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final payload = prefs.getString(_resumeStorageKey);
        if (payload == null) return;
        final raw = jsonDecode(payload) as Map<String, dynamic>;
        if (raw['track_key'] == _trackKey(track) &&
            raw['queue_key'] == queueKey) {
          await prefs.remove(_resumeStorageKey);
        }
      });

  String _trackKey(PlayerTrack track) {
    final id = track.id.trim();
    final platform = (track.platform ?? '').trim();
    return platform.isEmpty || platform == 'local' ? id : '$id|$platform';
  }
}

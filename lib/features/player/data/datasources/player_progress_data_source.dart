import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/player_track.dart';

const _progressStorageKey = 'player_progress_v1';
const _progressLimit = 200;

class PlayerProgressDataSource {
  const PlayerProgressDataSource();

  Future<void> saveProgress({
    required PlayerTrack track,
    required int positionMs,
  }) async {
    final safePosition = positionMs < 0 ? 0 : positionMs;
    final key = _trackKey(track);
    if (key.isEmpty) {
      return;
    }
    final current = await _readRaw();
    final next = <String, dynamic>{...current};
    next[key] = <String, dynamic>{
      'position_ms': safePosition,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    final trimmed = _trim(next);
    await _saveRaw(trimmed);
  }

  Future<int?> readProgress(PlayerTrack track) async {
    final key = _trackKey(track);
    if (key.isEmpty) {
      return null;
    }
    final raw = await _readRaw();
    final node = _asMap(raw[key]);
    final value = _toInt(node['position_ms']);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  Future<void> clearProgress(PlayerTrack track) async {
    final key = _trackKey(track);
    if (key.isEmpty) {
      return;
    }
    final raw = await _readRaw();
    if (!raw.containsKey(key)) {
      return;
    }
    final next = <String, dynamic>{...raw}..remove(key);
    await _saveRaw(next);
  }

  Future<Map<String, dynamic>> _readRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_progressStorageKey);
    if (payload == null || payload.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return <String, dynamic>{};
      }
      return decoded.map((key, value) => MapEntry('$key', value));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveRaw(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressStorageKey, jsonEncode(value));
  }

  Map<String, dynamic> _trim(Map<String, dynamic> raw) {
    if (raw.length <= _progressLimit) {
      return raw;
    }
    final entries = raw.entries.toList(growable: false);
    entries.sort((a, b) {
      final aTime = _toInt(_asMap(a.value)['updated_at']) ?? 0;
      final bTime = _toInt(_asMap(b.value)['updated_at']) ?? 0;
      return bTime.compareTo(aTime);
    });
    return Map<String, dynamic>.fromEntries(
      entries.take(_progressLimit).toList(growable: false),
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

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  String _trackKey(PlayerTrack track) {
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

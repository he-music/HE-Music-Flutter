import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_music_database.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_track.dart';

const _historyStorageKey = 'player_play_history_v1';
const _historyLimit = 100;

class PlayerHistoryDataSource {
  const PlayerHistoryDataSource({LocalMusicDatabase? database})
    : _database = database;

  final LocalMusicDatabase? _database;
  LocalMusicDatabase get _db => _database ?? appDatabase;

  // 同一数据库只检查一次迁移，正常的时长补写只执行条件 UPDATE。
  static final _migrations = Expando<Future<void>>();

  Future<void> _migrate() {
    final db = _db;
    final migration = _migrations[db];
    if (migration != null) {
      return migration.then((_) async {
        // 保留迁移后清理残留旧配置的能力，不再查询数据库标记。
        final preferences = await SharedPreferences.getInstance();
        if (preferences.containsKey(_historyStorageKey)) {
          await preferences.remove(_historyStorageKey);
        }
      });
    }
    return _migrations[db] ??=
        migratePreferences(db, _historyStorageKey, (value) async {
          final list = jsonDecode(value as String) as List;
          final seen = <String>{};
          for (final raw in list.whereType<Map>()) {
            final item = _asMap(raw);
            final key = _trackKey(item);
            if (key.isEmpty || !seen.add(key)) continue;
            await _writeItem(item);
            if (seen.length == _historyLimit) break;
          }
        }).onError((Object error, StackTrace stackTrace) {
          _migrations[db] = null;
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  Future<void> _writeItem(Map<String, dynamic> item, {int? sortTime}) async {
    await _db.customInsert(
      r'''
      INSERT INTO playback_history (track_key, played_at, payload)
      VALUES (?, ?, ?)
      ON CONFLICT (track_key) DO UPDATE SET
        played_at = excluded.played_at,
        payload = json_patch(
          json_object('duration', json_extract(playback_history.payload, '$.duration')),
          excluded.payload
        )
      ''',
      variables: [
        Variable.withString(_trackKey(item)),
        Variable.withInt(sortTime ?? _toInt(item['playedAt']) * 1000),
        Variable.withString(jsonEncode(item)),
      ],
      updates: {_db.playbackHistory},
    );
  }

  Future<List<PlayerHistoryItem>> listHistory() async {
    final list = await _readRawList();
    return list.map(_toHistoryItem).toList(growable: false);
  }

  Future<int> getCount() async {
    final list = await _readRawList();
    return list.length;
  }

  Future<int> appendTrack(
    PlayerTrack track, {
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
  }) async {
    await _migrate();
    // 本地歌曲：计算封面缓存文件路径
    String? artworkPath;
    if (track.platform == 'local' &&
        track.path != null &&
        track.path!.isNotEmpty) {
      final hash = sha256.convert(track.path!.codeUnits).toString();
      final appDir = await getApplicationDocumentsDirectory();
      artworkPath = p.join(appDir.path, 'artwork', '$hash.jpg');
    }
    final item = _toMap(
      track,
      isRadioMode: isRadioMode,
      currentRadioId: currentRadioId,
      currentRadioPlatform: currentRadioPlatform,
      currentRadioPageIndex: currentRadioPageIndex,
      previousPlayModeBeforeRadio: previousPlayModeBeforeRadio,
      artworkPath: artworkPath,
    );
    return _db.transaction(() async {
      await _writeItem(item, sortTime: DateTime.now().microsecondsSinceEpoch);
      final rows = await _readHistoryRows();
      if (rows.length > _historyLimit) {
        await (_db.delete(_db.playbackHistory)..where(
              (row) => row.trackKey.isIn(
                rows.skip(_historyLimit).map((row) => row.trackKey),
              ),
            ))
            .go();
      }
      return rows.length.clamp(0, _historyLimit);
    });
  }

  /// 仅补写已存在记录的总时长，保留播放时间和排序；相同秒数不更新。
  Future<bool> updateTrackDuration(PlayerTrack track) async {
    final seconds = track.duration?.inSeconds ?? 0;
    if (seconds <= 0) return false;
    await _migrate();
    final key = _trackKey({'id': track.id, 'platform': track.platform ?? ''});
    final updated = await _db.customUpdate(
      r'''
      UPDATE playback_history
      SET payload = json_set(payload, '$.duration', ?)
      WHERE track_key = ?
        AND COALESCE(CAST(json_extract(payload, '$.duration') AS INTEGER), 0) <> ?
      ''',
      variables: [
        Variable.withInt(seconds),
        Variable.withString(key),
        Variable.withInt(seconds),
      ],
      updates: {_db.playbackHistory},
    );
    return updated > 0;
  }

  Stream<List<PlayerHistoryItem>> watchHistory() async* {
    await _migrate();
    yield* (_db.select(_db.playbackHistory)..orderBy([
          (row) => OrderingTerm.desc(row.playedAt),
          (row) => OrderingTerm.asc(row.trackKey),
        ]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => _toHistoryItem(_asMap(jsonDecode(row.payload) as Map)),
              )
              .toList(growable: false),
        );
  }

  Future<void> clearHistory() async {
    await _migrate();
    await _db.delete(_db.playbackHistory).go();
  }

  Future<List<Map<String, dynamic>>> _readRawList() async {
    await _migrate();
    final rows = await _readHistoryRows();
    return rows
        .map((row) => jsonDecode(row.payload) as Map<String, dynamic>)
        .toList();
  }

  Future<List<PlaybackHistoryData>> _readHistoryRows() {
    return (_db.select(_db.playbackHistory)..orderBy([
          (row) => OrderingTerm.desc(row.playedAt),
          (row) => OrderingTerm.asc(row.trackKey),
        ]))
        .get();
  }

  Map<String, dynamic> _toMap(
    PlayerTrack track, {
    required bool isRadioMode,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
    String? artworkPath,
  }) {
    return <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'artist': track.artist ?? '',
      'album': track.album ?? '',
      'artworkUrl': track.artworkUrl ?? '',
      'url': track.url,
      'path': track.path,
      'platform': track.platform ?? '',
      'album_id': track.albumId ?? '',
      'artists': track.artists
          .map((a) => <String, dynamic>{'id': a.id, 'name': a.name})
          .toList(growable: false),
      if ((track.duration?.inSeconds ?? 0) > 0)
        'duration': track.duration!.inSeconds,
      'playedAt': DateTime.now().millisecondsSinceEpoch,
      'is_radio_mode': isRadioMode,
      'current_radio_id': currentRadioId,
      'current_radio_platform': currentRadioPlatform,
      'current_radio_page_index': currentRadioPageIndex,
      'previous_play_mode_before_radio': previousPlayModeBeforeRadio?.name,
      'artwork_path': artworkPath,
    };
  }

  Map<String, dynamic> _asMap(Map value) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }

  String _trackKey(Map<String, dynamic> item) {
    final id = '${item['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return '';
    }
    final platform = '${item['platform'] ?? ''}'.trim();
    if (platform == 'local') {
      return id;
    }
    if (platform.isNotEmpty) {
      return '$id|$platform';
    }
    return id;
  }

  PlayerHistoryItem _toHistoryItem(Map<String, dynamic> item) {
    return PlayerHistoryItem(
      id: '${item['id'] ?? ''}',
      title: '${item['title'] ?? ''}',
      artist: '${item['artist'] ?? ''}',
      album: '${item['album'] ?? ''}',
      artworkUrl: '${item['artworkUrl'] ?? ''}',
      url: '${item['url'] ?? ''}',
      path: _toOptionalText(item['path']),
      playedAt: _toInt(item['playedAt']),
      duration: _toOptionalInt(item['duration']),
      platform: _toOptionalText(item['platform']),
      albumId: _toOptionalText(item['album_id']),
      artists: _toArtistList(item['artists']),
      isRadioMode: item['is_radio_mode'] == true,
      currentRadioId: _toOptionalText(item['current_radio_id']),
      currentRadioPlatform: _toOptionalText(item['current_radio_platform']),
      currentRadioPageIndex: _toOptionalInt(item['current_radio_page_index']),
      previousPlayModeBeforeRadio: _toPlayMode(
        item['previous_play_mode_before_radio'],
      ),
      artworkPath: _toOptionalText(item['artwork_path']),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  String? _toOptionalText(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = '$value'.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  int? _toOptionalInt(dynamic value) {
    if (value == null) {
      return null;
    }
    final parsed = int.tryParse('$value');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  List<SongInfoArtistInfo> _toArtistList(dynamic value) {
    if (value is! List) {
      return const <SongInfoArtistInfo>[];
    }
    return value
        .whereType<Map>()
        .map((raw) => SongInfoArtistInfo.fromMap(_asMap(raw)))
        .where((a) => a.id.trim().isNotEmpty && a.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  PlayerPlayMode? _toPlayMode(dynamic value) {
    final normalized = '$value'.trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }
    for (final mode in PlayerPlayMode.values) {
      if (mode.name == normalized) {
        return mode;
      }
    }
    return null;
  }
}

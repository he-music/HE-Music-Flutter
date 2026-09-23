import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_music_database.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_queue_snapshot.dart';
import '../../domain/entities/player_queue_source.dart';
import '../../domain/entities/player_track.dart';

const _queueStorageKey = 'player_queue_v1';

class PlayerQueueDataSource {
  const PlayerQueueDataSource({LocalMusicDatabase? database})
    : _database = database;

  final LocalMusicDatabase? _database;
  LocalMusicDatabase get _db => _database ?? appDatabase;

  Future<void> _migrate() =>
      migratePreferences(_db, _queueStorageKey, (value) async {
        final raw = jsonDecode(value as String) as Map<String, dynamic>;
        await _writeSlot('current', raw);
        await _writeSlot('previous', _asMap(raw['previous_snapshot']));
      });

  Future<void> saveQueue({
    required List<PlayerTrack> queue,
    required int currentIndex,
    required PlayerPlayMode playMode,
    required bool isRadioMode,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
    PlayerQueueSource? source,
    PlayerQueueSnapshot? previousSnapshot,
  }) async {
    await _migrate();
    final hasPreviousSnapshot =
        previousSnapshot != null && previousSnapshot.queue.isNotEmpty;
    if (queue.isEmpty && !hasPreviousSnapshot) {
      await clearQueue();
      return;
    }
    final payload = <String, dynamic>{
      'current_index': currentIndex,
      'play_mode': playMode.name,
      'is_radio_mode': isRadioMode,
      'current_radio_id': currentRadioId,
      'current_radio_platform': currentRadioPlatform,
      'current_radio_page_index': currentRadioPageIndex,
      'previous_play_mode_before_radio': previousPlayModeBeforeRadio?.name,
      'queue': queue.map(_trackToMap).toList(growable: false),
      'source': source?.toMap(),
      'previous_snapshot':
          previousSnapshot == null || previousSnapshot.queue.isEmpty
          ? null
          : _snapshotToMap(previousSnapshot),
    };
    await _db.transaction(() async {
      await _writeSlot('current', payload);
      await _writeSlot('previous', _asMap(payload['previous_snapshot']));
    });
  }

  Future<PlayerQueueSnapshot?> readQueue() async {
    try {
      await _migrate();
      return await _db.transaction(() async {
        final raw = await _readSlot('current');
        raw['previous_snapshot'] = await _readSlot('previous');
        final queue = _trackList(raw['queue']);
        final previousSnapshot = previousSnapshotFromValue(
          raw['previous_snapshot'],
        );
        if (queue.isEmpty && previousSnapshot == null) {
          return null;
        }
        final currentIndex = _toInt(raw['current_index']) ?? 0;
        final playMode = _playModeFromValue('${raw['play_mode'] ?? ''}');
        return PlayerQueueSnapshot(
          queue: queue,
          currentIndex: queue.isEmpty
              ? 0
              : currentIndex.clamp(0, queue.length - 1).toInt(),
          playMode: playMode,
          isRadioMode: raw['is_radio_mode'] == true,
          source: _sourceFromValue(raw['source']),
          previousSnapshot: previousSnapshot,
          currentRadioId: _nullableString(raw['current_radio_id']),
          currentRadioPlatform: _nullableString(raw['current_radio_platform']),
          currentRadioPageIndex: _toInt(raw['current_radio_page_index']),
          previousPlayModeBeforeRadio: _nullablePlayMode(
            raw['previous_play_mode_before_radio'],
          ),
        );
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> clearQueue() async {
    await _migrate();
    await _db.delete(_db.playbackQueues).go();
  }

  Future<Map<String, dynamic>> _readSlot(String slot) async {
    final record = await (_db.select(
      _db.playbackQueues,
    )..where((row) => row.slot.equals(slot))).getSingleOrNull();
    if (record == null) return {};
    final entries =
        await (_db.select(_db.playbackQueueEntries)
              ..where((row) => row.slot.equals(slot))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    return {
      ...jsonDecode(record.metadata) as Map<String, dynamic>,
      'queue': entries.map((row) => jsonDecode(row.payload)).toList(),
    };
  }

  Future<void> _writeSlot(String slot, Map<String, dynamic> raw) async {
    final tracks = (raw['queue'] as List?) ?? const [];
    if (tracks.isEmpty && slot == 'previous') {
      await (_db.delete(
        _db.playbackQueues,
      )..where((row) => row.slot.equals(slot))).go();
      return;
    }
    final metadata = jsonEncode(
      {...raw}
        ..remove('queue')
        ..remove('previous_snapshot'),
    );
    final previous = await (_db.select(
      _db.playbackQueues,
    )..where((row) => row.slot.equals(slot))).getSingleOrNull();
    if (previous?.metadata != metadata) {
      await _db
          .into(_db.playbackQueues)
          .insertOnConflictUpdate(
            PlaybackQueue(slot: slot, metadata: metadata),
          );
    }
    final existing = await (_db.select(
      _db.playbackQueueEntries,
    )..where((row) => row.slot.equals(slot))).get();
    final byPosition = {for (final row in existing) row.position: row.payload};
    await _db.batch((batch) {
      for (var i = 0; i < tracks.length; i++) {
        final payload = jsonEncode(tracks[i]);
        if (byPosition[i] == payload) continue;
        batch.insert(
          _db.playbackQueueEntries,
          PlaybackQueueEntry(slot: slot, position: i, payload: payload),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    await (_db.delete(_db.playbackQueueEntries)..where(
          (row) =>
              row.slot.equals(slot) &
              row.position.isBiggerOrEqualValue(tracks.length),
        ))
        .go();
  }

  Map<String, dynamic> _trackToMap(PlayerTrack track) {
    return <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'url': track.url,
      'path': track.path,
      'duration_ms': track.duration?.inMilliseconds,
      'artist': track.artist,
      'album': track.album,
      'album_id': track.albumId,
      'artists': track.artists
          .map(
            (artist) => <String, dynamic>{'id': artist.id, 'name': artist.name},
          )
          .toList(growable: false),
      'mv_id': track.mvId,
      'artwork_url': track.artworkUrl,
      'platform': track.platform,
      'format': track.format,
      'bitrate': track.bitrate,
      'sample_rate': track.sampleRate,
      'links': track.links.map(_linkToMap).toList(growable: false),
    };
  }

  Map<String, dynamic> _snapshotToMap(PlayerQueueSnapshot snapshot) {
    return <String, dynamic>{
      'current_index': snapshot.currentIndex,
      'play_mode': snapshot.playMode.name,
      'is_radio_mode': snapshot.isRadioMode,
      'current_radio_id': snapshot.currentRadioId,
      'current_radio_platform': snapshot.currentRadioPlatform,
      'current_radio_page_index': snapshot.currentRadioPageIndex,
      'previous_play_mode_before_radio':
          snapshot.previousPlayModeBeforeRadio?.name,
      'queue': snapshot.queue.map(_trackToMap).toList(growable: false),
      'source': snapshot.source?.toMap(),
      'previous_snapshot': null,
    };
  }

  Map<String, dynamic> _linkToMap(LinkInfo link) {
    return <String, dynamic>{
      'name': link.name,
      'quality': link.quality,
      'format': link.format,
      'size': link.size,
      'url': link.url,
    };
  }

  List<PlayerTrack> _trackList(dynamic value) {
    if (value is! List) {
      return const <PlayerTrack>[];
    }
    return value
        .map((item) => _trackFromMap(_asMap(item)))
        .whereType<PlayerTrack>()
        .toList(growable: false);
  }

  PlayerTrack? _trackFromMap(Map<String, dynamic> raw) {
    final id = '${raw['id'] ?? ''}'.trim();
    final title = '${raw['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) {
      return null;
    }
    return PlayerTrack(
      id: id,
      title: title,
      url: '${raw['url'] ?? ''}'.trim(),
      path: _nullableString(raw['path']),
      duration: _nullableDuration(raw['duration_ms']),
      links: _linkList(raw['links']),
      artist: _nullableString(raw['artist']),
      album: _nullableString(raw['album']),
      albumId: _nullableString(raw['album_id']),
      artists: _artistList(raw['artists']),
      mvId: _nullableString(raw['mv_id']),
      artworkUrl: _nullableString(raw['artwork_url']),
      platform: _nullableString(raw['platform']),
      format: _nullableString(raw['format']),
      bitrate: _toInt(raw['bitrate']),
      sampleRate: _toInt(raw['sample_rate']),
    );
  }

  PlayerQueueSource? _sourceFromValue(dynamic value) {
    final raw = _asMap(value);
    if (raw.isEmpty) {
      return null;
    }
    final source = PlayerQueueSource.fromMap(raw);
    if (!source.isValid) {
      return null;
    }
    return source;
  }

  PlayerQueueSnapshot? previousSnapshotFromValue(dynamic value) {
    final raw = _asMap(value);
    if (raw.isEmpty) {
      return null;
    }
    final queue = _trackList(raw['queue']);
    if (queue.isEmpty) {
      return null;
    }
    final currentIndex = _toInt(raw['current_index']) ?? 0;
    final playMode = _playModeFromValue('${raw['play_mode'] ?? ''}');
    return PlayerQueueSnapshot(
      queue: queue,
      currentIndex: currentIndex.clamp(0, queue.length - 1).toInt(),
      playMode: playMode,
      isRadioMode: raw['is_radio_mode'] == true,
      source: _sourceFromValue(raw['source']),
      currentRadioId: _nullableString(raw['current_radio_id']),
      currentRadioPlatform: _nullableString(raw['current_radio_platform']),
      currentRadioPageIndex: _toInt(raw['current_radio_page_index']),
      previousPlayModeBeforeRadio: _nullablePlayMode(
        raw['previous_play_mode_before_radio'],
      ),
    );
  }

  List<LinkInfo> _linkList(dynamic value) {
    if (value is! List) {
      return const <LinkInfo>[];
    }
    return value
        .map((item) => LinkInfo.fromMap(_asMap(item)))
        .toList(growable: false);
  }

  List<SongInfoArtistInfo> _artistList(dynamic value) {
    if (value is! List) {
      return const <SongInfoArtistInfo>[];
    }
    return value
        .map((item) => SongInfoArtistInfo.fromMap(_asMap(item)))
        .toList(growable: false);
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

  String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final normalized = '$value'.trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }

  Duration? _nullableDuration(dynamic value) {
    final milliseconds = _toInt(value);
    if (milliseconds == null || milliseconds <= 0) {
      return null;
    }
    return Duration(milliseconds: milliseconds);
  }

  PlayerPlayMode _playModeFromValue(String value) {
    final normalized = value.trim();
    for (final mode in PlayerPlayMode.values) {
      if (mode.name == normalized) {
        return mode;
      }
    }
    return PlayerPlayMode.sequence;
  }

  PlayerPlayMode? _nullablePlayMode(dynamic value) {
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

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_queue_snapshot.dart';
import '../../domain/entities/player_queue_source.dart';
import '../../domain/entities/player_track.dart';

const _queueStorageKey = 'player_queue_v1';

class PlayerQueueDataSource {
  const PlayerQueueDataSource();

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
    final prefs = await SharedPreferences.getInstance();
    final hasPreviousSnapshot =
        previousSnapshot != null && previousSnapshot.queue.isNotEmpty;
    if (queue.isEmpty && !hasPreviousSnapshot) {
      await prefs.remove(_queueStorageKey);
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
    await prefs.setString(_queueStorageKey, jsonEncode(payload));
  }

  Future<PlayerQueueSnapshot?> readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_queueStorageKey);
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      final raw = decoded.map((key, value) => MapEntry('$key', value));
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
    } catch (_) {
      return null;
    }
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueStorageKey);
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
      'previous_snapshot': snapshot.previousSnapshot == null
          ? null
          : _snapshotToMap(snapshot.previousSnapshot!),
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
      previousSnapshot: previousSnapshotFromValue(raw['previous_snapshot']),
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

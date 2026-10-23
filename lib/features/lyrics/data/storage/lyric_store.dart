import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_music_database.dart';
import '../../domain/entities/lyric_request.dart';
import '../../domain/entities/raw_lyric_bundle.dart';
import '../../domain/usecases/parse_lrc.dart';

String lyricStorageKey(LyricRequest target) {
  final local = target.platform == 'local';
  var path = target.localPath ?? '';
  if (path.startsWith('file:')) path = Uri.parse(path).toFilePath();
  final identity = local
      ? p.normalize(p.absolute(path))
      : jsonEncode([target.platform, target.trackId]);
  return '${local ? 'local' : 'online'}_${sha256.convert(utf8.encode(identity))}';
}

/// Positive values advance lyric display; negative values delay it.
class LyricOffsetChange {
  const LyricOffsetChange(this.key, this.manual, this.milliseconds);

  const LyricOffsetChange.resetAll()
    : key = null,
      manual = false,
      milliseconds = 0;

  final String? key;
  final bool manual;
  final int milliseconds;
}

class LyricStorageStats {
  const LyricStorageStats(
    this.automaticBytes,
    this.manualBytes,
    this.manualCount,
  );
  final int automaticBytes;
  final int manualBytes;
  final int manualCount;
}

/// Separate durable user choices and disposable default lyrics. All disk work
/// is serialized; epochs invalidate network work before a destructive operation.
class LyricStore {
  LyricStore({
    required Future<Directory> Function() manualDirectory,
    required Future<Directory> Function() automaticDirectory,
    LocalMusicDatabase? database,
    this.limitBytes = 50 * 1024 * 1024,
  }) : _manualDirectory = manualDirectory,
       _automaticDirectory = automaticDirectory,
       _database = database;

  static final shared = LyricStore(
    manualDirectory: () async => Directory(
      p.join((await getApplicationSupportDirectory()).path, 'lyrics', 'manual'),
    ),
    automaticDirectory: () async => Directory(
      p.join(
        (await getApplicationCacheDirectory()).path,
        'lyrics',
        'automatic',
      ),
    ),
  );
  final Future<Directory> Function() _manualDirectory;
  final Future<Directory> Function() _automaticDirectory;
  final LocalMusicDatabase? _database;
  LocalMusicDatabase get _db => _database ?? appDatabase;
  final int limitBytes;
  final _changes = StreamController<String?>.broadcast(sync: true);
  Stream<String?> get changes => _changes.stream;
  // Statistics changes never request a reload of the currently playing lyrics.
  final _statisticsChanges = StreamController<int>.broadcast(sync: true);
  int _statisticsRevision = 0;
  Stream<int> get statisticsChanges => _statisticsChanges.stream;
  Future<void> _tail = Future<void>.value();
  final _offsetChanges = StreamController<LyricOffsetChange>.broadcast(
    sync: true,
  );
  Stream<LyricOffsetChange> get offsetChanges => _offsetChanges.stream;

  // Bind manual offsets to the saved selection, so replacing or deleting a
  // selection cannot transfer its timing correction to different lyrics.
  Future<String?> _manualRevision(LyricRequest target) async {
    final file = await _file(target, true);
    if (!await file.exists()) return null;
    return sha256.convert(await file.readAsBytes()).toString();
  }

  Future<int> readOffset(LyricRequest target, {required bool manual}) =>
      _serial(() => _readOffset(target, manual: manual));

  Future<int> _readOffset(LyricRequest target, {required bool manual}) async {
    final key = lyricStorageKey(target);
    final kind = manual ? 'manual' : 'default';
    final row =
        await (_db.select(_db.lyricOffsets)..where(
              (row) => row.targetKey.equals(key) & row.sourceKind.equals(kind),
            ))
            .getSingleOrNull();
    if (row == null) return 0;
    if (manual) {
      final revision = await _manualRevision(target);
      if (revision == null || row.manualRevision != revision) {
        await _deleteManualOffset(target);
        return 0;
      }
    }
    return row.milliseconds;
  }

  Future<int> adjustOffset(
    LyricRequest target,
    int deltaMilliseconds, {
    required bool manual,
  }) => _updateOffset(target, manual: manual, delta: deltaMilliseconds);

  Future<int> resetOffset(LyricRequest target, {required bool manual}) =>
      _updateOffset(target, manual: manual);

  /// Only user timing corrections are removed; lyric content is kept.
  Future<void> resetAllOffsets() => _serial(() async {
    await _db.delete(_db.lyricOffsets).go();
    _offsetChanges.add(const LyricOffsetChange.resetAll());
  });

  Future<void> _deleteManualOffset(LyricRequest target) =>
      (_db.delete(_db.lyricOffsets)..where(
            (row) =>
                row.targetKey.equals(lyricStorageKey(target)) &
                row.sourceKind.equals('manual'),
          ))
          .go();

  Future<void> _deleteAllManualOffsets() => (_db.delete(
    _db.lyricOffsets,
  )..where((row) => row.sourceKind.equals('manual'))).go();

  Future<int> _updateOffset(
    LyricRequest target, {
    required bool manual,
    int? delta,
  }) => _serial(() async {
    final milliseconds = await _db.transaction(() async {
      final revision = manual ? await _manualRevision(target) : null;
      if (manual && revision == null) throw StateError('手动歌词已被移除');
      final milliseconds = delta == null
          ? 0
          : await _readOffset(target, manual: manual) + delta;
      final key = lyricStorageKey(target);
      final kind = manual ? 'manual' : 'default';
      if (milliseconds == 0) {
        await (_db.delete(_db.lyricOffsets)..where(
              (row) => row.targetKey.equals(key) & row.sourceKind.equals(kind),
            ))
            .go();
      } else {
        await _db
            .into(_db.lyricOffsets)
            .insertOnConflictUpdate(
              LyricOffsetEntry(
                targetKey: key,
                sourceKind: kind,
                milliseconds: milliseconds,
                manualRevision: revision,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
      }
      return milliseconds;
    });
    _offsetChanges.add(
      LyricOffsetChange(lyricStorageKey(target), manual, milliseconds),
    );
    return milliseconds;
  });

  int automaticEpoch = 0;
  int _manualEpoch = 0;
  final Map<String, int> _versions = {};
  (int, int) selectionToken(LyricRequest target) =>
      (_manualEpoch, _versions[lyricStorageKey(target)] ?? 0);
  (int, int) beginSelection(LyricRequest target) {
    final key = lyricStorageKey(target);
    _versions[key] = (_versions[key] ?? 0) + 1;
    return selectionToken(target);
  }

  bool isCurrent(LyricRequest target, (int, int) token) =>
      selectionToken(target) == token;

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<File> _file(LyricRequest target, bool manual) async {
    final directory = await (manual
        ? _manualDirectory()
        : _automaticDirectory());
    await directory.create(recursive: true);
    return File(p.join(directory.path, '${lyricStorageKey(target)}.json'));
  }

  Future<bool> hasManual(LyricRequest target) =>
      _serial(() async => (await _file(target, true)).exists());

  Future<RawLyricBundle?> read(LyricRequest target, {required bool manual}) =>
      _serial(() async {
        final file = await _file(target, manual);
        if (!await file.exists()) return null;
        try {
          final value =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          if (value['version'] != 1 ||
              value['targetKey'] != lyricStorageKey(target)) {
            throw const FormatException('歌词记录版本或身份不兼容');
          }
          final bundle = RawLyricBundle(
            lyric: value['lyric'] as String,
            translation: value['trans'] as String,
            romanization: value['roma'] as String,
          );
          if (!usable(bundle)) throw const FormatException('歌词内容不可用');
          if (!manual) await file.setLastModified(DateTime.now());
          return bundle;
        } catch (_) {
          if (manual) rethrow;
          await _delete(file);
          return null;
        }
      });

  static bool usable(RawLyricBundle bundle) => !parseLyricDocument(
    lyric: bundle.lyric,
    translation: bundle.translation,
    romanization: bundle.romanization,
  ).isEmpty;

  Future<void> saveManual(
    LyricRequest target,
    RawLyricBundle bundle, {
    required String sourcePlatform,
    required String sourceId,
    required String title,
    required String artist,
    required (int, int) token,
  }) => _serial(() async {
    if (!isCurrent(target, token)) throw StateError('歌词选择已失效，请重试');
    if (!usable(bundle)) throw const FormatException('没有可用歌词');
    await _write(
      target,
      bundle,
      manual: true,
      source: {'type': 'candidate', 'platform': sourcePlatform, 'id': sourceId},
      title: title,
      artist: artist,
      canCommit: () => isCurrent(target, token),
    );
    try {
      await _deleteManualOffset(target);
      // A reset queued during the write will remove it before any later read.
      if (!isCurrent(target, token)) throw StateError('歌词选择已失效');
    } finally {
      if (isCurrent(target, token)) {
        _versions[lyricStorageKey(target)] = token.$2 + 1;
      }
      // The lyrics have committed, so notify even if offset cleanup failed.
      _changes.add(lyricStorageKey(target));
    }
  });

  Future<void> saveAutomatic(
    LyricRequest target,
    RawLyricBundle bundle,
    int epoch,
  ) => _serial(() async {
    if (target.platform == 'local' ||
        epoch != automaticEpoch ||
        !usable(bundle)) {
      return;
    }
    await _write(
      target,
      bundle,
      manual: false,
      source: {
        'type': 'defaultSong',
        'platform': target.platform,
        'id': target.trackId,
      },
    );
    await _evict();
  });

  Future<void> _write(
    LyricRequest target,
    RawLyricBundle bundle, {
    required bool manual,
    required Map<String, dynamic> source,
    String title = '',
    String artist = '',
    bool Function()? canCommit,
  }) async {
    final data = utf8.encode(
      jsonEncode({
        'version': 1,
        'targetKey': lyricStorageKey(target),
        'target': {
          'platform': target.platform,
          'id': target.trackId,
          'path': target.localPath,
        },
        'title': title,
        'artist': artist,
        'source': source,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'lyric': bundle.lyric,
        'trans': bundle.translation,
        'roma': bundle.romanization,
      }),
    );
    if (!manual && data.length > limitBytes) return;
    final file = await _file(target, manual);
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(data, flush: true);
      if (canCommit != null && !canCommit()) throw StateError('歌词选择已失效');
      await temporary.rename(file.path);
      _statisticsChanges.add(++_statisticsRevision);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _delete(File file) async {
    await file.delete();
    _statisticsChanges.add(++_statisticsRevision);
  }

  Future<List<File>> _files(bool manual) async {
    final directory = await (manual
        ? _manualDirectory()
        : _automaticDirectory());
    if (!await directory.exists()) return [];
    return directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.json'))
        .cast<File>()
        .toList();
  }

  Future<void> _evict() async {
    final entries = <(File, FileStat)>[];
    for (final file in await _files(false)) {
      entries.add((file, await file.stat()));
    }
    entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var bytes = entries.fold<int>(0, (sum, entry) => sum + entry.$2.size);
    for (final entry in entries) {
      if (bytes <= limitBytes) break;
      await _delete(entry.$1);
      bytes -= entry.$2.size;
    }
  }

  Future<void> restoreDefault(LyricRequest target) {
    final key = lyricStorageKey(target);
    _versions[key] = (_versions[key] ?? 0) + 1;
    return _serial(() async {
      try {
        final file = await _file(target, true);
        if (await file.exists()) await _delete(file);
        await _deleteManualOffset(target);
      } finally {
        _changes.add(key);
      }
    });
  }

  /// Remove only this track's disposable lyrics and reload its default source.
  Future<void> refreshAutomatic(LyricRequest target) {
    automaticEpoch++;
    return _serial(() async {
      final file = await _file(target, false);
      if (await file.exists()) await _delete(file);
      _changes.add(lyricStorageKey(target));
    });
  }

  Future<void> clearAutomatic() {
    automaticEpoch++;
    return _serial(() async {
      for (final file in await _files(false)) {
        await _delete(file);
      }
    });
  }

  Future<void> clearManual() {
    _manualEpoch++;
    return _serial(() async {
      try {
        for (final file in await _files(true)) {
          await _delete(file);
        }
        await _deleteAllManualOffsets();
      } finally {
        _changes.add(null);
      }
    });
  }

  Future<LyricStorageStats> statistics() => _serial(() async {
    var automatic = 0;
    var manual = 0;
    final choices = await _files(true);
    for (final file in choices) {
      manual += await file.length();
    }
    for (final file in await _files(false)) {
      automatic += await file.length();
    }
    return LyricStorageStats(automatic, manual, choices.length);
  });
}

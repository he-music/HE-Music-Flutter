import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_music_database.dart';
import '../../domain/entities/download_task.dart';

class DownloadedMusicDataSource {
  DownloadedMusicDataSource({LocalMusicDatabase? database})
    : _database = database;

  final LocalMusicDatabase? _database;
  LocalMusicDatabase get _db => _database ?? appDatabase;

  Future<void> register(DownloadTask task, {bool overwrite = true}) async {
    if (task.status != DownloadTaskStatus.completed ||
        (task.filePath?.trim().isEmpty ?? true)) {
      return;
    }
    final row = DownloadedMusicEntry(
      taskId: task.id,
      songId: task.songId?.trim() ?? '',
      platform: task.platform?.trim() ?? '',
      downloadedAt: (task.finishedAt ?? task.createdAt).microsecondsSinceEpoch,
      payload: jsonEncode(task.toJson()),
    );
    if (overwrite) {
      await _db.into(_db.downloadedMusic).insertOnConflictUpdate(row);
    } else {
      await _db
          .into(_db.downloadedMusic)
          .insert(row, mode: InsertMode.insertOrIgnore);
    }
  }

  Stream<List<DownloadTask>> watchTasks() =>
      (_db.select(_db.downloadedMusic)..orderBy([
            (row) => OrderingTerm.desc(row.downloadedAt),
            (row) => OrderingTerm.asc(row.taskId),
          ]))
          .watch()
          .map((rows) => rows.map(_decode).toList(growable: false));

  Future<List<DownloadTask>> find(String songId, String platform) async {
    final rows =
        await (_db.select(_db.downloadedMusic)
              ..where(
                (row) =>
                    row.songId.equals(songId.trim()) &
                    row.platform.equals(platform.trim()),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.downloadedAt)]))
            .get();
    return rows.map(_decode).toList(growable: false);
  }

  Future<void> remove(String id) => (_db.delete(
    _db.downloadedMusic,
  )..where((row) => row.taskId.equals(id))).go();

  DownloadTask _decode(DownloadedMusicEntry row) =>
      DownloadTask.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
}

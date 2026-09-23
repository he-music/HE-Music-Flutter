import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_music_database.dart';
import '../../domain/entities/download_task.dart';

const _downloadTaskStoreKey = 'download.tasks.v2';

class DownloadTaskStoreDataSource {
  DownloadTaskStoreDataSource({LocalMusicDatabase? database})
    : _database = database;

  final LocalMusicDatabase? _database;
  LocalMusicDatabase get _db => _database ?? appDatabase;

  Future<void> _migrate() =>
      migratePreferences(_db, _downloadTaskStoreKey, (value) async {
        var order = 0;
        for (final raw in value as List<String>) {
          final task = DownloadTask.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          await _write(task, order++);
        }
      });

  Future<List<DownloadTask>> loadTasks() async {
    await _migrate();
    final rows = await (_db.select(
      _db.storedDownloadTasks,
    )..orderBy([(row) => OrderingTerm.asc(row.updatedAt)])).get();
    return rows
        .map(
          (row) => DownloadTask.fromJson(
            jsonDecode(row.payload) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> saveTask(DownloadTask task) async {
    await _migrate();
    await _write(task, DateTime.now().microsecondsSinceEpoch);
  }

  Future<void> _write(DownloadTask task, int order) async {
    await _db
        .into(_db.storedDownloadTasks)
        .insertOnConflictUpdate(
          StoredDownloadTask(
            taskId: task.id,
            updatedAt: order,
            payload: jsonEncode(task.toJson()),
          ),
        );
  }

  Future<void> deleteTask(String taskId) async {
    await _migrate();
    await (_db.delete(
      _db.storedDownloadTasks,
    )..where((row) => row.taskId.equals(taskId))).go();
  }
}

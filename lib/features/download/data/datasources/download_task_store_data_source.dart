import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_music_database.dart';
import '../../domain/entities/download_task.dart';
import 'downloaded_music_data_source.dart';

const _downloadTaskStoreKey = 'download.tasks.v2';

class DownloadTaskStoreDataSource {
  DownloadTaskStoreDataSource({LocalMusicDatabase? database})
    : _database = database;

  final LocalMusicDatabase? _database;
  LocalMusicDatabase get _db => _database ?? appDatabase;

  Future<void> _migrate() async {
    await migratePreferences(_db, _downloadTaskStoreKey, (value) async {
      var order = 0;
      for (final raw in value as List<String>) {
        final task = DownloadTask.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        await _write(task, order++);
      }
    });
    // Import the retained completed tasks once. Removing an offline entry must
    // not resurrect it on the next startup while its old task still exists.
    await _db.transaction(() async {
      const key = 'downloaded_music.v1';
      final marker = await (_db.select(
        _db.storageMigrations,
      )..where((row) => row.storageKey.equals(key))).getSingleOrNull();
      if (marker != null) return;
      final rows = await _db.select(_db.storedDownloadTasks).get();
      final library = DownloadedMusicDataSource(database: _db);
      for (final row in rows) {
        await library.register(
          DownloadTask.fromJson(
            jsonDecode(row.payload) as Map<String, dynamic>,
          ),
          overwrite: false,
        );
      }
      await _db
          .into(_db.storageMigrations)
          .insert(const StorageMigration(storageKey: key));
    });
  }

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
    await _db.transaction(() async {
      await _write(task, DateTime.now().microsecondsSinceEpoch);
      await DownloadedMusicDataSource(database: _db).register(task);
    });
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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_music_database.dart';

LocalMusicDatabase? _database;

/// App-lifetime connection shared by the library, player and downloads.
LocalMusicDatabase get appDatabase => _database ??= LocalMusicDatabase();

@visibleForTesting
void setAppDatabaseForTesting(LocalMusicDatabase database) {
  _database = database;
}

/// Import once, atomically. A failed cleanup is retried without reimporting stale
/// preferences over newer database records. Import failures retain legacy data.
Future<void> migratePreferences(
  LocalMusicDatabase db,
  String key,
  Future<void> Function(Object value) import,
) async {
  final prefs = await SharedPreferences.getInstance();
  await db.transaction(() async {
    final marker = await (db.select(
      db.storageMigrations,
    )..where((row) => row.storageKey.equals(key))).getSingleOrNull();
    if (marker != null) return;
    final value = prefs.get(key);
    if (value != null) await import(value);
    await db
        .into(db.storageMigrations)
        .insert(StorageMigration(storageKey: key));
  });
  if (prefs.containsKey(key)) await prefs.remove(key);
}

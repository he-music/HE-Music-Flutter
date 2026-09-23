import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_music_database.dart';
import '../../../../shared/models/he_music_models.dart';

const _cacheMarker = 'favorite_songs_cache';

/// One global cache; the server remains authoritative.
class FavoriteSongCacheDataSource {
  const FavoriteSongCacheDataSource({LocalMusicDatabase? database})
    : _database = database;
  final LocalMusicDatabase? _database;
  LocalMusicDatabase get _db => _database ?? appDatabase;

  Future<List<IdPlatformInfo>?> read() => _db.transaction(() async {
    final marker = await (_db.select(
      _db.storageMigrations,
    )..where((row) => row.storageKey.equals(_cacheMarker))).getSingleOrNull();
    if (marker == null) return null;
    final rows = await _db.select(_db.cachedFavoriteSongs).get();
    return rows
        .map((row) => IdPlatformInfo(id: row.songId, platform: row.platform))
        .toList();
  });

  Future<void> replace(List<IdPlatformInfo> songs) => _db.transaction(() async {
    await _db.delete(_db.cachedFavoriteSongs).go();
    await _db.batch((batch) {
      for (final song in songs) {
        if (song.id.trim().isEmpty || song.platform.trim().isEmpty) continue;
        batch.insert(
          _db.cachedFavoriteSongs,
          CachedFavoriteSong(
            platform: song.platform.trim(),
            songId: song.id.trim(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    await _db
        .into(_db.storageMigrations)
        .insert(
          const StorageMigration(storageKey: _cacheMarker),
          mode: InsertMode.insertOrIgnore,
        );
  });

  Future<void> setSong(IdPlatformInfo song, {required bool liked}) =>
      _db.transaction(() async {
        if (liked) {
          await _db
              .into(_db.cachedFavoriteSongs)
              .insert(
                CachedFavoriteSong(
                  platform: song.platform.trim(),
                  songId: song.id.trim(),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        } else {
          await (_db.delete(_db.cachedFavoriteSongs)..where(
                (row) =>
                    row.platform.equals(song.platform.trim()) &
                    row.songId.equals(song.id.trim()),
              ))
              .go();
        }
        await _db
            .into(_db.storageMigrations)
            .insert(
              const StorageMigration(storageKey: _cacheMarker),
              mode: InsertMode.insertOrIgnore,
            );
      });

  Future<void> clear() => _db.transaction(() async {
    await _db.delete(_db.cachedFavoriteSongs).go();
    await (_db.delete(
      _db.storageMigrations,
    )..where((row) => row.storageKey.equals(_cacheMarker))).go();
  });
}

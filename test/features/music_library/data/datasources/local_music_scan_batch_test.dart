import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_scan.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_dao.dart';

LocalSongsCompanion _song(String id, {int modifiedAt = 100}) =>
    LocalSongsCompanion(
      id: Value(id),
      title: Value('Song $id'),
      artist: const Value('Artist'),
      album: const Value('Album'),
      durationMs: const Value(180000),
      filePath: Value('/music/$id.mp3'),
      fileSize: const Value(1024),
      mimeType: const Value('audio/mpeg'),
      modifiedAt: Value(modifiedAt),
      genre: const Value(''),
    );

void main() {
  late LocalMusicDatabase db;
  late LocalMusicDao dao;
  setUp(() {
    db = LocalMusicDatabase.forTesting();
    dao = LocalMusicDao(db);
  });
  tearDown(() => db.close());

  test(
    'unchanged scan touches only batch/status across SQLite parameter chunks',
    () async {
      final songs = [for (var i = 0; i < 405; i++) _song('$i')];
      await dao.commitScanBatch(
        songs: songs,
        artistsBySongId: {
          for (var i = 0; i < 405; i++) '$i': ['Artist'],
        },
        scanSource: 'macos',
        batchId: 'first',
      );
      await db.customStatement('UPDATE local_songs SET updated_at = 42');
      await dao.markFileMissing('0');
      await db.customStatement('CREATE TABLE metadata_writes (song_id TEXT)');
      await db.customStatement(
        'CREATE TRIGGER audit_metadata AFTER UPDATE OF title, artist, album ON local_songs BEGIN INSERT INTO metadata_writes VALUES (NEW.id); END',
      );

      await dao.commitScanBatch(
        songs: [],
        artistsBySongId: {},
        unchangedSongIds: [for (var i = 0; i < 405; i++) '$i'],
        scanSource: 'macos',
        batchId: 'second',
        replaceOnlyProvidedArtists: true,
      );

      final rows = await db.select(db.localSongs).get();
      expect(rows, hasLength(405));
      expect(
        rows.every(
          (row) =>
              row.updatedAt == 42 &&
              row.scanBatchId == 'second' &&
              row.status == 'active',
        ),
        isTrue,
      );
      expect(
        await db.customSelect('SELECT * FROM metadata_writes').get(),
        isEmpty,
      );
      expect(await dao.getSongArtists('0'), ['Artist']);
    },
  );

  test(
    'absent artwork is cached, changed files reset it and stale jobs cannot overwrite it',
    () async {
      await dao.upsertSongs([_song('1')], 'macos', 'first');
      final job = (await dao.getPendingArtwork()).single;
      await dao.commitArtworkResults([
        LocalArtworkResult(job, LocalArtworkState.absent),
      ]);
      expect(await dao.getPendingArtwork(), isEmpty);

      await dao.upsertSongs([_song('1', modifiedAt: 200)], 'macos', 'second');
      final changed = (await dao.getPendingArtwork()).single;
      expect(changed.modifiedAt, 200);
      await dao.commitArtworkResults([
        LocalArtworkResult(job, LocalArtworkState.present),
      ]);
      final row = await db.select(db.localSongs).getSingle();
      expect(row.artworkState, 'unknown');
      expect(row.hasArtwork, 0);
      expect(row.artworkCheckedAt, isNull);

      await dao.commitArtworkResults([
        LocalArtworkResult(changed, LocalArtworkState.present),
      ]);
      await dao.upsertSongs([_song('1', modifiedAt: 300)], 'macos', 'third');
      expect((await db.select(db.localSongs).getSingle()).hasArtwork, 0);
      expect(await dao.getPendingArtwork(), hasLength(1));
    },
  );

  test(
    'failed artwork waits for retry cooldown, but a new file version retries immediately',
    () async {
      await dao.upsertSongs([_song('1')], 'macos', 'first');
      final job = (await dao.getPendingArtwork()).single;
      await dao.commitArtworkResults([
        LocalArtworkResult(job, LocalArtworkState.failed),
      ]);
      final row = await db.select(db.localSongs).getSingle();
      final checked = DateTime.fromMillisecondsSinceEpoch(
        row.artworkCheckedAt!,
      );
      expect(
        await dao.getPendingArtwork(
          now: checked.add(const Duration(hours: 23)),
        ),
        isEmpty,
      );
      expect(
        await dao.getPendingArtwork(
          now: checked.add(const Duration(hours: 24)),
        ),
        hasLength(1),
      );
      await dao.upsertSongs([_song('1', modifiedAt: 200)], 'macos', 'second');
      expect(await dao.getPendingArtwork(), hasLength(1));
    },
  );

  test(
    'v6 migration preserves extracted artwork and schedules unknown songs',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'local_music_migration_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/library.db');
      var database = LocalMusicDatabase.forTesting(file: file);
      await LocalMusicDao(
        database,
      ).upsertSongs([_song('1'), _song('2')], 'macos', 'first');
      await database.customStatement(
        "UPDATE local_songs SET has_artwork = 1 WHERE id = '1'",
      );
      await database.customStatement(
        'ALTER TABLE local_songs DROP COLUMN artwork_state',
      );
      await database.customStatement(
        'ALTER TABLE local_songs DROP COLUMN artwork_checked_at',
      );
      await database.customStatement('PRAGMA user_version = 6');
      await database.close();
      database = LocalMusicDatabase.forTesting(file: file);
      try {
        final rows = await LocalMusicDao(database).getSongRowsBySource('macos');
        expect(rows['1']!.artworkState, 'present');
        expect(rows['1']!.hasArtwork, 1);
        expect(rows['2']!.artworkState, 'unknown');
      } finally {
        await database.close();
      }
    },
  );
}

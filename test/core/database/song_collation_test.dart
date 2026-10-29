import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_dao.dart';

void main() {
  test(
    'background connections rebuild missing collation indexes and reopen safely',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'song-collation-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.db');
      final original = LocalMusicDatabase.forTesting(file: file);
      try {
        await LocalMusicDao(original).upsertSongs(
          [
            for (final (id, title) in [('z', '上海'), ('m', '阿里'), ('a', '阿里')])
              LocalSongsCompanion.insert(
                id: id,
                title: title,
                artist: title,
                album: title,
                genre: const Value(''),
                durationMs: 180000,
                filePath: '/$id.mp3',
                fileSize: 1024,
                mimeType: 'audio/mpeg',
                scanBatchId: 'first',
                scanSource: 'macos',
                createdAt: 100,
                updatedAt: 100,
              ),
          ],
          'macos',
          'first',
        );
        // Existing libraries have no ICU indexes; reopening should add them
        // without a table migration or losing any songs.
        for (final field in ['title', 'artist', 'album']) {
          await original.customStatement(
            'DROP INDEX idx_local_songs_status_${field}_zh_cn_v1',
          );
        }
      } finally {
        await original.close();
      }

      for (var reopen = 0; reopen < 2; reopen++) {
        final database = LocalMusicDatabase.forTesting(file: file);
        try {
          final dao = LocalMusicDao(database);
          for (final field in ['title', 'artist', 'album']) {
            final ascending = await dao.watchSongs(sortBy: field).first;
            final descending = await dao
                .watchSongs(sortBy: field, ascending: false)
                .first;
            expect(ascending.map((song) => song.id), ['a', 'm', 'z']);
            expect(descending.map((song) => song.id), ['z', 'a', 'm']);
          }
          final indexes = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE '%_zh_cn_v1'",
              )
              .get();
          expect(indexes, hasLength(3));
          final version = await database
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(version.read<int>('user_version'), 7);
        } finally {
          await database.close();
        }
      }
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/database/app_database.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_history_data_source.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('v3 upgrade preserves library data and adds playback tables', () async {
    final dir = await Directory.systemTemp.createTemp('he-storage-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/local_music.db');
    final original = LocalMusicDatabase.forTesting(NativeDatabase(file));
    await original.customStatement(
      "INSERT INTO scan_folders (platform,path,bookmark) VALUES ('macos','/Music','bookmark')",
    );
    for (final table in [
      'playback_queue_entries',
      'playback_queues',
      'playback_history',
      'stored_download_tasks',
      'cached_favorite_songs',
      'storage_migrations',
    ]) {
      await original.customStatement('DROP TABLE $table');
    }
    await original.customStatement('PRAGMA user_version = 3');
    await original.close();
    final upgraded = LocalMusicDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    final folders = await upgraded.select(upgraded.scanFolders).get();
    expect(folders.single.path, '/Music');
    expect(folders.single.bookmark, 'bookmark');
    expect(await upgraded.select(upgraded.playbackQueues).get(), isEmpty);
    expect(await upgraded.select(upgraded.cachedFavoriteSongs).get(), isEmpty);
    expect(
      (await upgraded.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      4,
    );
  });

  test(
    'failed import rolls back rows and marker, and retains legacy data for retry',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('legacy-test', 'payload');
      await expectLater(
        migratePreferences(appDatabase, 'legacy-test', (_) async {
          await appDatabase
              .into(appDatabase.playbackQueues)
              .insert(const PlaybackQueue(slot: 'current', metadata: '{}'));
          throw StateError('interrupted');
        }),
        throwsStateError,
      );
      expect(
        await appDatabase.select(appDatabase.playbackQueues).get(),
        isEmpty,
      );
      expect(
        await appDatabase.select(appDatabase.storageMigrations).get(),
        isEmpty,
      );
      expect(prefs.getString('legacy-test'), 'payload');
      await migratePreferences(appDatabase, 'legacy-test', (_) async {
        await appDatabase
            .into(appDatabase.playbackQueues)
            .insert(const PlaybackQueue(slot: 'current', metadata: '{}'));
      });
      expect(prefs.containsKey('legacy-test'), isFalse);
      expect(
        await appDatabase.select(appDatabase.playbackQueues).get(),
        hasLength(1),
      );
    },
  );

  test(
    'queue index updates do not rewrite song entries and duplicates survive',
    () async {
      const source = PlayerQueueDataSource();
      const song = PlayerTrack(id: 'same', title: 'Song', platform: 'qq');
      await source.saveQueue(
        queue: [song, song],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );
      await appDatabase.customStatement(
        'CREATE TABLE entry_writes (value INTEGER)',
      );
      await appDatabase.customStatement(
        'CREATE TRIGGER track_entry_insert AFTER INSERT ON playback_queue_entries BEGIN INSERT INTO entry_writes VALUES (1); END',
      );
      await appDatabase.customStatement(
        'CREATE TRIGGER track_entry_update AFTER UPDATE ON playback_queue_entries BEGIN INSERT INTO entry_writes VALUES (1); END',
      );
      await source.saveQueue(
        queue: [song, song],
        currentIndex: 1,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );
      expect(
        await appDatabase.customSelect('SELECT * FROM entry_writes').get(),
        isEmpty,
      );
      final restored = await source.readQueue();
      expect(restored!.queue, hasLength(2));
      expect(restored.currentIndex, 1);
    },
  );

  test(
    'legacy history imports once and retains latest 100 unique songs',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final old = jsonEncode(
        List.generate(
          120,
          (i) => {
            'id': '$i',
            'title': 'Song $i',
            'platform': 'qq',
            'playedAt': 1000 - i,
          },
        ),
      );
      await prefs.setString('player_play_history_v1', old);
      const source = PlayerHistoryDataSource();
      expect(await source.getCount(), 100);
      expect((await source.listHistory()).first.id, '0');
      expect(prefs.containsKey('player_play_history_v1'), isFalse);
      await source.clearHistory();
      // Simulates process exit after DB commit but before old preferences cleanup.
      await prefs.setString('player_play_history_v1', old);
      expect(await source.listHistory(), isEmpty);
      expect(prefs.containsKey('player_play_history_v1'), isFalse);
      await source.appendTrack(
        const PlayerTrack(id: 'new', title: 'New', platform: 'qq'),
      );
      expect((await source.listHistory()).single.id, 'new');
    },
  );
}

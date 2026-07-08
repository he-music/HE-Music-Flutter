import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_dao.dart';

void main() {
  late LocalMusicDatabase db;
  late LocalMusicDao dao;

  setUp(() async {
    db = LocalMusicDatabase.forTesting(NativeDatabase.memory());
    dao = LocalMusicDao(db);
    // 等待数据库初始化完成
    await db.customSelect('SELECT 1').getSingle();
  });

  tearDown(() async {
    await db.close();
  });

  /// 构建测试用歌曲 Companion
  LocalSongsCompanion buildSong({
    required String id,
    String title = 'Test Song',
    String artist = 'Test Artist',
    String album = 'Test Album',
    String genre = '',
    int? year,
    int? trackNumber,
    int durationMs = 180000,
    String filePath = '/music/test.mp3',
    String? folderPath,
    int fileSize = 5000000,
    String mimeType = 'audio/mpeg',
    int hasArtwork = 0,
    int metadataEdited = 0,
    String status = 'active',
    String scanBatchId = 'batch-1',
    String scanSource = 'macos',
    int? modifiedAt,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return LocalSongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      genre: Value(genre),
      year: Value(year),
      trackNumber: Value(trackNumber),
      durationMs: Value(durationMs),
      filePath: Value(filePath),
      folderPath: Value(folderPath),
      fileSize: Value(fileSize),
      mimeType: Value(mimeType),
      hasArtwork: Value(hasArtwork),
      metadataEdited: Value(metadataEdited),
      status: Value(status),
      scanBatchId: Value(scanBatchId),
      scanSource: Value(scanSource),
      createdAt: Value(now),
      updatedAt: Value(now),
      modifiedAt: Value(modifiedAt),
    );
  }

  group('LocalMusicDao', () {
    group('upsertSongs', () {
      test('批量插入歌曲后可查询到', () async {
        final songs = [
          buildSong(id: '1', title: 'Song A', filePath: '/a.mp3'),
          buildSong(id: '2', title: 'Song B', filePath: '/b.mp3'),
        ];
        await dao.upsertSongs(songs, 'macos', 'batch-1');

        final all = await dao.getSongsWithoutArtwork();
        expect(all.length, 2);
      });

      test('相同 file_path 的歌曲会被更新而非重复插入', () async {
        final song1 = buildSong(
          id: '1',
          title: 'Old Title',
          filePath: '/same.mp3',
        );
        await dao.upsertSongs([song1], 'macos', 'batch-1');

        final song2 = buildSong(
          id: '1',
          title: 'New Title',
          filePath: '/same.mp3',
        );
        await dao.upsertSongs([song2], 'macos', 'batch-2');

        // 应该只有 1 条记录
        final results = await dao.getSongsWithoutArtwork();
        expect(results.length, 1);
      });
    });

    group('deleteStaleBySource', () {
      test('只清理指定 scan_source 且 metadata_edited=0 的旧批次记录', () async {
        // batch-1 的记录（raw SQL 硬编码 metadata_edited=0）
        await dao.upsertSongs(
          [
            buildSong(
              id: '1',
              filePath: '/a.mp3',
              scanSource: 'macos',
              scanBatchId: 'batch-1',
            ),
            buildSong(
              id: '2',
              filePath: '/b.mp3',
              scanSource: 'macos',
              scanBatchId: 'batch-1',
            ),
          ],
          'macos',
          'batch-1',
        );
        // 标记 id=2 为已编辑
        await dao.markMetadataEdited('2');

        // batch-2 扫描完成
        await dao.upsertSongs(
          [
            buildSong(
              id: '3',
              filePath: '/c.mp3',
              scanSource: 'macos',
              scanBatchId: 'batch-2',
            ),
          ],
          'macos',
          'batch-2',
        );

        // 清理旧批次
        await dao.deleteStaleBySource('macos', 'batch-2');

        // id=1 应被清理（metadata_edited=0，旧批次）
        // id=2 应保留（metadata_edited=1）
        // id=3 应保留（当前批次）
        final all = await db.select(db.localSongs).get();
        expect(all.length, 2);
        final ids = all.map((r) => r.id).toSet();
        expect(ids.contains('2'), true); // 保留编辑过的
        expect(ids.contains('3'), true); // 保留当前批次
        expect(ids.contains('1'), false); // 清理旧批次
      });

      test('不同 scan_source 的记录不会被清理', () async {
        await dao.upsertSongs(
          [
            buildSong(
              id: '1',
              filePath: '/a.mp3',
              scanSource: 'android',
              scanBatchId: 'batch-1',
              metadataEdited: 0,
            ),
          ],
          'android',
          'batch-1',
        );

        await dao.upsertSongs(
          [
            buildSong(
              id: '2',
              filePath: '/b.mp3',
              scanSource: 'macos',
              scanBatchId: 'batch-2',
              metadataEdited: 0,
            ),
          ],
          'macos',
          'batch-2',
        );

        // 只清理 macos 的旧批次
        await dao.deleteStaleBySource('macos', 'batch-2');

        // android 的记录应保留
        final all = await db.select(db.localSongs).get();
        expect(all.length, 2);
      });
    });

    group('markMetadataEdited', () {
      test('标记后 metadataEdited 为 1', () async {
        await dao.upsertSongs(
          [buildSong(id: '1', filePath: '/a.mp3', metadataEdited: 0)],
          'macos',
          'batch-1',
        );

        await dao.markMetadataEdited('1');

        final rows = await (db.select(
          db.localSongs,
        )..where((t) => t.id.equals('1'))).get();
        expect(rows.first.metadataEdited, 1);
      });
    });

    group('markFileMissing', () {
      test('标记后 status 为 missing', () async {
        await dao.upsertSongs(
          [buildSong(id: '1', filePath: '/a.mp3', status: 'active')],
          'macos',
          'batch-1',
        );

        await dao.markFileMissing('1');

        final rows = await (db.select(
          db.localSongs,
        )..where((t) => t.id.equals('1'))).get();
        expect(rows.first.status, 'missing');
      });

      test('missing 状态的歌曲不出现在 watchSongs 结果中', () async {
        await dao.upsertSongs(
          [
            buildSong(id: '1', title: 'Active', filePath: '/a.mp3'),
            buildSong(id: '2', title: 'Missing', filePath: '/b.mp3'),
          ],
          'macos',
          'batch-1',
        );
        // 标记 id=2 为 missing
        await dao.markFileMissing('2');

        final stream = dao.watchSongs();
        final songs = await stream.first;
        expect(songs.length, 1);
        expect(songs.first.title, 'Active');
      });
    });

    group('updateSongMetadata', () {
      test('更新后字段值正确', () async {
        await dao.upsertSongs(
          [
            buildSong(
              id: '1',
              filePath: '/a.mp3',
              title: 'Old',
              artist: 'Old Artist',
            ),
          ],
          'macos',
          'batch-1',
        );

        await dao.updateSongMetadata(
          songId: '1',
          title: 'New Title',
          artist: 'New Artist',
          album: 'New Album',
          genre: 'Rock',
          year: 2024,
        );

        final rows = await (db.select(
          db.localSongs,
        )..where((t) => t.id.equals('1'))).get();
        final row = rows.first;
        expect(row.title, 'New Title');
        expect(row.artist, 'New Artist');
        expect(row.album, 'New Album');
        expect(row.genre, 'Rock');
        expect(row.year, 2024);
      });
    });

    group('incrementPlayCount', () {
      test('首次播放创建 play_stats 记录', () async {
        await dao.upsertSongs(
          [buildSong(id: '1', filePath: '/a.mp3')],
          'macos',
          'batch-1',
        );

        await dao.incrementPlayCount('1', durationMs: 180000);

        final stats = await db.select(db.playStats).get();
        expect(stats.length, 1);
        expect(stats.first.songId, '1');
        expect(stats.first.playCount, 1);
        expect(stats.first.totalDurationMs, 180000);
      });

      test('重复播放累加 playCount 和 totalDurationMs', () async {
        await dao.upsertSongs(
          [buildSong(id: '1', filePath: '/a.mp3')],
          'macos',
          'batch-1',
        );

        await dao.incrementPlayCount('1', durationMs: 180000);
        await dao.incrementPlayCount('1', durationMs: 200000);

        final stats = await db.select(db.playStats).get();
        expect(stats.first.playCount, 2);
        expect(stats.first.totalDurationMs, 380000);
      });
    });

    group('scanFolders CRUD', () {
      test('添加和查询文件夹', () async {
        await dao.addScanFolder('macos', '/Users/test/Music');
        await dao.addScanFolder('macos', '/Users/test/Downloads');

        final folders = await dao.getScanFolders('macos');
        expect(folders.length, 2);
      });

      test('重复添加同路径不会重复插入', () async {
        await dao.addScanFolder('macos', '/Users/test/Music');
        await dao.addScanFolder('macos', '/Users/test/Music');

        final folders = await dao.getScanFolders('macos');
        expect(folders.length, 1);
      });

      test('删除文件夹', () async {
        await dao.addScanFolder('macos', '/Users/test/Music');
        await dao.removeScanFolder('macos', '/Users/test/Music');

        final folders = await dao.getScanFolders('macos');
        expect(folders.length, 0);
      });

      test('启用/禁用文件夹', () async {
        await dao.addScanFolder('macos', '/Users/test/Music');
        await dao.toggleScanFolder('macos', '/Users/test/Music', false);

        final folders = await dao.getScanFolders('macos');
        expect(folders.first.enabled, 0);

        await dao.toggleScanFolder('macos', '/Users/test/Music', true);
        final folders2 = await dao.getScanFolders('macos');
        expect(folders2.first.enabled, 1);
      });
    });

    group('clearAll', () {
      test('清除所有歌曲', () async {
        await dao.upsertSongs(
          [
            buildSong(id: '1', filePath: '/a.mp3'),
            buildSong(id: '2', filePath: '/b.mp3'),
          ],
          'macos',
          'batch-1',
        );

        await dao.clearAll();

        final songs = await db.select(db.localSongs).get();
        expect(songs.length, 0);
      });
    });

    group('getSongsWithoutArtwork', () {
      test('只返回 has_artwork=0 且 status=active 的歌曲', () async {
        // upsertSongs 硬编码 has_artwork=0，插入后用 markArtworkExtracted 标记
        await dao.upsertSongs(
          [
            buildSong(id: '1', filePath: '/a.mp3', status: 'active'),
            buildSong(id: '2', filePath: '/b.mp3', status: 'active'),
            buildSong(id: '3', filePath: '/c.mp3', status: 'missing'),
          ],
          'macos',
          'batch-1',
        );
        // 标记 id=2 已有封面
        await dao.markArtworkExtracted('2');
        // 标记 id=3 为 missing（虽然 status 已经是 missing）
        await dao.markFileMissing('3');

        final result = await dao.getSongsWithoutArtwork();
        expect(result.length, 1);
        expect(result.first, '/a.mp3');
      });
    });

    group('markArtworkExtracted', () {
      test('标记后 hasArtwork 为 1', () async {
        await dao.upsertSongs(
          [buildSong(id: '1', filePath: '/a.mp3', hasArtwork: 0)],
          'macos',
          'batch-1',
        );

        await dao.markArtworkExtracted('1');

        final rows = await (db.select(
          db.localSongs,
        )..where((t) => t.id.equals('1'))).get();
        expect(rows.first.hasArtwork, 1);
      });
    });
  });
}

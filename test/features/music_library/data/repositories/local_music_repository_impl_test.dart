import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/local_audio_metadata_reader.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_dao.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_query_data_source.dart';
import 'package:he_music_flutter/features/music_library/data/repositories/local_music_repository_impl.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';

/// 创建内存数据库用于测试
LocalMusicDatabase _createTestDb() {
  return LocalMusicDatabase.forTesting(NativeDatabase.memory());
}

void main() {
  test(
    'single-file import preserves other songs, history and edited tags',
    () async {
      final db = _createTestDb();
      addTearDown(db.close);
      final directory = await Directory.systemTemp.createTemp('song_import_');
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/download.mp3',
      ).writeAsBytes([1, 2]);
      final source = _FakeLocalMusicQueryDataSource(
        tracks: [_makeTrack(id: 'existing', filePath: '/music/existing.mp3')],
      );
      final metadata = _FakeLocalAudioMetadataReader(
        metadata: const LocalAudioMetadata(
          title: 'Downloaded song',
          artist: 'Artist A / Artist B',
          duration: Duration(minutes: 3),
        ),
      );
      final dao = LocalMusicDao(db);
      final repo = LocalMusicRepositoryImpl(source, metadata, dao);
      await repo.scanSongs();
      await dao.incrementPlayCount('existing');
      final original = await dao.getSongRow('existing');

      await repo.importSong(file.path);
      expect(await db.select(db.localSongs).get(), hasLength(2));
      expect(await dao.getSongRow('existing'), original);
      expect((await db.select(db.playStats).get()).single.songId, 'existing');
      expect(await dao.getSongArtists(file.path), ['Artist A', 'Artist B']);
      expect(metadata.readPaths, ['/music/existing.mp3', file.path]);

      await repo.importSong(file.uri.toString());
      expect(metadata.readCount, 2);
      expect(await db.select(db.localSongs).get(), hasLength(2));
      await db.customStatement(
        'UPDATE local_songs SET title = ?, artist = ?, metadata_edited = 1 WHERE id = ?',
        ['Edited title', 'Edited artist', file.path],
      );
      await file.writeAsBytes([1, 2, 3]);
      await repo.importSong(file.path);
      expect((await dao.getSongRow(file.path))!.title, 'Edited title');
      expect(await dao.getSongArtists(file.path), ['Edited artist']);

      source.tracks = [
        source.tracks.single,
        (await source.queryFile(file.path))!,
      ];
      await repo.scanSongs();
      expect(await db.select(db.localSongs).get(), hasLength(2));
      expect((await dao.getSongRow(file.path))!.title, 'Edited title');
    },
  );

  test(
    'incomplete iOS scan retains inaccessible media and complete scan removes stale songs',
    () async {
      final db = _createTestDb();
      addTearDown(db.close);
      final source = _FakeLocalMusicQueryDataSource(
        platform: 'ios',
        tracks: [
          _makeTrack(id: 'media', filePath: 'ipod-library://song.mp3?id=1'),
        ],
      );
      final dao = LocalMusicDao(db);
      final repo = LocalMusicRepositoryImpl(
        source,
        _FakeLocalAudioMetadataReader(),
        dao,
      );
      await repo.scanSongs();
      source.tracks = [
        _makeTrack(id: 'download', filePath: '/app/Downloads/song.mp3'),
      ];
      source.isComplete = false;
      await repo.scanSongs();
      expect(await db.select(db.localSongs).get(), hasLength(2));
      source.isComplete = true;
      await repo.scanSongs();
      expect((await db.select(db.localSongs).get()).single.id, 'download');
    },
  );

  test('download import waits for an in-flight full scan to commit', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final directory = await Directory.systemTemp.createTemp(
      'scan_import_race_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/new.mp3').writeAsBytes([1]);
    final source = _FakeLocalMusicQueryDataSource()
      ..scanGate = Completer<void>();
    final metadata = _FakeLocalAudioMetadataReader(
      metadata: const LocalAudioMetadata(duration: Duration(minutes: 3)),
    );
    final dao = LocalMusicDao(db);
    final repo = LocalMusicRepositoryImpl(source, metadata, dao);
    final scan = repo.scanSongs();
    final importing = repo.importSong(file.path);
    await Future<void>.delayed(Duration.zero);
    expect(source.fileQueries, 0);
    source.scanGate!.complete();
    await scan;
    await importing;
    expect((await db.select(db.localSongs).get()).single.id, file.path);
  });

  test('invalid imports leave the existing library untouched', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final directory = await Directory.systemTemp.createTemp('invalid_import_');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/short.mp3').writeAsBytes([1]);
    final source = _FakeLocalMusicQueryDataSource(
      tracks: [_makeTrack(id: 'existing', filePath: '/music/existing.mp3')],
    );
    final metadata = _FakeLocalAudioMetadataReader();
    final dao = LocalMusicDao(db);
    final repo = LocalMusicRepositoryImpl(source, metadata, dao);
    await repo.scanSongs();
    metadata.metadata = const LocalAudioMetadata(
      duration: Duration(seconds: 30),
    );
    await repo.importSong(file.path);
    await repo.importSong('${directory.path}/missing.mp3');
    await repo.importSong('${directory.path}/lyric.lrc');
    expect((await db.select(db.localSongs).get()).single.id, 'existing');
  });

  test(
    'file deletion hides the song but preserves history through scanning and redownload',
    () async {
      final db = _createTestDb();
      addTearDown(db.close);
      final directory = await Directory.systemTemp.createTemp('missing_song_');
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('${directory.path}/song.mp3').writeAsBytes([1]);
      final dao = LocalMusicDao(db);
      final repo = LocalMusicRepositoryImpl(
        _FakeLocalMusicQueryDataSource(),
        _FakeLocalAudioMetadataReader(
          metadata: const LocalAudioMetadata(
            title: 'Song',
            artist: 'Artist',
            duration: Duration(minutes: 3),
          ),
        ),
        dao,
      );
      await repo.importSong(file.path);
      await dao.incrementPlayCount(file.path);
      await repo.markFileMissingByPath(file.path);
      expect((await dao.getSongRow(file.path))!.status, 'active');
      await file.delete();
      await repo.markFileMissingByPath(file.uri.toString());
      expect((await dao.getSongRow(file.path))!.status, 'missing');
      expect(await repo.watchSongs().first, isEmpty);
      expect(await repo.watchArtists().first, isEmpty);
      await repo.scanSongs();
      expect((await dao.getSongRow(file.path))!.status, 'missing');
      expect((await db.select(db.playStats).get()).single.songId, file.path);
      await file.writeAsBytes([1, 2]);
      await repo.importSong(file.path);
      expect((await repo.watchSongs().first).single.filePath, file.path);
      expect((await dao.getSongRow(file.path))!.status, 'active');
      expect((await db.select(db.playStats).get()).single.songId, file.path);
      expect(await db.select(db.localSongs).get(), hasLength(1));
    },
  );

  test('scanSongs processes tracks and returns LocalSong list', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(
      tracks: [
        _makeTrack(id: '1', filePath: '/music/artist - album - song.mp3'),
      ],
    );
    final fakeMetadata = _FakeLocalAudioMetadataReader(
      metadata: const LocalAudioMetadata(
        title: 'song',
        artist: 'artist',
        album: 'album',
        duration: Duration(seconds: 180),
      ),
    );
    final dao = LocalMusicDao(db);

    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    final songs = await repo.scanSongs();

    expect(songs, hasLength(1));
    expect(songs.first.title, 'song');
    expect(songs.first.artist, 'artist');
    expect(songs.first.album, 'album');
  });

  test('scanSongs filters tracks shorter than 60 seconds', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(
      tracks: [
        _makeTrack(id: '1', filePath: '/music/short.mp3', duration: 30000),
        _makeTrack(id: '2', filePath: '/music/long.mp3', duration: 180000),
      ],
    );
    final fakeMetadata = _FakeLocalAudioMetadataReader();
    final dao = LocalMusicDao(db);

    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    final songs = await repo.scanSongs();

    // 只有 180 秒的歌曲被保留，30 秒的被过滤
    expect(songs, hasLength(1));
    expect(songs.first.id, '2');
  });

  test(
    'scanSongs keeps tracks when tag duration corrects short query duration',
    () async {
      final db = _createTestDb();
      addTearDown(db.close);
      final fakeDataSource = _FakeLocalMusicQueryDataSource(
        tracks: [
          _makeTrack(id: '1', filePath: '/music/song.mp3', duration: 30000),
        ],
      );
      final fakeMetadata = _FakeLocalAudioMetadataReader(
        metadata: const LocalAudioMetadata(duration: Duration(seconds: 180)),
      );
      final dao = LocalMusicDao(db);

      final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

      final songs = await repo.scanSongs();

      expect(fakeMetadata.readCount, 1);
      expect(songs, hasLength(1));
      expect(songs.first.id, '1');
    },
  );

  test('scanSongs filters call recording paths', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(
      tracks: [
        _makeTrack(id: '1', filePath: '/storage/callrecord/recording.mp3'),
        _makeTrack(
          id: '2',
          filePath: '/storage/music/normal.mp3',
          duration: 180000,
        ),
      ],
    );
    final fakeMetadata = _FakeLocalAudioMetadataReader();
    final dao = LocalMusicDao(db);

    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    final songs = await repo.scanSongs();

    expect(songs, hasLength(1));
    expect(songs.first.id, '2');
  });

  test(
    'scanSongs falls back to parsed filename when metadata is null',
    () async {
      final db = _createTestDb();
      addTearDown(db.close);
      final fakeDataSource = _FakeLocalMusicQueryDataSource(
        tracks: [
          _makeTrack(
            id: '1',
            title: '',
            artist: '',
            album: '',
            filePath: '/music/张三 - 经典专辑 - 好歌.mp3',
            duration: 200000,
          ),
        ],
      );
      final fakeMetadata = _FakeLocalAudioMetadataReader(metadata: null);
      final dao = LocalMusicDao(db);

      final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

      final songs = await repo.scanSongs();

      expect(songs, hasLength(1));
      expect(songs.first.title, '好歌');
      expect(songs.first.artist, '张三');
      expect(songs.first.album, '经典专辑');
    },
  );

  test('scanSongs returns empty list when no tracks found', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(tracks: []);
    final fakeMetadata = _FakeLocalAudioMetadataReader();
    final dao = LocalMusicDao(db);

    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    final songs = await repo.scanSongs();

    expect(songs, isEmpty);
  });

  test('scanSongs splits artist by / separator and links to DB', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(
      tracks: [
        _makeTrack(id: '1', filePath: '/music/song.mp3', duration: 180000),
      ],
    );
    final fakeMetadata = _FakeLocalAudioMetadataReader(
      metadata: const LocalAudioMetadata(
        title: 'song',
        artist: '歌手A / 歌手B',
        album: 'album',
        duration: Duration(seconds: 180),
      ),
    );
    final dao = LocalMusicDao(db);

    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    await repo.scanSongs();

    // 验证歌手关联写入了数据库
    final artists = await dao.getSongArtists('1');
    expect(artists, containsAll(['歌手A', '歌手B']));
  });

  test('scanSongs skips tag read for unchanged files', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(
      tracks: [
        _makeTrack(
          id: '1',
          filePath: '/music/song.mp3',
          size: 1000,
          modifiedAt: 100,
        ),
      ],
    );
    final fakeMetadata = _FakeLocalAudioMetadataReader(
      metadata: const LocalAudioMetadata(
        title: '第一次标题',
        artist: '歌手A',
        album: '专辑A',
        duration: Duration(seconds: 180),
      ),
    );
    final dao = LocalMusicDao(db);
    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    await repo.scanSongs();
    fakeMetadata.metadata = const LocalAudioMetadata(
      title: '第二次标题',
      artist: '歌手B',
      album: '专辑B',
      duration: Duration(seconds: 180),
    );
    final songs = await repo.scanSongs();

    expect(fakeMetadata.readCount, 1);
    expect(songs, hasLength(1));
    expect(songs.first.title, '第一次标题');
    expect(await dao.getSongArtists('1'), ['歌手A']);
  });

  test('scanSongs rereads tags when file fingerprint changes', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(
      tracks: [
        _makeTrack(
          id: '1',
          filePath: '/music/song.mp3',
          size: 1000,
          modifiedAt: 100,
        ),
      ],
    );
    final fakeMetadata = _FakeLocalAudioMetadataReader(
      metadata: const LocalAudioMetadata(
        title: '旧标题',
        artist: '旧歌手',
        album: '旧专辑',
        duration: Duration(seconds: 180),
      ),
    );
    final dao = LocalMusicDao(db);
    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    await repo.scanSongs();
    fakeDataSource.tracks = [
      _makeTrack(
        id: '1',
        filePath: '/music/song.mp3',
        size: 1000,
        modifiedAt: 200,
      ),
    ];
    fakeMetadata.metadata = const LocalAudioMetadata(
      title: '新标题',
      artist: '新歌手',
      album: '新专辑',
      duration: Duration(seconds: 180),
    );
    final songs = await repo.scanSongs();

    expect(fakeMetadata.readCount, 2);
    expect(songs.single.title, '新标题');
    expect(await dao.getSongArtists('1'), ['新歌手']);
  });

  test('scanSongs stores file stat modified time when available', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final tempDir = await Directory.systemTemp.createTemp('local_music_repo_');
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}/song.mp3');
    await file.writeAsBytes(<int>[1, 2, 3, 4]);
    final modified = DateTime(2026, 1, 2, 3, 4, 5);
    await file.setLastModified(modified);
    final fakeDataSource = _FakeLocalMusicQueryDataSource(
      tracks: [
        _makeTrack(id: '1', filePath: file.path, duration: 180000, size: 4),
      ],
    );
    final fakeMetadata = _FakeLocalAudioMetadataReader();
    final dao = LocalMusicDao(db);

    final repo = LocalMusicRepositoryImpl(fakeDataSource, fakeMetadata, dao);

    await repo.scanSongs();

    final row = await db.select(db.localSongs).getSingle();
    expect(row.modifiedAt, modified.millisecondsSinceEpoch);
  });

  test('watchSongs delegates to dao', () {
    final db = _createTestDb();
    addTearDown(db.close);
    final dao = LocalMusicDao(db);
    final repo = LocalMusicRepositoryImpl(
      _FakeLocalMusicQueryDataSource(),
      _FakeLocalAudioMetadataReader(),
      dao,
    );

    final stream = repo.watchSongs(
      searchQuery: 'test',
      sortBy: 'artist',
      ascending: false,
    );

    expect(stream, isA<Stream<List<LocalSong>>>());
  });

  test('clearLibrary delegates to dao', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final dao = LocalMusicDao(db);
    final repo = LocalMusicRepositoryImpl(
      _FakeLocalMusicQueryDataSource(),
      _FakeLocalAudioMetadataReader(),
      dao,
    );

    // 不应抛异常
    await repo.clearLibrary();
  });

  test('incrementPlayCount delegates to dao', () async {
    final db = _createTestDb();
    addTearDown(db.close);
    final dao = LocalMusicDao(db);
    final repo = LocalMusicRepositoryImpl(
      _FakeLocalMusicQueryDataSource(
        tracks: [
          _makeTrack(
            id: 'song-1',
            filePath: '/music/song.mp3',
            duration: 180000,
          ),
        ],
      ),
      _FakeLocalAudioMetadataReader(
        metadata: const LocalAudioMetadata(
          title: 'song',
          duration: Duration(seconds: 180),
        ),
      ),
      dao,
    );

    // 先扫描写入歌曲，满足外键约束
    await repo.scanSongs();
    // 不应抛异常
    await repo.incrementPlayCount('song-1');
  });
}

LocalMusicQueryTrack _makeTrack({
  required String id,
  String title = '',
  String artist = '',
  String album = '',
  required String filePath,
  int duration = 180000,
  String mimeType = 'audio/mpeg',
  int size = 1024000,
  int? modifiedAt,
}) {
  return LocalMusicQueryTrack(
    id: id,
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    filePath: filePath,
    mimeType: mimeType,
    size: size,
    modifiedAt: modifiedAt,
  );
}

class _FakeLocalMusicQueryDataSource extends LocalMusicQueryDataSource {
  _FakeLocalMusicQueryDataSource({this.tracks = const [], super.platform});

  List<LocalMusicQueryTrack> tracks;
  bool isComplete = true;
  Completer<void>? scanGate;
  int fileQueries = 0;

  @override
  Future<LocalMusicQueryTrack?> queryFile(String filePath) {
    fileQueries++;
    return super.queryFile(filePath);
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<LocalMusicScanResult> scanSongs({
    List<String> scanFolders = const [],
  }) async {
    await scanGate?.future;
    return LocalMusicScanResult(tracks, isComplete: isComplete);
  }
}

class _FakeLocalAudioMetadataReader extends LocalAudioMetadataReader {
  _FakeLocalAudioMetadataReader({this.metadata});

  LocalAudioMetadata? metadata;
  int readCount = 0;
  final readPaths = <String>[];

  @override
  Future<LocalAudioMetadata?> read(
    String filePath, {
    bool fetchArtwork = false,
    bool fetchLyrics = true,
  }) async {
    readCount++;
    readPaths.add(filePath);
    return metadata;
  }
}

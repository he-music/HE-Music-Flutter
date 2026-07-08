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
  );
}

class _FakeLocalMusicQueryDataSource extends LocalMusicQueryDataSource {
  _FakeLocalMusicQueryDataSource({this.tracks = const []});

  final List<LocalMusicQueryTrack> tracks;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<LocalMusicQueryTrack>> scanSongs({
    List<String> scanFolders = const [],
  }) async => tracks;
}

class _FakeLocalAudioMetadataReader extends LocalAudioMetadataReader {
  _FakeLocalAudioMetadataReader({this.metadata});

  final LocalAudioMetadata? metadata;

  @override
  Future<LocalAudioMetadata?> read(
    String filePath, {
    bool fetchArtwork = false,
  }) async => metadata;
}

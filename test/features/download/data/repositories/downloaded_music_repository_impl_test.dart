import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/core/audio/local_audio_metadata_reader.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';
import 'package:he_music_flutter/features/download/data/datasources/download_task_store_data_source.dart';
import 'package:he_music_flutter/features/download/data/datasources/downloaded_music_data_source.dart';
import 'package:he_music_flutter/features/download/data/repositories/downloaded_music_repository_impl.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/demo_lyric_data_source.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/online_lyric_data_source.dart';
import 'package:he_music_flutter/features/lyrics/data/repositories/lyric_repository_impl.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'completed music survives deleting its task and reopening SQLite',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final task = await fixture.song('first');
      await fixture.tasks.saveTask(task);
      await fixture.tasks.deleteTask(task.id);
      await fixture.reopen();

      expect(await fixture.tasks.loadTasks(), isEmpty);
      final songs = await fixture.repository.watchSongs().first;
      expect(songs.single.task.id, task.id);
      expect(songs.single.isAvailable, isTrue);
      expect(songs.single.task.artworkPath, task.artworkPath);
      expect(songs.single.task.lyricPath, task.lyricPath);
    },
  );

  test(
    'legacy completed tasks import once; removed songs stay removed',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final task = await fixture.song('legacy');
      SharedPreferences.setMockInitialValues({
        'download.tasks.v2': [jsonEncode(task.toJson())],
      });
      expect((await fixture.repository.watchSongs().first).single.id, task.id);
      await fixture.repository.remove(task.id);
      await fixture.reopen();
      expect(await fixture.repository.watchSongs().first, isEmpty);
      expect(await fixture.tasks.loadTasks(), hasLength(1));
    },
  );

  test(
    'schema 4 retained task rows migrate into the new independent index',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final task = await fixture.song('upgrade');
      await fixture.tasks.saveTask(task);
      await fixture.database.customStatement('DROP TABLE downloaded_music');
      await fixture.database.customStatement('DROP TABLE lyric_offsets');
      await fixture.database.customStatement(
        "DELETE FROM storage_migrations WHERE storage_key = 'downloaded_music.v1'",
      );
      await fixture.database.customStatement(
        'ALTER TABLE local_songs DROP COLUMN artwork_state',
      );
      await fixture.database.customStatement(
        'ALTER TABLE local_songs DROP COLUMN artwork_checked_at',
      );
      await fixture.database.customStatement('PRAGMA user_version = 4');
      await fixture.reopen();
      expect((await fixture.repository.watchSongs().first).single.id, task.id);
    },
  );

  test(
    'missing files remain visible; same-platform lookup skips missing variants',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final first = await fixture.song('older');
      final second = await fixture.song('newer');
      await fixture.tasks.saveTask(first);
      await fixture.tasks.saveTask(second);
      await File(second.filePath!).delete();
      final songs = await fixture.repository.watchSongs().first;
      expect(songs.where((song) => !song.isAvailable).single.id, second.id);
      expect(
        (await fixture.repository.findPlayable(
          songId: 'song-1',
          platform: 'qq',
        ))?.id,
        first.id,
      );
      expect(
        await fixture.repository.findPlayable(
          songId: 'song-1',
          platform: 'netease',
        ),
        isNull,
      );
      await File(first.filePath!).writeAsBytes([]);
      expect(
        await fixture.repository.findPlayable(songId: 'song-1', platform: 'qq'),
        isNull,
      );
    },
  );

  test('unfinished tasks never enter the offline library', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    await fixture.tasks.saveTask(
      (await fixture.song(
        'partial',
      )).copyWith(status: DownloadTaskStatus.downloading),
    );
    expect(await fixture.repository.watchSongs().first, isEmpty);
  });

  for (final network in [
    NetworkConnectionType.offline,
    NetworkConnectionType.wifi,
  ]) {
    test('downloaded audio precedes remote resolution on $network', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final task = await fixture.song('play');
      await fixture.tasks.saveTask(task);
      await fixture.tasks.deleteTask(task.id);
      final loaded = <Uri>[];
      var requests = 0;
      final handler = HeAudioHandler(
        initialConfig: AppConfigState.initial.copyWith(
          enableDesktopLyric: false,
        ),
        downloadedMusicRepository: fixture.repository,
        networkStatusPort: _Network(network),
        fetchSongUrlOverride:
            ({required songId, required platform, quality, format}) async {
              requests++;
              return {'url': 'https://audio.invalid/song.mp3'};
            },
        fetchLyricsOverride: ({required trackId, platform, localPath}) async =>
            const LyricDocument.empty(),
        setAudioSourceOverride: (source, player) async {
          loaded.add((source as UriAudioSource).uri);
          return const Duration(minutes: 3);
        },
        playOverride: (_) async {},
        disposeOverride: (_) async {},
      );
      addTearDown(handler.disposeHandler);
      await handler.setQueueData(const [
        AudioTrack(id: 'song-1', title: 'Song', platform: 'qq', url: ''),
      ]);
      expect(loaded.single, Uri.file(task.filePath!));
      expect(requests, 0);
      expect(handler.mediaItem.value?.id, 'song-1');
      expect(handler.mediaItem.value?.artUri, Uri.file(task.artworkPath!));
      expect(handler.mediaItem.value?.extras?['format'], 'flac');
      final alternate = await fixture.song('selected');
      await fixture.tasks.saveTask(alternate);
      await handler.setQueueData([
        AudioTrack(
          id: 'song-1',
          title: 'Song',
          platform: 'qq',
          url: '',
          path: alternate.filePath,
        ),
      ]);
      expect(loaded, [Uri.file(task.filePath!), Uri.file(alternate.filePath!)]);
      expect(requests, 0);
    });
  }

  test(
    'missing downloaded audio falls back to remote playback when connected',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final task = await fixture.song('deleted');
      await fixture.tasks.saveTask(task);
      await File(task.filePath!).delete();
      var requests = 0;
      final loaded = <Uri>[];
      final handler = HeAudioHandler(
        initialConfig: AppConfigState.initial.copyWith(
          enableDesktopLyric: false,
        ),
        downloadedMusicRepository: fixture.repository,
        networkStatusPort: const _Network(NetworkConnectionType.wifi),
        fetchSongUrlOverride:
            ({required songId, required platform, quality, format}) async {
              requests++;
              return {'url': 'https://audio.invalid/song.mp3'};
            },
        fetchLyricsOverride: ({required trackId, platform, localPath}) async =>
            const LyricDocument.empty(),
        setAudioSourceOverride: (source, player) async {
          loaded.add((source as UriAudioSource).uri);
          return const Duration(minutes: 3);
        },
        disposeOverride: (_) async {},
      );
      addTearDown(handler.disposeHandler);
      await handler.setQueueData(const [
        AudioTrack(id: 'song-1', title: 'Song', platform: 'qq', url: ''),
      ]);
      expect(requests, 1);
      expect(loaded.single.scheme, 'https');
    },
  );

  test(
    'downloaded sidecar lyrics work with online identity and no lyric requests',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final task = await fixture.song('lyrics');
      await fixture.tasks.saveTask(task);
      final alternate = await fixture.song('alternate');
      await File(
        alternate.lyricPath!,
      ).writeAsString('[00:01.00]alternate lyrics');
      await fixture.tasks.saveTask(alternate);
      final online = _OnlineLyrics();
      final repository = LyricRepositoryImpl(
        online,
        DemoLyricDataSource(),
        const LocalAudioMetadataReader(),
        downloadedMusicRepository: fixture.repository,
        store: LyricStore(
          manualDirectory: () async =>
              Directory('${fixture.directory.path}/manual'),
          automaticDirectory: () async =>
              Directory('${fixture.directory.path}/cache'),
        ),
      );
      final document = await repository.fetchLyrics(
        trackId: 'song-1',
        platform: 'qq',
        localPath: task.filePath,
      );
      expect(document.lines.single.text, 'offline lyrics');
      expect(document.source, LyricSource.local);
      final automatic = await repository.fetchLyrics(
        trackId: 'song-1',
        platform: 'qq',
      );
      expect(automatic.lines.single.text, 'alternate lyrics');
      expect(online.requests, 0);
    },
  );
}

class _Fixture {
  _Fixture(this.directory) {
    _open();
  }
  final Directory directory;
  late LocalMusicDatabase database;
  late DownloadTaskStoreDataSource tasks;
  late DownloadedMusicRepositoryImpl repository;

  static Future<_Fixture> create() async =>
      _Fixture(await Directory.systemTemp.createTemp('downloaded_music_'));

  void _open() {
    database = LocalMusicDatabase.forTesting(
      NativeDatabase(File('${directory.path}/music.db')),
    );
    tasks = DownloadTaskStoreDataSource(database: database);
    repository = DownloadedMusicRepositoryImpl(
      dataSource: DownloadedMusicDataSource(database: database),
      taskStore: tasks,
    );
  }

  Future<void> reopen() async {
    await database.close();
    _open();
  }

  Future<void> dispose() async {
    await database.close();
    await directory.delete(recursive: true);
  }

  Future<DownloadTask> song(String id) async {
    final audio = File('${directory.path}/$id.flac');
    final lyric = File('${directory.path}/$id-renamed.lrc');
    final cover = File('${directory.path}/$id.cover');
    await audio.writeAsBytes([1, 2, 3]);
    await lyric.writeAsString('[00:01.00]offline lyrics');
    await cover.writeAsBytes([1, 2]);
    return DownloadTask.queued(
      id: id,
      title: 'Song $id',
      url: 'https://audio.invalid/song.mp3',
      songId: 'song-1',
      platform: 'qq',
      artist: 'Artist',
      album: 'Album',
      quality: DownloadTaskQuality(
        label: 'FLAC',
        bitrate: 999,
        fileExtension: 'flac',
      ),
    ).copyWith(
      status: DownloadTaskStatus.completed,
      filePath: audio.path,
      lyricPath: lyric.path,
      artworkPath: cover.path,
      finishedAt: DateTime.now(),
      progress: 1,
      resolvedFileExtension: 'flac',
    );
  }
}

class _Network implements NetworkStatusPort {
  const _Network(this.lastKnown);
  @override
  final NetworkConnectionType lastKnown;
  @override
  Future<NetworkConnectionType> current() async => lastKnown;
  @override
  Stream<NetworkConnectionType> get changes => const Stream.empty();
}

class _OnlineLyrics extends OnlineLyricDataSource {
  _OnlineLyrics() : super(OnlineApiClient(Dio()));
  int requests = 0;
  @override
  Future<RawLyricBundle?> fetchRawLyric({
    required String trackId,
    required String platform,
  }) async {
    requests++;
    throw StateError('Offline lyrics must not require an API');
  }
}

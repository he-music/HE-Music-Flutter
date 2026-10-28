import 'dart:async';
import 'dart:io';

import 'package:audiotags/audiotags.dart' as at;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/local_audio_metadata_reader.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_extractor.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_scan.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_dao.dart';

at.Picture _cover() => at.Picture(
  pictureType: at.PictureType.coverFront,
  mimeType: at.MimeType.jpeg,
  bytes: Uint8List.fromList([1, 2, 3]),
);

class _RecordingDao extends LocalMusicDao {
  _RecordingDao(super.db);
  final batches = <int>[];
  @override
  Future<void> commitArtworkResults(List<LocalArtworkResult> results) async {
    batches.add(results.length);
    await super.commitArtworkResults(results);
  }
}

void main() {
  late LocalMusicDatabase db;
  late _RecordingDao dao;
  late Directory directory;
  setUp(() async {
    db = LocalMusicDatabase.forTesting(NativeDatabase.memory());
    dao = _RecordingDao(db);
    directory = await Directory.systemTemp.createTemp('local_artwork_');
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> seed(int count) => dao.upsertSongs(
    [
      for (var i = 0; i < count; i++)
        LocalSongsCompanion(
          id: Value('$i'),
          title: Value('$i'),
          artist: const Value('Artist'),
          album: const Value('Album'),
          durationMs: const Value(180000),
          filePath: Value('/music/$i.mp3'),
          fileSize: const Value(100),
          mimeType: const Value('audio/mpeg'),
          modifiedAt: const Value(100),
          genre: const Value(''),
        ),
    ],
    'macos',
    'first',
  );

  test('cover-only reads stay bounded and update the DB in batches', () async {
    await seed(65);
    var calls = 0;
    var running = 0;
    var maxRunning = 0;
    final extractor = LocalArtworkExtractor(
      dao,
      LocalAudioMetadataReader(
        readArtwork: (_) async {
          calls++;
          running++;
          if (running > maxRunning) maxRunning = running;
          await Future<void>.delayed(Duration.zero);
          running--;
          return _cover();
        },
        readTag: (_) => throw StateError('Full metadata must not be read'),
      ),
      artworkDirectory: () async => directory.path,
    );

    expect(await extractor.extractAll(), 65);
    expect(maxRunning, 3);
    expect(dao.batches, [30, 30, 5]);
    expect(await extractor.getArtworkBytes('/music/0.mp3'), [1, 2, 3]);
    expect(await extractor.extractAll(), 0);
    expect(calls, 65);
  });

  test('no artwork is cached while read failures remain retryable', () async {
    await seed(2);
    var calls = 0;
    final extractor = LocalArtworkExtractor(
      dao,
      LocalAudioMetadataReader(
        readArtwork: (path) async {
          calls++;
          if (path.endsWith('1.mp3')) {
            throw const FileSystemException('unavailable');
          }
          return null;
        },
      ),
      artworkDirectory: () async => directory.path,
    );

    expect(await extractor.extractAll(), 0);
    final rows = await dao.getSongRowsBySource('macos');
    expect(rows['0']!.artworkState, 'absent');
    expect(rows['1']!.artworkState, 'failed');
    expect(await extractor.extractAll(), 0);
    expect(calls, 2);
  });

  test(
    'a replacement task waits for cancelled native reads and ignores their results',
    () async {
      await seed(1);
      final started = Completer<void>();
      final pendingCover = Completer<at.Picture?>();
      var calls = 0;
      final extractor = LocalArtworkExtractor(
        dao,
        LocalAudioMetadataReader(
          readArtwork: (_) async {
            calls++;
            if (calls == 1) {
              started.complete();
              return pendingCover.future;
            }
            return _cover();
          },
        ),
        artworkDirectory: () async => directory.path,
      );

      final first = extractor.extractAll();
      await started.future;
      final second = extractor.extractAll();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      pendingCover.complete(null);
      expect(await first, 0);
      expect(await second, 1);
      expect(
        (await dao.getSongRowsBySource('macos'))['0']!.artworkState,
        'present',
      );
    },
  );
}

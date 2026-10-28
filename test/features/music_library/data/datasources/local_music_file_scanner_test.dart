import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_file_scanner.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('local_file_scan_');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'overlapping roots, aliases and link cycles enumerate each audio file once',
    () async {
      final album = await Directory(p.join(directory.path, 'album')).create();
      final song = await File(
        p.join(album.path, 'song.FLAC'),
      ).writeAsBytes([1, 2, 3]);
      await File(p.join(album.path, 'notes.txt')).writeAsString('ignored');
      await Link(p.join(directory.path, 'alias')).create(album.path);
      await Link(p.join(album.path, 'cycle')).create(directory.path);
      await Link(p.join(directory.path, 'song-link.flac')).create(song.path);
      await Link(
        p.join(directory.path, 'missing.mp3'),
      ).create(p.join(directory.path, 'missing-target.mp3'));

      final files = await const LocalMusicFileScanner().scan([
        album.path,
        directory.path,
        directory.path,
      ]);

      expect(files, hasLength(1));
      expect(files.single.size, 3);
      expect(
        files.single.modifiedAt,
        (await song.stat()).modified.millisecondsSinceEpoch,
      );
    },
  );

  test('a root alias preserves the configured display path', () async {
    final actual = await Directory(p.join(directory.path, 'actual')).create();
    await File(p.join(actual.path, 'song.mp3')).writeAsBytes([1]);
    final alias = await Link(
      p.join(directory.path, 'alias'),
    ).create(actual.path);

    final files = await const LocalMusicFileScanner().scan([
      alias.path,
      directory.path,
    ]);

    expect(files.single.path, p.join(alias.path, 'song.mp3'));
  });

  test(
    'unavailable configured root fails instead of returning a partial library',
    () async {
      await File(p.join(directory.path, 'song.mp3')).writeAsBytes([1]);
      await expectLater(
        const LocalMusicFileScanner().scan([
          directory.path,
          p.join(directory.path, 'missing'),
        ]),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'batched attributes retain every file across batch boundaries',
    () async {
      for (var index = 0; index < 19; index++) {
        await File(
          p.join(directory.path, '$index.mp3'),
        ).writeAsBytes(List.filled(index + 1, 0));
      }
      final files = await const LocalMusicFileScanner(
        statConcurrency: 4,
      ).scan([directory.path]);
      expect(files, hasLength(19));
      expect(files.map((file) => file.size).toSet(), {
        for (var size = 1; size <= 19; size++) size,
      });
    },
  );
}

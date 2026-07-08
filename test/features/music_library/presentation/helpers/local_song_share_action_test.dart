import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/presentation/helpers/local_song_share_action.dart';

void main() {
  test('shareLocalSongIfAvailable shares song when file exists', () async {
    final sharedSongs = <LocalSong>[];
    var missingCalled = false;
    final song = _makeSong(filePath: '/music/song.mp3');

    final shared = await shareLocalSongIfAvailable(
      song: song,
      fileExists: (_) async => true,
      shareSong: (song) async => sharedSongs.add(song),
      onMissing: () => missingCalled = true,
    );

    expect(shared, isTrue);
    expect(sharedSongs, [song]);
    expect(missingCalled, isFalse);
  });

  test(
    'shareLocalSongIfAvailable reports missing file without sharing',
    () async {
      final sharedSongs = <LocalSong>[];
      var missingCalled = false;
      final song = _makeSong(filePath: '/music/missing.mp3');

      final shared = await shareLocalSongIfAvailable(
        song: song,
        fileExists: (_) async => false,
        shareSong: (song) async => sharedSongs.add(song),
        onMissing: () => missingCalled = true,
      );

      expect(shared, isFalse);
      expect(sharedSongs, isEmpty);
      expect(missingCalled, isTrue);
    },
  );
}

LocalSong _makeSong({required String filePath}) {
  return LocalSong(
    id: 'song-1',
    title: '本地歌曲',
    filePath: filePath,
    artist: '歌手',
    album: '专辑',
    duration: const Duration(minutes: 3),
    mimeType: 'audio/mpeg',
    size: 1024,
  );
}

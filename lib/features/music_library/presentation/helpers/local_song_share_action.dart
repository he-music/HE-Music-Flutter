import '../../domain/entities/local_song.dart';

typedef LocalSongFileExists = Future<bool> Function(String filePath);
typedef LocalSongShareHandler = Future<void> Function(LocalSong song);

Future<bool> shareLocalSongIfAvailable({
  required LocalSong song,
  required LocalSongFileExists fileExists,
  required LocalSongShareHandler shareSong,
  required void Function() onMissing,
}) async {
  if (!await fileExists(song.filePath)) {
    onMissing();
    return false;
  }
  await shareSong(song);
  return true;
}

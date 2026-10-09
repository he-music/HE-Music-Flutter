import '../entities/downloaded_song.dart';

abstract class DownloadedMusicRepository {
  Stream<List<DownloadedSong>> watchSongs();
  Future<DownloadedSong?> findPlayable({
    required String songId,
    required String platform,
    String? filePath,
  });
  Future<void> remove(String id);
}

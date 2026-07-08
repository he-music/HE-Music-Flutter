import '../entities/lyric_document.dart';

abstract class LyricRepository {
  Future<LyricDocument> fetchLyrics({
    required String trackId,
    String? platform,
    String? localPath,
  });
}

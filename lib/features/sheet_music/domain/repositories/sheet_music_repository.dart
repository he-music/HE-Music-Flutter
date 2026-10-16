import '../entities/sheet_music_info.dart';

abstract class SheetMusicRepository {
  Future<List<SheetMusicInfo>> fetchList({
    required String platform,
    required String songId,
  });

  Future<SheetMusicInfo> fetchDetail({
    required String platform,
    required String id,
    required String songId,
  });
}

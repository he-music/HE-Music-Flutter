import '../../domain/entities/sheet_music_info.dart';
import '../../domain/repositories/sheet_music_repository.dart';
import '../datasources/sheet_music_api_client.dart';

class SheetMusicRepositoryImpl implements SheetMusicRepository {
  const SheetMusicRepositoryImpl(this._apiClient);

  final SheetMusicApiClient _apiClient;

  @override
  Future<List<SheetMusicInfo>> fetchList({
    required String platform,
    required String songId,
  }) => _apiClient.fetchList(platform: platform, songId: songId);

  @override
  Future<SheetMusicInfo> fetchDetail({
    required String platform,
    required String id,
    required String songId,
  }) => _apiClient.fetchDetail(platform: platform, id: id, songId: songId);
}

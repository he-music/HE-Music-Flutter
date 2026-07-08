import '../../domain/entities/video_detail_content.dart';
import '../../domain/entities/video_detail_request.dart';
import '../../domain/repositories/video_detail_repository.dart';
import '../datasources/video_detail_api_client.dart';

class VideoDetailRepositoryImpl implements VideoDetailRepository {
  const VideoDetailRepositoryImpl(this._apiClient);

  final VideoDetailApiClient _apiClient;

  @override
  Future<VideoDetailContent> fetchDetail(VideoDetailRequest request) {
    return _apiClient.fetchDetail(request);
  }
}

import '../entities/video_detail_content.dart';
import '../entities/video_detail_request.dart';

abstract class VideoDetailRepository {
  Future<VideoDetailContent> fetchDetail(VideoDetailRequest request);
}

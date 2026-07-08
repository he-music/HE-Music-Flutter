import '../../../../shared/models/he_music_models.dart';
import 'video_detail_link.dart';

class VideoDetailContent {
  const VideoDetailContent({required this.info, required this.links});

  final MvInfo info;
  final List<VideoDetailLink> links;

  String get id => info.id;
  String get platform => info.platform;
  String get title => info.name;
  String get coverUrl => info.cover;
  String get creator => info.creator;
  String get playCount => info.playCount;
  int get duration => info.duration;
  String get description => info.description;
}

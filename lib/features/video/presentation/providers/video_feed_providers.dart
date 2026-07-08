import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_feed_state.dart';
import '../controllers/video_feed_controller.dart';

export '../../data/providers/video_feed_providers.dart';

final videoFeedControllerProvider =
    NotifierProvider<VideoFeedController, VideoFeedState>(
      VideoFeedController.new,
    );

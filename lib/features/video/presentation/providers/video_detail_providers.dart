import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_detail_state.dart';
import '../controllers/video_detail_controller.dart';

export '../../data/providers/video_detail_providers.dart';

final videoDetailControllerProvider =
    NotifierProvider<VideoDetailController, VideoDetailState>(
      VideoDetailController.new,
    );

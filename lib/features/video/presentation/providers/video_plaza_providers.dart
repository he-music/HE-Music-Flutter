import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_plaza_state.dart';
import '../controllers/video_plaza_controller.dart';

export '../../data/providers/video_plaza_providers.dart';

final videoPlazaControllerProvider =
    NotifierProvider<VideoPlazaController, VideoPlazaState>(
      VideoPlazaController.new,
    );

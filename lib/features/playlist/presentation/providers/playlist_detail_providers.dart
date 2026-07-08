import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist_detail_state.dart';
import '../controllers/playlist_detail_controller.dart';

export '../../data/providers/playlist_detail_providers.dart';

final playlistDetailControllerProvider =
    NotifierProvider<PlaylistDetailController, PlaylistDetailState>(
      PlaylistDetailController.new,
    );

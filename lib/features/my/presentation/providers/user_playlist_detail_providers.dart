import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlist/domain/entities/playlist_detail_state.dart';
import '../controllers/user_playlist_detail_controller.dart';

export '../../data/providers/user_playlist_detail_providers.dart';

final userPlaylistDetailControllerProvider = NotifierProvider.autoDispose
    .family<UserPlaylistDetailController, PlaylistDetailState, String>(
      (_) => UserPlaylistDetailController(),
    );

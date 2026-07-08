import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist_plaza_state.dart';
import '../controllers/playlist_plaza_controller.dart';

export '../../data/providers/playlist_plaza_providers.dart';

final playlistPlazaControllerProvider =
    NotifierProvider<PlaylistPlazaController, PlaylistPlazaState>(
      PlaylistPlazaController.new,
    );

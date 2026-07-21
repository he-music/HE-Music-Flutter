import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/song_detail_state.dart';
import '../controllers/song_detail_controller.dart';

export '../../data/providers/song_detail_providers.dart';

final songDetailControllerProvider = NotifierProvider.autoDispose
    .family<SongDetailController, SongDetailState, String>(
      (_) => SongDetailController(),
    );

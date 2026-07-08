import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/album_detail_state.dart';
import '../controllers/album_detail_controller.dart';

export '../../data/providers/album_detail_providers.dart';

final albumDetailControllerProvider =
    NotifierProvider<AlbumDetailController, AlbumDetailState>(
      AlbumDetailController.new,
    );

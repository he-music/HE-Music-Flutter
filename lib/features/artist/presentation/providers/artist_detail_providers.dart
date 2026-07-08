import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/artist_detail_state.dart';
import '../controllers/artist_detail_controller.dart';

export '../../data/providers/artist_detail_providers.dart';

final artistDetailControllerProvider =
    NotifierProvider<ArtistDetailController, ArtistDetailState>(
      ArtistDetailController.new,
    );

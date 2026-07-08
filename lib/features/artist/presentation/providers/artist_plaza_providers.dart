import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/artist_plaza_state.dart';
import '../controllers/artist_plaza_controller.dart';

export '../../data/providers/artist_plaza_providers.dart';

final artistPlazaControllerProvider =
    NotifierProvider<ArtistPlazaController, ArtistPlazaState>(
      ArtistPlazaController.new,
    );

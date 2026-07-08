import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/new_song_api_client.dart';
import '../../domain/entities/new_song_page_state.dart';
import '../controllers/new_song_page_controller.dart';

final newSongApiClientProvider = Provider<NewSongApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return NewSongApiClient(dio);
});

final newSongPageControllerProvider =
    NotifierProvider<NewSongPageController, NewSongPageState>(
      NewSongPageController.new,
    );

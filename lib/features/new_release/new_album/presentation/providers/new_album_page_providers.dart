import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/api_dio_provider.dart';
import '../../data/datasources/new_album_api_client.dart';
import '../../domain/entities/new_album_page_state.dart';
import '../controllers/new_album_page_controller.dart';

final newAlbumApiClientProvider = Provider<NewAlbumApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return NewAlbumApiClient(dio);
});

final newAlbumPageControllerProvider =
    NotifierProvider<NewAlbumPageController, NewAlbumPageState>(
      NewAlbumPageController.new,
    );

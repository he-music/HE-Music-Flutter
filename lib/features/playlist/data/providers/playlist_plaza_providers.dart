import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/playlist_plaza_api_client.dart';

export '../datasources/playlist_plaza_api_client.dart';

final playlistPlazaApiClientProvider = Provider<PlaylistPlazaApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return PlaylistPlazaApiClient(dio);
});

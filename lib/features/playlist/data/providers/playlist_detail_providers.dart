import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/playlist_detail_repository.dart';
import '../datasources/playlist_detail_api_client.dart';
import '../repositories/playlist_detail_repository_impl.dart';

final playlistDetailApiClientProvider = Provider<PlaylistDetailApiClient>((
  ref,
) {
  final dio = ref.watch(apiDioProvider);
  return PlaylistDetailApiClient(dio);
});

final playlistDetailRepositoryProvider = Provider<PlaylistDetailRepository>((
  ref,
) {
  final apiClient = ref.watch(playlistDetailApiClientProvider);
  return PlaylistDetailRepositoryImpl(apiClient);
});

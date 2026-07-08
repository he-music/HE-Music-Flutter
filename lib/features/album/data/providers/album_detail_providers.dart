import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/album_detail_repository.dart';
import '../datasources/album_detail_api_client.dart';
import '../repositories/album_detail_repository_impl.dart';

final albumDetailApiClientProvider = Provider<AlbumDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return AlbumDetailApiClient(dio);
});

final albumDetailRepositoryProvider = Provider<AlbumDetailRepository>((ref) {
  final apiClient = ref.watch(albumDetailApiClientProvider);
  return AlbumDetailRepositoryImpl(apiClient);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/artist_detail_repository.dart';
import '../datasources/artist_detail_api_client.dart';
import '../repositories/artist_detail_repository_impl.dart';

final artistDetailApiClientProvider = Provider<ArtistDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return ArtistDetailApiClient(dio);
});

final artistDetailRepositoryProvider = Provider<ArtistDetailRepository>((ref) {
  final apiClient = ref.watch(artistDetailApiClientProvider);
  return ArtistDetailRepositoryImpl(apiClient);
});

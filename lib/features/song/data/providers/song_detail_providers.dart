import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/song_detail_repository.dart';
import '../datasources/song_detail_api_client.dart';
import '../repositories/song_detail_repository_impl.dart';

final songDetailApiClientProvider = Provider<SongDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return SongDetailApiClient(dio);
});

final songDetailRepositoryProvider = Provider<SongDetailRepository>((ref) {
  final apiClient = ref.watch(songDetailApiClientProvider);
  return SongDetailRepositoryImpl(apiClient);
});

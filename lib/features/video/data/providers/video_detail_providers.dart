import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/video_detail_repository.dart';
import '../datasources/video_detail_api_client.dart';
import '../repositories/video_detail_repository_impl.dart';

final videoDetailApiClientProvider = Provider<VideoDetailApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return VideoDetailApiClient(dio);
});

final videoDetailRepositoryProvider = Provider<VideoDetailRepository>((ref) {
  final apiClient = ref.watch(videoDetailApiClientProvider);
  return VideoDetailRepositoryImpl(apiClient);
});

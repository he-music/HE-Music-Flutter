import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/video_plaza_api_client.dart';

export '../datasources/video_plaza_api_client.dart';

final videoFeedApiClientProvider = Provider<VideoPlazaApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return VideoPlazaApiClient(dio);
});

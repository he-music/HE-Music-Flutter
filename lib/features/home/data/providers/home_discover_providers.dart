import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/home_discover_api_client.dart';

export '../datasources/home_discover_api_client.dart';

final homeDiscoverApiClientProvider = Provider<HomeDiscoverApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return HomeDiscoverApiClient(dio);
});

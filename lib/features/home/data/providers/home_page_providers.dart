import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/home_page_api_client.dart';

export '../datasources/home_page_api_client.dart';

final homePageApiClientProvider = Provider<HomePageApiClient>((ref) {
  return HomePageApiClient(ref.watch(apiDioProvider));
});

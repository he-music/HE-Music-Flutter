import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../device_api_client.dart';

final deviceApiClientProvider = Provider<DeviceApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return DeviceApiClient(dio);
});

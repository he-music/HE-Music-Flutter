import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/captcha_api_client.dart';

export '../datasources/captcha_api_client.dart';

final captchaApiClientProvider = Provider<CaptchaApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return CaptchaApiClient(dio);
});

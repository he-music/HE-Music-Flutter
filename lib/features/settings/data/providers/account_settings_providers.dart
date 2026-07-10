import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../account_settings_api_client.dart';

final accountSettingsApiClientProvider = Provider<AccountSettingsApiClient>((
  ref,
) {
  return AccountSettingsApiClient(ref.watch(apiDioProvider));
});

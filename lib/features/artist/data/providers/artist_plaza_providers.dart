import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/artist_plaza_api_client.dart';

export '../datasources/artist_plaza_api_client.dart';

final artistPlazaApiClientProvider = Provider<ArtistPlazaApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return ArtistPlazaApiClient(dio);
});

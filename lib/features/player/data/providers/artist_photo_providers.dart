import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/artist_photo_api_client.dart';

final artistPhotoApiClientProvider = Provider<ArtistPhotoApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return ArtistPhotoApiClient(dio);
});

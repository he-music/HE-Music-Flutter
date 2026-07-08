import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/radio_repository.dart';
import '../datasources/radio_api_client.dart';
import '../repositories/radio_repository_impl.dart';

export '../datasources/radio_api_client.dart';

final radioApiClientProvider = Provider<RadioApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return RadioApiClient(dio);
});

final radioRepositoryProvider = Provider<RadioRepository>((ref) {
  final apiClient = ref.watch(radioApiClientProvider);
  return RadioRepositoryImpl(apiClient);
});

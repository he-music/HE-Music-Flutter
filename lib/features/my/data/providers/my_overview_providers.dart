import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/my_overview_repository.dart';
import '../datasources/my_overview_api_client.dart';
import '../repositories/my_overview_repository_impl.dart';

final myOverviewApiClientProvider = Provider<MyOverviewApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return MyOverviewApiClient(dio);
});

final myOverviewRepositoryProvider = Provider<MyOverviewRepository>((ref) {
  final apiClient = ref.watch(myOverviewApiClientProvider);
  return MyOverviewRepositoryImpl(apiClient);
});

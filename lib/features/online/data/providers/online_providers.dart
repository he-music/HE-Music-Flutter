import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/online_search_repository.dart';
import '../datasources/search_history_data_source.dart';
import '../online_api_client.dart';
import '../repositories/online_search_repository_impl.dart';

export '../online_api_client.dart';

final onlineApiClientProvider = Provider<OnlineApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return OnlineApiClient(dio);
});

final searchHistoryDataSourceProvider = Provider<SearchHistoryDataSource>((
  ref,
) {
  return const SearchHistoryDataSource();
});

final onlineSearchRepositoryProvider = Provider<OnlineSearchRepository>((ref) {
  final apiClient = ref.watch(onlineApiClientProvider);
  final historyDataSource = ref.watch(searchHistoryDataSourceProvider);
  return OnlineSearchRepositoryImpl(apiClient, historyDataSource);
});

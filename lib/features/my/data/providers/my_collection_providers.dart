import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/my_collection_repository.dart';
import '../datasources/my_collection_api_client.dart';
import '../repositories/my_collection_repository_impl.dart';

final myCollectionApiClientProvider = Provider<MyCollectionApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return MyCollectionApiClient(dio);
});

final myCollectionRepositoryProvider = Provider<MyCollectionRepository>((ref) {
  final apiClient = ref.watch(myCollectionApiClientProvider);
  return MyCollectionRepositoryImpl(apiClient);
});

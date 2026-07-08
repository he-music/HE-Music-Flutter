import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/ranking_repository.dart';
import '../datasources/ranking_api_client.dart';
import '../repositories/ranking_repository_impl.dart';

final rankingApiClientProvider = Provider<RankingApiClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return RankingApiClient(dio);
});

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  final api = ref.watch(rankingApiClientProvider);
  return RankingRepositoryImpl(api);
});

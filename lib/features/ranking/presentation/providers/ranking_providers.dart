import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../data/providers/ranking_providers.dart';
import '../../domain/entities/ranking_group.dart';

export '../../data/providers/ranking_providers.dart';

final rankingPlatformsProvider = FutureProvider<List<OnlinePlatform>>((
  ref,
) async {
  final globalAsync = ref.watch(onlinePlatformsProvider);
  final cached = globalAsync.value;
  if (cached != null && cached.isNotEmpty) {
    return cached
        .where((platform) => platform.available)
        .toList(growable: false);
  }
  final loaded = await ref
      .read(onlinePlatformsProvider.notifier)
      .ensureLoaded(forceRefresh: true);
  return loaded.where((platform) => platform.available).toList(growable: false);
});

final rankingGroupsProvider = FutureProvider.family<List<RankingGroup>, String>(
  (ref, platform) async {
    final repo = ref.read(rankingRepositoryProvider);
    return repo.fetchRankingGroups(platform: platform);
  },
);

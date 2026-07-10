import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/domain/entities/player_history_item.dart';
import '../../../player/presentation/providers/player_history_provider.dart';
import '../../../player/presentation/providers/player_providers.dart';

class MyHistoryController extends AsyncNotifier<List<PlayerHistoryItem>> {
  @override
  Future<List<PlayerHistoryItem>> build() async {
    return _dataSource.listHistory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_dataSource.listHistory);
  }

  Future<void> clear() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _dataSource.clearHistory();
      ref.read(playerControllerProvider.notifier).resetHistoryCount();
      return const <PlayerHistoryItem>[];
    });
  }

  PlayerHistoryDataSource get _dataSource {
    return ref.read(playerHistoryDataSourceProvider);
  }
}

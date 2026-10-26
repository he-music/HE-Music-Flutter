import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/image/local_artwork_bytes_provider.dart';
import '../../../player/domain/entities/player_history_item.dart';
import '../../../player/presentation/providers/player_history_provider.dart';
import '../../../player/presentation/providers/player_providers.dart';

class MyHistoryController extends StreamNotifier<List<PlayerHistoryItem>> {
  @override
  Stream<List<PlayerHistoryItem>> build() {
    return _dataSource.watchHistory();
  }

  Future<void> refresh() async {
    ref.invalidate(localArtworkBytesProvider);
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

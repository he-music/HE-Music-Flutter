import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/player_queue_data_source.dart';

export '../datasources/player_queue_data_source.dart';

final playerQueueDataSourceProvider = Provider<PlayerQueueDataSource>((ref) {
  return const PlayerQueueDataSource();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/player_progress_data_source.dart';

export '../datasources/player_progress_data_source.dart';

final playerProgressDataSourceProvider = Provider<PlayerProgressDataSource>((
  ref,
) {
  return const PlayerProgressDataSource();
});

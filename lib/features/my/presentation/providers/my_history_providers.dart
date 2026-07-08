import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/domain/entities/player_history_item.dart';
import '../controllers/my_history_controller.dart';

final myHistoryControllerProvider =
    AsyncNotifierProvider<MyHistoryController, List<PlayerHistoryItem>>(
      MyHistoryController.new,
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/my_overview_state.dart';
import '../controllers/my_overview_controller.dart';

export '../../data/providers/my_overview_providers.dart';

final myOverviewControllerProvider =
    NotifierProvider<MyOverviewController, MyOverviewState>(
      MyOverviewController.new,
    );

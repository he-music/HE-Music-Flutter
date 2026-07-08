import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_discover_state.dart';
import '../controllers/home_discover_controller.dart';

export '../../data/providers/home_discover_providers.dart';

final homeDiscoverControllerProvider =
    NotifierProvider<HomeDiscoverController, HomeDiscoverState>(
      HomeDiscoverController.new,
    );

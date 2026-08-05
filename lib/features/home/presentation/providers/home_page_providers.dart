import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_page_state.dart';
import '../controllers/home_page_controller.dart';

export '../../data/providers/home_page_providers.dart';

final homePageControllerProvider =
    NotifierProvider<HomePageController, HomePageState>(HomePageController.new);

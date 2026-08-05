import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_page_state.dart';
import '../../domain/entities/recommend_song_list_state.dart';
import '../controllers/home_page_controller.dart';
import '../controllers/recommend_song_list_controller.dart';

export '../../data/providers/home_page_providers.dart';

final homePageControllerProvider =
    NotifierProvider<HomePageController, HomePageState>(HomePageController.new);

final recommendSongListControllerProvider = NotifierProvider.autoDispose
    .family<RecommendSongListController, RecommendSongListState, String>(
      (_) => RecommendSongListController(),
    );

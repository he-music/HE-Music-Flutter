import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/my_collection_state.dart';
import '../controllers/my_collection_controller.dart';

export '../../data/providers/my_collection_providers.dart';

final myCollectionControllerProvider =
    NotifierProvider<MyCollectionController, MyCollectionState>(
      MyCollectionController.new,
    );

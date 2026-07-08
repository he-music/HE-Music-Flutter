import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/radio_plaza_controller.dart';

export '../../data/providers/radio_providers.dart';

final radioPlazaControllerProvider =
    NotifierProvider<RadioPlazaController, RadioPlazaState>(
      RadioPlazaController.new,
    );

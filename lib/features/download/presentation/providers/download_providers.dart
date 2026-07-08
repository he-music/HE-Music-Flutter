import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/download_state.dart';
import '../controllers/download_controller.dart';

export '../../data/providers/download_providers.dart';

final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadState>(DownloadController.new);

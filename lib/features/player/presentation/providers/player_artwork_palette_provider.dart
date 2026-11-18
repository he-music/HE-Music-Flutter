import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/image/image_color_extractor.dart';

final playerArtworkPaletteProvider = FutureProvider.autoDispose
    .family<List<Color>, ImageProvider<Object>?>(
      (ref, image) =>
          colorsFromImageProvider(image, prioritizeSaturation: false),
    );

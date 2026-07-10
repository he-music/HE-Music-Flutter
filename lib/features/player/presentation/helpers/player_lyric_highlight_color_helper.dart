import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'player_artwork_helper.dart';
import 'player_image_color_helper.dart';

/// 从当前歌曲封面提取适合深色歌词背景的高亮色。
Future<Color?> loadPlayerLyricHighlightColor({
  required String? artworkUrl,
  required Uint8List? artworkBytes,
}) async {
  final imageProvider = artworkProvider(artworkUrl, artworkBytes);
  if (imageProvider == null) {
    return null;
  }
  final colors = await colorsFromImageProvider(
    imageProvider,
    decodeSize: const Size(112, 112),
  );
  return pickPlayerLyricHighlightColor(colors);
}

@visibleForTesting
Color? pickPlayerLyricHighlightColor(List<Color> colors) {
  for (final color in colors) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.40 || hsl.saturation < 0.24) {
      continue;
    }
    return hsl
        .withLightness(math.max(hsl.lightness, 0.72))
        .withSaturation(math.max(hsl.saturation, 0.56))
        .toColor();
  }
  if (colors.isEmpty) {
    return null;
  }
  final hsl = HSLColor.fromColor(colors.first);
  return hsl
      .withLightness(math.max(hsl.lightness, 0.70))
      .withSaturation(math.max(hsl.saturation, 0.46))
      .toColor();
}

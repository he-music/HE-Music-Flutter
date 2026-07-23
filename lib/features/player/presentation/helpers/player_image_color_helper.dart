import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// 从 [ImageProvider] 提取主色调列表。
///
/// 解码图片后使用 QuantizerCelebi 量化颜色，
/// 按饱和度和像素数量排序返回最多 [maxColors] 种颜色。
Future<List<Color>> colorsFromImageProvider(
  ImageProvider<Object>? imageProvider, {
  int maxColors = 12,
  Size decodeSize = const Size(96, 96),
  bool prioritizeSaturation = true,
}) async {
  if (imageProvider == null) return const <Color>[];
  try {
    final imageStream = imageProvider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (error, _) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
    imageStream.addListener(listener);
    final rawImage = await completer.future;
    imageStream.removeListener(listener);

    final resized = await _decodeImageSized(rawImage, decodeSize);
    final byteData = await resized.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rawImage.dispose();
    resized.dispose();
    if (byteData == null) return const <Color>[];

    final pixels = _argbPixelsFromRgbaBytes(byteData);
    final result = await QuantizerCelebi().quantize(pixels, maxColors);

    // 经典样式优先醒目颜色；流体样式按像素数量保留封面原始气质。
    final sorted = result.colorToCount.entries.toList()
      ..sort((a, b) {
        if (!prioritizeSaturation) {
          return b.value.compareTo(a.value);
        }
        final sa = HSLColor.fromColor(Color(a.key)).saturation;
        final sb = HSLColor.fromColor(Color(b.key)).saturation;
        final diff = sb.compareTo(sa);
        return diff != 0 ? diff : b.value.compareTo(a.value);
      });
    return sorted.take(maxColors).map((entry) => Color(entry.key)).toList();
  } catch (_) {
    return const <Color>[];
  }
}

/// 缩放解码 [ui.Image] 至 [targetSize]，降低颜色量化开销。
Future<ui.Image> _decodeImageSized(ui.Image source, Size targetSize) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    source,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
    Paint()..filterQuality = FilterQuality.low,
  );
  return recorder.endRecording().toImage(
    targetSize.width.toInt(),
    targetSize.height.toInt(),
  );
}

/// 将 RGBA 字节数据转换为 ARGB 整数列表，供 QuantizerCelebi 使用。
List<int> _argbPixelsFromRgbaBytes(ByteData byteData) {
  final pixels = <int>[];
  for (var i = 0; i < byteData.lengthInBytes; i += 4) {
    final r = byteData.getUint8(i);
    final g = byteData.getUint8(i + 1);
    final b = byteData.getUint8(i + 2);
    final a = byteData.getUint8(i + 3);
    pixels.add((a << 24) | (r << 16) | (g << 8) | b);
  }
  return pixels;
}

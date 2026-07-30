import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// 从图片中提取量化后的代表色，供播放器与自定义皮肤共同使用。
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

    final pixels = argbPixelsFromRgbaBytes(byteData);
    final result = await QuantizerCelebi().quantize(pixels, maxColors);
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

/// 将 RGBA 字节转换为 QuantizerCelebi 接受的 ARGB32 像素。
List<int> argbPixelsFromRgbaBytes(ByteData byteData) {
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

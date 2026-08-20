import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

const int _imageColorCacheCapacity = 24;
final Map<_ImageColorCacheKey, List<Color>> _imageColorCache = {};
final Map<_ImageColorCacheKey, Future<List<Color>>> _inFlightImageColors = {};

/// 从图片中提取量化后的代表色，供播放器与自定义皮肤共同使用。
Future<List<Color>> colorsFromImageProvider(
  ImageProvider<Object>? imageProvider, {
  int maxColors = 12,
  Size decodeSize = const Size(96, 96),
  bool prioritizeSaturation = true,
}) async {
  if (imageProvider == null) return const <Color>[];
  final cacheKey = _ImageColorCacheKey(
    provider: imageProvider,
    maxColors: maxColors,
    decodeWidth: decodeSize.width.toInt(),
    decodeHeight: decodeSize.height.toInt(),
    prioritizeSaturation: prioritizeSaturation,
  );
  final cached = _imageColorCache.remove(cacheKey);
  if (cached != null) {
    _imageColorCache[cacheKey] = cached;
    return cached;
  }
  final inFlight = _inFlightImageColors[cacheKey];
  if (inFlight != null) return inFlight;
  final future = _extractColors(
    imageProvider,
    maxColors: maxColors,
    decodeSize: decodeSize,
    prioritizeSaturation: prioritizeSaturation,
  );
  _inFlightImageColors[cacheKey] = future;
  try {
    final colors = List<Color>.unmodifiable(await future);
    if (colors.isNotEmpty) {
      _imageColorCache[cacheKey] = colors;
      if (_imageColorCache.length > _imageColorCacheCapacity) {
        _imageColorCache.remove(_imageColorCache.keys.first);
      }
    }
    return colors;
  } finally {
    _inFlightImageColors.remove(cacheKey);
  }
}

Future<List<Color>> _extractColors(
  ImageProvider<Object> imageProvider, {
  required int maxColors,
  required Size decodeSize,
  required bool prioritizeSaturation,
}) async {
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
    late final ui.Image rawImage;
    try {
      rawImage = await completer.future;
    } finally {
      imageStream.removeListener(listener);
    }

    ui.Image? resized;
    ByteData? byteData;
    try {
      resized = await _decodeImageSized(rawImage, decodeSize);
      byteData = await resized.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      rawImage.dispose();
      resized?.dispose();
    }
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

class _ImageColorCacheKey {
  const _ImageColorCacheKey({
    required this.provider,
    required this.maxColors,
    required this.decodeWidth,
    required this.decodeHeight,
    required this.prioritizeSaturation,
  });

  final ImageProvider<Object> provider;
  final int maxColors;
  final int decodeWidth;
  final int decodeHeight;
  final bool prioritizeSaturation;

  @override
  bool operator ==(Object other) {
    return other is _ImageColorCacheKey &&
        other.provider == provider &&
        other.maxColors == maxColors &&
        other.decodeWidth == decodeWidth &&
        other.decodeHeight == decodeHeight &&
        other.prioritizeSaturation == prioritizeSaturation;
  }

  @override
  int get hashCode => Object.hash(
    provider,
    maxColors,
    decodeWidth,
    decodeHeight,
    prioritizeSaturation,
  );
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

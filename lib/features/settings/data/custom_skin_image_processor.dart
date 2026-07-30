import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:material_color_utilities/material_color_utilities.dart';

const int customSkinMaxFileBytes = 32 * 1024 * 1024;
const int customSkinMaxSourcePixels = 80000000;
const int customSkinMaxOutputDimension = 3200;

enum CustomSkinImageBrightness { light, dark, neutral }

enum CustomSkinImageError {
  fileTooLarge,
  tooManyPixels,
  unsupportedOrDamaged,
  animated,
  noVisiblePixels,
  processingFailed,
}

class CustomSkinImageException implements Exception {
  const CustomSkinImageException(this.error, [this.cause]);

  final CustomSkinImageError error;
  final Object? cause;

  @override
  String toString() => 'CustomSkinImageException($error, $cause)';
}

@immutable
class CustomSkinProcessedImage {
  const CustomSkinProcessedImage({
    required this.lightBytes,
    required this.darkBytes,
    required this.fileExtension,
    required this.candidateColors,
    required this.sourceBrightness,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.outputWidth,
    required this.outputHeight,
  });

  final Uint8List lightBytes;
  final Uint8List darkBytes;
  final String fileExtension;
  final List<int> candidateColors;
  final CustomSkinImageBrightness sourceBrightness;
  final int sourceWidth;
  final int sourceHeight;
  final int outputWidth;
  final int outputHeight;
}

class CustomSkinImageProcessor {
  const CustomSkinImageProcessor();

  Future<CustomSkinProcessedImage> process(XFile file) async {
    final length = await file.length();
    if (length > customSkinMaxFileBytes) {
      throw const CustomSkinImageException(CustomSkinImageError.fileTooLarge);
    }
    return processBytes(await file.readAsBytes());
  }

  Future<CustomSkinProcessedImage> processBytes(Uint8List encodedBytes) async {
    if (encodedBytes.lengthInBytes > customSkinMaxFileBytes) {
      throw const CustomSkinImageException(CustomSkinImageError.fileTooLarge);
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decodedImage;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(encodedBytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final sourceWidth = descriptor.width;
      final sourceHeight = descriptor.height;
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        throw const CustomSkinImageException(
          CustomSkinImageError.unsupportedOrDamaged,
        );
      }
      if (sourceWidth * sourceHeight > customSkinMaxSourcePixels) {
        throw const CustomSkinImageException(
          CustomSkinImageError.tooManyPixels,
        );
      }
      final target = calculateCustomSkinTargetSize(sourceWidth, sourceHeight);
      codec = await descriptor.instantiateCodec(
        targetWidth: target.width,
        targetHeight: target.height,
      );
      if (codec.frameCount != 1) {
        throw const CustomSkinImageException(CustomSkinImageError.animated);
      }
      final frame = await codec.getNextFrame();
      decodedImage = frame.image;
      final rgbaData = await decodedImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (rgbaData == null) {
        throw const CustomSkinImageException(
          CustomSkinImageError.processingFailed,
        );
      }
      final rgba = Uint8List.fromList(
        rgbaData.buffer.asUint8List(
          rgbaData.offsetInBytes,
          rgbaData.lengthInBytes,
        ),
      );
      var hasVisiblePixel = false;
      for (var offset = 3; offset < rgba.length; offset += 4) {
        if (rgba[offset] >= 16) {
          hasVisiblePixel = true;
          break;
        }
      }
      if (!hasVisiblePixel) {
        throw const CustomSkinImageException(
          CustomSkinImageError.noVisiblePixels,
        );
      }
      final result = await compute(_deriveCustomSkinImages, <String, Object>{
        'rgba': rgba,
        'width': decodedImage.width,
        'height': decodedImage.height,
      });
      final candidates = (result['candidateColors']! as List<Object?>)
          .cast<int>();
      if (candidates.isEmpty) {
        throw const CustomSkinImageException(
          CustomSkinImageError.noVisiblePixels,
        );
      }
      return CustomSkinProcessedImage(
        lightBytes: result['lightBytes']! as Uint8List,
        darkBytes: result['darkBytes']! as Uint8List,
        fileExtension: result['fileExtension']! as String,
        candidateColors: List<int>.unmodifiable(candidates),
        sourceBrightness: CustomSkinImageBrightness.values.byName(
          result['sourceBrightness']! as String,
        ),
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        outputWidth: decodedImage.width,
        outputHeight: decodedImage.height,
      );
    } on CustomSkinImageException {
      rethrow;
    } catch (error) {
      throw CustomSkinImageException(
        CustomSkinImageError.unsupportedOrDamaged,
        error,
      );
    } finally {
      decodedImage?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

({int width, int height}) calculateCustomSkinTargetSize(int width, int height) {
  final longest = math.max(width, height);
  if (longest <= customSkinMaxOutputDimension) {
    return (width: width, height: height);
  }
  final scale = customSkinMaxOutputDimension / longest;
  return (
    width: math.max(1, (width * scale).round()),
    height: math.max(1, (height * scale).round()),
  );
}

CustomSkinImageBrightness classifyCustomSkinLuminance(List<double> luminances) {
  if (luminances.isEmpty) {
    return CustomSkinImageBrightness.neutral;
  }
  final sorted = List<double>.of(luminances)..sort();
  final median = _percentile(sorted, 0.5);
  final lowerQuartile = _percentile(sorted, 0.25);
  final upperQuartile = _percentile(sorted, 0.75);
  final darkRatio =
      sorted.where((value) => value < 0.32).length / sorted.length;
  final lightRatio =
      sorted.where((value) => value > 0.68).length / sorted.length;

  if (median <= 0.38 && (darkRatio >= 0.52 || upperQuartile < 0.58)) {
    return CustomSkinImageBrightness.dark;
  }
  if (median >= 0.62 && (lightRatio >= 0.52 || lowerQuartile > 0.42)) {
    return CustomSkinImageBrightness.light;
  }
  return CustomSkinImageBrightness.neutral;
}

Future<Map<String, Object>> _deriveCustomSkinImages(
  Map<String, Object> request,
) async {
  final rgba = request['rgba']! as Uint8List;
  final width = request['width']! as int;
  final height = request['height']! as int;
  final sampled = _sampleVisiblePixels(rgba, width, height);
  if (sampled.argbPixels.isEmpty) {
    throw const CustomSkinImageException(CustomSkinImageError.noVisiblePixels);
  }
  final sourceBrightness = classifyCustomSkinLuminance(sampled.luminances);
  final candidates = await _extractCandidateColors(sampled.argbPixels);
  if (candidates.isEmpty) {
    throw const CustomSkinImageException(CustomSkinImageError.noVisiblePixels);
  }

  final lightRgba = switch (sourceBrightness) {
    CustomSkinImageBrightness.light => Uint8List.fromList(rgba),
    CustomSkinImageBrightness.dark ||
    CustomSkinImageBrightness.neutral => _adaptRgba(rgba, makeDark: false),
  };
  final darkRgba = switch (sourceBrightness) {
    CustomSkinImageBrightness.dark => Uint8List.fromList(rgba),
    CustomSkinImageBrightness.light ||
    CustomSkinImageBrightness.neutral => _adaptRgba(rgba, makeDark: true),
  };
  var hasTransparency = false;
  for (var offset = 3; offset < rgba.length; offset += 4) {
    if (rgba[offset] < 255) {
      hasTransparency = true;
      break;
    }
  }
  return <String, Object>{
    'lightBytes': _encodeRgba(lightRgba, width, height, hasTransparency),
    'darkBytes': _encodeRgba(darkRgba, width, height, hasTransparency),
    'fileExtension': hasTransparency ? 'png' : 'jpg',
    'candidateColors': candidates,
    'sourceBrightness': sourceBrightness.name,
  };
}

({List<int> argbPixels, List<double> luminances}) _sampleVisiblePixels(
  Uint8List rgba,
  int width,
  int height,
) {
  const sampleEdge = 96;
  final stepX = math.max(1, (width / sampleEdge).ceil());
  final stepY = math.max(1, (height / sampleEdge).ceil());
  final pixels = <int>[];
  final luminances = <double>[];
  for (var y = 0; y < height; y += stepY) {
    for (var x = 0; x < width; x += stepX) {
      final offset = (y * width + x) * 4;
      final r = rgba[offset];
      final g = rgba[offset + 1];
      final b = rgba[offset + 2];
      final a = rgba[offset + 3];
      if (a < 16) {
        continue;
      }
      pixels.add(0xFF000000 | (r << 16) | (g << 8) | b);
      luminances.add((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255);
    }
  }
  return (argbPixels: pixels, luminances: luminances);
}

Future<List<int>> _extractCandidateColors(List<int> pixels) async {
  final result = await QuantizerCelebi().quantize(pixels, 12);
  final entries = result.colorToCount.entries.toList()
    ..sort((a, b) {
      final scoreA = a.value * (0.55 + 0.45 * _rgbSaturation(a.key));
      final scoreB = b.value * (0.55 + 0.45 * _rgbSaturation(b.key));
      return scoreB.compareTo(scoreA);
    });
  final colors = <int>[];
  for (final entry in entries) {
    final color = 0xFF000000 | (entry.key & 0x00FFFFFF);
    if (colors.any((other) => _rgbDistance(color, other) < 28)) {
      continue;
    }
    colors.add(color);
    if (colors.length == 6) {
      break;
    }
  }
  return colors;
}

Uint8List _adaptRgba(Uint8List source, {required bool makeDark}) {
  final output = Uint8List(source.length);
  for (var offset = 0; offset < source.length; offset += 4) {
    final r = source[offset].toDouble();
    final g = source[offset + 1].toDouble();
    final b = source[offset + 2].toDouble();
    if (makeDark) {
      final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      output[offset] = _byte((r * 0.9 + luma * 0.1) * 0.58);
      output[offset + 1] = _byte((g * 0.9 + luma * 0.1) * 0.58);
      output[offset + 2] = _byte((b * 0.9 + luma * 0.1) * 0.58);
    } else {
      output[offset] = _byte(255 - (255 - r) * 0.76);
      output[offset + 1] = _byte(255 - (255 - g) * 0.76);
      output[offset + 2] = _byte(255 - (255 - b) * 0.76);
    }
    output[offset + 3] = source[offset + 3];
  }
  return output;
}

Uint8List _encodeRgba(
  Uint8List rgba,
  int width,
  int height,
  bool hasTransparency,
) {
  final decoded = image.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: image.ChannelOrder.rgba,
  );
  return hasTransparency
      ? image.encodePng(decoded, singleFrame: true, level: 6)
      : image.encodeJpg(decoded, quality: 92);
}

double _percentile(List<double> sorted, double fraction) {
  final index = ((sorted.length - 1) * fraction).round();
  return sorted[index];
}

double _rgbSaturation(int color) {
  final r = ((color >> 16) & 0xFF) / 255;
  final g = ((color >> 8) & 0xFF) / 255;
  final b = (color & 0xFF) / 255;
  final maxChannel = math.max(r, math.max(g, b));
  final minChannel = math.min(r, math.min(g, b));
  if (maxChannel == minChannel) {
    return 0;
  }
  final lightness = (maxChannel + minChannel) / 2;
  return (maxChannel - minChannel) /
      (1 - (2 * lightness - 1).abs()).clamp(0.0001, 1);
}

double _rgbDistance(int first, int second) {
  final dr = ((first >> 16) & 0xFF) - ((second >> 16) & 0xFF);
  final dg = ((first >> 8) & 0xFF) - ((second >> 8) & 0xFF);
  final db = (first & 0xFF) - (second & 0xFF);
  return math.sqrt((dr * dr + dg * dg + db * db).toDouble());
}

int _byte(double value) => value.round().clamp(0, 255);

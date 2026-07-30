import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/settings/data/custom_skin_image_processor.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('target size only scales images whose longest edge exceeds 3200', () {
    expect(calculateCustomSkinTargetSize(1200, 800), (
      width: 1200,
      height: 800,
    ));
    expect(calculateCustomSkinTargetSize(6400, 3200), (
      width: 3200,
      height: 1600,
    ));
  });

  test('luminance classifier resists small opposite-brightness regions', () {
    expect(
      classifyCustomSkinLuminance(<double>[
        ...List<double>.filled(90, 0.12),
        ...List<double>.filled(10, 0.95),
      ]),
      CustomSkinImageBrightness.dark,
    );
    expect(
      classifyCustomSkinLuminance(<double>[
        ...List<double>.filled(90, 0.88),
        ...List<double>.filled(10, 0.05),
      ]),
      CustomSkinImageBrightness.light,
    );
    expect(
      classifyCustomSkinLuminance(List<double>.filled(100, 0.5)),
      CustomSkinImageBrightness.neutral,
    );
  });

  test(
    'bright source keeps a bright version and generates a darker pair',
    () async {
      const processor = CustomSkinImageProcessor();
      final result = await processor.processBytes(
        _solidPng(12, 8, red: 235, green: 220, blue: 205),
      );

      expect(result.sourceBrightness, CustomSkinImageBrightness.light);
      expect(result.fileExtension, 'jpg');
      expect(result.candidateColors, isNotEmpty);
      expect(result.outputWidth, 12);
      expect(result.outputHeight, 8);
      expect(
        _averageLuminance(result.lightBytes),
        greaterThan(_averageLuminance(result.darkBytes)),
      );
    },
  );

  test('transparent source preserves PNG output for both variants', () async {
    const processor = CustomSkinImageProcessor();
    final result = await processor.processBytes(
      _solidPng(8, 8, red: 70, green: 120, blue: 200, alpha: 120),
    );

    expect(result.fileExtension, 'png');
    expect(image.decodePng(result.lightBytes), isNotNull);
    expect(image.decodePng(result.darkBytes), isNotNull);
  });

  test('animated images and oversized files are rejected', () async {
    const processor = CustomSkinImageProcessor();
    final animation = image.Image(width: 2, height: 2, numChannels: 4);
    animation.setPixelRgba(0, 0, 255, 0, 0, 255);
    final second = animation.addFrame();
    second.setPixelRgba(0, 0, 0, 255, 0, 255);

    await expectLater(
      processor.processBytes(image.encodeGif(animation)),
      throwsA(
        isA<CustomSkinImageException>().having(
          (error) => error.error,
          'error',
          CustomSkinImageError.animated,
        ),
      ),
    );
    await expectLater(
      processor.processBytes(Uint8List(customSkinMaxFileBytes + 1)),
      throwsA(
        isA<CustomSkinImageException>().having(
          (error) => error.error,
          'error',
          CustomSkinImageError.fileTooLarge,
        ),
      ),
    );
  });
}

Uint8List _solidPng(
  int width,
  int height, {
  required int red,
  required int green,
  required int blue,
  int alpha = 255,
}) {
  final value = image.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      value.setPixelRgba(x, y, red, green, blue, alpha);
    }
  }
  return image.encodePng(value);
}

double _averageLuminance(Uint8List encoded) {
  final decoded = image.decodeImage(encoded)!;
  var total = 0.0;
  for (final pixel in decoded) {
    total += (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) / 255;
  }
  return total / (decoded.width * decoded.height);
}

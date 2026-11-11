import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/image/image_color_extractor.dart';

void main() {
  testWidgets(
    'color extraction decodes at the sample size and preserves aspect ratio',
    (tester) async {
      await tester.runAsync(() async {
        final cache = PaintingBinding.instance.imageCache;
        cache.clear();
        cache.clearLiveImages();
        addTearDown(cache.clear);
        addTearDown(cache.clearLiveImages);
        final bytes = await _png(1024, 512);
        final original = MemoryImage(bytes);
        const sample = Size(112, 112);
        final colors = await colorsFromImageProvider(
          original,
          decodeSize: sample,
        );
        expect(colors, isNotEmpty);
        expect(colors.first.r, greaterThan(.9));
        final resized = ResizeImage(
          original,
          width: 112,
          height: 112,
          policy: ResizeImagePolicy.fit,
        );
        final sampleKey = await resized.obtainKey(ImageConfiguration.empty);
        final originalKey = await original.obtainKey(ImageConfiguration.empty);
        expect(cache.containsKey(sampleKey), isTrue);
        expect(cache.containsKey(originalKey), isFalse);
        expect(cache.currentSizeBytes, 112 * 56 * 4);

        // The image cache still owns a valid image after extraction releases its frame.
        final frame = await _firstFrame(resized);
        expect(frame.image.width, 112);
        expect(frame.image.height, 56);
        frame.dispose();
        final repeated = await colorsFromImageProvider(
          MemoryImage(bytes),
          decodeSize: sample,
        );
        expect(repeated, same(colors));
        expect(cache.currentSizeBytes, 112 * 56 * 4);
      });
    },
  );

  testWidgets(
    'small images are not upscaled and concurrent samples share a decode',
    (tester) async {
      await tester.runAsync(() async {
        final cache = PaintingBinding.instance.imageCache;
        cache.clear();
        cache.clearLiveImages();
        addTearDown(cache.clear);
        addTearDown(cache.clearLiveImages);
        final image = MemoryImage(await _png(32, 16));
        final results = await Future.wait([
          colorsFromImageProvider(image),
          colorsFromImageProvider(image),
        ]);
        expect(results.first, isNotEmpty);
        expect(results.last, results.first);
        expect(cache.currentSize, 1);
        expect(cache.currentSizeBytes, 32 * 16 * 4);
      });
    },
  );

  testWidgets('missing, invalid and unreadable images return no colors', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(await colorsFromImageProvider(null), isEmpty);
      final invalid = MemoryImage(Uint8List.fromList([1, 2, 3]));
      expect(
        await colorsFromImageProvider(invalid, decodeSize: Size.zero),
        isEmpty,
      );
      expect(
        await colorsFromImageProvider(
          invalid,
          decodeSize: const Size(double.infinity, 1),
        ),
        isEmpty,
      );
      expect(await colorsFromImageProvider(invalid, maxColors: 0), isEmpty);
      expect(await colorsFromImageProvider(invalid), isEmpty);
    });
  });
}

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.red, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<ImageInfo> _firstFrame(ImageProvider<Object> provider) async {
  // Image listeners receive their own frame handle, which callers dispose.
  final stream = provider.resolve(ImageConfiguration.empty);
  final result = Completer<ImageInfo>();
  final listener = ImageStreamListener((info, _) => result.complete(info));
  stream.addListener(listener);
  try {
    return await result.future;
  } finally {
    stream.removeListener(listener);
  }
}

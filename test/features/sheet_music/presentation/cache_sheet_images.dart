import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 注入已解码图片，图片手势测试不依赖网络，也不只测试失败占位。
Future<void> cacheSheetImages(WidgetTester tester, List<String> urls) async {
  await tester.runAsync(() async {
    const preview = String.fromEnvironment('SHEET_MUSIC_PREVIEW_IMAGE');
    final bytes = await File(
      preview.isEmpty ? 'test/assets/player/artist_photo.png' : preview,
    ).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    for (final url in urls) {
      for (final provider in [
        NetworkImage(url),
        ResizeImage.resizeIfNeeded(220, null, NetworkImage(url)),
      ]) {
        final key = await provider.obtainKey(ImageConfiguration.empty);
        PaintingBinding.instance.imageCache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: frame.image.clone())),
          ),
        );
      }
    }
    frame.image.dispose();
  });
  addTearDown(() => PaintingBinding.instance.imageCache.clear());
}

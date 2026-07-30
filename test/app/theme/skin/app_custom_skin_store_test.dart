import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/skin/app_custom_skin_store.dart';
import 'package:he_music_flutter/features/settings/data/custom_skin_image_processor.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppCustomSkinStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('custom_skin_store_test_');
    store = AppCustomSkinStore(
      applicationSupportDirectory: () async => support,
      revisionFactory: () => 'revision_1',
    );
  });

  tearDown(() async {
    if (await support.exists()) {
      await support.delete(recursive: true);
    }
  });

  test(
    'stage validates, publishes, and resolves one immutable revision',
    () async {
      final staged = await _stage(store, _processed());
      final config = staged.createConfig(
        seedColor: staged.candidateColors.first,
        focalX: 0.2,
        focalY: -0.3,
        swapped: false,
      );

      expect(
        File(
          '${support.path}/skins/custom_image/.staging/revision_1/'
          'wallpaper_light.png',
        ).existsSync(),
        isTrue,
      );
      await store.publish(staged);

      expect(await store.validateConfig(config), isTrue);
      expect(
        File(
          '${support.path}/skins/custom_image/revision_1/'
          'wallpaper_dark.png',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'published revision can return to staging after config failure',
    () async {
      final staged = await _stage(store, _processed());
      await store.publish(staged);

      await store.restoreStaging(staged);

      expect(
        Directory('${support.path}/skins/custom_image/revision_1').existsSync(),
        isFalse,
      );
      expect(
        Directory(
          '${support.path}/skins/custom_image/.staging/revision_1',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('orphan cleanup preserves only the configured revision', () async {
    final staged = await _stage(store, _processed());
    final config = staged.createConfig(
      seedColor: staged.candidateColors.first,
      focalX: 0,
      focalY: 0,
      swapped: false,
    );
    await store.publish(staged);
    await Directory(
      '${support.path}/skins/custom_image/orphan',
    ).create(recursive: true);

    await store.cleanupOrphans(config);

    expect(
      Directory('${support.path}/skins/custom_image/revision_1').existsSync(),
      isTrue,
    );
    expect(
      Directory('${support.path}/skins/custom_image/orphan').existsSync(),
      isFalse,
    );
  });
}

Future<AppCustomSkinStagedRevision> _stage(
  AppCustomSkinStore store,
  CustomSkinProcessedImage processed,
) {
  return store.stage(
    lightBytes: processed.lightBytes,
    darkBytes: processed.darkBytes,
    fileExtension: processed.fileExtension,
    candidateColors: processed.candidateColors,
    sourceWidth: processed.sourceWidth,
    sourceHeight: processed.sourceHeight,
    outputWidth: processed.outputWidth,
    outputHeight: processed.outputHeight,
  );
}

CustomSkinProcessedImage _processed() {
  final source = image.Image(width: 2, height: 2, numChannels: 4);
  for (var y = 0; y < 2; y++) {
    for (var x = 0; x < 2; x++) {
      source.setPixelRgba(x, y, 30, 90, 180, 180);
    }
  }
  final bytes = image.encodePng(source);
  return CustomSkinProcessedImage(
    lightBytes: bytes,
    darkBytes: bytes,
    fileExtension: 'png',
    candidateColors: const <int>[0xFF1E5AB4],
    sourceBrightness: CustomSkinImageBrightness.neutral,
    sourceWidth: 2,
    sourceHeight: 2,
    outputWidth: 2,
    outputHeight: 2,
  );
}

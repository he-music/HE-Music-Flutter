import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skins/classic_skin.dart';

const _sourcePath =
    'assets/skins/starlit_melody/sources/wallpaper_light_provider.png';
const _sourceHash =
    'ef01feb3bc440b514881287d9bf2c271fc3c8b25fa94e890722e6f41b3577820';
const _wallpaperPath = 'assets/skins/starlit_melody/wallpaper_light.png';
const _wallpaperHash =
    '7232392767ae9f99f6289130ffc446fe4a45986df91cfb7691846560b6d9c78c';
const _darkEvaluationPath =
    'assets/skins/starlit_melody/wallpaper_dark_evaluation.png';
const _darkEvaluationHash =
    '704ad67cc9b98dfe86d25b7a35d289a2d4bb0ff7ba9763cb7fac68638176650a';
const _lightPreviewPath = 'assets/skins/starlit_melody/preview_light.png';
const _lightPreviewHash =
    'ec44137c0302b839c2e1aa6365b62e59765a0ee1a31a3faeb2b0070bc9587caa';
const _darkPreviewPath = 'assets/skins/starlit_melody/preview_dark.png';
const _darkPreviewHash =
    '4de717f1a0e8046ee2084da4f1926e9bcda11306d68b02cbb51428b6ed76ff7c';

void main() {
  test('evaluation assets match their recorded provenance', () async {
    final sourceBytes = await File(_sourcePath).readAsBytes();
    final wallpaperBytes = await File(_wallpaperPath).readAsBytes();
    final lightPreviewBytes = await File(_lightPreviewPath).readAsBytes();
    final darkPreviewBytes = await File(_darkPreviewPath).readAsBytes();
    final darkEvaluationBytes = await File(_darkEvaluationPath).readAsBytes();

    expect(sha256.convert(sourceBytes).toString(), _sourceHash);
    expect(_pngSize(sourceBytes), (941, 1672));
    expect(sha256.convert(wallpaperBytes).toString(), _wallpaperHash);
    expect(_pngSize(wallpaperBytes), (1882, 3344));
    expect(sha256.convert(lightPreviewBytes).toString(), _lightPreviewHash);
    expect(_pngSize(lightPreviewBytes), (360, 640));
    expect(sha256.convert(darkPreviewBytes).toString(), _darkPreviewHash);
    expect(_pngSize(darkPreviewBytes), (360, 640));
    expect(sha256.convert(darkEvaluationBytes).toString(), _darkEvaluationHash);
    expect(_pngSize(darkEvaluationBytes), (941, 1672));

    final provenance = await File(
      'assets/skins/starlit_melody/LICENSES.md',
    ).readAsString();
    for (final hash in <String>[
      _sourceHash,
      _wallpaperHash,
      _lightPreviewHash,
      _darkPreviewHash,
      _darkEvaluationHash,
    ]) {
      expect(provenance, contains(hash));
    }
    expect(provenance, contains('upscaled=true'));
    expect(provenance, contains('Face restoration: disabled'));
    expect(provenance, contains('matched byte-for-byte'));
    expect(provenance, contains('make skin-previews'));
  });

  test('runtime packages only the approved evaluation assets', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    expect(pubspec, contains('    - $_wallpaperPath'));
    expect(pubspec, contains('    - $_lightPreviewPath'));
    expect(pubspec, contains('    - $_darkPreviewPath'));
    expect(pubspec, contains('    - $_darkEvaluationPath'));
    expect(pubspec, isNot(contains(_sourcePath)));
    expect(
      pubspec,
      isNot(contains('assets/skins/starlit_melody/wallpaper_dark.png')),
    );
    expect(pubspec, isNot(contains('assets/skins/starlit_melody/icons/')));
    expect(
      File('assets/skins/starlit_melody/wallpaper_dark.png').existsSync(),
      isFalse,
    );
    expect(
      Directory('assets/skins/starlit_melody/icons').existsSync(),
      isFalse,
    );

    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.rose,
    ).resolve(AppSkinRegistry.starlitMelodyId);
    final graphite = classicSkinForAccent(AppThemeAccent.graphite);
    expect(
      skin.light.background.wallpaper.descriptor,
      const AppSkinAssetDescriptor(
        path: _wallpaperPath,
        type: AppSkinAssetType.rasterImage,
      ),
    );
    expect(
      skin.metadata.lightPreview.descriptor,
      const AppSkinAssetDescriptor(
        path: _lightPreviewPath,
        type: AppSkinAssetType.rasterImage,
      ),
    );
    expect(
      skin.metadata.darkPreview.descriptor,
      const AppSkinAssetDescriptor(
        path: _darkPreviewPath,
        type: AppSkinAssetType.rasterImage,
      ),
    );
    expect(
      skin.dark.background.wallpaper.descriptor,
      const AppSkinAssetDescriptor(
        path: _darkEvaluationPath,
        type: AppSkinAssetType.rasterImage,
      ),
    );
    expect(skin.dark, isNot(graphite.dark));
    expect(skin.icons, graphite.icons);
  });
}

(int, int) _pngSize(Uint8List bytes) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24) {
    throw const FormatException('PNG header is incomplete');
  }
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) {
      throw const FormatException('Invalid PNG signature');
    }
  }
  final header = ByteData.sublistView(bytes);
  return (header.getUint32(16), header.getUint32(20));
}

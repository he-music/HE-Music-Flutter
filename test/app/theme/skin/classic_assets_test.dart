import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/classic_skin.dart';

const _lightPreviewPath = 'assets/skins/classic/preview_light.png';
const _lightPreviewHash =
    '0c7dda2a66c134cc0d2ce5e325bc540e129ea774e993fd1b8914d84698b81e4f';
const _darkPreviewPath = 'assets/skins/classic/preview_dark.png';
const _darkPreviewHash =
    'b98d3fcf60fcf70e946640abe78185f382ce34d3e485cdfb0f824be9ff3b9e88';

void main() {
  test('classic previews match their recorded provenance', () async {
    final lightBytes = await File(_lightPreviewPath).readAsBytes();
    final darkBytes = await File(_darkPreviewPath).readAsBytes();

    expect(sha256.convert(lightBytes).toString(), _lightPreviewHash);
    expect(_pngSize(lightBytes), (360, 640));
    expect(sha256.convert(darkBytes).toString(), _darkPreviewHash);
    expect(_pngSize(darkBytes), (360, 640));
    expect(AppConfigState.initial.themeAccent, AppThemeAccent.forest);

    final provenance = await File(
      'assets/skins/classic/LICENSES.md',
    ).readAsString();
    expect(provenance, contains(_lightPreviewHash));
    expect(provenance, contains(_darkPreviewHash));
    expect(provenance, contains('AppThemeAccent.forest'));
    expect(provenance, contains('make skin-previews'));
  });

  test('runtime packages both classic previews', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    expect(pubspec, contains('    - $_lightPreviewPath'));
    expect(pubspec, contains('    - $_darkPreviewPath'));

    final skin = classicSkinForAccent(AppConfigState.initial.themeAccent);
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

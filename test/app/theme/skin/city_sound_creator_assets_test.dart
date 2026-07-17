import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';

const _light = _WallpaperContract(
  sourcePath:
      'assets/skins/city_sound_creator/sources/'
      'wallpaper_light_provider_v5.png',
  sourceHash:
      '6716a96c0e87206237c020d1d5268d0dcdf0b11c351860b2e1c8b25f47a24808',
  productionPath: 'assets/skins/city_sound_creator/wallpaper_light.png',
  productionHash:
      '5da529d8fa41a4c2a487de2c3078dd9c1aff918a13bb3cd64edf51246e845a49',
);

const _dark = _WallpaperContract(
  sourcePath:
      'assets/skins/city_sound_creator/sources/'
      'wallpaper_dark_provider_v2.png',
  sourceHash:
      '2442efaa998af1a23c51f160a32b06e484d0a739645a9a5f8ec3bfb43e9d8e2d',
  productionPath: 'assets/skins/city_sound_creator/wallpaper_dark.png',
  productionHash:
      '3b2cd675bc05b23fc37f98587d6da017f7a0bf4734d2e5ccc381e4b99eceef17',
);

const _lightPreview = _PreviewContract(
  path: 'assets/skins/city_sound_creator/preview_light.png',
  hash: '73647d7cee0fd0d8753e921b3f782fe53cb575925a1c54852aceffd392e7a438',
);

const _darkPreview = _PreviewContract(
  path: 'assets/skins/city_sound_creator/preview_dark.png',
  hash: 'afbde82aad22cad3d7c5b041335eede125ba1ec4147867cac187fc273a5d36a4',
);

const _iconDirectory = 'assets/skins/city_sound_creator/icons';
const _iconSourceColorValue = 0xFFE85D52;

void main() {
  test('production wallpapers match approved provenance', () async {
    for (final contract in <_WallpaperContract>[_light, _dark]) {
      final sourceBytes = await File(contract.sourcePath).readAsBytes();
      final productionBytes = await File(contract.productionPath).readAsBytes();

      expect(sha256.convert(sourceBytes).toString(), contract.sourceHash);
      expect(_pngSize(sourceBytes), (941, 1672));
      expect(
        sha256.convert(productionBytes).toString(),
        contract.productionHash,
      );
      expect(_pngSize(productionBytes), (1882, 3344));
    }

    final provenance = await File(
      'assets/skins/city_sound_creator/LICENSES.md',
    ).readAsString();
    expect(provenance, contains('upscaled=true'));
    expect(provenance, contains('ImageMagick `7.1.2-13 Q16-HDRI`'));
    expect(provenance, contains('Face restoration: disabled'));
    expect(
      provenance,
      contains('Final user approval of the 2x derivatives: approved'),
    );
  });

  test('runtime packages derivatives but excludes provider sources', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    for (final contract in <_WallpaperContract>[_light, _dark]) {
      expect(pubspec, contains('    - ${contract.productionPath}'));
      expect(pubspec, isNot(contains(contract.sourcePath)));
    }

    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.graphite,
    ).resolve('city_sound_creator');
    expect(
      skin.light.background.wallpaper.descriptor,
      AppSkinAssetDescriptor(
        path: _light.productionPath,
        type: AppSkinAssetType.rasterImage,
      ),
    );
    expect(
      skin.dark.background.wallpaper.descriptor,
      AppSkinAssetDescriptor(
        path: _dark.productionPath,
        type: AppSkinAssetType.rasterImage,
      ),
    );
  });

  test('production icon catalog matches the approved V2 contract', () async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.graphite,
    ).resolve('city_sound_creator');
    final catalogPaths = <String>{};

    for (final role in AppSkinIconRole.values) {
      final descriptor = skin.icons[role]!.asset.descriptor;
      expect(descriptor, isNotNull, reason: '$role must use a themed SVG');
      expect(descriptor!.type, AppSkinAssetType.svg);
      expect(descriptor.themeColorSource?.toARGB32(), _iconSourceColorValue);
      expect(descriptor.path, startsWith('$_iconDirectory/'));

      final file = File(descriptor.path);
      expect(file.existsSync(), isTrue, reason: descriptor.path);
      final svg = await file.readAsString();
      expect(svg, contains('viewBox="0 0 24 24"'), reason: descriptor.path);
      expect(svg, contains('#E85D52'), reason: descriptor.path);
      expect(
        svg,
        isNot(
          matches(
            RegExp(
              r'<(text|image|script|foreignObject)\b',
              caseSensitive: false,
            ),
          ),
        ),
        reason: descriptor.path,
      );
      catalogPaths.add(descriptor.path);
    }

    expect(catalogPaths, hasLength(53));
    final diskPaths = Directory(_iconDirectory)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.svg'))
        .map((file) => file.path.replaceAll(Platform.pathSeparator, '/'))
        .toSet();
    expect(diskPaths, catalogPaths);

    final pubspec = await File('pubspec.yaml').readAsString();
    expect(pubspec, contains('    - $_iconDirectory/'));
    final provenance = await File(
      'assets/skins/city_sound_creator/LICENSES.md',
    ).readAsString();
    expect(provenance, contains('71 semantic roles'));
    expect(provenance, contains('53 unique `24x24` SVG files'));
    expect(provenance, contains('approved the complete V2 icon catalog'));
  });

  test('real UI previews match metadata and provenance', () async {
    final contracts = <_PreviewContract>[_lightPreview, _darkPreview];
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.graphite,
    ).resolve('city_sound_creator');
    final descriptors = <AppSkinAssetDescriptor?>[
      skin.metadata.lightPreview.descriptor,
      skin.metadata.darkPreview.descriptor,
    ];
    final pubspec = await File('pubspec.yaml').readAsString();
    final provenance = await File(
      'assets/skins/city_sound_creator/LICENSES.md',
    ).readAsString();

    for (var index = 0; index < contracts.length; index += 1) {
      final contract = contracts[index];
      final bytes = await File(contract.path).readAsBytes();
      expect(sha256.convert(bytes).toString(), contract.hash);
      expect(_pngSize(bytes), (360, 640));
      expect(
        descriptors[index],
        AppSkinAssetDescriptor(
          path: contract.path,
          type: AppSkinAssetType.rasterImage,
        ),
      );
      expect(pubspec, contains('    - ${contract.path}'));
      expect(provenance, contains(contract.path));
      expect(provenance, contains(contract.hash));
    }

    expect(provenance, contains('make skin-previews'));
    expect(provenance, contains('360x640'));
  });
}

(int, int) _pngSize(Uint8List bytes) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24) {
    throw const FormatException('PNG header is incomplete');
  }
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) {
      throw const FormatException('Invalid PNG signature');
    }
  }
  final header = ByteData.sublistView(bytes);
  return (header.getUint32(16), header.getUint32(20));
}

class _WallpaperContract {
  const _WallpaperContract({
    required this.sourcePath,
    required this.sourceHash,
    required this.productionPath,
    required this.productionHash,
  });

  final String sourcePath;
  final String sourceHash;
  final String productionPath;
  final String productionHash;
}

class _PreviewContract {
  const _PreviewContract({required this.path, required this.hash});

  final String path;
  final String hash;
}

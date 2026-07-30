import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';

void main() {
  test('bundled resolver loads an allowed skin asset', () async {
    final resolver = BundledAppSkinAssetResolver(
      bundle: _FakeAssetBundle(<String, List<int>>{
        'assets/skins/example/icon.svg': <int>[1, 2, 3],
      }),
    );

    final result = await resolver.load(
      const AppSkinAssetDescriptor(
        path: 'assets/skins/example/icon.svg',
        type: AppSkinAssetType.svg,
      ),
    );

    expect(result, isA<AppSkinAssetLoadSuccess>());
    expect(
      (result as AppSkinAssetLoadSuccess).bytes.buffer.asUint8List(),
      <int>[1, 2, 3],
    );
  });

  test('bundled resolver rejects paths outside skin assets', () async {
    final resolver = BundledAppSkinAssetResolver(bundle: _FakeAssetBundle({}));

    final result = await resolver.load(
      const AppSkinAssetDescriptor(
        path: 'assets/app_config.json',
        type: AppSkinAssetType.rasterImage,
      ),
    );

    expect(result, isA<AppSkinAssetLoadFailure>());
  });

  test('bundled resolver reports missing assets without throwing', () async {
    final resolver = BundledAppSkinAssetResolver(bundle: _FakeAssetBundle({}));

    final result = await resolver.load(
      const AppSkinAssetDescriptor(
        path: 'assets/skins/example/missing.png',
        type: AppSkinAssetType.rasterImage,
      ),
    );

    expect(result, isA<AppSkinAssetLoadFailure>());
  });

  test('resolver loads a validated application support image', () async {
    final support = await Directory.systemTemp.createTemp(
      'skin_asset_resolver_test_',
    );
    addTearDown(() => support.delete(recursive: true));
    final file = File(
      '${support.path}/skins/custom_image/revision_1/wallpaper_light.jpg',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(<int>[4, 5, 6]);
    final resolver = BundledAppSkinAssetResolver(
      bundle: _FakeAssetBundle(<String, List<int>>{}),
      applicationSupportDirectory: () async => support,
    );

    final result = await resolver.load(
      const AppSkinAssetDescriptor(
        path: 'skins/custom_image/revision_1/wallpaper_light.jpg',
        type: AppSkinAssetType.rasterImage,
        source: AppSkinAssetSource.applicationSupport,
      ),
    );

    expect(result, isA<AppSkinAssetLoadSuccess>());
    expect(
      (result as AppSkinAssetLoadSuccess).bytes.buffer.asUint8List(),
      <int>[4, 5, 6],
    );
  });

  test('resolver rejects application support path escape', () async {
    final resolver = BundledAppSkinAssetResolver(bundle: _FakeAssetBundle({}));

    final result = await resolver.load(
      const AppSkinAssetDescriptor(
        path: 'skins/custom_image/../wallpaper_light.jpg',
        type: AppSkinAssetType.rasterImage,
        source: AppSkinAssetSource.applicationSupport,
      ),
    );

    expect(result, isA<AppSkinAssetLoadFailure>());
  });
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, List<int>> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) {
      throw StateError('Missing asset: $key');
    }
    return Uint8List.fromList(bytes).buffer.asByteData();
  }
}

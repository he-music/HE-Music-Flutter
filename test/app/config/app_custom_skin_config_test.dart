import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_custom_skin_config.dart';

void main() {
  test('custom skin config round trips through versioned JSON', () {
    final config = _config();

    expect(AppCustomSkinConfig.tryDecode(config.encode()), config);
  });

  test('custom skin config rejects unknown schema and extra fields', () {
    final json = _config().toJson();

    expect(
      AppCustomSkinConfig.tryDecode(
        jsonEncode(<String, Object>{...json, 'schemaVersion': 2}),
      ),
      isNull,
    );
    expect(
      AppCustomSkinConfig.tryDecode(
        jsonEncode(<String, Object>{...json, 'unexpected': true}),
      ),
      isNull,
    );
  });

  test('custom skin config rejects path escape and a foreign seed color', () {
    final json = _config().toJson();

    expect(
      AppCustomSkinConfig.tryDecode(
        jsonEncode(<String, Object>{
          ...json,
          'lightAssetPath': '../wallpaper_light.jpg',
        }),
      ),
      isNull,
    );
    expect(
      AppCustomSkinConfig.tryDecode(
        jsonEncode(<String, Object>{...json, 'seedColor': 0xFF00FF00}),
      ),
      isNull,
    );
  });

  test('custom skin config rejects invalid focal points and empty colors', () {
    final json = _config().toJson();

    expect(
      AppCustomSkinConfig.tryDecode(
        jsonEncode(<String, Object>{...json, 'focalX': 1.1}),
      ),
      isNull,
    );
    expect(
      AppCustomSkinConfig.tryDecode(
        jsonEncode(<String, Object>{...json, 'candidateColors': <int>[]}),
      ),
      isNull,
    );
  });
}

AppCustomSkinConfig _config() {
  return AppCustomSkinConfig(
    revision: 'revision_1',
    lightAssetPath: 'skins/custom_image/revision_1/wallpaper_light.jpg',
    darkAssetPath: 'skins/custom_image/revision_1/wallpaper_dark.jpg',
    candidateColors: const <int>[0xFF123456, 0xFF654321],
    seedColor: 0xFF123456,
    focalX: 0.25,
    focalY: -0.5,
    sourceWidth: 2400,
    sourceHeight: 3200,
  );
}

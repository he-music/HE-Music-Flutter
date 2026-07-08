import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/shared/helpers/platform_label_helper.dart';

void main() {
  group('resolvePlatformLabel', () {
    final platforms = <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
      OnlinePlatform(
        id: 'kg',
        name: '',
        shortName: '酷狗',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];

    test('命中平台配置时返回平台名称', () {
      expect(resolvePlatformLabel('qq', platforms: platforms), 'QQ 音乐');
    });

    test('平台名称为空时回退为平台 ID 大写', () {
      expect(resolvePlatformLabel('kg', platforms: platforms), 'KG');
    });

    test('未知平台时回退为平台 ID 大写', () {
      expect(resolvePlatformLabel('wy', platforms: platforms), 'WY');
    });

    test('本地平台固定显示为 LOCAL', () {
      expect(resolvePlatformLabel('local', platforms: platforms), 'LOCAL');
    });

    test('空平台 ID 返回空字符串', () {
      expect(resolvePlatformLabel('  ', platforms: platforms), '');
    });
  });
}

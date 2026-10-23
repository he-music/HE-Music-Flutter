import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:he_music_flutter/features/online/data/datasources/online_platform_cache_data_source.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const cache = OnlinePlatformCacheDataSource();
  final platform = OnlinePlatform(
    id: 'qq',
    name: 'QQ',
    shortName: 'Q',
    status: 1,
    featureSupportFlag:
        PlatformFeatureSupportFlag.getDiscoverPage |
        PlatformFeatureSupportFlag.getSheetMusic,
    imageSizes: const [100, 300, 1000],
    qualities: const {'flac': '无损'},
  );

  test(
    'restores capabilities, image sizes and qualities without losing high bits',
    () async {
      final scope = OnlinePlatformCacheDataSource.scopeFor(
        'https://example.com/',
        'token-a',
      );
      await cache.write(scope, [platform]);
      final restored = (await cache.read(scope))!.single;
      expect(
        restored.supports(PlatformFeatureSupportFlag.getSheetMusic),
        isTrue,
      );
      expect(restored.imageSizes, platform.imageSizes);
      expect(restored.qualities, platform.qualities);
      expect(restored.shortName, 'Q');
    },
  );

  test('never reuses a snapshot across servers or credentials', () async {
    final scope = OnlinePlatformCacheDataSource.scopeFor(
      'https://a.example',
      'a',
    );
    await cache.write(scope, [platform]);
    expect(
      await cache.read(
        OnlinePlatformCacheDataSource.scopeFor('https://b.example', 'a'),
      ),
      isNull,
    );
    expect(
      await cache.read(
        OnlinePlatformCacheDataSource.scopeFor('https://a.example', 'b'),
      ),
      isNull,
    );
    expect(
      await cache.read(
        OnlinePlatformCacheDataSource.scopeFor('https://a.example', null),
      ),
      isNull,
    );
    expect(await cache.read(scope), isNotNull);
  });

  test(
    'empty writes do not erase a usable snapshot and clear is scoped',
    () async {
      await cache.write('a', [platform]);
      await cache.write('a', []);
      await cache.clear('b');
      expect(await cache.read('a'), hasLength(1));
      await cache.clear('a');
      expect(await cache.read('a'), isNull);
    },
  );

  test('corrupt data is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'online_platform_snapshot_v1': '{invalid',
    });
    expect(await cache.read('a'), isNull);
  });
  test('duplicate and incomplete snapshots are rejected', () async {
    await cache.write('a', [platform, platform]);
    expect(await cache.read('a'), isNull);
    SharedPreferences.setMockInitialValues({
      'online_platform_snapshot_v1':
          '{"schema":1,"scope":"a","platforms":[{"id":"qq","name":"QQ"}]}',
    });
    expect(await cache.read('a'), isNull);
  });
}

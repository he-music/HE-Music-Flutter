import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/data/datasources/favorite_song_cache_data_source.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const song = IdPlatformInfo(id: 'song', platform: 'qq');

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(authToken: 'token');
  void logout() => state = state.copyWith(clearToken: true);
}

class _Api extends OnlineApiClient {
  _Api(this.fetch) : super(Dio());
  final Future<List<IdPlatformInfo>> Function(int page) fetch;
  @override
  Future<List<IdPlatformInfo>> fetchFavoriteSongs({
    int pageIndex = 1,
    int pageSize = 1000,
  }) => fetch(pageIndex);
}

Future<void> drain() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cache roundtrip preserves distinct platforms, dedupes and represents empty lists',
    () async {
      const cache = FavoriteSongCacheDataSource();
      expect(await cache.read(), isNull);
      await cache.replace([
        song,
        song,
        const IdPlatformInfo(id: 'song', platform: 'kuwo'),
      ]);
      expect(await cache.read(), hasLength(2));
      await cache.setSong(song, liked: false);
      expect((await cache.read())!.single.platform, 'kuwo');
      await cache.replace([]);
      expect(await cache.read(), isEmpty);
      await cache.clear();
      expect(await cache.read(), isNull);
    },
  );

  test('offline startup retains saved favorites', () async {
    const cache = FavoriteSongCacheDataSource();
    await cache.replace([song]);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_Config.new),
        onlineApiClientProvider.overrideWithValue(
          _Api((_) async => throw StateError('offline')),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(favoriteSongStatusProvider.notifier);
    await drain();
    expect(
      controller.contains(songId: song.id, platform: song.platform),
      isTrue,
    );
    expect(container.read(favoriteSongStatusProvider).ready, isTrue);
    expect(await cache.read(), hasLength(1));
  });

  test('refresh fetches every page and replaces the global cache', () async {
    final pages = <int>[];
    final api = _Api((page) async {
      pages.add(page);
      return page == 1
          ? List.generate(1000, (i) => IdPlatformInfo(id: '$i', platform: 'qq'))
          : [song];
    });
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_Config.new),
        onlineApiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.read(favoriteSongStatusProvider);
    await drain();
    expect(pages, [1, 2]);
    expect(
      container.read(favoriteSongStatusProvider).songKeys,
      hasLength(1001),
    );
    expect(await const FavoriteSongCacheDataSource().read(), hasLength(1001));
  });

  test(
    'logout clears cache and a late network response cannot restore it',
    () async {
      const cache = FavoriteSongCacheDataSource();
      await cache.replace([song]);
      final pending = Completer<List<IdPlatformInfo>>();
      final started = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_Config.new),
          onlineApiClientProvider.overrideWithValue(
            _Api((_) {
              started.complete();
              return pending.future;
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(favoriteSongStatusProvider);
      await started.future;
      (container.read(appConfigProvider.notifier) as _Config).logout();
      pending.complete([song]);
      await drain();
      expect(container.read(favoriteSongStatusProvider).songKeys, isEmpty);
      expect(await cache.read(), isNull);
    },
  );
}

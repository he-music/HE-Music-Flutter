import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/artist_photo_api_client.dart';
import 'package:he_music_flutter/features/player/presentation/providers/artist_photo_provider.dart';

void main() {
  test('artist photo cache key isolates portrait and landscape photos', () {
    final container = ProviderContainer(
      overrides: [
        artistPhotoApiClientProvider.overrideWithValue(
          _TestArtistPhotoApiClient(const <String>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final cache = container.read(artistPhotoCacheProvider.notifier);

    final portrait = cache.buildCacheKey(
      'qq',
      const <String>['artist-b', 'artist-a'],
      const <String>['Beta', 'Alpha'],
      true,
    );
    final landscape = cache.buildCacheKey(
      'qq',
      const <String>['artist-a', 'artist-b'],
      const <String>['Alpha', 'Beta'],
      false,
    );

    expect(portrait, isNot(landscape));
    expect(portrait, 'qq|artist-a,artist-b|Alpha,Beta|true');
  });

  test(
    'fetching a new cache entry preserves every current photo index',
    () async {
      final client = _TestArtistPhotoApiClient(const <String>['photo-c']);
      final container = ProviderContainer(
        overrides: [artistPhotoApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final cache = container.read(artistPhotoCacheProvider.notifier);
      final firstKey = cache.buildCacheKey(
        'qq',
        const <String>['artist-a'],
        const <String>[],
        true,
      );
      final secondKey = cache.buildCacheKey(
        'qq',
        const <String>['artist-b'],
        const <String>[],
        false,
      );
      cache.updateIndex(firstKey, 2);
      cache.updateIndex(secondKey, 1);

      await cache.fetchPhotos(
        platform: 'qq',
        ids: const <String>['artist-c'],
        isPortrait: true,
      );

      final state = container.read(artistPhotoCacheProvider);
      expect(state.currentIndices[firstKey], 2);
      expect(state.currentIndices[secondKey], 1);
      expect(client.requestCount, 1);
    },
  );
  test(
    'concurrent matching photo requests share one call and cache the result',
    () async {
      final client = _DeferredPhotoApiClient();
      final container = ProviderContainer(
        overrides: [artistPhotoApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final cache = container.read(artistPhotoCacheProvider.notifier);
      final requests = [
        cache.fetchPhotos(platform: 'qq', ids: ['b', 'a'], isPortrait: true),
        cache.fetchPhotos(platform: 'qq', ids: ['a', 'b'], isPortrait: true),
        cache.fetchPhotos(platform: 'qq', ids: ['a', 'b'], isPortrait: true),
      ];
      expect(client.pending, hasLength(1));
      final key = cache.buildCacheKey('qq', ['a', 'b'], [], true);
      cache.updateIndex(key, 2);
      client.pending.single.complete(['photo-a', 'photo-b']);
      expect(await Future.wait(requests), everyElement(['photo-a', 'photo-b']));
      expect(
        await cache.fetchPhotos(
          platform: 'qq',
          ids: ['a', 'b'],
          isPortrait: true,
        ),
        ['photo-a', 'photo-b'],
      );
      expect(client.pending, hasLength(1));
      expect(cache.currentIndex(key), 2);
    },
  );

  test(
    'different photo keys remain independent and empty results are cached',
    () async {
      final client = _DeferredPhotoApiClient();
      final container = ProviderContainer(
        overrides: [artistPhotoApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final cache = container.read(artistPhotoCacheProvider.notifier);
      final portrait = cache.fetchPhotos(
        platform: 'qq',
        ids: ['a'],
        isPortrait: true,
      );
      final landscape = cache.fetchPhotos(platform: 'qq', ids: ['a']);
      final otherArtist = cache.fetchPhotos(platform: 'qq', ids: ['b']);
      final otherPlatform = cache.fetchPhotos(platform: 'netease', ids: ['a']);
      expect(client.pending, hasLength(4));
      client.pending[0].complete(['portrait']);
      client.pending[1].complete(['landscape']);
      client.pending[2].complete([]);
      client.pending[3].complete(['other-platform']);
      expect(await portrait, ['portrait']);
      expect(await landscape, ['landscape']);
      expect(await otherArtist, isEmpty);
      expect(await otherPlatform, ['other-platform']);
      expect(await cache.fetchPhotos(platform: 'qq', ids: ['b']), isEmpty);
      expect(client.pending, hasLength(4));
    },
  );

  test(
    'failed shared requests release their key so retries can succeed',
    () async {
      final client = _DeferredPhotoApiClient();
      final container = ProviderContainer(
        overrides: [artistPhotoApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final cache = container.read(artistPhotoCacheProvider.notifier);
      final requests = [
        cache.fetchPhotos(platform: 'qq', ids: ['a']),
        cache.fetchPhotos(platform: 'qq', ids: ['a']),
      ];
      final failure = expectLater(Future.wait(requests), throwsStateError);
      expect(client.pending, hasLength(1));
      client.pending.single.completeError(StateError('offline'));
      await failure;
      final retry = cache.fetchPhotos(platform: 'qq', ids: ['a']);
      expect(client.pending, hasLength(2));
      client.pending.last.complete(['recovered']);
      expect(await retry, ['recovered']);
    },
  );

  test('a completed request does not update a disposed photo cache', () async {
    final client = _DeferredPhotoApiClient();
    final container = ProviderContainer(
      overrides: [artistPhotoApiClientProvider.overrideWithValue(client)],
    );
    final cache = container.read(artistPhotoCacheProvider.notifier);
    final request = cache.fetchPhotos(platform: 'qq', ids: ['a']);
    container.dispose();
    client.pending.single.complete(['photo']);
    expect(await request, ['photo']);
  });
}

class _TestArtistPhotoApiClient extends ArtistPhotoApiClient {
  _TestArtistPhotoApiClient(this.urls) : super(Dio());

  final List<String> urls;
  int requestCount = 0;

  @override
  Future<List<String>> listPhotos({
    required String platform,
    List<String> ids = const <String>[],
    List<String> names = const <String>[],
    bool isPortrait = false,
  }) async {
    requestCount++;
    return urls;
  }
}

class _DeferredPhotoApiClient extends ArtistPhotoApiClient {
  _DeferredPhotoApiClient() : super(Dio());

  final pending = <Completer<List<String>>>[];

  @override
  Future<List<String>> listPhotos({
    required String platform,
    List<String> ids = const [],
    List<String> names = const [],
    bool isPortrait = false,
  }) {
    final result = Completer<List<String>>();
    pending.add(result);
    return result.future;
  }
}

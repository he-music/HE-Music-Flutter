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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/album/domain/entities/album_detail_content.dart';
import 'package:he_music_flutter/features/album/domain/entities/album_detail_request.dart';
import 'package:he_music_flutter/features/album/domain/repositories/album_detail_repository.dart';
import 'package:he_music_flutter/features/album/presentation/providers/album_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test(
    'initialize does not refetch same album when content already exists',
    () async {
      final repository = _FakeAlbumDetailRepository();
      final container = ProviderContainer(
        overrides: [
          albumDetailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      const request = AlbumDetailRequest(
        id: 'album-1',
        platform: 'qq',
        title: '测试专辑',
      );
      final provider = albumDetailControllerProvider(request.cacheKey);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(provider.notifier).initialize(request);
      await container.read(provider.notifier).initialize(request);

      final state = container.read(provider);

      expect(repository.fetchDetailCallCount, 1);
      expect(state.content?.title, '测试专辑');
      expect(state.loading, false);
      expect(state.errorMessage, isNull);
    },
  );
}

class _FakeAlbumDetailRepository implements AlbumDetailRepository {
  int fetchDetailCallCount = 0;

  @override
  Future<AlbumDetailContent> fetchDetail(AlbumDetailRequest request) async {
    fetchDetailCallCount += 1;
    return AlbumDetailContent(
      info: const AlbumInfo(
        name: '测试专辑',
        id: 'album-1',
        cover: '',
        artists: <SongInfoArtistInfo>[
          SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
        ],
        songCount: '1',
        publishTime: '2026-04-01',
        songs: <SongInfo>[],
        description: '',
        platform: 'qq',
        language: '',
        genre: '',
        type: 0,
        isFinished: true,
        playCount: '123',
      ),
      songs: const <SongInfo>[],
    );
  }
}

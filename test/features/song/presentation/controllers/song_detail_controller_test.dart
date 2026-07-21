import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_content.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_relations.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_request.dart';
import 'package:he_music_flutter/features/song/domain/repositories/song_detail_repository.dart';
import 'package:he_music_flutter/features/song/presentation/providers/song_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test(
    'initialize skips relations when platform does not support listSongRelations',
    () async {
      final repository = _FakeSongDetailRepository();
      final container = ProviderContainer(
        overrides: [
          songDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _UnsupportedSongRelationsPlatformsController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      const request = SongDetailRequest(
        id: 'song-1',
        platform: 'qq',
        title: '测试歌曲',
      );
      final provider = songDetailControllerProvider(request.cacheKey);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(provider.notifier).initialize(request);

      final state = container.read(provider);

      expect(repository.fetchDetailCallCount, 1);
      expect(repository.fetchRelationsCallCount, 0);
      expect(state.content?.song.title, '测试歌曲');
      expect(state.relations, isNull);
      expect(state.relationsLoading, false);
      expect(state.relationsErrorMessage, isNull);
    },
  );
}

class _UnsupportedSongRelationsPlatformsController
    extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getSongDetail,
      ),
    ];
  }
}

class _FakeSongDetailRepository implements SongDetailRepository {
  int fetchDetailCallCount = 0;
  int fetchRelationsCallCount = 0;

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) async {
    fetchDetailCallCount += 1;
    return SongDetailContent(
      song: SongInfo(
        name: '测试歌曲',
        subtitle: '测试副标题',
        id: 'song-1',
        duration: 215,
        mvId: 'mv-1',
        album: const SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
        artists: const <SongInfoArtistInfo>[
          SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
        ],
        links: const <LinkInfo>[],
        platform: 'qq',
        cover: '',
        sublist: const <SongInfo>[],
        originalType: 0,
      ),
      publishTime: '2024-01-01',
      language: '国语',
    );
  }

  @override
  Future<SongDetailRelations> fetchRelations(SongDetailRequest request) async {
    fetchRelationsCallCount += 1;
    return const SongDetailRelations();
  }
}

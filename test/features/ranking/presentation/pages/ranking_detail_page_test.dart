import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_collection_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_collection_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_detail.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_group.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_info.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_preview_song.dart';
import 'package:he_music_flutter/features/ranking/domain/repositories/ranking_repository.dart';
import 'package:he_music_flutter/features/ranking/presentation/pages/ranking_detail_page.dart';
import 'package:he_music_flutter/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('ranking detail shows english count text for en locale', (
    tester,
  ) async {
    final repository = _FakeRankingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            () => _TestAppConfigController(localeCode: 'en'),
          ),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          rankingRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(_TestFavoriteSongStatus.new),
          favoriteCollectionStatusProvider.overrideWith(
            _TestFavoriteCollectionStatus.new,
          ),
        ],
        child: const MaterialApp(
          home: RankingDetailPage(
            id: 'ranking-1',
            platform: 'qq',
            title: 'Test Ranking',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('2 tracks'), findsOneWidget);
    expect(find.text('Play All 2'), findsOneWidget);
  });

  testWidgets('ranking detail shows songs from detail payload on first paint', (
    tester,
  ) async {
    final repository = _FakeRankingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          rankingRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(_TestFavoriteSongStatus.new),
          favoriteCollectionStatusProvider.overrideWith(
            _TestFavoriteCollectionStatus.new,
          ),
        ],
        child: const MaterialApp(
          home: RankingDetailPage(
            id: 'ranking-1',
            platform: 'qq',
            title: '测试榜单',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.fetchDetailCallCount, 1);
    expect(find.text('榜单首屏歌曲'), findsOneWidget);
  });

  testWidgets('ranking detail enters batch mode and toggles loaded songs', (
    tester,
  ) async {
    final repository = _FakeRankingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          rankingRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(_TestFavoriteSongStatus.new),
          favoriteCollectionStatusProvider.overrideWith(
            _TestFavoriteCollectionStatus.new,
          ),
        ],
        child: const MaterialApp(
          home: RankingDetailPage(
            id: 'ranking-1',
            platform: 'qq',
            title: '测试榜单',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Batch'));
    await tester.pump();

    await tester.tap(find.text('榜单首屏歌曲'));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
  });
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({this.localeCode = 'zh'});

  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: localeCode,
      apiBaseUrl: 'https://example.com',
      authToken: 'token',
    );
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}

class _FakeRankingRepository implements RankingRepository {
  int fetchDetailCallCount = 0;

  @override
  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  }) async {
    fetchDetailCallCount += 1;
    return RankingDetail(
      info: RankingInfo(
        id: id,
        platform: platform,
        name: '测试榜单',
        coverUrl: 'https://example.com/ranking.jpg',
        previewSongs: const <RankingPreviewSong>[],
      ),
      songs: const <SongInfo>[
        SongInfo(
          name: '榜单首屏歌曲',
          subtitle: '',
          id: 'song-1',
          duration: 240,
          mvId: '',
          album: SongInfoAlbumInfo(name: '专辑 A', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '歌手 A'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: 'https://example.com/song-1.jpg',
        ),
        SongInfo(
          name: '榜单第二首',
          subtitle: '',
          id: 'song-2',
          duration: 200,
          mvId: '',
          album: SongInfoAlbumInfo(name: '专辑 B', id: 'album-2'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-2', name: '歌手 B'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: 'https://example.com/song-2.jpg',
        ),
      ],
      hasMore: false,
      lastId: '',
      totalCount: 2,
      description: '测试榜单描述',
    );
  }

  @override
  Future<List<RankingGroup>> fetchRankingGroups({
    required String platform,
  }) async {
    return const <RankingGroup>[];
  }
}

class _TestFavoriteSongStatus extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return FavoriteSongStatusState.initial;
  }
}

class _TestFavoriteCollectionStatus extends FavoriteCollectionStatusController {
  @override
  FavoriteCollectionStatusState build() {
    return FavoriteCollectionStatusState.initial;
  }
}

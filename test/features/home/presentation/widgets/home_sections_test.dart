import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_state.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/home_sections.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_info.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_preview_song.dart';
import 'package:he_music_flutter/features/ranking/presentation/widgets/ranking_cards.dart';
import 'package:he_music_flutter/shared/layout/adaptive_media_grid_spec.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/artist_grid_card.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';
import 'package:he_music_flutter/shared/widgets/online_song_list_item.dart';
import 'package:he_music_flutter/shared/widgets/video_item.dart';

void main() {
  testWidgets('按后端标题渲染七类资源专属布局', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tappedActions = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: buildHomeSectionSlivers(
                state: _loadedState,
                gridSpec: resolveAdaptiveMediaGridSpec(maxWidth: 860),
                loadingText: '加载中',
                emptyText: '空',
                retryText: '重试',
                onRetry: () {},
                sectionActionOf: (section) {
                  if (section.sectionType != HomeSectionType.newSongs &&
                      section.sectionType != HomeSectionType.newAlbums &&
                      section.sectionType != HomeSectionType.ranking) {
                    return null;
                  }
                  return HomeSectionAction(
                    label: '更多-${section.title}',
                    onTap: () => tappedActions.add(section.title),
                  );
                },
                onTapSong: (_, _) {},
                onTapAlbum: (_) {},
                onTapPlaylist: (_) {},
                onTapMv: (_) {},
                onTapArtist: (_) {},
                onTapRanking: (_) {},
                onTapRadio: (_) {},
                onMoreSong: (_) {},
                isSongLiked: (_) => false,
                onLikeSong: (_) async {},
                isCurrentSong: (_) => false,
                isRadioPlaying: (_) => false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final title in _sectionTitles) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byType(OnlineSongListItem), findsOneWidget);
    expect(find.byType(MediaGridCard), findsNWidgets(3));
    expect(find.byType(VideoGridItem), findsOneWidget);
    expect(find.byType(ArtistGridCard), findsOneWidget);
    expect(find.byType(RankingCards), findsOneWidget);
    expect(find.text('别名'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(3));

    for (final title in <String>['动态新歌', '动态新碟', '动态榜单']) {
      await tester.tap(find.text('更多-$title'));
      await tester.pump();
    }
    expect(tappedActions, <String>['动态新歌', '动态新碟', '动态榜单']);
  });

  test('section slivers 不依赖滚动期 SliverLayoutBuilder', () {
    final slivers = buildHomeSectionSlivers(
      state: _loadedState,
      gridSpec: resolveAdaptiveMediaGridSpec(maxWidth: 320),
      loadingText: '加载中',
      emptyText: '空',
      retryText: '重试',
      onRetry: () {},
      sectionActionOf: (_) => null,
      onTapSong: (_, _) {},
      onTapAlbum: (_) {},
      onTapPlaylist: (_) {},
      onTapMv: (_) {},
      onTapArtist: (_) {},
      onTapRanking: (_) {},
      onTapRadio: (_) {},
      onMoreSong: (_) {},
      isSongLiked: (_) => false,
      onLikeSong: (_) async {},
      isCurrentSong: (_) => false,
      isRadioPlaying: (_) => false,
    );

    expect(slivers.whereType<SliverLayoutBuilder>(), isEmpty);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

const _sectionTitles = <String>[
  '动态新歌',
  '动态新碟',
  '动态歌单',
  '动态视频',
  '动态歌手',
  '动态榜单',
  '动态电台',
];

const _loadedState = HomeContentState(
  initialized: true,
  loading: false,
  refreshing: false,
  loadingMore: false,
  selectedPlatformId: 'qq',
  hasMore: false,
  nextPageIndex: 2,
  sections: <HomePageSection>[
    HomePageSection(
      sectionTypeCode: 2,
      sectionType: HomeSectionType.newSongs,
      resourceType: HomeResourceType.song,
      title: '动态新歌',
      songs: <SongInfo>[_song],
    ),
    HomePageSection(
      sectionTypeCode: 3,
      sectionType: HomeSectionType.newAlbums,
      resourceType: HomeResourceType.album,
      title: '动态新碟',
      albums: <AlbumInfo>[_album],
    ),
    HomePageSection(
      sectionTypeCode: 1,
      sectionType: HomeSectionType.generic,
      resourceType: HomeResourceType.playlist,
      title: '动态歌单',
      playlists: <PlaylistInfo>[_playlist],
    ),
    HomePageSection(
      sectionTypeCode: 5,
      sectionType: HomeSectionType.feed,
      resourceType: HomeResourceType.mv,
      title: '动态视频',
      mvs: <MvInfo>[_mv],
    ),
    HomePageSection(
      sectionTypeCode: 0,
      sectionType: HomeSectionType.unspecified,
      resourceType: HomeResourceType.artist,
      title: '动态歌手',
      artists: <ArtistInfo>[_artist],
    ),
    HomePageSection(
      sectionTypeCode: 4,
      sectionType: HomeSectionType.ranking,
      resourceType: HomeResourceType.ranking,
      title: '动态榜单',
      rankings: <RankingInfo>[_ranking],
    ),
    HomePageSection(
      sectionTypeCode: 99,
      sectionType: HomeSectionType.unknown,
      resourceType: HomeResourceType.radio,
      title: '动态电台',
      radios: <RadioInfo>[_radio],
    ),
  ],
);

const _song = SongInfo(
  name: '歌曲',
  subtitle: '',
  id: 'song-1',
  duration: 180000,
  mvId: '',
  album: SongInfoAlbumInfo(id: 'album-1', name: '专辑'),
  artists: <SongInfoArtistInfo>[SongInfoArtistInfo(id: 'artist-1', name: '歌手')],
  links: <LinkInfo>[],
  platform: 'qq',
  cover: '',
);

const _album = AlbumInfo(
  name: '专辑',
  id: 'album-1',
  cover: '',
  artists: <SongInfoArtistInfo>[SongInfoArtistInfo(id: 'artist-1', name: '歌手')],
  songCount: '10',
  publishTime: '',
  songs: <SongInfo>[],
  description: '',
  platform: 'qq',
  language: '',
  genre: '',
  type: 0,
  isFinished: true,
  playCount: '1',
);

const _playlist = PlaylistInfo(
  name: '歌单',
  id: 'playlist-1',
  cover: '',
  creator: '创建者',
  songCount: '20',
  playCount: '2',
  songs: <SongInfo>[],
  platform: 'qq',
  description: '',
);

const _mv = MvInfo(
  platform: 'qq',
  links: <LinkInfo>[],
  id: 'mv-1',
  name: '视频',
  cover: '',
  type: 0,
  playCount: '3',
  creator: '作者',
  duration: 120,
  description: '',
);

const _artist = ArtistInfo(
  id: 'artist-1',
  name: '歌手卡',
  cover: '',
  platform: 'qq',
  description: '',
  mvCount: '1',
  songCount: '10',
  albumCount: '2',
  alias: '别名',
);

const _ranking = RankingInfo(
  id: 'ranking-1',
  platform: 'qq',
  name: '榜单卡',
  coverUrl: '',
  previewSongs: <RankingPreviewSong>[
    RankingPreviewSong(name: '榜单歌曲', artist: '榜单歌手'),
  ],
);

const _radio = RadioInfo(name: '电台', id: 'radio-1', cover: '', platform: 'qq');

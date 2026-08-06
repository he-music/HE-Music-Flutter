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
import 'package:he_music_flutter/shared/constants/layout_tokens.dart';
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
    final tappedEntries = <HomePageEntry>[];

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
                quickEntryGridSpec: resolveHomeQuickEntryGridSpec(
                  maxWidth: 860,
                ),
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
                onTapEntry: tappedEntries.add,
                onMoreSong: (_) {},
                isSongLiked: (_) => false,
                onLikeSong: (_) async {},
                isCurrentSong: (_) => false,
                isRadioPlaying: (_) => false,
                isEntryRadioPlaying: (_) => false,
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
    expect(find.byType(MediaGridCard), findsNWidgets(6));
    expect(find.byType(VideoGridItem), findsOneWidget);
    expect(find.byType(ArtistGridCard), findsOneWidget);
    expect(find.byType(RankingCards), findsOneWidget);
    expect(find.text('别名'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(3));

    final quickEntryCard = find.ancestor(
      of: find.text('每日新歌'),
      matching: find.byType(MediaGridCard),
    );
    final albumCard = find.ancestor(
      of: find.text('专辑'),
      matching: find.byType(MediaGridCard),
    );
    expect(
      tester.getSize(quickEntryCard).width,
      lessThan(tester.getSize(albumCard).width),
    );
    expect(
      tester.getSize(quickEntryCard).aspectRatio,
      closeTo(1, 0.01),
      reason: '快捷入口使用方形封面叠字卡片',
    );
    expect(
      find.ancestor(of: find.text('每日新歌'), matching: find.byType(Stack)),
      findsWidgets,
      reason: '快捷入口文字应位于封面 Stack 内',
    );

    await tester.tap(find.text('每日新歌'));
    await tester.pump();
    expect(tappedEntries.single.targetType, HomePageEntryTargetType.songList);

    final radioCard = find.ancestor(
      of: find.text('私人电台'),
      matching: find.byType(MediaGridCard),
    );
    final fallbackIcon = find.descendant(
      of: radioCard,
      matching: find.byIcon(Icons.queue_music_rounded),
    );
    expect(fallbackIcon, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('私人电台')).dy,
      greaterThan(tester.getTopLeft(fallbackIcon).dy),
    );

    for (final title in <String>['动态新歌', '动态新碟', '动态榜单']) {
      await tester.tap(find.text('更多-$title'));
      await tester.pump();
    }
    expect(tappedActions, <String>['动态新歌', '动态新碟', '动态榜单']);
  });

  test('section slivers 不依赖滚动期 SliverLayoutBuilder', () {
    final quickEntryGridSpec = resolveHomeQuickEntryGridSpec(maxWidth: 320);
    final slivers = buildHomeSectionSlivers(
      state: _loadedState,
      gridSpec: resolveAdaptiveMediaGridSpec(maxWidth: 320),
      quickEntryGridSpec: quickEntryGridSpec,
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
      onTapEntry: (_) {},
      onMoreSong: (_) {},
      isSongLiked: (_) => false,
      onLikeSong: (_) async {},
      isCurrentSong: (_) => false,
      isRadioPlaying: (_) => false,
      isEntryRadioPlaying: (_) => false,
    );

    expect(slivers.whereType<SliverLayoutBuilder>(), isEmpty);
    expect(quickEntryGridSpec.crossAxisCount, 3);
    expect(quickEntryGridSpec.childAspectRatio, 1);
    expect(slivers, hasLength(23), reason: '空标题 QUICK_ENTRIES 不应生成标题 sliver');
  });

  testWidgets('紧凑宽度无法容纳全部快捷入口时使用单行横向滚动', (tester) async {
    const surfaceWidth = 390.0;
    await tester.binding.setSurfaceSize(const Size(surfaceWidth, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildQuickEntryTestApp(
        maxWidth: surfaceWidth - LayoutTokens.compactPageGutter * 2,
        entryCount: 4,
      ),
    );
    await tester.pump();

    final horizontalList = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalList, findsOneWidget);
    expect(find.byType(SliverGrid), findsNothing);
    expect(find.byType(MediaGridCard), findsNWidgets(4));

    final scrollable = find.descendant(
      of: horizontalList,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));

    final listRect = tester.getRect(horizontalList);
    final nextCardRect = tester.getRect(find.byType(MediaGridCard).at(3));
    expect(listRect.right - nextCardRect.left, closeTo(26, 0.01));
  });

  testWidgets('移动端按宽度展示不同数量卡片并固定露出下一张', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cases = <({double surfaceWidth, int entryCount, int nextIndex})>[
      (surfaceWidth: 320, entryCount: 4, nextIndex: 2),
      (surfaceWidth: 480, entryCount: 6, nextIndex: 4),
      (surfaceWidth: 600, entryCount: 7, nextIndex: 5),
    ];

    for (final testCase in cases) {
      await tester.binding.setSurfaceSize(Size(testCase.surfaceWidth, 800));
      await tester.pumpWidget(
        _buildQuickEntryTestApp(
          maxWidth: testCase.surfaceWidth - LayoutTokens.compactPageGutter * 2,
          entryCount: testCase.entryCount,
        ),
      );
      await tester.pump();

      final horizontalList = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );
      final listRect = tester.getRect(horizontalList);
      final cardSize = tester.getSize(find.byType(MediaGridCard).first);
      final nextCardRect = tester.getRect(
        find.byType(MediaGridCard).at(testCase.nextIndex),
      );
      expect(cardSize.width, inInclusiveRange(96, 128));
      expect(cardSize.height, cardSize.width);
      expect(
        listRect.right - nextCardRect.left,
        closeTo(26, 0.01),
        reason: '${testCase.surfaceWidth}dp 宽度应露出下一张卡片',
      );
    }
  });

  testWidgets('非移动端横滑卡片保持固定尺寸', (tester) async {
    const surfaceWidth = 700.0;
    await tester.binding.setSurfaceSize(const Size(surfaceWidth, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildQuickEntryTestApp(
        maxWidth: surfaceWidth - LayoutTokens.compactPageGutter * 2,
        entryCount: 7,
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(MediaGridCard).first),
      const Size.square(112),
    );
  });

  testWidgets('宽度能容纳全部快捷入口时使用 Grid', (tester) async {
    const surfaceWidth = 900.0;
    await tester.binding.setSurfaceSize(const Size(surfaceWidth, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildQuickEntryTestApp(
        maxWidth: surfaceWidth - LayoutTokens.compactPageGutter * 2,
        entryCount: 7,
      ),
    );
    await tester.pump();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    expect(find.byType(MediaGridCard), findsNWidgets(7));
  });
}

Widget _buildQuickEntryTestApp({
  required double maxWidth,
  required int entryCount,
}) {
  final entries = List<HomePageEntry>.generate(
    entryCount,
    (index) => HomePageEntry(
      targetType: HomePageEntryTargetType.songList,
      targetId: 'entry-$index',
      title: '入口-$index',
      subtitle: '',
      cover: '',
    ),
  );
  final state = HomeContentState(
    initialized: true,
    loading: false,
    refreshing: false,
    loadingMore: false,
    selectedPlatformId: 'qq',
    sections: <HomePageSection>[
      HomePageSection(
        sectionTypeCode: 6,
        sectionType: HomeSectionType.quickEntries,
        resourceType: null,
        title: '',
        entries: entries,
      ),
    ],
    hasMore: false,
    nextPageIndex: 2,
  );
  return ProviderScope(
    overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    child: MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: buildHomeSectionSlivers(
            state: state,
            gridSpec: resolveAdaptiveMediaGridSpec(maxWidth: maxWidth),
            quickEntryGridSpec: resolveHomeQuickEntryGridSpec(
              maxWidth: maxWidth,
            ),
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
            onTapEntry: (_) {},
            onMoreSong: (_) {},
            isSongLiked: (_) => false,
            onLikeSong: (_) async {},
            isCurrentSong: (_) => false,
            isRadioPlaying: (_) => false,
            isEntryRadioPlaying: (_) => false,
          ),
        ),
      ),
    ),
  );
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
    HomePageSection(
      sectionTypeCode: 6,
      sectionType: HomeSectionType.quickEntries,
      resourceType: null,
      title: '',
      entries: <HomePageEntry>[
        HomePageEntry(
          targetType: HomePageEntryTargetType.songList,
          targetId: 'daily-new',
          title: '每日新歌',
          subtitle: '今日更新',
          cover: 'https://example.com/new.jpg',
        ),
        HomePageEntry(
          targetType: HomePageEntryTargetType.radio,
          targetId: 'radio-1',
          title: '私人电台',
          subtitle: '',
          cover: '',
        ),
        HomePageEntry(
          targetType: HomePageEntryTargetType.playlist,
          targetId: 'playlist-1',
          title: '精选歌单',
          subtitle: '',
          cover: '',
        ),
      ],
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

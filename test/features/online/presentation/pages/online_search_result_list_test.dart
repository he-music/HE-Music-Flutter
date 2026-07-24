import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_result_list.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/video_item.dart';

void main() {
  testWidgets(
    'video search result list shows video skeleton on initial loading',
    (tester) async {
      await tester.pumpWidget(
        _buildResultList(type: SearchType.video, initialLoading: true),
      );

      expect(find.byType(PlazaVideoListSkeleton), findsOneWidget);
    },
  );

  testWidgets('video search result list renders video card and handles tap', (
    tester,
  ) async {
    Map<String, dynamic>? tappedItem;

    await tester.pumpWidget(
      _buildResultList(
        type: SearchType.video,
        results: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'mv-1',
            'platform': 'qq',
            'name': '测试视频',
            'cover': '',
            'creator': '测试作者',
            'duration': 120,
            'play_count': '88',
          },
        ],
        onTapItem: (item) => tappedItem = item,
      ),
    );

    expect(find.byType(VideoListItem), findsOneWidget);
    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('测试作者'), findsOneWidget);

    await tester.tap(find.byType(VideoListItem));
    await tester.pump();

    expect(tappedItem?['id'], 'mv-1');
  });

  testWidgets(
    'immersive artist playlist and album results use content surfaces',
    (tester) async {
      for (final type in <SearchType>[
        SearchType.artist,
        SearchType.playlist,
        SearchType.album,
      ]) {
        await tester.pumpWidget(
          _buildResultList(
            type: type,
            results: <Map<String, dynamic>>[_resultForType(type)],
            immersive: true,
          ),
        );

        expect(find.byType(AppSkinSurface), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
      }
    },
  );

  testWidgets(
    'immersive search skeleton items use zero-blur content surfaces',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final type in <SearchType>[
        SearchType.song,
        SearchType.artist,
        SearchType.playlist,
        SearchType.album,
      ]) {
        await tester.pumpWidget(
          _buildResultList(type: type, initialLoading: true, immersive: true),
        );

        expect(find.byType(AppSkinSurface), findsNWidgets(8));
        expect(find.byType(BackdropFilter), findsNothing);
      }
    },
  );

  testWidgets('song search uses nested song and never expands full lyrics', (
    tester,
  ) async {
    SongInfo? tappedSong;
    await tester.pumpWidget(
      _buildResultList(
        type: SearchType.song,
        immersive: true,
        songResults: <SearchSongInfo>[
          _searchSong(
            lyricSnippet: r'命中的歌词片段\n第二行片段',
            lyric: '完整歌词第一行\n完整歌词第二行',
          ),
        ],
        onTapSongItem: (song) => tappedSong = song,
      ),
    );
    await tester.pump();

    expect(find.text('测试歌曲'), findsOneWidget);
    const snippetKey = ValueKey('search-lyric-snippet-song-1|qq');
    expect(find.byKey(snippetKey), findsOneWidget);
    final snippet = tester.widget<Text>(find.byKey(snippetKey));
    final secondSnippetLine = tester.widget<Text>(
      find.byKey(const ValueKey('search-lyric-snippet-song-1|qq-1')),
    );
    expect(snippet.softWrap, isFalse);
    expect(snippet.maxLines, 1);
    expect(snippet.overflow, TextOverflow.ellipsis);
    expect(secondSnippetLine.textSpan?.toPlainText(), '第二行片段');
    expect(secondSnippetLine.softWrap, isFalse);
    expect(secondSnippetLine.maxLines, 1);
    expect(secondSnippetLine.overflow, TextOverflow.ellipsis);
    expect(
      find.byKey(const ValueKey('search-lyric-badge-song-1|qq')),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.byKey(snippetKey), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('search-lyric-snippet-action-song-1|qq')),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(snippetKey),
        matching: find.byType(AppSkinSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('search-lyric-toggle-song-1|qq')),
      findsNothing,
    );

    await tester.tap(find.text('测试歌曲'));
    await tester.pump();
    expect(tappedSong?.id, 'song-1');
  });

  testWidgets('lyric search expands and collapses full plain-text lyrics', (
    tester,
  ) async {
    SongInfo? tappedSong;
    await tester.pumpWidget(
      _buildResultList(
        type: SearchType.lyric,
        immersive: true,
        songResults: <SearchSongInfo>[
          _searchSong(
            lyricSnippet: r'命中的歌词片段\n第二行片段',
            lyric: r'完整歌词第一行\n完整歌词第二行',
          ),
        ],
        onTapSongItem: (song) => tappedSong = song,
      ),
    );
    await tester.pump();

    const fullLyricKey = ValueKey('search-lyric-full-song-1|qq');
    const snippetKey = ValueKey('search-lyric-snippet-song-1|qq');
    final toggle = find.byKey(const ValueKey('search-lyric-toggle-song-1|qq'));
    final snippet = tester.widget<Text>(find.byKey(snippetKey));
    final secondSnippetLine = tester.widget<Text>(
      find.byKey(const ValueKey('search-lyric-snippet-song-1|qq-1')),
    );
    final snippetFontSize = snippet.style?.fontSize;
    expect(snippet.softWrap, isFalse);
    expect(snippet.maxLines, 1);
    expect(snippet.overflow, TextOverflow.ellipsis);
    expect(secondSnippetLine.textSpan?.toPlainText(), '第二行片段');
    expect(secondSnippetLine.softWrap, isFalse);
    expect(secondSnippetLine.maxLines, 1);
    expect(secondSnippetLine.overflow, TextOverflow.ellipsis);
    expect(
      find.ancestor(of: find.byKey(snippetKey), matching: find.byType(InkWell)),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('search-lyric-snippet-action-song-1|qq')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('search-lyric-badge-song-1|qq')),
      findsNothing,
    );
    expect(toggle, findsOneWidget);
    expect(tester.getSize(toggle).height, 32);
    expect(find.byKey(fullLyricKey), findsNothing);

    await tester.tap(find.byKey(snippetKey));
    await tester.pump();
    expect(find.byKey(fullLyricKey), findsOneWidget);
    expect(find.byKey(snippetKey), findsNothing);
    expect(tappedSong, isNull);
    expect(find.text('收起歌词'), findsOneWidget);
    final fullLyricText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(fullLyricKey),
        matching: find.byType(Text),
      ),
    );
    expect(fullLyricText.textSpan?.toPlainText(), '完整歌词第一行\n完整歌词第二行');
    expect(fullLyricText.textSpan?.toPlainText(), isNot(contains(r'\n')));
    expect(fullLyricText.style?.fontSize, snippetFontSize);
    expect(
      find.ancestor(
        of: find.byKey(fullLyricKey),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('search-lyric-full-action-song-1|qq')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(fullLyricKey),
        matching: find.byType(AppSkinSurface),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(fullLyricKey));
    await tester.pump();
    expect(find.byKey(fullLyricKey), findsNothing);
    expect(find.byKey(snippetKey), findsOneWidget);
    expect(tappedSong, isNull);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.byKey(fullLyricKey), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.byKey(fullLyricKey), findsNothing);
    expect(find.byKey(snippetKey), findsOneWidget);
  });

  testWidgets('expanded version invokes action with the nested version song', (
    tester,
  ) async {
    SongInfo? tappedSong;
    await tester.pumpWidget(
      _buildResultList(
        type: SearchType.song,
        songResults: <SearchSongInfo>[
          _searchSong(
            lyricSnippet: '',
            lyric: '',
            sublist: <SearchSongInfo>[
              _searchSong(
                id: 'song-live',
                name: '现场版本',
                lyricSnippet: '',
                lyric: '',
              ),
            ],
          ),
        ],
        onTapSongItem: (song) => tappedSong = song,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('更多版本'));
    await tester.pump();
    await tester.tap(find.text('现场版本'));
    await tester.pump();

    expect(tappedSong?.id, 'song-live');
  });
}

Widget _buildResultList({
  required SearchType type,
  bool initialLoading = false,
  bool immersive = false,
  List<Map<String, dynamic>> results = const <Map<String, dynamic>>[],
  List<SearchSongInfo> songResults = const <SearchSongInfo>[],
  ValueChanged<Map<String, dynamic>>? onTapItem,
  ValueChanged<SongInfo>? onTapSongItem,
}) {
  final skin = AppSkinRegistry.builtIn(
    AppThemeAccent.forest,
  ).resolve(AppSkinRegistry.citySoundCreatorId);
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
    ],
    child: MaterialApp(
      theme: immersive ? AppTheme.light(skin) : null,
      home: Scaffold(
        body: OnlineSearchResultList(
          type: type,
          results: results,
          songResults: songResults,
          searchKeyword: '歌词',
          error: null,
          initialLoading: initialLoading,
          likedSongKeys: const <String>{},
          loadingMore: false,
          hasMore: true,
          onTapItem: onTapItem ?? (_) {},
          onTapSongItem: onTapSongItem ?? (_) {},
          onLikeSongItem: (_) async {},
          onMoreSongItem: (_) {},
          onLoadMore: () async {},
        ),
      ),
    ),
  );
}

SearchSongInfo _searchSong({
  String id = 'song-1',
  String name = '测试歌曲',
  required String lyricSnippet,
  required String lyric,
  List<SearchSongInfo> sublist = const <SearchSongInfo>[],
}) {
  return SearchSongInfo(
    song: SongInfo(
      name: name,
      subtitle: '',
      id: id,
      duration: 180,
      mvId: '',
      album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
      artists: <SongInfoArtistInfo>[
        SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
      ],
      links: <LinkInfo>[],
      platform: 'qq',
      cover: '',
    ),
    sublist: sublist,
    originalType: 1,
    lyricSnippet: lyricSnippet,
    lyric: lyric,
    matchedKeywords: const <String>['歌词'],
  );
}

Map<String, dynamic> _resultForType(SearchType type) {
  return switch (type) {
    SearchType.artist => <String, dynamic>{
      'id': 'artist-1',
      'platform': 'qq',
      'name': '测试歌手',
      'cover': '',
      'song_count': 10,
      'album_count': 5,
      'mv_count': 1,
    },
    SearchType.playlist => <String, dynamic>{
      'id': 'playlist-1',
      'platform': 'qq',
      'name': '测试歌单',
      'creator': '测试用户',
      'cover': '',
      'song_count': 8,
    },
    SearchType.album => <String, dynamic>{
      'id': 'album-1',
      'platform': 'qq',
      'name': '测试专辑',
      'artists': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'artist-1', 'name': '测试歌手'},
      ],
      'cover': '',
    },
    _ => throw ArgumentError.value(type, 'type'),
  };
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      apiBaseUrl: 'https://example.com',
      localeCode: 'zh',
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.searchMv,
        imageSizes: const <int>[300],
      ),
    ];
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  @override
  Future<void> initialize() async {}
}

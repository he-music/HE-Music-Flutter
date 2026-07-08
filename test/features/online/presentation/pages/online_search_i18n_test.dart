import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_bars.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_hot_panel.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_result_list.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/online/presentation/widgets/search_artist_list_item.dart';

void main() {
  testWidgets('search type bar shows english labels when locale is en', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        localeCode: 'en',
        child: SearchTypeBar(
          localeCode: 'en',
          selectedType: SearchType.song,
          types: const <SearchType>[
            SearchType.comprehensive,
            SearchType.song,
            SearchType.playlist,
            SearchType.album,
            SearchType.artist,
            SearchType.video,
          ],
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
  });

  testWidgets('search hot panel shows english texts when locale is en', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        localeCode: 'en',
        child: OnlineSearchHotPanel(
          localeCode: 'en',
          historyKeywords: const <String>[],
          hotKeywords: const <String>[],
          loadingHistory: false,
          loadingHot: false,
          onTapKeyword: (_) {},
          onClearHistory: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Hot Searches'), findsOneWidget);
    expect(find.text('No hot searches'), findsOneWidget);
  });

  testWidgets(
    'search hot panel shows chinese clear tooltip when locale is zh',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          localeCode: 'zh',
          child: OnlineSearchHotPanel(
            localeCode: 'zh',
            historyKeywords: const <String>["你好"],
            hotKeywords: const <String>[],
            loadingHistory: false,
            loadingHot: false,
            onTapKeyword: (_) {},
            onClearHistory: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('清空'), findsOneWidget);
    },
  );

  testWidgets('search result list shows english empty state and footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        localeCode: 'en',
        child: Scaffold(
          body: Column(
            children: <Widget>[
              const Expanded(
                child: OnlineSearchResultList(
                  type: SearchType.playlist,
                  results: <Map<String, dynamic>>[],
                  error: null,
                  initialLoading: false,
                  likedSongKeys: <String>{},
                  loadingMore: false,
                  hasMore: true,
                  onTapItem: _noopTapItem,
                  onLikeSongItem: _noopLikeSongItem,
                  onMoreSongItem: _noopTapItem,
                  onLoadMore: _noopLoadMore,
                ),
              ),
              Expanded(
                child: OnlineSearchResultList(
                  type: SearchType.playlist,
                  results: const <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'playlist-1',
                      'platform': 'qq',
                      'name': 'Playlist',
                      'creator': 'Creator',
                      'cover': '',
                      'song_count': 8,
                    },
                  ],
                  error: null,
                  initialLoading: false,
                  likedSongKeys: const <String>{},
                  loadingMore: false,
                  hasMore: false,
                  onTapItem: _noopTapItem,
                  onLikeSongItem: _noopLikeSongItem,
                  onMoreSongItem: _noopTapItem,
                  onLoadMore: _noopLoadMore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No search results'), findsOneWidget);
    expect(find.text('No more results'), findsOneWidget);
  });

  testWidgets('search artist list item shows english stat labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        localeCode: 'en',
        child: SearchArtistListItem(
          localeCode: 'en',
          title: 'Artist',
          coverUrl: '',
          songCount: '12',
          albumCount: '3',
          videoCount: '5',
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('songs', findRichText: true), findsOneWidget);
    expect(find.textContaining('albums', findRichText: true), findsOneWidget);
    expect(find.textContaining('videos', findRichText: true), findsOneWidget);
  });
}

Widget _buildTestApp({required String localeCode, required Widget child}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(localeCode: localeCode),
      ),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(body: child),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.localeCode});

  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: localeCode);
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
        featureSupportFlag: PlatformFeatureSupportFlag.searchPlaylist,
        imageSizes: const <int>[300],
      ),
    ];
  }
}

void _noopTapItem(Map<String, dynamic> item) {}

Future<void> _noopLikeSongItem(Map<String, dynamic> item) async {}

Future<void> _noopLoadMore() async {}

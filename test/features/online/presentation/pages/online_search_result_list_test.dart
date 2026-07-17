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
}

Widget _buildResultList({
  required SearchType type,
  bool initialLoading = false,
  bool immersive = false,
  List<Map<String, dynamic>> results = const <Map<String, dynamic>>[],
  ValueChanged<Map<String, dynamic>>? onTapItem,
}) {
  final skin = AppSkinRegistry.builtIn(
    AppThemeAccent.forest,
  ).resolve(AppSkinRegistry.citySoundCreatorId);
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
    ],
    child: MaterialApp(
      theme: immersive ? AppTheme.light(skin) : null,
      home: Scaffold(
        body: OnlineSearchResultList(
          type: type,
          results: results,
          error: null,
          initialLoading: initialLoading,
          likedSongKeys: const <String>{},
          loadingMore: false,
          hasMore: true,
          onTapItem: onTapItem ?? (_) {},
          onLikeSongItem: (_) async {},
          onMoreSongItem: (_) {},
          onLoadMore: () async {},
        ),
      ),
    ),
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

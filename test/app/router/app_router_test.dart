import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/core/network/api_dio_provider.dart';
import 'package:he_music_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:he_music_flutter/features/auth/presentation/pages/qr_login_scan_page.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/discover_home_tab.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_library_page.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_page.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_page.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/playlist/data/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/repositories/playlist_detail_repository.dart';
import 'package:he_music_flutter/features/playlist/presentation/pages/playlist_detail_page.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/account_password_page.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/account_profile_page.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:he_music_flutter/features/video/presentation/pages/video_detail_page.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('content route keeps mini player visible', (tester) async {
    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.online),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayerBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MiniPlayerBar),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
    expect(find.text('路由测试歌曲'), findsOneWidget);
  });

  testWidgets('settings route covers mini player', (tester) async {
    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.settings),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayerBar), findsNothing);
    expect(find.text('路由测试歌曲'), findsNothing);
  });

  testWidgets('immersive route transitions keep the root wallpaper visible', (
    tester,
  ) async {
    final router = createAppRouter(AppRoutes.my);
    final resolver = _CountingAssetResolver();
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildImmersiveRouterTestApp(router, resolver));
    await tester.pumpAndSettle();

    final wallpaperFinder = find.byKey(
      const ValueKey<String>('app-skin-wallpaper'),
    );
    final initialProvider = tester.widget<Image>(wallpaperFinder).image;

    final surfaceColor = Theme.of(
      tester.element(find.byType(MyPage)),
    ).colorScheme.surface;
    const routes = <String>[
      AppRoutes.settings,
      AppRoutes.rankingList,
      AppRoutes.playlistPlaza,
    ];

    for (final route in routes) {
      router.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(router.state.uri.path, route, reason: route);
      expect(
        find.byType(AppSkinBackgroundLayer),
        findsOneWidget,
        reason: route,
      );
      expect(
        tester.widget<Image>(wallpaperFinder).image,
        same(initialProvider),
        reason: route,
      );
      expect(resolver.loadCount, 1, reason: route);
      expect(
        find.ancestor(
          of: find.byType(MyPage),
          matching: find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == surfaceColor,
          ),
        ),
        findsNothing,
        reason: route,
      );

      await tester.pump(const Duration(milliseconds: 300));
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MyPage), findsOneWidget, reason: route);
    }

    expect(tester.widget<Image>(wallpaperFinder).image, same(initialProvider));
  });

  testWidgets('ordinary routes inherit one transparent immersive background', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = createAppRouter(AppRoutes.my);
    final resolver = _CountingAssetResolver();
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildImmersiveRouterTestApp(router, resolver));
    await tester.pumpAndSettle();

    final wallpaperFinder = find.byKey(
      const ValueKey<String>('app-skin-wallpaper'),
    );
    final initialProvider = tester.widget<Image>(wallpaperFinder).image;
    final detailLocation = Uri(
      path: AppRoutes.playlistDetail,
      queryParameters: const <String, String>{
        'id': 'playlist-1',
        'platform': 'qq',
        'title': '测试歌单',
      },
    ).toString();
    final routes = <({String location, Type pageType})>[
      (location: AppRoutes.home, pageType: DiscoverHomeTab),
      (location: AppRoutes.my, pageType: MyPage),
      (location: AppRoutes.settings, pageType: SettingsPage),
      (location: AppRoutes.onlineSearch, pageType: OnlineSearchPage),
      (location: detailLocation, pageType: PlaylistDetailPage),
      (location: AppRoutes.login, pageType: LoginPage),
      (location: AppRoutes.library, pageType: LocalLibraryPage),
    ];

    for (final route in routes) {
      router.go(route.location);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(router.state.uri.path, Uri.parse(route.location).path);
      expect(
        find.byType(route.pageType),
        findsOneWidget,
        reason: route.location,
      );
      expect(
        find.byType(AppSkinBackgroundLayer),
        findsOneWidget,
        reason: route.location,
      );
      expect(
        tester.widget<Image>(wallpaperFinder).image,
        same(initialProvider),
        reason: route.location,
      );
      expect(resolver.loadCount, 1, reason: route.location);
      for (final scaffold in tester.widgetList<Scaffold>(
        find.byType(Scaffold),
      )) {
        expect(
          scaffold.backgroundColor == null || scaffold.backgroundColor!.a == 0,
          isTrue,
          reason: '${route.location} has an opaque Scaffold',
        );
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('only approved routes add an exclusive visual surface', (
    tester,
  ) async {
    final router = createAppRouter(AppRoutes.my);
    final resolver = _CountingAssetResolver();
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildImmersiveRouterTestApp(router, resolver));
    await tester.pumpAndSettle();

    router.go(AppRoutes.player);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey<String>('app-player-theme-boundary')),
      findsOneWidget,
    );

    router.go(
      Uri(
        path: AppRoutes.videoDetail,
        queryParameters: const <String, String>{
          'id': 'video-1',
          'platform': 'qq',
          'title': '测试视频',
        },
      ).toString(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(VideoDetailPage), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('video-detail-exclusive-media-surface'),
      ),
      findsOneWidget,
    );

    router.go(AppRoutes.loginQrScan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(QrLoginScanPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('qr-scan-exclusive-camera-surface')),
      findsOneWidget,
    );
    expect(find.byType(AppSkinBackgroundLayer), findsOneWidget);
    expect(resolver.loadCount, 1);
  });

  testWidgets('account profile route builds independent page', (tester) async {
    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.settingsProfile),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountProfilePage), findsOneWidget);
    expect(find.byType(MiniPlayerBar), findsNothing);
  });

  testWidgets('account password route builds independent page', (tester) async {
    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.settingsPassword),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountPasswordPage), findsOneWidget);
    expect(find.byType(MiniPlayerBar), findsNothing);
  });

  testWidgets('system back closes playlist detail action sheet before route', (
    tester,
  ) async {
    final initialLocation = Uri(
      path: AppRoutes.playlistDetail,
      queryParameters: const <String, String>{
        'id': 'playlist-1',
        'platform': 'qq',
        'title': '测试歌单',
      },
    ).toString();

    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: initialLocation),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('路由测试歌单歌曲'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('路由测试歌单歌曲'), findsOneWidget);
  });
}

Widget _buildRouterTestApp({required String initialLocation}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      apiDioProvider.overrideWithValue(Dio()),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlineControllerProvider.overrideWith(_TestOnlineController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      searchDefaultPlaceholderProvider.overrideWith(
        _TestSearchPlaceholderController.new,
      ),
      playlistDetailRepositoryProvider.overrideWithValue(
        _TestPlaylistDetailRepository(),
      ),
      appRouterProvider.overrideWith((ref) => createAppRouter(initialLocation)),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(routerConfig: router);
      },
    ),
  );
}

Widget _buildImmersiveRouterTestApp(
  GoRouter router,
  AppSkinAssetResolver resolver,
) {
  final skin = AppSkinRegistry.builtIn(
    AppConfigState.initial.themeAccent,
  ).resolve(AppSkinRegistry.citySoundCreatorId);
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_ImmersiveTestAppConfigController.new),
      apiDioProvider.overrideWithValue(Dio()),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlineControllerProvider.overrideWith(_TestOnlineController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      searchDefaultPlaceholderProvider.overrideWith(
        _TestSearchPlaceholderController.new,
      ),
      playlistDetailRepositoryProvider.overrideWithValue(
        _TestPlaylistDetailRepository(),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(skin).copyWith(platform: TargetPlatform.android),
      routerConfig: router,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppSkinBackgroundLayer(
            skin: skin,
            enableAnimation: false,
            assetResolver: resolver,
          ),
          child ?? const SizedBox.shrink(),
        ],
      ),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }
}

class _ImmersiveTestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      skinId: AppSkinRegistry.citySoundCreatorId,
    );
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'route-test-song', title: '路由测试歌曲'),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _TestOnlineController extends OnlineController {
  @override
  OnlineFeatureState build() {
    return OnlineFeatureState.initial;
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ Music',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}

class _TestSearchPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState();
  }
}

class _TestPlaylistDetailRepository implements PlaylistDetailRepository {
  @override
  Future<PlaylistDetailContent> fetchDetail(
    PlaylistDetailRequest request,
  ) async {
    const song = SongInfo(
      name: '路由测试歌单歌曲',
      subtitle: '测试歌手',
      id: 'song-1',
      duration: 0,
      mvId: '',
      album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
      artists: <SongInfoArtistInfo>[SongInfoArtistInfo(name: '测试歌手', id: 'a1')],
      links: <LinkInfo>[],
      platform: 'qq',
      cover: '',
      sublist: <SongInfo>[],
      originalType: 0,
    );
    return const PlaylistDetailContent(
      info: PlaylistInfo(
        name: '测试歌单',
        id: 'playlist-1',
        cover: '',
        creator: '测试创建者',
        songCount: '1',
        playCount: '0',
        songs: <SongInfo>[song],
        platform: 'qq',
        description: '',
      ),
      songs: <SongInfo>[song],
    );
  }
}

class _CountingAssetResolver implements AppSkinAssetResolver {
  static final _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=',
  );

  var loadCount = 0;

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    loadCount += 1;
    return AppSkinAssetLoadSuccess(_pngBytes.buffer.asByteData());
  }
}

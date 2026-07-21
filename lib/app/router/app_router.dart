import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_navigation_service.dart';
import '../config/app_config_controller.dart';
import '../i18n/app_i18n.dart';
import '../theme/player/app_player_style_boundary.dart';
import '../../features/album/presentation/pages/album_detail_page.dart';
import '../../features/artist/presentation/pages/artist_detail_page.dart';
import '../../features/artist/presentation/pages/artist_plaza_page.dart';
import '../../features/auth/presentation/pages/captcha_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/qr_login_confirm_page.dart';
import '../../features/auth/presentation/pages/qr_login_scan_page.dart';
import '../../features/download/presentation/pages/download_page.dart';
import '../../features/home/presentation/widgets/discover_home_tab.dart';
import '../../features/music_library/presentation/pages/local_library_page.dart';
import '../../features/music_library/presentation/pages/genre_page.dart';
import '../../features/music_library/presentation/pages/local_artist_detail_page.dart';
import '../../features/music_library/presentation/pages/local_album_detail_page.dart';
import '../../features/music_library/presentation/pages/metadata_edit_page.dart';
import '../../features/music_library/domain/entities/local_song.dart';
import '../../features/my/presentation/pages/my_collection_page.dart';
import '../../features/my/presentation/pages/my_history_page.dart';
import '../../features/my/presentation/pages/my_page.dart';
import '../../features/my/presentation/pages/user_playlist_detail_page.dart';
import '../../features/new_release/new_album/presentation/pages/new_album_page.dart';
import '../../features/new_release/new_song/presentation/pages/new_song_page.dart';
import '../../features/online/presentation/pages/online_comments_page.dart';
import '../../features/online/presentation/pages/online_page.dart';
import '../../features/online/presentation/pages/online_search_page.dart';
import '../../features/online/presentation/pages/parse_source_url_page.dart';
import '../../features/playlist/presentation/pages/playlist_detail_page.dart';
import '../../features/playlist/presentation/pages/playlist_plaza_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/ranking/presentation/pages/ranking_detail_page.dart';
import '../../features/ranking/presentation/pages/ranking_list_page.dart';
import '../../features/radio/presentation/pages/radio_plaza_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/skin_selection_page.dart';
import '../../features/song/presentation/pages/song_detail_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/settings/presentation/pages/account_password_page.dart';
import '../../features/settings/presentation/pages/account_profile_page.dart';
import '../../features/settings/presentation/pages/device_management_page.dart';
import '../../features/video/presentation/pages/video_detail_page.dart';
import '../../features/video/presentation/pages/video_plaza_page.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/player/presentation/widgets/mini_player_bar.dart';
import 'app_routes.dart';

// Tab Shell 只保留底部导航直接展示的页面。
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _myNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'my');

/// Root content pages keep MiniPlayer visible without creating another Navigator.
class _RootContentRouteShell extends StatelessWidget {
  const _RootContentRouteShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: MiniPlayerBar(
        bottomSafeArea: true,
        onOpenFullPlayer: () => context.push(AppRoutes.player),
      ),
    );
  }
}

GoRoute _rootContentRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
}) {
  return GoRoute(
    path: path,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        _RootContentRouteShell(child: builder(context, state)),
  );
}

/// 非 Tab 内容页挂到 root Navigator，并保留 MiniPlayer。
List<RouteBase> _contentRoutes() => <RouteBase>[
  _rootContentRoute(
    path: AppRoutes.onlineSearch,
    builder: (context, state) => OnlineSearchPage(
      platform: _readOptionalQuery(state, 'platform') ?? '',
      initialKeyword: _readOptionalQuery(state, 'keyword'),
      initialType: _readOptionalQuery(state, 'type'),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.online,
    builder: (context, state) => const OnlinePage(),
  ),
  _rootContentRoute(
    path: AppRoutes.parseSourceUrl,
    builder: (context, state) => const ParseSourceUrlPage(),
  ),
  _rootContentRoute(
    path: AppRoutes.onlineComments,
    builder: (context, state) => OnlineCommentsPage(
      resourceId: _readQuery(state, 'id'),
      resourceType: _readQuery(state, 'resource_type'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title'),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.discoverDetail,
    builder: (context, state) => ArtistDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readQuery(state, 'title'),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.artistDetail,
    builder: (context, state) {
      final platform = _readQuery(state, 'platform');
      if (platform == 'local') {
        final title = _readQuery(state, 'title');
        final id = _readQuery(state, 'id');
        return LocalArtistDetailPage(
          artistName: title.isNotEmpty ? title : Uri.decodeComponent(id),
        );
      }
      return ArtistDetailPage(
        id: _readQuery(state, 'id'),
        platform: platform,
        title: _readOptionalQuery(state, 'title') ?? '',
      );
    },
  ),
  _rootContentRoute(
    path: AppRoutes.playlistDetail,
    builder: (context, state) => PlaylistDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title') ?? '',
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.albumDetail,
    builder: (context, state) {
      final platform = _readQuery(state, 'platform');
      if (platform == 'local') {
        final title = _readQuery(state, 'title');
        final id = _readQuery(state, 'id');
        return LocalAlbumDetailPage(
          albumName: title.isNotEmpty ? title : Uri.decodeComponent(id),
        );
      }
      return AlbumDetailPage(
        id: _readQuery(state, 'id'),
        platform: platform,
        title: _readOptionalQuery(state, 'title') ?? '',
      );
    },
  ),
  _rootContentRoute(
    path: AppRoutes.songDetail,
    builder: (context, state) => SongDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title') ?? '',
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.rankingDetail,
    builder: (context, state) => RankingDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title'),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.newSong,
    builder: (context, state) => NewSongPage(
      initialPlatform: _readOptionalQuery(state, 'platform'),
      initialTabId: _readOptionalQuery(state, 'tab_id'),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.newAlbum,
    builder: (context, state) => NewAlbumPage(
      initialPlatform: _readOptionalQuery(state, 'platform'),
      initialTabId: _readOptionalQuery(state, 'tab_id'),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.myHistory,
    builder: (context, state) => const MyHistoryPage(),
  ),
  _rootContentRoute(
    path: AppRoutes.myCollection,
    builder: (context, state) => const MyCollectionPage(),
  ),
  _rootContentRoute(
    path: AppRoutes.userPlaylistDetail,
    builder: (context, state) => UserPlaylistDetailPage(
      id: _readQuery(state, 'id'),
      title:
          _readOptionalQuery(state, 'title') ??
          AppI18n.t(
            ProviderScope.containerOf(context).read(appConfigProvider),
            'common.default_playlist',
          ),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.localGenre,
    builder: (context, state) {
      final name = state.uri.queryParameters['name'] ?? '';
      return GenrePage(genreName: name);
    },
  ),
  _rootContentRoute(
    path: AppRoutes.localMetadataEdit,
    builder: (context, state) {
      final song = state.extra as LocalSong?;
      if (song == null) {
        return const Scaffold(body: Center(child: Text('Song not found')));
      }
      return MetadataEditPage(song: song);
    },
  ),
  _rootContentRoute(
    path: AppRoutes.playlistPlaza,
    builder: (context, state) => PlaylistPlazaPage(
      initialPlatform: _readOptionalQuery(state, 'platform'),
    ),
  ),
  _rootContentRoute(
    path: AppRoutes.rankingList,
    builder: (context, state) =>
        RankingListPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _rootContentRoute(
    path: AppRoutes.artistPlaza,
    builder: (context, state) =>
        ArtistPlazaPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _rootContentRoute(
    path: AppRoutes.videoPlaza,
    builder: (context, state) =>
        VideoPlazaPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _rootContentRoute(
    path: AppRoutes.radioPlaza,
    builder: (context, state) =>
        RadioPlazaPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _rootContentRoute(
    path: AppRoutes.library,
    builder: (context, state) => const LocalLibraryPage(),
  ),
  _rootContentRoute(
    path: AppRoutes.downloads,
    builder: (context, state) => const DownloadPage(),
  ),
];

/// 这些页面需要覆盖 MiniPlayer，直接走根 Navigator。
List<RouteBase> _fullscreenRootRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.settings,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SettingsPage(),
  ),
  GoRoute(
    path: AppRoutes.about,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AboutPage(),
  ),
  GoRoute(
    path: AppRoutes.settingsSkin,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SkinSelectionPage(),
  ),
  GoRoute(
    path: AppRoutes.settingsProfile,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AccountProfilePage(),
  ),
  GoRoute(
    path: AppRoutes.settingsPassword,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AccountPasswordPage(),
  ),
  GoRoute(
    path: AppRoutes.settingsDevice,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const DeviceManagementPage(),
  ),
];

final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});

GoRouter createAppRouter([String? initialLocation]) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation ?? AppRoutes.home,
    routes: <RouteBase>[
      // ── StatefulShellRoute：底部导航的两个主页面分支 ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // Branch 0: 首页
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const DiscoverHomeTab(),
              ),
            ],
          ),
          // Branch 1: 我的
          StatefulShellBranch(
            navigatorKey: _myNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.my,
                builder: (context, state) => const MyPage(),
              ),
            ],
          ),
        ],
      ),

      ..._contentRoutes(),
      ..._fullscreenRootRoutes(),

      // ── 独立路由（全屏，push 到根 Navigator）──

      // 登录流程
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            LoginPage(redirectLocation: _readOptionalQuery(state, 'redirect')),
      ),
      GoRoute(
        path: AppRoutes.loginQrScan,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QrLoginScanPage(),
      ),
      GoRoute(
        path: AppRoutes.loginQrConfirm,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QrLoginConfirmPage(),
      ),
      GoRoute(
        path: AppRoutes.captcha,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CaptchaPage(
          scene: _readQuery(state, 'scene'),
          meta: _readQuery(state, 'meta'),
        ),
      ),

      // 播放器（全屏）
      GoRoute(
        path: AppRoutes.player,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const AppPlayerStyleBoundary(child: PlayerPage()),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offsetAnimation =
                Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                );
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
        ),
      ),

      // 视频详情（全屏，覆盖底部 Tab 和 MiniPlayer）
      GoRoute(
        path: AppRoutes.videoDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => VideoDetailPage(
          id: _readQuery(state, 'id'),
          platform: _readQuery(state, 'platform'),
          title: _readOptionalQuery(state, 'title') ?? '',
        ),
      ),
    ],
  );
}

String _readQuery(GoRouterState state, String key) {
  final value = state.uri.queryParameters[key];
  if (value == null || value.isEmpty) {
    throw StateError('Missing query parameter: $key');
  }
  return value;
}

String? _readOptionalQuery(GoRouterState state, String key) {
  final value = state.uri.queryParameters[key];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

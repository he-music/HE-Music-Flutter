import 'package:flutter/cupertino.dart';
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
import '../../features/home/presentation/pages/recommend_song_list_page.dart';
import '../../features/music_library/presentation/pages/local_library_page.dart';
import '../../features/music_library/presentation/pages/genre_page.dart';
import '../../features/music_library/presentation/pages/local_artist_detail_page.dart';
import '../../features/music_library/presentation/pages/local_album_detail_page.dart';
import '../../features/music_library/presentation/pages/metadata_edit_page.dart';
import '../../features/music_library/domain/entities/local_song.dart';
import '../../features/my/presentation/pages/my_collection_page.dart';
import '../../features/my/presentation/pages/my_history_page.dart';
import '../../features/my/presentation/pages/library_page.dart';
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
import '../../features/player/presentation/widgets/player_route_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/ranking/presentation/pages/ranking_detail_page.dart';
import '../../features/ranking/presentation/pages/ranking_list_page.dart';
import '../../features/radio/presentation/pages/radio_plaza_page.dart';
import '../../features/settings/domain/settings_catalog.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/skin_selection_page.dart';
import '../../features/song/presentation/pages/song_detail_page.dart';
import '../../features/sheet_music/presentation/pages/sheet_music_page.dart';
import '../../features/update/presentation/pages/release_history_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/settings/presentation/pages/account_password_page.dart';
import '../../features/settings/presentation/pages/account_profile_page.dart';
import '../../features/settings/presentation/pages/device_management_page.dart';
import '../../features/settings/presentation/pages/github_download_acceleration_page.dart';
import '../../features/video/presentation/pages/video_detail_page.dart';
import '../../features/video/presentation/pages/video_plaza_page.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_route_observers.dart';
import 'app_routes.dart';

// Navigator identities are independent of the selected design language.
final _contentNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'content');
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _libraryNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'library');
final _myNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'my');

/// 图片皮肤下页面背景透明，前后路由必须同步移动，避免内容叠画。
class _SettingsSectionTransitionPage extends Page<void> {
  const _SettingsSectionTransitionPage({required this.child, super.key});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return _SettingsSectionPageRoute(page: this);
  }
}

class _SettingsSectionPageRoute extends PageRouteBuilder<void> {
  _SettingsSectionPageRoute({required _SettingsSectionTransitionPage page})
    : super(
        settings: page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => page.child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            MediaQuery.disableAnimationsOf(context)
            ? child
            : FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                ),
                child: SlideTransition(
                  position: _positionAnimation(
                    animation,
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ),
                  textDirection: Directionality.of(context),
                  child: child,
                ),
              ),
      );

  bool get _usesInteractiveBack =>
      navigator != null &&
      Theme.of(navigator!.context).platform == TargetPlatform.iOS;

  @override
  bool get popGestureEnabled =>
      _usesInteractiveBack && !_reduceMotion && super.popGestureEnabled;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_usesInteractiveBack) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    if (MediaQuery.disableAnimationsOf(context)) return child;
    // SDK owns gesture eligibility, cancellation, velocity and Navigator cleanup.
    // Only the visual offset changes: transparent pages move a full width.
    return AnimatedBuilder(
      animation: navigator!.userGestureInProgressNotifier,
      builder: (context, _) => SlideTransition(
        position: _positionAnimation(
          animation,
          begin: const Offset(1, 0),
          end: Offset.zero,
          linear: popGestureInProgress,
        ),
        textDirection: Directionality.of(context),
        child: CupertinoRouteTransitionMixin.buildPageTransitions<void>(
          this,
          context,
          kAlwaysCompleteAnimation,
          kAlwaysDismissedAnimation,
          child,
        ),
      ),
    );
  }

  bool get _reduceMotion {
    final context = navigator?.context;
    return context != null && MediaQuery.disableAnimationsOf(context);
  }

  @override
  Duration get transitionDuration =>
      _reduceMotion ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _reduceMotion ? Duration.zero : super.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) {
        if (child == null) {
          return null;
        }
        if (MediaQuery.disableAnimationsOf(context)) return child;
        return AnimatedBuilder(
          animation: navigator!.userGestureInProgressNotifier,
          builder: (context, _) => SlideTransition(
            position: _positionAnimation(
              secondaryAnimation,
              begin: Offset.zero,
              end: const Offset(-1, 0),
              linear: _usesInteractiveBack && popGestureInProgress,
            ),
            textDirection: Directionality.of(context),
            child: child,
          ),
        );
      };

  static Animation<Offset> _positionAnimation(
    Animation<double> animation, {
    required Offset begin,
    required Offset end,
    bool linear = false,
  }) {
    return Tween<Offset>(begin: begin, end: end).animate(
      linear
          ? animation
          : CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
    );
  }
}

GoRoute _contentRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
}) {
  return GoRoute(
    path: path,
    parentNavigatorKey: _contentNavigatorKey,
    redirect: (context, state) {
      final router = GoRouter.of(context);
      final navigation = router.routeInformationProvider.value.state;
      if (navigation is! RouteInformationState ||
          navigation.type == NavigatingType.go ||
          navigation.type == NavigatingType.restore) {
        return null;
      }
      final current = router.routerDelegate.currentConfiguration.lastOrNull;
      // Root fullscreen pages interrupt the content Shell's match chain.
      // Keep their subsequent browsing on root so GoRouter never clones the
      // fixed content Shell's PageKey or Navigator key above itself.
      if (current?.route.parentNavigatorKey != rootNavigatorKey) return null;
      return state.uri
          .replace(path: '${AppRoutes.rootBrowsePrefix}${state.uri.path}')
          .toString();
    },
    builder: builder,
  );
}

/// Browsing routes share the content Navigator and the outer playback surface.
List<RouteBase> _contentRoutes() => <RouteBase>[
  _contentRoute(
    path: AppRoutes.onlineSearch,
    builder: (context, state) => OnlineSearchPage(
      platform: _readOptionalQuery(state, 'platform') ?? '',
      initialKeyword: _readOptionalQuery(state, 'keyword'),
      initialType: _readOptionalQuery(state, 'type'),
    ),
  ),
  _contentRoute(
    path: AppRoutes.online,
    builder: (context, state) => const OnlinePage(),
  ),
  _contentRoute(
    path: AppRoutes.parseSourceUrl,
    builder: (context, state) => const ParseSourceUrlPage(),
  ),
  _contentRoute(
    path: AppRoutes.onlineComments,
    builder: (context, state) => OnlineCommentsPage(
      resourceId: _readQuery(state, 'id'),
      resourceType: _readQuery(state, 'resource_type'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title'),
    ),
  ),
  _contentRoute(
    path: AppRoutes.discoverDetail,
    builder: (context, state) => ArtistDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readQuery(state, 'title'),
    ),
  ),
  _contentRoute(
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
  _contentRoute(
    path: AppRoutes.playlistDetail,
    builder: (context, state) => PlaylistDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title') ?? '',
    ),
  ),
  _contentRoute(
    path: AppRoutes.recommendSongList,
    builder: (context, state) => RecommendSongListPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
    ),
  ),
  _contentRoute(
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
  _contentRoute(
    path: AppRoutes.songDetail,
    builder: (context, state) => SongDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title') ?? '',
    ),
  ),
  _contentRoute(
    path: AppRoutes.songSheetMusic,
    builder: (context, state) => SheetMusicListPage(
      platform: _readQuery(state, 'platform'),
      songId: _readQuery(state, 'song_id'),
      title: _readOptionalQuery(state, 'title') ?? '',
    ),
  ),
  _contentRoute(
    path: AppRoutes.sheetMusicDetail,
    builder: (context, state) => SheetMusicDetailPage(
      platform: _readQuery(state, 'platform'),
      songId: _readQuery(state, 'song_id'),
      id: _readQuery(state, 'id'),
      title: _readOptionalQuery(state, 'title') ?? '',
    ),
  ),
  _contentRoute(
    path: AppRoutes.rankingDetail,
    builder: (context, state) => RankingDetailPage(
      id: _readQuery(state, 'id'),
      platform: _readQuery(state, 'platform'),
      title: _readOptionalQuery(state, 'title'),
    ),
  ),
  _contentRoute(
    path: AppRoutes.newSong,
    builder: (context, state) => NewSongPage(
      initialPlatform: _readOptionalQuery(state, 'platform'),
      initialTabId: _readOptionalQuery(state, 'tab_id'),
    ),
  ),
  _contentRoute(
    path: AppRoutes.newAlbum,
    builder: (context, state) => NewAlbumPage(
      initialPlatform: _readOptionalQuery(state, 'platform'),
      initialTabId: _readOptionalQuery(state, 'tab_id'),
    ),
  ),
  _contentRoute(
    path: AppRoutes.myHistory,
    builder: (context, state) => const MyHistoryPage(),
  ),
  _contentRoute(
    path: AppRoutes.myCollection,
    builder: (context, state) => const MyCollectionPage(),
  ),
  _contentRoute(
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
  _contentRoute(
    path: AppRoutes.localGenre,
    builder: (context, state) {
      final name = state.uri.queryParameters['name'] ?? '';
      return GenrePage(genreName: name);
    },
  ),
  _contentRoute(
    path: AppRoutes.playlistPlaza,
    builder: (context, state) => PlaylistPlazaPage(
      initialPlatform: _readOptionalQuery(state, 'platform'),
    ),
  ),
  _contentRoute(
    path: AppRoutes.rankingList,
    builder: (context, state) =>
        RankingListPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _contentRoute(
    path: AppRoutes.artistPlaza,
    builder: (context, state) =>
        ArtistPlazaPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _contentRoute(
    path: AppRoutes.videoPlaza,
    builder: (context, state) =>
        VideoPlazaPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _contentRoute(
    path: AppRoutes.radioPlaza,
    builder: (context, state) =>
        RadioPlazaPage(initialPlatform: _readOptionalQuery(state, 'platform')),
  ),
  _contentRoute(
    path: AppRoutes.library,
    builder: (context, state) => const LocalLibraryPage(),
  ),
  _contentRoute(
    path: AppRoutes.downloads,
    builder: (context, state) => DownloadPage(
      initialTab: state.uri.queryParameters['tab'] == 'tasks'
          ? DownloadPageTab.tasks
          : DownloadPageTab.downloaded,
    ),
  ),
  GoRoute(
    path: AppRoutes.downloadedMusic,
    redirect: (context, state) => AppRoutes.downloads,
  ),
];

/// 这些页面需要覆盖 MiniPlayer，直接走根 Navigator。
List<RouteBase> _fullscreenRootRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.localMetadataEdit,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) {
      final song = state.extra as LocalSong?;
      if (song == null) {
        return const Scaffold(body: Center(child: Text('Song not found')));
      }
      return MetadataEditPage(song: song);
    },
  ),
  GoRoute(
    path: AppRoutes.settings,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SettingsPage(),
  ),
  GoRoute(
    path: AppRoutes.settingsSection,
    parentNavigatorKey: rootNavigatorKey,
    redirect: (context, state) {
      final sectionId = state.pathParameters['sectionId'];
      final sectionExists = settingsSections.any(
        (section) => section.id == sectionId,
      );
      return sectionExists ? null : AppRoutes.settings;
    },
    pageBuilder: (context, state) {
      final sectionId = state.pathParameters['sectionId']!;
      return _SettingsSectionTransitionPage(
        key: state.pageKey,
        child: SettingsPage(
          sectionId: sectionId,
          highlightedItemId: _readOptionalQuery(state, 'highlight'),
        ),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.releaseHistory,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        ReleaseHistoryPage(latestVersion: state.uri.queryParameters['latest']),
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
    path: AppRoutes.settingsGitHubDownloadAcceleration,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const GitHubDownloadAccelerationPage(),
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

/// Fixed root aliases reuse browsing pages above fullscreen root flows.
/// Each is a normal PageRoute, so push/pop futures and the player stack survive.
List<RouteBase> _rootBrowsingRoutes() => [
  for (final route in _contentRoutes().whereType<GoRoute>())
    if (route.builder != null)
      GoRoute(
        path: '${AppRoutes.rootBrowsePrefix}${route.path}',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AppShell(
          location: route.path,
          initialBranchLocation: _lastBranchLocation(
            GoRouter.of(context).routerDelegate.currentConfiguration.matches,
          ),
          child: route.builder!(context, state),
        ),
      ),
];

String? _lastBranchLocation(List<RouteMatchBase> matches) {
  for (final match in matches.reversed) {
    if (match is ShellRouteMatch) {
      final location = _lastBranchLocation(match.matches);
      if (location != null) return location;
    } else if (match is RouteMatch &&
        const [
          AppRoutes.home,
          AppRoutes.collection,
          AppRoutes.my,
        ].contains(match.route.path)) {
      return match.route.path;
    }
  }
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});

GoRouter createAppRouter([String? initialLocation]) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: <NavigatorObserver>[appPageRouteObserver],
    initialLocation: initialLocation ?? AppRoutes.home,
    routes: <RouteBase>[
      ShellRoute(
        navigatorKey: _contentNavigatorKey,
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => navigationShell,
            branches: <StatefulShellBranch>[
              StatefulShellBranch(
                navigatorKey: _homeNavigatorKey,
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.home,
                    builder: (context, state) => const DiscoverHomeTab(),
                  ),
                ],
              ),
              StatefulShellBranch(
                navigatorKey: _libraryNavigatorKey,
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.collection,
                    builder: (context, state) => const LibraryPage(),
                  ),
                ],
              ),
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
        ],
      ),
      ..._fullscreenRootRoutes(),
      ..._rootBrowsingRoutes(),

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
        pageBuilder: (context, state) => PlayerRoutePage(
          key: state.pageKey,
          child: const AppPlayerStyleBoundary(child: PlayerPage()),
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

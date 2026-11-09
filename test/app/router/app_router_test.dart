import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/core/network/api_dio_provider.dart';
import 'package:he_music_flutter/core/device/screen_wake_lock.dart';
import 'package:he_music_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:he_music_flutter/features/auth/presentation/pages/qr_login_scan_page.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/discover_home_tab.dart';
import 'package:he_music_flutter/features/home/presentation/pages/recommend_song_list_page.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_info.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_request.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_library_page.dart';
import 'package:he_music_flutter/features/my/presentation/pages/library_page.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_page.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_page.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/playlist/data/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_songs_page_result.dart';
import 'package:he_music_flutter/features/playlist/domain/repositories/playlist_detail_repository.dart';
import 'package:he_music_flutter/features/playlist/presentation/pages/playlist_detail_page.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/pages/player_page.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/features/settings/domain/settings_catalog.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/account_password_page.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/account_profile_page.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:he_music_flutter/features/video/presentation/pages/video_detail_page.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/app_bottom_navigation_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_player_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final location in [
    AppRoutes.settingsProfile,
    AppRoutes.settingsPassword,
    AppRoutes.settingsDevice,
    '${AppRoutes.userPlaylistDetail}?id=private',
    '${AppRoutes.rootBrowsePrefix}${AppRoutes.userPlaylistDetail}?id=private',
    AppRoutes.myCollection,
    AppRoutes.loginQrConfirm,
  ]) {
    testWidgets(
      'anonymous private deep link $location opens login with return path',
      (tester) async {
        await tester.pumpWidget(
          _buildRouterTestApp(initialLocation: location, authenticated: false),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(LoginPage));
        final router = ProviderScope.containerOf(
          context,
        ).read(appRouterProvider);
        expect(router.state.uri.path, AppRoutes.login);
        expect(
          router.state.uri.queryParameters['redirect'],
          Uri.parse(buildLoginLocation(location)).queryParameters['redirect'],
        );
        expect(find.byType(MiniPlayerBar), findsNothing);
      },
    );
  }

  testWidgets('anonymous users can open public search without login', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRouterTestApp(
        initialLocation: AppRoutes.onlineSearch,
        authenticated: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnlineSearchPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
  testWidgets('opening the full player clears the previous input focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRouterTestApp(
        initialLocation: AppRoutes.onlineSearch,
        authenticated: false,
      ),
    );
    await tester.pumpAndSettle();

    final searchPage = find.byType(OnlineSearchPage);
    final focusNode = tester.widget<TextField>(find.byType(TextField)).focusNode!;
    expect(focusNode.hasFocus, isTrue);

    final context = tester.element(searchPage);
    final router = GoRouter.of(context);
    final opening = openFullPlayer(context);
    await tester.pumpAndSettle();
    await opening;
    expect(find.byType(PlayerPage), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });
  for (final complete in [false, true]) {
    testWidgets(
      'iOS settings edge back ${complete ? 'completes' : 'cancels'} without overlap',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = createAppRouter(AppRoutes.settings);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          _buildImmersiveRouterTestApp(
            router,
            _CountingAssetResolver(),
            platform: TargetPlatform.iOS,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('歌词'));
        await tester.pumpAndSettle();
        final section = find.byKey(
          const ValueKey<String>('settings-page-lyrics'),
        );
        final home = find.byKey(const ValueKey<String>('settings-page-home'));
        final navigator = Navigator.of(tester.element(section));
        expect(
          ModalRoute.of(tester.element(section))!.popGestureEnabled,
          isTrue,
        );
        final gesture = await tester.startGesture(const Offset(2, 300));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.moveBy(Offset(complete ? 250 : 70, 0));
        await tester.pump(const Duration(milliseconds: 200));
        expect(navigator.userGestureInProgress, isTrue);
        expect(tester.getTopLeft(section).dx, greaterThan(0));
        expect(
          tester.getRect(home).right,
          closeTo(tester.getRect(section).left, .1),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(navigator.userGestureInProgress, isFalse);
        expect(
          router.state.uri.path,
          complete
              ? AppRoutes.settings
              : AppRoutes.settingsSectionLocation(SettingsSectionIds.lyrics),
        );
        if (!complete) {
          expect(tester.getTopLeft(section).dx, closeTo(0, .1));
          await tester.tap(find.byTooltip('返回'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('歌词'));
        await tester.pumpAndSettle();
        expect(section, findsOneWidget);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('iOS reduced motion skips settings slide and interactive back', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = createAppRouter(AppRoutes.settings);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _buildImmersiveRouterTestApp(
        router,
        _CountingAssetResolver(),
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('歌词'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final section = find.byKey(const ValueKey<String>('settings-page-lyrics'));
    expect(tester.getTopLeft(section).dx, 0);
    expect(ModalRoute.of(tester.element(section))!.popGestureEnabled, isFalse);
    router.pop();
    await tester.pumpAndSettle();
    expect(section, findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'detail style changes retain Navigator, input, focus and one player',
    (tester) async {
      await tester.pumpWidget(
        _buildRouterTestApp(initialLocation: AppRoutes.collection),
      );
      await tester.pumpAndSettle();
      final libraryElement = tester.element(find.byType(LibraryPage));
      final router = GoRouter.of(libraryElement);
      final container = ProviderScope.containerOf(libraryElement);
      final controller =
          container.read(appConfigProvider.notifier)
              as _TestAppConfigController;
      final branchNavigator = Navigator.of(libraryElement);
      router.push<void>(AppRoutes.onlineSearch);
      await tester.pumpAndSettle();
      final search = find.byType(OnlineSearchPage);
      final searchState = tester.state(search);
      final contentNavigator = Navigator.of(tester.element(search));
      expect(contentNavigator, isNot(same(branchNavigator)));
      final editable = find.descendant(
        of: search,
        matching: find.byType(EditableText),
      );
      await tester.enterText(editable, 'keep this query');
      await tester.pump();
      final focus = tester.widget<EditableText>(editable).focusNode;
      expect(focus.hasFocus, isTrue);
      for (final style in [
        AppUiStyle.cupertino,
        AppUiStyle.material,
        AppUiStyle.cupertino,
      ]) {
        controller.changeStyle(style);
        await tester.pumpAndSettle();
        expect(tester.state(search), same(searchState));
        expect(Navigator.of(tester.element(search)), same(contentNavigator));
        expect(
          tester.widget<EditableText>(editable).controller.text,
          'keep this query',
        );
        expect(tester.widget<EditableText>(editable).focusNode, same(focus));
        expect(focus.hasFocus, isTrue);
        expect(find.byType(AppPlayerScaffold), findsOneWidget);
        expect(find.byType(MiniPlayerBar), findsOneWidget);
        expect(
          find.byType(AppBottomNavigationBar),
          style == AppUiStyle.cupertino ? findsOneWidget : findsNothing,
        );
        if (style == AppUiStyle.cupertino) {
          expect(
            tester
                .widget<CupertinoTabBar>(find.byType(CupertinoTabBar))
                .currentIndex,
            1,
          );
        }
      }
      router.pop();
      await tester.pumpAndSettle();
      expect(
        Navigator.of(tester.element(find.byType(LibraryPage))),
        same(branchNavigator),
      );
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      router.push<void>(AppRoutes.onlineSearch);
      await tester.pumpAndSettle();
      tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar)).onTap!(2);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.my);
      tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar)).onTap!(1);
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(LibraryPage)), same(libraryElement));
      expect(router.canPop(), isFalse);
      router.push<void>(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavigationBar), findsNothing);
      expect(find.byType(MiniPlayerBar), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(LibraryPage), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
    },
  );
  testWidgets(
    'content opened from full player returns through player to its tab',
    (tester) async {
      await tester.pumpWidget(
        _buildRouterTestApp(initialLocation: AppRoutes.collection),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(LibraryPage)));
      router.push<void>(AppRoutes.player);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerPage), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsNothing);
      router.push<void>(AppRoutes.onlineSearch);
      await tester.pumpAndSettle();
      expect(find.byType(OnlineSearchPage), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.player);
      expect(find.byType(PlayerPage), findsOneWidget);
      router.push<void>(AppRoutes.onlineSearch);
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        '${AppRoutes.rootBrowsePrefix}${AppRoutes.onlineSearch}',
      );
      final detailState = tester.state(find.byType(OnlineSearchPage));
      final reopening = openFullPlayer(
        tester.element(find.byType(OnlineSearchPage)),
      );
      await tester.pumpAndSettle();
      await reopening;
      expect(
        router.routerDelegate.currentConfiguration.matches.where(
          (match) =>
              match.route is GoRoute &&
              (match.route as GoRoute).path == AppRoutes.player,
        ),
        hasLength(1),
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(OnlineSearchPage)), same(detailState));
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(LibraryPage), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final endMethod in ['cancelBackGesture', 'commitBackGesture']) {
    testWidgets(
      'Android repeated back start followed by $endMethod keeps taps working',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.pumpWidget(
          _buildRouterTestApp(
            initialLocation: AppRoutes.my,
            theme: AppTheme.light(
              AppSkinRegistry.builtIn(
                AppConfigState.initial.themeAccent,
              ).resolve(AppSkinRegistry.classicId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(MyPage)));
        router.push(AppRoutes.settings);
        await tester.pumpAndSettle();
        final navigator = Navigator.of(
          tester.element(find.byType(SettingsPage)),
        );
        Future<void> send(String method, {double progress = 0}) async {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(
                method,
                method == 'startBackGesture' ||
                        method == 'updateBackGestureProgress'
                    ? <String, dynamic>{
                        'touchOffset': <double>[5, 300],
                        'progress': progress,
                        'swipeEdge': 0,
                      }
                    : null,
              ),
            ),
            (_) {},
          );
        }

        await send('startBackGesture');
        await tester.pump();
        await send('updateBackGestureProgress', progress: 0.35);
        await tester.pump();
        await send('startBackGesture');
        await send(endMethod);
        await tester.pumpAndSettle();
        expect(navigator.userGestureInProgress, isFalse);
        if (endMethod == 'cancelBackGesture') {
          expect(router.state.uri.path, AppRoutes.settings);
          await tester.tap(find.byTooltip('返回'));
          await tester.pumpAndSettle();
        }
        expect(router.state.uri.path, AppRoutes.my);
        expect(
          tester
              .widgetList<IgnorePointer>(
                find.ancestor(
                  of: find.byType(MyPage),
                  matching: find.byType(IgnorePointer),
                ),
              )
              .any((widget) => widget.ignoring),
          isFalse,
        );
        await tester.tap(find.byTooltip('设置'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.settings);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets(
    'root GoRouter observer distinguishes PageRoute from PopupRoute',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final wakeLock = _RecordingScreenWakeLockPort();

      await tester.pumpWidget(
        _buildRouterTestApp(
          initialLocation: AppRoutes.player,
          playerControllerFactory: _ActiveTestPlayerController.new,
          screenWakeLockPort: wakeLock,
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      final playerContext = tester.element(find.byType(PlayerPage));
      showDialog<void>(
        context: playerContext,
        builder: (context) => const AlertDialog(content: Text('route popup')),
      );
      await tester.pumpAndSettle();
      expect(wakeLock.calls, <bool>[true]);
      Navigator.of(tester.element(find.text('route popup'))).pop();
      await tester.pumpAndSettle();

      final router = GoRouter.of(playerContext);
      router.push(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(wakeLock.calls, <bool>[true, false]);

      router.pop();
      await tester.pumpAndSettle();
      expect(wakeLock.calls, <bool>[true, false, true]);

      debugDefaultTargetPlatformOverride = null;
    },
  );

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

  testWidgets('search route stays fixed for keyboard insets', (tester) async {
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.onlineSearch),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final searchPage = find.byType(OnlineSearchPage);
    final miniPlayer = find.byType(MiniPlayerBar);
    final initialSearchRect = tester.getRect(searchPage);
    final initialMiniPlayerRect = tester.getRect(miniPlayer);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pump();

    expect(tester.getRect(searchPage), initialSearchRect);
    expect(tester.getRect(miniPlayer), initialMiniPlayerRect);
    expect(find.text('路由测试歌曲'), findsOneWidget);
  });

  testWidgets('recommend song list route reads only platform and id', (
    tester,
  ) async {
    final location = Uri(
      path: AppRoutes.recommendSongList,
      queryParameters: const <String, String>{
        'platform': 'qq',
        'id': 'daily-new',
      },
    ).toString();

    await tester.pumpWidget(
      _buildRouterTestApp(
        initialLocation: location,
        homePageApiClient: _TestHomePageApiClient(),
      ),
    );
    await tester.pump();

    final page = tester.widget<RecommendSongListPage>(
      find.byType(RecommendSongListPage),
    );
    expect(page.platform, 'qq');
    expect(page.id, 'daily-new');
    expect(find.byType(MiniPlayerBar), findsOneWidget);
  });

  testWidgets('settings route covers mini player', (tester) async {
    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.settings),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayerBar), findsNothing);
    expect(find.text('路由测试歌曲'), findsNothing);
  });

  testWidgets('settings section slides in and returns through route stack', (
    tester,
  ) async {
    final router = createAppRouter(AppRoutes.settings);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _buildImmersiveRouterTestApp(router, _CountingAssetResolver()),
    );
    await tester.pumpAndSettle();

    final sectionPage = find.byKey(
      const ValueKey<String>('settings-page-lyrics'),
    );
    final homePage = find.byKey(const ValueKey<String>('settings-page-home'));

    await tester.tap(find.text('歌词'));
    await tester.pump();
    await tester.pump();

    expect(
      router.state.uri.path,
      AppRoutes.settingsSectionLocation(SettingsSectionIds.lyrics),
    );
    expect(sectionPage, findsOneWidget);
    final startDx = tester.getTopLeft(sectionPage).dx;
    expect(startDx, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 130));
    final middleDx = tester.getTopLeft(sectionPage).dx;
    expect(middleDx, greaterThan(0));
    expect(middleDx, lessThan(startDx));
    expect(
      tester.getRect(homePage).right,
      lessThanOrEqualTo(tester.getRect(sectionPage).left + 0.01),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(sectionPage).dx, closeTo(0, 0.01));

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.getTopLeft(sectionPage).dx, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 150));
    expect(router.state.uri.path, AppRoutes.settings);
    expect(
      find.byKey(const ValueKey<String>('settings-page-home')),
      findsOneWidget,
    );
  });
  testWidgets('settings sections respect the system reduced-motion setting', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = createAppRouter(AppRoutes.settings);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _buildImmersiveRouterTestApp(router, _CountingAssetResolver()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('歌词'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('settings-page-lyrics')),
          )
          .dx,
      0,
    );
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(const ValueKey<String>('settings-page-lyrics')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-page-home')),
      findsOneWidget,
    );
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
      find.byKey(const ValueKey<String>('app-player-style-boundary')),
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

Widget _buildRouterTestApp({
  required String initialLocation,
  bool authenticated = true,
  PlayerController Function()? playerControllerFactory,
  ScreenWakeLockPort? screenWakeLockPort,
  HomePageApiClient? homePageApiClient,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        authenticated
            ? _TestAppConfigController.new
            : _AnonymousAppConfigController.new,
      ),
      apiDioProvider.overrideWithValue(_emptyApiDio()),
      if (homePageApiClient != null)
        homePageApiClientProvider.overrideWithValue(homePageApiClient),
      playerControllerProvider.overrideWith(
        playerControllerFactory ?? _TestPlayerController.new,
      ),
      if (screenWakeLockPort != null)
        screenWakeLockPortProvider.overrideWithValue(screenWakeLockPort),
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
        final style = ref.watch(
          appConfigProvider.select((state) => state.uiStyle),
        );
        final skin = AppSkinRegistry.builtIn(
          AppConfigState.initial.themeAccent,
        ).resolve(AppSkinRegistry.classicId);
        return MaterialApp.router(
          theme: theme ?? AppTheme.light(skin, uiStyle: style),
          routerConfig: router,
        );
      },
    ),
  );
}

Widget _buildImmersiveRouterTestApp(
  GoRouter router,
  AppSkinAssetResolver resolver, {
  TargetPlatform platform = TargetPlatform.android,
}) {
  final skin = AppSkinRegistry.builtIn(
    AppConfigState.initial.themeAccent,
  ).resolve(AppSkinRegistry.citySoundCreatorId);
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_ImmersiveTestAppConfigController.new),
      apiDioProvider.overrideWithValue(_emptyApiDio()),
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
      theme: AppTheme.light(skin).copyWith(platform: platform),
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

Dio _emptyApiDio() => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/v1/mv') {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
          return;
        }
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{},
          ),
        );
      },
    ),
  );

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      authToken: 'token',
    );
  }

  void changeStyle(AppUiStyle style) {
    state = state.copyWith(uiStyle: style);
  }
}

class _AnonymousAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');
}

class _TestHomePageApiClient extends HomePageApiClient {
  _TestHomePageApiClient() : super(Dio());

  @override
  Future<RecommendSongListInfo> fetchRecommendSongList(
    RecommendSongListRequest request,
  ) async {
    return RecommendSongListInfo(
      id: request.id,
      title: '路由测试推荐',
      cover: '',
      description: '',
      songs: const <SongInfo>[],
    );
  }
}

class _ImmersiveTestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      authToken: 'token',
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

class _ActiveTestPlayerController extends _TestPlayerController {
  @override
  PlayerPlaybackState build() {
    return super.build().copyWith(isPlaybackSessionActive: true);
  }
}

class _RecordingScreenWakeLockPort implements ScreenWakeLockPort {
  final List<bool> calls = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
  }
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
  static const song = SongInfo(
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
  );

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) async {
    return const PlaylistInfo(
      name: '测试歌单',
      id: 'playlist-1',
      cover: '',
      creator: '测试创建者',
      songCount: '1',
      playCount: '0',
      songs: <SongInfo>[song],
      platform: 'qq',
      description: '',
    );
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) async {
    return PlaylistDetailSongsPageResult(
      songs: const <SongInfo>[song],
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalCount: 1,
      hasMore: false,
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

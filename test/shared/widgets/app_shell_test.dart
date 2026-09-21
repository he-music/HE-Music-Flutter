import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_shell.dart';
import 'package:he_music_flutter/shared/widgets/song_list_component.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';
import 'package:he_music_flutter/shared/widgets/app_glass_player_scaffold.dart';

void main() {
  testWidgets('immersive shell uses one themed selection indicator', (
    tester,
  ) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);
    final router = _createRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_ImmersiveAppConfigController.new),
          playerControllerProvider.overrideWith(_EmptyPlayerController.new),
        ],
        child: _GlassTestApp(theme: AppTheme.light(skin), router: router),
      ),
    );
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(navigationBar.showIndicator, isTrue);
    expect(
      find.byKey(
        const ValueKey<String>('app-skin-navigation-selection-indicator'),
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppSkinIcon &&
            widget.role == AppSkinIconRole.navigationHomeSelected,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(navigationBar.tabs[1].label!).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
      1,
    );
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.my);
    expect(
      tester.widget<GlassScaffold>(find.byType(GlassScaffold).first).extendBody,
      isTrue,
    );
  });

  testWidgets('shell chrome stays fixed for keyboard insets', (tester) async {
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);
    final router = _createRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_ImmersiveAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
        ],
        child: _GlassTestApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    final miniPlayer = find.byType(MiniPlayerBar);
    final navigationBar = find.byType(GlassTabBar);
    final initialMiniPlayerRect = tester.getRect(miniPlayer);
    final initialNavigationBarRect = tester.getRect(navigationBar);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pump();

    expect(tester.getRect(miniPlayer), initialMiniPlayerRect);
    expect(tester.getRect(navigationBar), initialNavigationBarRect);
  });

  testWidgets('shell uses compact bottom chrome heights', (tester) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.classicId);
    final router = _createRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_ImmersiveAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
        ],
        child: _GlassTestApp(theme: AppTheme.light(skin), router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(MiniPlayerBar)).height, 60);
    expect(tester.getSize(find.byType(GlassTabBar)).height, 60);
  });
  for (final batchMode in [false, true]) {
    testWidgets(
      'detail list clears floating player with batchMode=$batchMode',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        const playerKey = ValueKey('floating-player');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(_ImmersiveAppConfigController.new),
              playerControllerProvider.overrideWith(_TestPlayerController.new),
            ],
            child: AppGlassScope(
              enabled: true,
              child: GlassAdaptiveScope(
                minQuality: GlassQuality.minimal,
                maxQuality: GlassQuality.minimal,
                initialQuality: GlassQuality.minimal,
                child: MaterialApp(
                  home: AppGlassPlayerScaffold(
                    miniPlayer: const SizedBox(key: playerKey, height: 60),
                    body: DetailPageShell(
                      bottomBar: batchMode
                          ? const SizedBox(
                              key: ValueKey('batch-bar'),
                              height: 48,
                            )
                          : null,
                      child: SafeArea(
                        bottom: false,
                        child: SongListComponent(
                          enablePaging: false,
                          itemCount: 40,
                          itemBuilder: (_, index) =>
                              SizedBox(height: 64, child: Text('Row $index')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final viewport = find.byType(ListView);
        final player = tester.getRect(find.byKey(playerKey));
        if (batchMode) {
          expect(
            tester.getBottomLeft(find.byKey(const ValueKey('batch-bar'))).dy,
            player.top,
          );
        } else {
          expect(tester.getRect(viewport).bottom, 800);
          expect(tester.getRect(viewport).bottom, greaterThan(player.bottom));
        }
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomLeft(find.text('Row 39')).dy,
          lessThanOrEqualTo(player.top),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        tester.view.padding = FakeViewPadding.zero;
        await tester.pump();
        expect(tester.getRect(find.byKey(playerKey)), player);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final hasTrack in [false, true]) {
    testWidgets(
      'detail glass shell reserves safe area once with track=$hasTrack',
      (tester) async {
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        const bodyKey = ValueKey('detail-body');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playerControllerProvider.overrideWith(
                hasTrack
                    ? _TestPlayerController.new
                    : _EmptyPlayerController.new,
              ),
            ],
            child: MaterialApp(
              home: GlassAdaptiveScope(
                minQuality: GlassQuality.minimal,
                maxQuality: GlassQuality.minimal,
                initialQuality: GlassQuality.minimal,
                child: const AppGlassPlayerScaffold(
                  body: SizedBox.expand(key: bodyKey),
                  miniPlayer: SizedBox(height: 60),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scaffold = tester.widget<GlassScaffold>(
          find.byType(GlassScaffold),
        );
        expect(scaffold.extendBody, hasTrack);
        final safeBottom = 24 / tester.view.devicePixelRatio;
        expect(scaffold.bottomBarHeight, hasTrack ? 60 + safeBottom : 0);
        final bodyContext = tester.element(find.byKey(bodyKey));
        expect(
          MediaQuery.paddingOf(bodyContext).bottom,
          hasTrack ? 60 + safeBottom : safeBottom,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _GlassTestApp extends StatelessWidget {
  const _GlassTestApp({required this.router, this.theme});

  final GoRouter router;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) => AppGlassScope(
    enabled: true,
    child: GlassAdaptiveScope(
      minQuality: GlassQuality.minimal,
      maxQuality: GlassQuality.minimal,
      initialQuality: GlassQuality.minimal,
      child: MaterialApp.router(theme: theme, routerConfig: router),
    ),
  );
}

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.my,
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _ImmersiveAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      skinId: AppSkinRegistry.citySoundCreatorId,
    );
  }
}

class _EmptyPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'song-1', title: '测试歌曲'),
    ]);
  }
}

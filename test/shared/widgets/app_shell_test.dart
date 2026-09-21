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
  testWidgets('short content keeps stable expanded chrome', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = _createRouter(
      home: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          children: const [SizedBox(height: 784)],
        ),
      ),
    );
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
    final controller = tester
        .widget<GlassTabBar>(find.byType(GlassTabBar))
        .minimizeController!;
    var transitions = 0;
    controller.addListener(() {
      transitions++;
    });
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.maxScrollExtent, greaterThan(50));
    expect(position.maxScrollExtent, lessThan(110));
    await tester.timedDrag(
      find.byType(ListView),
      const Offset(0, -100),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(controller.minimized, isFalse);
    expect(
      transitions,
      0,
      reason:
          'Changing clearance must not alternate collapse and expansion on short content.',
    );
    expect(tester.takeException(), isNull);
  });

  for (final waitForIdle in [true, false]) {
    testWidgets(
      'manual navigation expansion wins over the current fling, waitForIdle=$waitForIdle',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = _createRouter(home: const _ChromeAwareList());
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
        final list = find.byKey(const ValueKey('home-scroll'));
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: list, matching: find.byType(Scrollable)),
            )
            .position;
        final controller = tester
            .widget<GlassTabBar>(find.byType(GlassTabBar))
            .minimizeController!;
        for (final (offset, collapsed) in <(double, bool)>[
          (40, false),
          (60, true),
          (49, true),
          (80, true),
          (30, true),
          (20, false),
          (0, false),
        ]) {
          position.jumpTo(offset);
          await tester.pumpAndSettle();
          expect(
            controller.minimized,
            collapsed,
            reason: 'Offset $offset should respect the 50/20 hysteresis.',
          );
        }
        await tester.fling(list, const Offset(0, -300), 3000);
        await tester.pump(const Duration(milliseconds: 350));
        expect(controller.minimized, isTrue);
        expect(position.isScrollingNotifier.value, isTrue);
        final before = position.pixels;
        await tester.tap(
          find
              .byWidgetPredicate(
                (w) =>
                    w is AppSkinIcon &&
                    w.role == AppSkinIconRole.navigationHomeSelected,
              )
              .hitTestable()
              .first,
        );
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            controller.minimized,
            isFalse,
            reason: 'The existing fling must not undo an explicit expansion.',
          );
        }
        expect(
          position.pixels,
          lessThan(before),
          reason:
              'The navigation tap takes over the fling and returns to the top.',
        );
        if (waitForIdle) {
          await tester.pumpAndSettle();
          expect(position.pixels, closeTo(position.minScrollExtent, 0.1));
        } else {
          expect(position.isScrollingNotifier.value, isTrue);
        }
        expect(controller.minimized, isFalse);
        await tester.timedDrag(
          list,
          const Offset(0, -150),
          const Duration(milliseconds: 400),
        );
        await tester.pumpAndSettle();
        expect(
          controller.minimized,
          isTrue,
          reason: 'A fresh drag restores automatic minimizing.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in [
    'narrow',
    'highContrast',
    'reduceMotion',
    'noTrack',
  ]) {
    testWidgets('bottom chrome remains expanded for $scenario', (tester) async {
      tester.view.physicalSize = Size(scenario == 'narrow' ? 320 : 390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(
            highContrast: scenario == 'highContrast',
            disableAnimations: scenario == 'reduceMotion',
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final router = _createRouter(home: const _ChromeAwareList());
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_ImmersiveAppConfigController.new),
            playerControllerProvider.overrideWith(
              scenario == 'noTrack'
                  ? _EmptyPlayerController.new
                  : _TestPlayerController.new,
            ),
          ],
          child: _GlassTestApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(GlassScaffold)).height;
      await tester.drag(
        find.byKey(const ValueKey('home-scroll')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(GlassScaffold)).height, height);
      if (scenario != 'highContrast') {
        final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
        expect(bar.minimizeController, isNull);
        expect(
          tester.getSize(find.byType(GlassTabBar)).height,
          scenario == 'noTrack' ? 60 : 120,
        );
      } else {
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(MiniPlayerBar), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'scroll folds the player into navigation without losing playback or page state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var builds = 0;
      final router = _createRouter(
        home: Builder(
          builder: (context) {
            builds++;
            return const _ChromeAwareList();
          },
        ),
      );
      addTearDown(router.dispose);
      final player = _InteractionPlayerController();
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve(AppSkinRegistry.classicId);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_ImmersiveAppConfigController.new),
            playerControllerProvider.overrideWith(() => player),
          ],
          child: _GlassTestApp(router: router, theme: AppTheme.light(skin)),
        ),
      );
      await tester.pumpAndSettle();
      final mini = find.byType(MiniPlayerBar);
      final originalState = tester.state(mini);
      final beforeBuilds = builds;
      final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      final controller = bar.minimizeController!;
      final list = find.byKey(const ValueKey('home-scroll'));
      await tester.drag(list, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(controller.minimized, isTrue);
      expect(tester.getSize(find.byType(GlassTabBar)).height, 60);
      expect(tester.getRect(mini).left, greaterThan(70));
      expect(tester.state(mini), same(originalState));
      expect(
        find.byWidgetPredicate(
          (w) => w is AppSkinIcon && w.role == AppSkinIconRole.miniPlayerQueue,
        ),
        findsNothing,
      );
      final play = find.byWidgetPredicate(
        (w) => w is AppSkinIcon && w.role == AppSkinIconRole.miniPlayerPlay,
      );
      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(player.playing, isTrue);
      expect(controller.minimized, isTrue);
      expect(builds, beforeBuilds);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('Row 59')).dy,
        lessThanOrEqualTo(tester.getTopLeft(mini).dy),
      );
      position.jumpTo(300);
      await tester.pumpAndSettle();
      // Restore tabs by tapping the collapsed current destination.
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is AppSkinIcon &&
                  w.role == AppSkinIconRole.navigationHomeSelected,
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(controller.minimized, isFalse);
      expect(tester.getSize(find.byType(GlassTabBar)).height, 120);
      expect(tester.state(mini), same(originalState));
      await tester.drag(list, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(controller.minimized, isTrue);
      await tester.drag(list, const Offset(0, 160));
      await tester.pumpAndSettle();
      expect(controller.minimized, isFalse);
      await tester.tap(find.text(bar.tabs[1].label!).first);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.my);
      expect(tester.state(mini), same(originalState));
      expect(tester.takeException(), isNull);
    },
  );

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

    expect(tester.getSize(find.byType(MiniPlayerBar)).height, 52);
    expect(tester.getSize(find.byType(GlassTabBar)).height, 120);
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

class _ChromeAwareList extends StatelessWidget {
  const _ChromeAwareList();
  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const ValueKey('home-scroll'),
    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
    itemCount: 60,
    itemBuilder: (_, index) => ListTile(title: Text('Row $index')),
  );
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

GoRouter _createRouter({Widget? home}) {
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
                builder: (context, state) => home ?? const SizedBox.shrink(),
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

class _InteractionPlayerController extends _TestPlayerController {
  bool get playing => state.isPlaying;
  @override
  Future<void> togglePlayPause() async {
    state = state.copyWith(isPlaying: !state.isPlaying);
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

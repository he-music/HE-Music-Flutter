import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/shared/widgets/app_player_scaffold.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_bottom_navigation_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_shell.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style navigation keeps browsing and playback across tabs and resizing',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final libraryScroll = ScrollController();
        addTearDown(libraryScroll.dispose);
        final router = _router(
          library: ListView.builder(
            controller: libraryScroll,
            itemCount: 60,
            itemBuilder: (_, index) => ListTile(title: Text('Library $index')),
          ),
          home: ListView.builder(
            controller: scroll,
            itemCount: 60,
            itemBuilder: (_, index) => ListTile(title: Text('Row $index')),
          ),
        );
        addTearDown(router.dispose);
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWith(_Config.new),
            playerControllerProvider.overrideWith(_Player.new),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light(citySoundCreatorSkin(), uiStyle: style),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBottomNavigationBar), findsOneWidget);
        expect(
          find.byType(
            style == AppUiStyle.cupertino ? CupertinoTabBar : NavigationBar,
          ),
          findsOneWidget,
        );
        final barFinder = find.byType(
          style == AppUiStyle.cupertino ? CupertinoTabBar : NavigationBar,
        );
        final bar = tester.getRect(barFinder);
        expect(bar.left, 0);
        expect(bar.right, 390);
        expect(bar.bottom, closeTo(844, 0.01));
        final miniSurface = find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.byType(AppSkinSurface),
        );
        final miniRect = tester.getRect(miniSurface);
        expect(miniRect.left, 12);
        expect(miniRect.right, 378);
        expect(miniRect.bottom, bar.top - 8);
        expect(
          tester.widget<AppSkinSurface>(miniSurface).showDecoration,
          isFalse,
        );
        if (style == AppUiStyle.material) {
          expect(bar.height, 64 + 24);
          expect(
            Theme.of(
              tester.element(barFinder),
            ).navigationBarTheme.indicatorColor!.a,
            greaterThan(0),
          );
        }
        scroll.jumpTo(500);
        await tester.pumpAndSettle();
        void selectTab(int index) {
          if (style == AppUiStyle.cupertino) {
            tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar)).onTap!(
              index,
            );
          } else {
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .onDestinationSelected!(index);
          }
        }

        selectTab(1);
        await tester.pumpAndSettle();
        libraryScroll.jumpTo(300);
        await tester.pumpAndSettle();
        selectTab(2);
        await tester.pumpAndSettle();
        expect(find.text('My page'), findsOneWidget);
        selectTab(0);
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(500, .1));
        selectTab(1);
        await tester.pumpAndSettle();
        expect(libraryScroll.offset, closeTo(300, .1));
        selectTab(0);
        await tester.pumpAndSettle();
        final mini = find.byType(MiniPlayerBar);
        final before = tester.getRect(mini);
        tester.view.padding = const FakeViewPadding();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.getRect(mini), before);
        tester.view.viewInsets = const FakeViewPadding();
        tester.view.padding = const FakeViewPadding(bottom: 24);
        tester.view.physicalSize = const Size(1400, 900);
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(500, .1));
        final wideMiniRect = tester.getRect(miniSurface);
        expect(wideMiniRect.width, 616);
        expect(wideMiniRect.center.dx, 700);
        expect(find.text('Test song'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$style mini player remains readable at large text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_Config.new),
            playerControllerProvider.overrideWith(_Player.new),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(citySoundCreatorSkin(), uiStyle: style),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test song'), findsOneWidget);
      expect(
        tester.getSize(find.byType(MiniPlayerBar)).height,
        greaterThan(60),
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$style standalone mini player preserves safe areas when keyboard appears',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.viewPadding = const FakeViewPadding(
          left: 18,
          right: 24,
          bottom: 24,
        );
        tester.view.padding = const FakeViewPadding(
          left: 18,
          right: 24,
          bottom: 24,
        );
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(_Config.new),
              playerControllerProvider.overrideWith(_Player.new),
            ],
            child: MaterialApp(
              theme: AppTheme.light(citySoundCreatorSkin(), uiStyle: style),
              home: AppPlayerScaffold(
                body: const SizedBox.shrink(),
                miniPlayer: MiniPlayerBar(
                  bottomSafeArea: true,
                  onOpenFullPlayer: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final surface = find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.byType(AppSkinSurface),
        );
        final before = tester.getRect(surface);
        expect(before.left, 30);
        expect(before.right, 354);
        expect(before.bottom, 812);
        tester.view.padding = const FakeViewPadding(left: 18, right: 24);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

GoRouter _router({Widget? home, Widget? library}) => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      builder: (_, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (_, _) => home ?? const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.collection,
                  builder: (_, _) =>
                      library ?? const Center(child: Text('Library page')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.my,
                  builder: (_, _) => const Center(child: Text('My page')),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const [
    PlayerTrack(id: 'song', title: 'Test song'),
  ]);
}

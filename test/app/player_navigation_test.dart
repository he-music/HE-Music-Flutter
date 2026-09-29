import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_route_page.dart';

void main() {
  Future<GoRouter> start(WidgetTester tester, {bool deepLink = false}) async {
    final router = GoRouter(
      initialLocation: deepLink ? AppRoutes.player : AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) => child,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const _Page('Home'),
            ),
          ],
        ),
        GoRoute(path: '/search', builder: (_, _) => const _Page('Search')),
        GoRoute(path: '/album', builder: (_, _) => const _Page('Album')),
        GoRoute(path: '/artist', builder: (_, _) => const _Page('Artist')),
        GoRoute(
          path: AppRoutes.player,
          pageBuilder: (_, state) =>
              PlayerRoutePage(key: state.pageKey, child: const _Page('Player')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  void expectSinglePlayer(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    expect(
      matches.where((match) {
        final route = match.route;
        return route is GoRoute && route.path == AppRoutes.player;
      }),
      hasLength(1),
    );
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).hitTestable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> toAlbum(WidgetTester tester) async {
    await tap(tester, 'Search link');
    await tester.enterText(find.byType(TextField), 'retained query');
    await tap(tester, 'MiniPlayer');
    await tap(tester, 'Album link');
  }

  Future<void> backTo(WidgetTester tester, String name) async {
    await tap(tester, 'Back');
    expect(find.text(name), findsOneWidget);
  }

  testWidgets('detail back returns to player, then search with its state', (
    tester,
  ) async {
    await start(tester);
    await toAlbum(tester);
    await backTo(tester, 'Player');
    await backTo(tester, 'Search');
    expect(find.text('retained query'), findsOneWidget);
    await backTo(tester, 'Home');
  });

  testWidgets(
    'reopening player preserves album and search, removing old player',
    (tester) async {
      final router = await start(tester);
      await toAlbum(tester);
      final album = tester.element(find.text('Album'));
      await tap(tester, 'MiniPlayer');
      expectSinglePlayer(router);
      await backTo(tester, 'Album');
      expect(tester.element(find.text('Album')), same(album));
      await backTo(tester, 'Search');
      expect(find.text('retained query'), findsOneWidget);
      await backTo(tester, 'Home');
    },
  );

  testWidgets(
    'artist back returns through moved player, album, search and home',
    (tester) async {
      await start(tester);
      await toAlbum(tester);
      await tap(tester, 'MiniPlayer');
      await tap(tester, 'Artist link');
      await backTo(tester, 'Player');
      await backTo(tester, 'Album');
      await backTo(tester, 'Search');
      await backTo(tester, 'Home');
    },
  );

  testWidgets(
    'repeated and same-frame MiniPlayer taps do not duplicate routes',
    (tester) async {
      final router = await start(tester);
      await toAlbum(tester);
      for (var i = 0; i < 3; i++) {
        final context = tester.element(find.text('Album'));
        unawaited(openFullPlayer(context));
        unawaited(openFullPlayer(context));
        await tester.pumpAndSettle();
        expectSinglePlayer(router);
        await backTo(tester, 'Album');
      }
      await backTo(tester, 'Search');
      await backTo(tester, 'Home');
    },
  );

  testWidgets('moving a deep-linked player supplies home beneath content', (
    tester,
  ) async {
    await start(tester, deepLink: true);
    await tap(tester, 'Album link');
    await tap(tester, 'MiniPlayer');
    await backTo(tester, 'Album');
    await backTo(tester, 'Home');
  });

  testWidgets(
    'pop player followed immediately by push does not leave its overlay',
    (tester) async {
      final router = await start(tester);
      var completed = false;
      unawaited(
        router.push<void>(AppRoutes.player).then((_) => completed = true),
      );
      await tester.pumpAndSettle();
      router.pop();
      unawaited(router.push<void>('/album'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      await backTo(tester, 'Home');
      expect(find.text('Player', skipOffstage: false), findsNothing);
    },
  );
}

class _Page extends StatelessWidget {
  const _Page(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(name),
        if (name == 'Search') const TextField(),
        TextButton(
          onPressed: () => context.push('/search'),
          child: const Text('Search link'),
        ),
        TextButton(
          onPressed: () => openFullPlayer(context),
          child: const Text('MiniPlayer'),
        ),
        TextButton(
          onPressed: () => context.push('/album'),
          child: const Text('Album link'),
        ),
        TextButton(
          onPressed: () => context.push('/artist'),
          child: const Text('Artist link'),
        ),
        TextButton(onPressed: () => context.pop(), child: const Text('Back')),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/pages/library_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style library keeps local entry routes and guest login redirect',
      (tester) async {
        final router = _router();
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router, style));
        await tester.pumpAndSettle();
        for (final entry in [
          ('Local Songs', AppRoutes.library),
          ('Downloads', AppRoutes.downloads),
          ('Play History', AppRoutes.myHistory),
          ('Collections', AppRoutes.login),
        ]) {
          await tester.tap(find.text(entry.$1));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, entry.$2);
          if (entry.$2 == AppRoutes.login) {
            expect(
              router.state.uri.queryParameters['redirect'],
              AppRoutes.collection,
            );
          }
          router.pop();
          await tester.pumpAndSettle();
        }
        expect(find.text('Created playlists'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$style library uses shared created and favorite playlist providers',
      (tester) async {
        final router = _router();
        addTearDown(router.dispose);
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(router, style, signedIn: true));
        await tester.pumpAndSettle();
        for (final entry in [
          ('Weekend mix', AppRoutes.userPlaylistDetail),
          ('Saved mix', AppRoutes.playlistDetail),
        ]) {
          await tester.ensureVisible(find.text(entry.$1));
          await tester.tap(find.text(entry.$1));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, entry.$2);
          expect(
            router.state.uri.queryParameters['id'],
            entry.$1 == 'Weekend mix' ? 'created-1' : 'favorite-1',
          );
          if (entry.$2 == AppRoutes.playlistDetail) {
            expect(router.state.uri.queryParameters['platform'], 'qq');
          }
          router.pop();
          await tester.pumpAndSettle();
        }
        expect(find.text('Sign In'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

GoRouter _router() => GoRouter(
  initialLocation: AppRoutes.collection,
  routes: [
    GoRoute(path: AppRoutes.collection, builder: (_, _) => const LibraryPage()),
    for (final route in [
      AppRoutes.library,
      AppRoutes.downloads,
      AppRoutes.myHistory,
      AppRoutes.myCollection,
      AppRoutes.login,
      AppRoutes.userPlaylistDetail,
      AppRoutes.playlistDetail,
    ])
      GoRoute(
        path: route,
        builder: (_, _) => const Scaffold(body: Text('Destination')),
      ),
  ],
);

Widget _app(GoRouter router, AppUiStyle style, {bool signedIn = false}) =>
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith(() => _Config(signedIn)),
        myCreatedPlaylistsProvider.overrideWith((_) async => const [_created]),
        myFavoritePlaylistsProvider.overrideWith(
          (_) => const AsyncData([_favorite]),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(
          AppSkinRegistry.builtIn(
            AppConfigState.initial.themeAccent,
          ).resolve(AppSkinRegistry.classicId),
          uiStyle: style,
        ),
        routerConfig: router,
      ),
    );

class _Config extends AppConfigController {
  _Config(this.signedIn);
  final bool signedIn;

  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: 'en',
    authToken: signedIn ? 'test-token' : '',
  );
}

const _created = MyFavoriteItem(
  id: 'created-1',
  platform: 'he',
  type: MyFavoriteType.playlists,
  title: 'Weekend mix',
  subtitle: 'My playlist',
  coverUrl: '',
);
const _favorite = MyFavoriteItem(
  id: 'favorite-1',
  platform: 'qq',
  type: MyFavoriteType.playlists,
  title: 'Saved mix',
  subtitle: 'Favorite playlist',
  coverUrl: '',
);

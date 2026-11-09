import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_theme.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/shared/widgets/select_user_playlist_sheet.dart';

void main() {
  testWidgets(
    'anonymous add to playlist opens login before loading user playlists',
    (tester) async {
      var loads = 0;
      final router = GoRouter(
        initialLocation: '/player',
        routes: [
          GoRoute(
            path: '/player',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showSelectUserPlaylistSheet(context),
                child: const Text('Add to playlist'),
              ),
            ),
          ),
          GoRoute(path: '/login', builder: (_, _) => const Text('Login')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_AnonymousConfig.new),
            appRouterProvider.overrideWithValue(router),
            myCreatedPlaylistsProvider.overrideWith((ref) async {
              loads++;
              return [];
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Add to playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      expect(loads, 0);
      expect(find.byType(SelectUserPlaylistSheet), findsNothing);
    },
  );
  testWidgets('playlist selection sheet follows player sheet brightness', (
    tester,
  ) async {
    final cases = <({Brightness brightness, AppPlayerSheetStyle sheet})>[
      (brightness: Brightness.light, sheet: AppPlayerSheetStyle.light),
      (brightness: Brightness.dark, sheet: AppPlayerSheetStyle.dark),
    ];

    for (final testCase in cases) {
      SelectedUserPlaylist? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_SignedInConfig.new),
            myCreatedPlaylistsProvider.overrideWith(
              (ref) async => const <MyFavoriteItem>[
                MyFavoriteItem(
                  id: 'playlist-1',
                  platform: 'user',
                  type: MyFavoriteType.playlists,
                  title: 'Target playlist',
                  subtitle: 'Owner',
                  coverUrl: '',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: buildAppPlayerStyleTheme(
              appPlayerForegroundColors,
              appPlayerSystemOverlayStyle,
              sheetBrightness: testCase.brightness,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    selected = await showSelectUserPlaylistSheet(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(SelectUserPlaylistSheet)).height,
        lessThan(300),
      );
      expect(
        _renderedTextColor(tester, 'Select playlist'),
        testCase.sheet.foregroundColor,
      );
      expect(
        _renderedTextColor(tester, 'Target playlist'),
        testCase.sheet.foregroundColor,
      );

      await tester.tap(find.text('Target playlist'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'playlist-1');
    }
  });
  for (final state in ['loading', 'empty', 'error', 'data']) {
    testWidgets(
      'Cupertino playlist sheet can close during $state without selecting',
      (tester) async {
        final playlists = Completer<List<MyFavoriteItem>>();
        final result = Completer<SelectedUserPlaylist?>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(_SignedInConfig.new),
              myCreatedPlaylistsProvider.overrideWith(
                (ref) => playlists.future,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(
                extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Open'),
                    onPressed: () async => result.complete(
                      await showSelectUserPlaylistSheet(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        if (state == 'error') {
          playlists.completeError(StateError('unavailable'));
        } else if (state != 'loading') {
          playlists.complete(
            state == 'data'
                ? const [
                    MyFavoriteItem(
                      id: 'playlist-1',
                      platform: 'user',
                      type: MyFavoriteType.playlists,
                      title: 'Target playlist',
                      subtitle: '',
                      coverUrl: '',
                    ),
                  ]
                : const [],
          );
        }
        await tester.pump();
        await tester.pump();
        expect(
          tester.getSize(find.byType(SelectUserPlaylistSheet)).height,
          lessThan(320),
        );
        expect(find.text('Select playlist'), findsOneWidget);
        expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(await result.future, isNull);
        expect(find.byType(SelectUserPlaylistSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Color? _renderedTextColor(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  return paragraph.text.style?.color;
}

class _SignedInConfig extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(authToken: 'token');
}

class _AnonymousConfig extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

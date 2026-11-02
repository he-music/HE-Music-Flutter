import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/helpers/song_artist_navigation_helper.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets(
    'short mobile artist menu cancels and opens selected artist once',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => openSongArtistSelection(
                  context: context,
                  platformId: 'qq',
                  artists: const [
                    SongInfoArtistInfo(id: '1', name: 'First'),
                    SongInfoArtistInfo(id: '2', name: 'Second'),
                  ],
                ),
                child: const Text('Artists'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.artistDetail,
            builder: (context, state) => Scaffold(
              body: Text('Artist ${state.uri.queryParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(
            extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
          ),
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('Artist 2'), findsOneWidget);
      expect(find.byType(CupertinoActionSheet), findsNothing);
    },
  );
}

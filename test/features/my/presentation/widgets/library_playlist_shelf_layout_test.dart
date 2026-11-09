import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/features/my/presentation/widgets/library_playlist_shelf.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';

void main() {
  for (final style in AppUiStyle.values) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        '$style playlist covers scale and retain expansion at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final playlists = List.generate(
            6,
            (index) => MyFavoriteItem(
              id: '$index',
              platform: 'he',
              type: MyFavoriteType.playlists,
              title: 'Evening collection $index',
              subtitle: 'Selected for quiet listening',
              coverUrl: '',
              songCount: index == 0 ? '12' : '',
            ),
          );
          final container = ProviderContainer(
            overrides: [
              appConfigProvider.overrideWith(_Config.new),
              myCreatedPlaylistsProvider.overrideWith((_) async => playlists),
              myFavoritePlaylistsProvider.overrideWith(
                (_) => const AsyncData(<MyFavoriteItem>[]),
              ),
            ],
          );
          addTearDown(container.dispose);
          Widget app(bool background) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(
                citySoundCreatorSkin(),
                uiStyle: style,
                showContentBackground: background,
              ),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [LibraryPlaylistShelf()],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpWidget(app(true));
          await tester.pumpAndSettle();
          expect(find.byType(MediaGridCard), findsNWidgets(5));
          expect(find.text('12 Tracks'), findsOneWidget);
          expect(find.text('0 Tracks'), findsNothing);
          final cards = find.byType(MediaGridCard);
          if (width == 390) {
            expect(
              tester.getTopLeft(cards.at(0)).dy,
              tester.getTopLeft(cards.at(1)).dy,
            );
            expect(tester.getSize(cards.first).width, greaterThan(150));
          }
          await tester.ensureVisible(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          expect(find.byType(MediaGridCard), findsNWidgets(6));
          final state = tester.state(find.byType(LibraryPlaylistShelf));
          await tester.pumpWidget(app(false));
          await tester.pumpAndSettle();
          expect(tester.state(find.byType(LibraryPlaylistShelf)), same(state));
          expect(find.byType(MediaGridCard), findsNWidgets(6));
          await tester.ensureVisible(find.text('Collapse'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Collapse'));
          await tester.pumpAndSettle();
          expect(find.byType(MediaGridCard), findsNWidgets(5));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: 'en',
    authToken: 'test-token',
  );
}

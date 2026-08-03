import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_theme.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/shared/widgets/select_user_playlist_sheet.dart';

void main() {
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
              AppPlayerStyleRegistry.instance.resolve(
                AppPlayerStyleRegistry.classicId,
              ),
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
}

Color? _renderedTextColor(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  return paragraph.text.style?.color;
}

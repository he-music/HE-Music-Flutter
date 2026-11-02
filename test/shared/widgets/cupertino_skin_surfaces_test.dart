import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/shared/widgets/app_list_tile.dart';
import 'package:he_music_flutter/features/online/presentation/widgets/search_album_list_item.dart';
import 'package:he_music_flutter/features/online/presentation/widgets/search_artist_list_item.dart';
import 'package:he_music_flutter/features/online/presentation/widgets/search_playlist_list_item.dart';
import 'package:he_music_flutter/shared/widgets/app_panel.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';
import 'package:he_music_flutter/shared/widgets/video_item.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Cupertino content shares surfaces across skins in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final registry = AppSkinRegistry.builtIn(AppThemeAccent.appleBlue);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var albumTaps = 0;
      var entryTaps = 0;
      for (final skinId in [
        AppSkinRegistry.classicId,
        AppSkinRegistry.starlitMelodyId,
        AppSkinRegistry.citySoundCreatorId,
      ]) {
        for (final enabled in [false, true]) {
          final skin = registry.resolve(skinId);
          final theme = brightness == Brightness.light
              ? AppTheme.light(
                  skin,
                  uiStyle: AppUiStyle.cupertino,
                  showContentBackground: enabled,
                )
              : AppTheme.dark(
                  skin,
                  uiStyle: AppUiStyle.cupertino,
                  showContentBackground: enabled,
                );
          final previousOffset = scroll.hasClients ? scroll.offset : 0.0;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appConfigProvider.overrideWith(_Config.new)],
              child: MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    controller: scroll,
                    child: Column(
                      children: [
                        AppPanel(
                          padding: const EdgeInsets.all(16),
                          child: const _Counter(),
                        ),
                        AppListSection(
                          children: [
                            AppListTile(
                              title: const Text('Grouped entry'),
                              onTap: () => entryTaps++,
                            ),
                          ],
                        ),
                        const Card(child: Text('Standard card')),
                        SongListItem(
                          data: const SongListItemData(
                            title: 'Song',
                            artistAlbumText: 'Artist',
                            subtitleText: '',
                          ),
                        ),
                        SearchAlbumListItem(
                          title: 'Album',
                          subtitle: 'Artist',
                          coverUrl: '',
                          onTap: () => albumTaps++,
                        ),
                        SearchArtistListItem(
                          localeCode: 'en',
                          title: 'Artist',
                          coverUrl: '',
                          songCount: '1',
                          albumCount: '2',
                          videoCount: '3',
                          onTap: () {},
                        ),
                        SearchPlaylistListItem(
                          title: 'Playlist',
                          subtitle: 'Creator',
                          coverUrl: '',
                          onTap: () {},
                        ),
                        VideoListItem(
                          title: 'Video',
                          coverUrl: '',
                          onTap: () {},
                        ),
                        SizedBox(
                          width: 160,
                          height: 200,
                          child: MediaGridCard(
                            kind: MediaGridCardKind.album,
                            title: 'Selected album',
                            subtitle: '',
                            coverUrl: '',
                            selected: true,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(scroll.offset, closeTo(previousOffset, 0.1));
          // Neither changing skin nor toggling content backgrounds remounts the
          // content. This models an expanded row or a local editor retaining state.
          final initial = skinId == AppSkinRegistry.classicId && !enabled;
          if (initial) {
            await tester.tap(find.text('Count 0'));
            await tester.pump();
          }
          expect(find.text('Count 1'), findsOneWidget);
          final surfaces = find.byType(AppSkinSurface);
          expect(surfaces, findsNWidgets(7));
          for (final element in surfaces.evaluate()) {
            final decoration =
                tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: find.byWidget(element.widget),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration;
            expect(decoration.border, isNull);
            expect(decoration.boxShadow, isEmpty);
            expect(decoration.borderRadius, BorderRadius.circular(10));
            expect(decoration.color!.a, enabled ? greaterThan(0) : 0);
          }
          final group = tester.widget<CupertinoListSection>(
            find.byType(CupertinoListSection),
          );
          final groupColor = group.decoration!.color!;
          expect(groupColor.a, enabled ? greaterThan(0) : 0);
          final cardMaterial = tester.widget<Material>(
            find.descendant(
              of: find.byType(Card),
              matching: find.byType(Material),
            ),
          );
          expect(cardMaterial.color, groupColor);
          await tester.ensureVisible(find.text('Grouped entry'));
          await tester.pumpAndSettle();
          final entriesBefore = entryTaps;
          await tester.tap(find.text('Grouped entry'));
          expect(entryTaps, entriesBefore + 1);
          // Selected cover borders remain meaningful even when skin frames vanish.
          final selection =
              tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byType(MediaGridCard),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration
                  as BoxDecoration;
          expect(selection.border, isNotNull);
          expect(selection.color!.a, greaterThan(0));
          expect(
            find.byKey(const ValueKey('cupertino-song-divider')),
            enabled ? findsNothing : findsOneWidget,
          );
          await tester.ensureVisible(find.text('Album'));
          await tester.pumpAndSettle();
          final before = albumTaps;
          await tester.tap(find.text('Album'));
          expect(albumTaps, before + 1);
          expect(find.byType(BackdropFilter), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('Count $count'),
  );
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'en');
}

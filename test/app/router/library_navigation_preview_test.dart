import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/pages/library_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_bottom_navigation_bar.dart';

// Explicit artifact export; no binary goldens are read or updated.
const _previewDirectory = String.fromEnvironment('NAVIGATION_PREVIEW_DIR');

void main() {
  setUpAll(() async {
    if (_previewDirectory.isEmpty) return;
    for (final family in [
      'Roboto',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      await (FontLoader(family)..addFont(
            File(
              'test/assets/fonts/Roboto-Regular.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });

  for (final style in AppUiStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('$style $brightness library navigation preview', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        final router = createAppRouter(AppRoutes.collection);
        addTearDown(router.dispose);
        final capture = GlobalKey();
        final skin = AppSkinRegistry.builtIn(
          AppConfigState.initial.themeAccent,
        ).resolve(AppSkinRegistry.classicId);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(() => _Config(style)),
              playerControllerProvider.overrideWith(_Player.new),
              myCreatedPlaylistsProvider.overrideWith(
                (_) async => const [_playlist],
              ),
              myFavoritePlaylistsProvider.overrideWith(
                (_) => const AsyncData([]),
              ),
            ],
            child: RepaintBoundary(
              key: capture,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(skin, uiStyle: style),
                darkTheme: AppTheme.dark(skin, uiStyle: style),
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LibraryPage), findsOneWidget);
        expect(find.byType(AppBottomNavigationBar), findsOneWidget);
        expect(find.byType(MiniPlayerBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (_previewDirectory.isNotEmpty) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '$_previewDirectory/library_${style.name}_${brightness.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
            expect(await file.length(), greaterThan(0));
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _Config extends AppConfigController {
  _Config(this.style);
  final AppUiStyle style;

  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: 'en',
    authToken: 'preview-token',
    uiStyle: style,
  );
}

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const [
    PlayerTrack(
      id: 'preview-track',
      title: 'Weekend listening',
      artist: 'HE Music',
    ),
  ]);

  @override
  Future<void> initialize() async {}
}

const _playlist = MyFavoriteItem(
  id: 'preview-playlist',
  platform: 'he',
  type: MyFavoriteType.playlists,
  title: 'Weekend mix',
  subtitle: 'My playlist',
  coverUrl: '',
);

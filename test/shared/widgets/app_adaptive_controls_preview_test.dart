import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_bars.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_control_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';
import 'package:he_music_flutter/shared/widgets/app_back_button.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';

void main() {
  setUpAll(() async {
    for (final family in [
      'ControlsPreview',
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
      testWidgets('$style controls preview in $brightness', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final skin = AppSkinRegistry.builtIn(
          AppThemeAccent.appleBlue,
        ).resolve('classic');
        final base = brightness == Brightness.light
            ? AppTheme.light(skin, uiStyle: style)
            : AppTheme.dark(skin, uiStyle: style);
        final theme = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'ControlsPreview'),
          appBarTheme: base.appBarTheme.copyWith(
            titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
              fontFamily: 'ControlsPreview',
            ),
          ),
        );
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                appBar: AppNavigationBar(
                  title: const Text('Music library'),
                  leading: AppBackButton(onPressed: () {}),
                  actions: [
                    AppIconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      onPressed: () {},
                    ),
                  ],
                ),
                body: ListView(
                  children: [
                    const SizedBox(height: 12),
                    SearchTypeBar(
                      localeCode: 'en',
                      selectedType: SearchType.song,
                      types: const [
                        SearchType.song,
                        SearchType.album,
                        SearchType.artist,
                      ],
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 10),
                    SearchPlatformBar(
                      loading: false,
                      platforms: [
                        for (final source in [
                          'QQ Music',
                          'NetEase',
                          'Apple Music',
                        ])
                          SearchPlatform(
                            id: source,
                            label: source,
                            available: true,
                            featureSupportFlag:
                                PlatformFeatureSupportFlag.searchSong,
                          ),
                      ],
                      requiredFeatureFlag:
                          PlatformFeatureSupportFlag.searchSong,
                      selectedPlatformId: 'QQ Music',
                      onChanged: (_) {},
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Recently added',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    for (var index = 0; index < 3; index++)
                      SongListItem(
                        data: SongListItemData(
                          title: [
                            'City echoes',
                            'A longer song title with a second readable line',
                            'Nightfall',
                          ][index],
                          artistAlbumText: [
                            'Lin Nuo · Signal room',
                            'Aurora · Collected works',
                            'Sora · After hours',
                          ][index],
                          subtitleText: index == 0
                              ? '2026 · Studio release'
                              : '',
                          isCurrent: index == 0,
                          showMoreVersionButton: index == 1,
                        ),
                        isLiked: index == 0,
                        onTap: () {},
                        onLikeTap: () {},
                        onMoreTap: () {},
                        onMoreVersionTap: () {},
                      ),
                    const SizedBox(height: 24),
                    ColoredBox(
                      color: const Color(0xFF203149),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: PlayerControlBar(
                          localeCode: 'en',
                          isPlaying: true,
                          playMode: PlayerPlayMode.sequence,
                          onOpenQueue: () {},
                          onCyclePlayMode: () {},
                          onPrevious: () {},
                          onPlayPause: () {},
                          onNext: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '/tmp/he-music-controls-previews/${style.name}-${brightness.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            expect(await file.length(), greaterThan(0));
          } finally {
            image.dispose();
          }
        });
      });
    }
  }
}

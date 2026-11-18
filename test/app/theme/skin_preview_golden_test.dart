import 'dart:io';

import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_info.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_request.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_state.dart';
import 'package:he_music_flutter/features/home/presentation/controllers/recommend_song_list_controller.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_state.dart';
import 'package:he_music_flutter/features/home/presentation/controllers/home_page_controller.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/shared/widgets/select_user_playlist_sheet.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';

const _previewSize = Size(360, 640);
const _previewKey = ValueKey<String>('skin-preview-golden-root');
const _previewFontFamily = 'PreviewRoboto';
const _previewCjkFontFamily = 'PreviewCjk';
const _previewFontFallback = <String>[_previewCjkFontFamily];
const _previewCjkFontPath = String.fromEnvironment(
  'MINI_PLAYER_PREVIEW_CJK_FONT',
  defaultValue: 'test/assets/fonts/DroidSansFallback-PreviewSubset.ttf',
);
final _previewHomePageFeatures =
    PlatformFeatureSupportFlag.getRecommendPage |
    PlatformFeatureSupportFlag.getDiscoverPage;

const _previewLongList = bool.fromEnvironment('MINI_PLAYER_PREVIEW_LONG_LIST');
// 预览基准图在 macOS 生成；Linux 渲染存在稳定像素差异，不做逐像素比较。
void main() {
  const miniPlayerPreviewDirectory = String.fromEnvironment(
    'MINI_PLAYER_PREVIEW_DIR',
  );
  testWidgets(
    'export floating mini player previews',
    (tester) async {
      await tester.runAsync(_loadPreviewFonts);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      for (final skinId in [
        AppSkinRegistry.classicId,
        AppSkinRegistry.starlitMelodyId,
        AppSkinRegistry.forestSanctuaryId,
        AppSkinRegistry.tidalSanctuaryId,
      ]) {
        for (final style in AppUiStyle.values) {
          for (final brightness in Brightness.values) {
            final router = createAppRouter(AppRoutes.home);
            await tester.pumpWidget(
              _buildPreviewApp(router, brightness, skinId, uiStyle: style),
            );
            await tester.pumpAndSettle();
            if (skinId != AppSkinRegistry.classicId) {
              await _pumpUntilWallpaperDecoded(tester);
            }
            for (final page in ['home', 'detail']) {
              if (page == 'detail') {
                router.push(
                  '${AppRoutes.recommendSongList}?id=preview&platform=platform-1',
                );
                await tester.pumpAndSettle();
              }
              final surface = find.descendant(
                of: find.byType(MiniPlayerBar),
                matching: find.byType(AppSkinSurface),
              );
              final rect = tester.getRect(surface);
              expect(rect.left, 12);
              expect(rect.right, 378);
              final navigation = find.byType(
                style == AppUiStyle.material ? NavigationBar : CupertinoTabBar,
              );
              if (page == 'detail' && style == AppUiStyle.material) {
                expect(navigation, findsNothing);
                expect(rect.bottom, 812);
              } else {
                expect(navigation, findsOneWidget);
                expect(rect.bottom, tester.getTopLeft(navigation).dy - 8);
              }
              expect(tester.takeException(), isNull);
              await _saveCupertinoPreview(
                tester,
                '$skinId-${style.name}-${brightness.name}-$page',
                directory: miniPlayerPreviewDirectory,
              );
              if (_previewLongList) {
                final list = page == 'home'
                    ? find.byType(CustomScrollView).first
                    : find.byType(ListView).first;
                expect(tester.getRect(list).bottom, 844);
                await tester.drag(list, const Offset(0, -320));
                await tester.pumpAndSettle();
                await _saveCupertinoPreview(
                  tester,
                  '$skinId-${style.name}-${brightness.name}-$page-scroll',
                  directory: miniPlayerPreviewDirectory,
                );
              }
            }
            await tester.pumpWidget(const SizedBox.shrink());
            router.dispose();
          }
        }
      }
    },
    skip: miniPlayerPreviewDirectory.isEmpty,
  );
  testWidgets('export themed bottom sheet previews', (tester) async {
    await tester.runAsync(() => _loadPreviewFonts(useSystemCjk: true));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    for (final skinId in [
      AppSkinRegistry.forestSanctuaryId,
      AppSkinRegistry.tidalSanctuaryId,
      AppSkinRegistry.starlitMelodyId,
      AppSkinRegistry.citySoundCreatorId,
    ]) {
      for (final style in AppUiStyle.values) {
        for (final brightness in Brightness.values) {
          final router = createAppRouter(AppRoutes.home);
          await tester.pumpWidget(
            _buildPreviewApp(
              router,
              brightness,
              skinId,
              uiStyle: style,
              localeCode: 'zh',
            ),
          );
          await tester.pumpAndSettle();
          await _pumpUntilWallpaperDecoded(tester);
          final context = router.routerDelegate.navigatorKey.currentContext!;
          final prefix = '$skinId-${style.name}-${brightness.name}';
          final menu = showSongActionsSheet(
            context: context,
            forceBottomSheet: true,
            coverUrl: null,
            title: '林间来信',
            subtitle: '山野集 · 午后漫游',
            duration: const Duration(minutes: 4, seconds: 32),
            hasMv: false,
            sourceLabel: '本地音乐',
            onPlay: () {},
            onPlayNext: () {},
            onAddToPlaylist: () {},
            onAddToUserPlaylist: () {},
            onDownload: () {},
            onCopySongName: () {},
            onCopySongId: () {},
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _saveCupertinoPreview(
            tester,
            '$prefix-menu',
            directory: '.artifacts/skin-sheets',
          );
          router.routerDelegate.navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          await menu;
          final selection = showAppThemedBottomSheet<SelectedUserPlaylist>(
            context: context,
            fitContent: true,
            isScrollControlled: true,
            heightFactor: 0.7,
            builder: (_) => ProviderScope(
              overrides: [
                myCreatedPlaylistsProvider.overrideWith(
                  (ref) async => [
                    for (var index = 0; index < 24; index++)
                      MyFavoriteItem(
                        id: 'preview-$index',
                        platform: 'user',
                        type: MyFavoriteType.playlists,
                        title: ['午后漫游', '山野来信', '雨声与旧唱片', '慢慢走回家'][index % 4],
                        subtitle: '${12 + index * 3} 首歌曲',
                        coverUrl: '',
                      ),
                  ],
                ),
              ],
              child: const SelectUserPlaylistSheet(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _saveCupertinoPreview(
            tester,
            '$prefix-playlists',
            directory: '.artifacts/skin-sheets',
          );
          router.routerDelegate.navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          await selection;
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      }
    }
  }, skip: true); // 仅显式导出真实弹窗预览，不更新既有首页基线。
  testWidgets('export wallpaper skin selection previews', (tester) async {
    await tester.runAsync(_loadPreviewFonts);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _previewSize;
    addTearDown(tester.view.reset);
    for (final skinId in [
      AppSkinRegistry.citySoundCreatorId,
      AppSkinRegistry.starlitMelodyId,
      AppSkinRegistry.forestSanctuaryId,
      AppSkinRegistry.tidalSanctuaryId,
    ]) {
      for (final brightness in Brightness.values) {
        final router = createAppRouter(AppRoutes.home);
        await tester.pumpWidget(_buildPreviewApp(router, brightness, skinId));
        await tester.pumpAndSettle();
        await _pumpUntilWallpaperDecoded(tester);
        expect(tester.takeException(), isNull);
        await _saveCupertinoPreview(
          tester,
          'preview_${brightness.name}',
          directory: 'assets/skins/$skinId',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    }
  }, skip: true); // 仅在显式 --run-skipped 导出时写入资源。
  for (final motionSkinId in [
    AppSkinRegistry.forestSanctuaryId,
    AppSkinRegistry.tidalSanctuaryId,
  ]) {
    final forest = motionSkinId == AppSkinRegistry.forestSanctuaryId;
    final motionPreviewDirectory = forest
        ? const String.fromEnvironment(
            'FOREST_MOTION_PREVIEW_DIR',
            defaultValue: '.artifacts/forest-sanctuary/motion',
          )
        : const String.fromEnvironment(
            'TIDAL_MOTION_PREVIEW_DIR',
            defaultValue: '.artifacts/tidal-sanctuary/motion',
          );
    testWidgets(
      'export ${forest ? 'forest' : 'tidal'} ambient motion',
      (tester) async {
        await tester.runAsync(() => _loadPreviewFonts(useSystemCjk: true));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        for (final brightness in Brightness.values) {
          final router = createAppRouter(AppRoutes.home);
          await tester.pumpWidget(
            _buildPreviewApp(
              router,
              brightness,
              motionSkinId,
              localeCode: 'zh',
              enableSkinAnimation: true,
            ),
          );
          await _pumpUntilWallpaperDecoded(tester);
          final riveFinder = find.byKey(const ValueKey('app-skin-rive-widget'));
          for (
            var attempt = 0;
            attempt < 150 && riveFinder.evaluate().isEmpty;
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(riveFinder, findsOneWidget);
          for (var frame = 0; frame < 240; frame++) {
            await tester.pump(const Duration(microseconds: 33333));
            expect(tester.takeException(), isNull);
            await _saveCupertinoPreview(
              tester,
              'frame-$frame',
              directory: brightness == Brightness.dark
                  ? motionPreviewDirectory
                  : '$motionPreviewDirectory-day',
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      },
      skip: forest
          ? !const bool.hasEnvironment('FOREST_MOTION_PREVIEW_DIR')
          : !const bool.hasEnvironment('TIDAL_MOTION_PREVIEW_DIR'),
    );
  }
  for (final sceneSkinId in [
    AppSkinRegistry.forestSanctuaryId,
    AppSkinRegistry.tidalSanctuaryId,
  ]) {
    const configuredSkin = String.fromEnvironment('SCENE_PREVIEW_SKIN');
    if (configuredSkin.isNotEmpty && configuredSkin != sceneSkinId) continue;
    final previewSkinId = sceneSkinId;
    const configuredDirectory = String.fromEnvironment(
      'SKIN_SCENE_PREVIEW_DIR',
    );
    final roomPreviewDirectory = configuredDirectory.isNotEmpty
        ? configuredDirectory
        : '.artifacts/${sceneSkinId.replaceAll('_', '-')}/previews';
    testWidgets(
      'export immersive skin scenes for $previewSkinId',
      (tester) async {
        await tester.runAsync(() => _loadPreviewFonts(useSystemCjk: true));
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final style in AppUiStyle.values) {
          for (final brightness in Brightness.values) {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            tester.view.viewPadding = const FakeViewPadding(
              top: 24,
              bottom: 24,
            );
            final router = createAppRouter(AppRoutes.home);
            await tester.pumpWidget(
              _buildPreviewApp(
                router,
                brightness,
                previewSkinId,
                uiStyle: style,
                localeCode: 'zh',
              ),
            );
            await tester.pumpAndSettle();
            await _pumpUntilWallpaperDecoded(tester);
            final prefix = '${style.name}-${brightness.name}';
            for (final page in ['home', 'playlist', 'settings']) {
              if (page == 'playlist') {
                router.push(
                  '${AppRoutes.recommendSongList}?id=preview&platform=platform-1',
                );
              } else if (page == 'settings') {
                router.push(AppRoutes.settingsSectionLocation('appearance'));
              }
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await _saveCupertinoPreview(
                tester,
                '$prefix-$page',
                directory: roomPreviewDirectory,
              );
            }
            // 重新挂载预览 scope，让主题与配置都使用开启内容底色的状态。
            await tester.pumpWidget(const SizedBox.shrink());
            router.dispose();
            final settingsRouter = createAppRouter(
              AppRoutes.settingsSectionLocation('appearance'),
            );
            await tester.pumpWidget(
              _buildPreviewApp(
                settingsRouter,
                brightness,
                previewSkinId,
                uiStyle: style,
                showContentBackground: true,
                localeCode: 'zh',
              ),
            );
            await tester.pumpAndSettle();
            await _pumpUntilWallpaperDecoded(tester);
            expect(tester.takeException(), isNull);
            await _saveCupertinoPreview(
              tester,
              '$prefix-settings-content',
              directory: roomPreviewDirectory,
            );
            await tester.pumpWidget(const SizedBox.shrink());
            settingsRouter.dispose();

            tester.view.physicalSize = const Size(320, 720);
            final largeTextRouter = createAppRouter(AppRoutes.home);
            await tester.pumpWidget(
              _buildPreviewApp(
                largeTextRouter,
                brightness,
                previewSkinId,
                uiStyle: style,
                localeCode: 'zh',
                previewTextScale: 2,
                showContentBackground: true,
              ),
            );
            await tester.pumpAndSettle();
            await _pumpUntilWallpaperDecoded(tester);
            for (final page in ['home', 'settings']) {
              if (page == 'settings') {
                largeTextRouter.push(
                  AppRoutes.settingsSectionLocation('appearance'),
                );
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull);
              await _saveCupertinoPreview(
                tester,
                '$prefix-$page-large-text',
                directory: roomPreviewDirectory,
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
            largeTextRouter.dispose();

            tester.view.physicalSize = const Size(1280, 800);
            tester.view.padding = FakeViewPadding.zero;
            tester.view.viewPadding = FakeViewPadding.zero;
            final wideRouter = createAppRouter(AppRoutes.home);
            await tester.pumpWidget(
              _buildPreviewApp(
                wideRouter,
                brightness,
                previewSkinId,
                uiStyle: style,
                localeCode: 'zh',
              ),
            );
            await tester.pumpAndSettle();
            await _pumpUntilWallpaperDecoded(tester);
            expect(tester.takeException(), isNull);
            await _saveCupertinoPreview(
              tester,
              '$prefix-home-wide',
              directory: roomPreviewDirectory,
            );
            await tester.pumpWidget(const SizedBox.shrink());
            wideRouter.dispose();
          }
        }
      },
      skip: !const bool.hasEnvironment('SKIN_SCENE_PREVIEW_DIR'),
    );
  }
  testWidgets(
    'wide home keeps bottom navigation and full width music',
    (tester) async {
      await tester.runAsync(_loadPreviewFonts);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      final router = createAppRouter(AppRoutes.home);
      await tester.pumpWidget(
        _buildPreviewApp(router, Brightness.light, AppSkinRegistry.classicId),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const ValueKey('desktop-queue')), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_previewKey),
        matchesGoldenFile('goldens/desktop_home.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    },
    skip: Platform.isLinux,
  );

  const previewCases =
      <
        ({String name, String skinId, String assetDirectory, bool hasWallpaper})
      >[
        (
          name: 'classic',
          skinId: AppSkinRegistry.classicId,
          assetDirectory: 'classic',
          hasWallpaper: false,
        ),
        (
          name: 'city sound creator',
          skinId: AppSkinRegistry.citySoundCreatorId,
          assetDirectory: 'city_sound_creator',
          hasWallpaper: true,
        ),
        (
          name: 'starlit melody',
          skinId: AppSkinRegistry.starlitMelodyId,
          assetDirectory: 'starlit_melody',
          hasWallpaper: true,
        ),
        (
          name: 'forest sanctuary',
          skinId: AppSkinRegistry.forestSanctuaryId,
          assetDirectory: 'forest_sanctuary',
          hasWallpaper: true,
        ),
        (
          name: 'tidal sanctuary',
          skinId: AppSkinRegistry.tidalSanctuaryId,
          assetDirectory: 'tidal_sanctuary',
          hasWallpaper: true,
        ),
      ];

  for (final previewCase in previewCases) {
    testWidgets(
      '${previewCase.name} previews match the real home scene',
      (tester) async {
        await tester.runAsync(_loadPreviewFonts);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = _previewSize;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        for (final brightness in Brightness.values) {
          final router = createAppRouter(AppRoutes.home);
          await tester.pumpWidget(
            _buildPreviewApp(router, brightness, previewCase.skinId),
          );
          await tester.pumpAndSettle();
          if (previewCase.hasWallpaper) {
            await _pumpUntilWallpaperDecoded(tester);
          }
          expect(find.text('推荐'), findsOneWidget);
          expect(find.text('浏览'), findsOneWidget);

          await expectLater(
            find.byKey(_previewKey),
            matchesGoldenFile(
              '../../../assets/skins/${previewCase.assetDirectory}/'
              'preview_${brightness.name}.png',
            ),
          );

          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      },
      skip: Platform.isLinux,
    );
    if (previewCase.hasWallpaper) {
      testWidgets('${previewCase.name} content surfaces render in both styles', (
        tester,
      ) async {
        await tester.runAsync(_loadPreviewFonts);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        for (final style in AppUiStyle.values) {
          for (final brightness in Brightness.values) {
            final router = createAppRouter(AppRoutes.home);
            await tester.pumpWidget(
              _buildPreviewApp(
                router,
                brightness,
                previewCase.skinId,
                uiStyle: style,
                showContentBackground: true,
              ),
            );
            await tester.pumpAndSettle();
            await _pumpUntilWallpaperDecoded(tester);
            expect(tester.takeException(), isNull);
            expect(find.byType(BackdropFilter), findsNWidgets(2));
            await _saveCupertinoPreview(
              tester,
              '${previewCase.skinId}-${style.name}-${brightness.name}-content',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            router.dispose();
          }
        }
      });
    }
    testWidgets(
      '${previewCase.name} Cupertino home and settings remain readable',
      (tester) async {
        await tester.runAsync(_loadPreviewFonts);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        for (final brightness in Brightness.values) {
          final router = createAppRouter(AppRoutes.home);
          await tester.pumpWidget(
            _buildPreviewApp(
              router,
              brightness,
              previewCase.skinId,
              uiStyle: AppUiStyle.cupertino,
            ),
          );
          await tester.pumpAndSettle();
          if (previewCase.hasWallpaper) {
            await _pumpUntilWallpaperDecoded(tester);
          }
          final bar = tester.getRect(find.byType(CupertinoTabBar));
          expect(bar.left, 0);
          expect(bar.right, 390);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is BackdropFilter && widget.enabled,
            ),
            previewCase.hasWallpaper ? findsNWidgets(2) : findsNothing,
          );
          await _saveCupertinoPreview(
            tester,
            '${previewCase.skinId}-${brightness.name}-home',
          );
          router.push(AppRoutes.settingsSectionLocation('appearance'));
          await tester.pumpAndSettle();
          expect(find.text('Appearance'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is BackdropFilter && widget.enabled,
            ),
            findsNothing,
          );
          await _saveCupertinoPreview(
            tester,
            '${previewCase.skinId}-${brightness.name}-settings',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      },
    );
  }
}

Future<void> _saveCupertinoPreview(
  WidgetTester tester,
  String name, {
  String? directory,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        '${directory ?? '${Directory.systemTemp.path}/he-music-cupertino-skin-previews'}/$name.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _pumpUntilWallpaperDecoded(WidgetTester tester) async {
  final wallpaperFinder = find.byKey(
    const ValueKey<String>('app-skin-wallpaper'),
  );
  const attempts = 150;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    // 图片解码运行在真实异步线程，完成后的帧仍需由测试绑定主动 pump。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (wallpaperFinder.evaluate().isEmpty) {
      continue;
    }
    final rawImageFinder = find.descendant(
      of: wallpaperFinder,
      matching: find.byType(RawImage),
    );
    if (rawImageFinder.evaluate().isNotEmpty &&
        tester.widget<RawImage>(rawImageFinder).image != null) {
      return;
    }
  }
  throw TestFailure('皮肤预览壁纸在 15 秒内未完成解码');
}

Widget _buildPreviewApp(
  GoRouter router,
  Brightness brightness,
  String skinId, {
  AppUiStyle uiStyle = AppUiStyle.material,
  bool showContentBackground = false,
  String? localeCode,
  bool enableSkinAnimation = false,
  double previewTextScale = 1,
}) {
  final skin = AppSkinRegistry.builtIn(
    AppConfigState.initial.themeAccent,
  ).resolve(skinId);
  final baseTheme = brightness == Brightness.light
      ? AppTheme.light(
          skin,
          uiStyle: uiStyle,
          showContentBackground: showContentBackground,
        )
      : AppTheme.dark(
          skin,
          uiStyle: uiStyle,
          showContentBackground: showContentBackground,
        );
  final textTheme = baseTheme.textTheme.apply(
    fontFamily: _previewFontFamily,
    fontFamilyFallback: _previewFontFallback,
  );
  final navigationLabelTextStyle = baseTheme.navigationBarTheme.labelTextStyle;
  final theme = baseTheme.copyWith(
    platform: TargetPlatform.android,
    textTheme: textTheme,
    appBarTheme: localeCode == null
        ? baseTheme.appBarTheme
        : baseTheme.appBarTheme.copyWith(
            titleTextStyle: baseTheme.appBarTheme.titleTextStyle?.copyWith(
              fontFamily: _previewFontFamily,
              fontFamilyFallback: _previewFontFallback,
            ),
          ),
    cupertinoOverrideTheme: uiStyle == AppUiStyle.cupertino
        ? CupertinoThemeData(
            brightness: brightness,
            primaryColor: baseTheme.colorScheme.primary,
            primaryContrastingColor: baseTheme.colorScheme.onPrimary,
            barBackgroundColor:
                baseTheme.cupertinoOverrideTheme!.barBackgroundColor,
            scaffoldBackgroundColor: baseTheme.scaffoldBackgroundColor,
            textTheme: CupertinoTextThemeData(
              primaryColor: baseTheme.colorScheme.primary,
              textStyle: textTheme.bodyMedium!,
              actionTextStyle: textTheme.bodyLarge!.copyWith(
                color: baseTheme.colorScheme.primary,
              ),
              navTitleTextStyle: textTheme.titleLarge!,
              navLargeTitleTextStyle: textTheme.headlineLarge!,
              tabLabelTextStyle: textTheme.bodySmall!.copyWith(fontSize: 10),
            ),
          )
        : baseTheme.cupertinoOverrideTheme,
    primaryTextTheme: baseTheme.primaryTextTheme.apply(
      fontFamily: _previewFontFamily,
      fontFamilyFallback: _previewFontFallback,
    ),
    navigationBarTheme: baseTheme.navigationBarTheme.copyWith(
      labelTextStyle: navigationLabelTextStyle == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => navigationLabelTextStyle
                  .resolve(states)
                  ?.copyWith(
                    fontFamily: _previewFontFamily,
                    fontFamilyFallback: _previewFontFallback,
                  ),
            ),
    ),
  );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _PreviewAppConfigController(
          brightness,
          skinId,
          uiStyle,
          showContentBackground,
          localeCode,
          enableSkinAnimation,
        ),
      ),
      appRouterProvider.overrideWithValue(router),
      playerControllerProvider.overrideWith(_PreviewPlayerController.new),
      homePageControllerProvider.overrideWith(_PreviewHomePageController.new),
      recommendSongListControllerProvider.overrideWith2(
        (_) => _PreviewRecommendSongListController(),
      ),
      onlinePlatformsProvider.overrideWith(
        _PreviewOnlinePlatformsController.new,
      ),
      searchDefaultPlaceholderProvider.overrideWith(
        _PreviewSearchPlaceholderController.new,
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: Locale(
        localeCode ?? (uiStyle == AppUiStyle.cupertino ? 'en' : 'zh'),
      ),
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(previewTextScale)),
        child: RepaintBoundary(
          key: _previewKey,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AppSkinBackgroundLayer(
                skin: skin,
                enableAnimation: enableSkinAnimation,
              ),
              child ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _loadPreviewFonts({bool useSystemCjk = false}) async {
  final textLoader = FontLoader(_previewFontFamily)
    ..addFont(_fontData('test/assets/fonts/Roboto-Regular.ttf'))
    ..addFont(_fontData('test/assets/fonts/Roboto-Medium.ttf'))
    ..addFont(_fontData('test/assets/fonts/Roboto-Bold.ttf'));
  // 显式导出可使用本机完整中文字库；常规 golden 固定使用仓库字体。
  final systemCjk = File('/System/Library/Fonts/STHeiti Light.ttc');
  final cjkPath =
      useSystemCjk &&
          !const bool.hasEnvironment('MINI_PLAYER_PREVIEW_CJK_FONT') &&
          systemCjk.existsSync()
      ? systemCjk.path
      : _previewCjkFontPath;
  final cjkLoader = FontLoader(_previewCjkFontFamily)
    ..addFont(_fontData(cjkPath));
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait(<Future<void>>[
    textLoader.load(),
    cjkLoader.load(),
    iconLoader.load(),
    (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load(),
  ]);
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

class _PreviewAppConfigController extends AppConfigController {
  _PreviewAppConfigController(
    this.brightness,
    this.skinId,
    this.uiStyle,
    this.showContentBackground,
    this.localeCode,
    this.enableSkinAnimation,
  );

  final Brightness brightness;
  final String skinId;
  final AppUiStyle uiStyle;
  final bool showContentBackground;
  final String? localeCode;
  final bool enableSkinAnimation;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      themeMode: brightness == Brightness.light
          ? AppThemeMode.light
          : AppThemeMode.dark,
      skinId: skinId,
      uiStyle: uiStyle,
      showContentBackground: showContentBackground,
      enableSkinAnimation: enableSkinAnimation,
      // The bundled CJK subset covers the home fixture, not all settings labels.
      localeCode: localeCode ?? (uiStyle == AppUiStyle.cupertino ? 'en' : 'zh'),
    );
  }
}

class _PreviewPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'preview-track',
        title: '城市回声',
        artist: '林诺',
        album: '信号房间',
        platform: 'platform-1',
      ),
    ]).copyWith(
      isPlaying: true,
      position: const Duration(minutes: 1, seconds: 24),
      duration: const Duration(minutes: 3, seconds: 48),
    );
  }

  @override
  Future<void> initialize() async {}
}

class _PreviewRecommendSongListController extends RecommendSongListController {
  @override
  RecommendSongListState build() => RecommendSongListState(
    loading: false,
    info: RecommendSongListInfo(
      id: 'preview',
      title: '新歌速递',
      cover: '',
      description: '城市回声',
      songs: _previewSongs(),
    ),
  );

  @override
  Future<void> initialize(RecommendSongListRequest request) async {}
}

class _PreviewHomePageController extends HomePageController {
  @override
  HomePageState build() {
    return HomePageState(
      platforms: <OnlinePlatform>[
        OnlinePlatform(
          id: 'platform-1',
          name: '平台1',
          shortName: '平台1',
          status: 1,
          featureSupportFlag: _previewHomePageFeatures,
        ),
        OnlinePlatform(
          id: 'platform-2',
          name: '平台2',
          shortName: '平台2',
          status: 1,
          featureSupportFlag: _previewHomePageFeatures,
        ),
      ],
      selectedPage: HomePageKind.recommend,
      recommend: HomeContentState(
        initialized: true,
        loading: false,
        refreshing: false,
        loadingMore: false,
        selectedPlatformId: 'platform-1',
        hasMore: false,
        nextPageIndex: 2,
        sections: <HomePageSection>[
          HomePageSection(
            sectionTypeCode: 2,
            sectionType: HomeSectionType.newSongs,
            resourceType: HomeResourceType.song,
            title: '新歌速递',
            songs: _previewSongs(),
          ),
        ],
      ),
      discover: HomeContentState.initial,
    );
  }

  @override
  Future<void> initialize() async {}
}

class _PreviewOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'platform-1',
        name: '平台1',
        shortName: '平台1',
        status: 1,
        featureSupportFlag: _previewHomePageFeatures,
      ),
      OnlinePlatform(
        id: 'platform-2',
        name: '平台2',
        shortName: '平台2',
        status: 1,
        featureSupportFlag: _previewHomePageFeatures,
      ),
    ];
  }
}

class _PreviewSearchPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState();
  }
}

List<SongInfo> _previewSongs() {
  const tracks = [
    ('城市回声', '林诺', '信号房间'),
    ('玻璃天台', '周河', '城市碎片'),
    ('低频大厅', '森', '凌晨之后'),
  ];
  return List.generate(_previewLongList ? 24 : 3, (index) {
    final track = tracks[index % tracks.length];
    return _song('track-${index + 1}', track.$1, track.$2, track.$3);
  });
}

SongInfo _song(String id, String title, String artist, String album) {
  return SongInfo(
    name: title,
    subtitle: artist,
    id: id,
    duration: 228,
    mvId: '',
    album: SongInfoAlbumInfo(name: album, id: 'album-$id'),
    artists: <SongInfoArtistInfo>[
      SongInfoArtistInfo(name: artist, id: 'artist-$id'),
    ],
    links: const <LinkInfo>[],
    platform: 'platform-1',
    cover: '',
  );
}

import 'dart:io';

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
import 'package:he_music_flutter/features/home/domain/entities/home_discover_item.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_platform.dart';
import 'package:he_music_flutter/features/home/presentation/controllers/home_discover_controller.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_discover_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

const _previewSize = Size(360, 640);
const _previewKey = ValueKey<String>('skin-preview-golden-root');
const _previewFontFamily = 'PreviewRoboto';
const _previewCjkFontFamily = 'PreviewCjk';
const _previewFontFallback = <String>[_previewCjkFontFamily];

// 预览基准图在 macOS 生成；Linux 渲染存在稳定像素差异，不做逐像素比较。
void main() {
  testWidgets(
    'city sound creator previews match the real home scene',
    (tester) async {
      await tester.runAsync(_loadPreviewFonts);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _previewSize;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final brightness in Brightness.values) {
        final router = createAppRouter(AppRoutes.home);
        await tester.pumpWidget(_buildPreviewApp(router, brightness));
        await tester.pumpAndSettle();
        await _pumpUntilWallpaperDecoded(tester);

        await expectLater(
          find.byKey(_previewKey),
          matchesGoldenFile(
            '../../../assets/skins/city_sound_creator/'
            'preview_${brightness.name}.png',
          ),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    },
    skip: Platform.isLinux,
  );
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

Widget _buildPreviewApp(GoRouter router, Brightness brightness) {
  final skin = AppSkinRegistry.builtIn(
    AppConfigState.initial.themeAccent,
  ).resolve(AppSkinRegistry.citySoundCreatorId);
  final baseTheme = brightness == Brightness.light
      ? AppTheme.light(skin)
      : AppTheme.dark(skin);
  final textTheme = baseTheme.textTheme.apply(
    fontFamily: _previewFontFamily,
    fontFamilyFallback: _previewFontFallback,
  );
  final navigationLabelTextStyle = baseTheme.navigationBarTheme.labelTextStyle;
  final theme = baseTheme.copyWith(
    platform: TargetPlatform.android,
    textTheme: textTheme,
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
        () => _PreviewAppConfigController(brightness),
      ),
      appRouterProvider.overrideWithValue(router),
      playerControllerProvider.overrideWith(_PreviewPlayerController.new),
      homeDiscoverControllerProvider.overrideWith(
        _PreviewHomeDiscoverController.new,
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
      locale: const Locale('zh'),
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => RepaintBoundary(
        key: _previewKey,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AppSkinBackgroundLayer(skin: skin, enableAnimation: false),
            child ?? const SizedBox.shrink(),
          ],
        ),
      ),
    ),
  );
}

Future<void> _loadPreviewFonts() async {
  final textLoader = FontLoader(_previewFontFamily)
    ..addFont(_fontData('test/assets/fonts/Roboto-Regular.ttf'))
    ..addFont(_fontData('test/assets/fonts/Roboto-Medium.ttf'))
    ..addFont(_fontData('test/assets/fonts/Roboto-Bold.ttf'));
  final cjkLoader = FontLoader(_previewCjkFontFamily)
    ..addFont(
      _fontData('test/assets/fonts/DroidSansFallback-PreviewSubset.ttf'),
    );
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait(<Future<void>>[
    textLoader.load(),
    cjkLoader.load(),
    iconLoader.load(),
  ]);
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

class _PreviewAppConfigController extends AppConfigController {
  _PreviewAppConfigController(this.brightness);

  final Brightness brightness;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      themeMode: brightness == Brightness.light
          ? AppThemeMode.light
          : AppThemeMode.dark,
      skinId: AppSkinRegistry.citySoundCreatorId,
      enableSkinAnimation: false,
      localeCode: 'zh',
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

class _PreviewHomeDiscoverController extends HomeDiscoverController {
  @override
  HomeDiscoverState build() {
    return HomeDiscoverState(
      loading: false,
      platforms: <HomePlatform>[
        HomePlatform(
          id: 'platform-1',
          name: '平台1',
          shortName: '平台1',
          status: 1,
          featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
        ),
        HomePlatform(
          id: 'platform-2',
          name: '平台2',
          shortName: '平台2',
          status: 1,
          featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
        ),
      ],
      selectedPlatformId: 'platform-1',
      sections: <HomeDiscoverSection>[
        HomeDiscoverSection(
          key: 'new-song',
          titleKey: 'home.section.new_song',
          type: HomeDiscoverItemType.song,
          songs: <SongInfo>[
            _song('track-1', '城市回声', '林诺', '信号房间'),
            _song('track-2', '玻璃天台', '周河', '城市碎片'),
            _song('track-3', '低频大厅', '森', '凌晨之后'),
          ],
        ),
      ],
    );
  }
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
        featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
      ),
      OnlinePlatform(
        id: 'platform-2',
        name: '平台2',
        shortName: '平台2',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
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
    sublist: const <SongInfo>[],
    originalType: 0,
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/app/config/app_custom_skin_config.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/skins/custom_image_skin.dart';
import 'package:he_music_flutter/shared/widgets/song_info_list_section.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_content.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_page_chunk.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_request.dart';
import 'package:he_music_flutter/features/artist/domain/repositories/artist_detail_repository.dart';
import 'package:he_music_flutter/features/artist/presentation/pages/artist_detail_page.dart';
import 'package:he_music_flutter/features/artist/presentation/providers/artist_detail_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/detail_loading_skeleton.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('artist image controls blend and remain usable in $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _cacheArtistPhoto(tester);
      await tester.pumpWidget(_buildGlassArtistApp(brightness: brightness));
      await tester.runAsync(
        () => precacheImage(
          AssetImage(
            'assets/skins/city_sound_creator/wallpaper_${brightness.name}.png',
          ),
          tester.element(find.byKey(_artistPreviewKey)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassTabBar), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
      final expandedTint = tester
          .widget<GlassTabBar>(find.byType(GlassTabBar))
          .settings!
          .backerColor!
          .a;
      expect(expandedTint, inExclusiveRange(0, 1));
      await _saveArtistPreview(tester, '${brightness.name}-expanded');
      final songs = tester.widget<SongInfoListSection>(
        find.byType(SongInfoListSection),
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      final pinnedTint = tester
          .widget<GlassTabBar>(find.byType(GlassTabBar))
          .settings!
          .backerColor!
          .a;
      expect(pinnedTint, greaterThan(expandedTint));
      expect(pinnedTint, lessThan(1));
      expect(
        tester
            .widget<GlassContainer>(find.byType(GlassContainer))
            .settings!
            .backerColor!
            .a,
        pinnedTint,
      );
      expect(
        identical(
          songs,
          tester.widget<SongInfoListSection>(find.byType(SongInfoListSection)),
        ),
        isTrue,
      );
      await _saveArtistPreview(tester, '${brightness.name}-pinned');

      await tester.tap(find.text('专辑').hitTestable().first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
        1,
      );
      expect(find.text('暂无专辑'), findsOneWidget);
      await tester.drag(find.byType(TabBarView), const Offset(350, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
        0,
      );
      tester
          .state<NestedScrollViewState>(find.byType(NestedScrollView))
          .outerController
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('批量操作'));
      await tester.pumpAndSettle();
      expect(find.text('已选 0 首'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final highContrast in [false, true]) {
    testWidgets(
      'artist controls keep opaque fallback, contrast=$highContrast',
      (tester) async {
        await tester.pumpWidget(
          _buildGlassArtistApp(
            highContrast: highContrast,
            glassEnabled: highContrast,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GlassTabBar), findsNothing);
        expect(find.byType(GlassContainer), findsNothing);
        for (final target in [find.byType(TabBar), find.text('全部播放 20')]) {
          final materials = tester.widgetList<Material>(
            find.ancestor(of: target, matching: find.byType(Material)),
          );
          expect(materials.any((material) => material.color?.a == 1), isTrue);
        }
        await tester.tap(find.text('专辑'));
        await tester.pumpAndSettle();
        expect(find.text('暂无专辑'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [2.0, 3.2]) {
    testWidgets('artist detail metadata fits narrow screens at scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(
              () => _TestAppConfigController(localeCode: 'zh'),
            ),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            artistDetailRepositoryProvider.overrideWithValue(
              _TestArtistDetailRepository(),
            ),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: _buildTestApp(
            localeCode: 'zh',
            textScaler: TextScaler.linear(scale),
            child: const ArtistDetailPage(
              id: 'artist-1',
              platform: 'qq',
              title: 'Artist',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('artist-detail-expanded-title')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'artist detail albums tab shows english no more text for en locale',
    (tester) async {
      final repository = _PagedArtistDetailRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(
              () => _TestAppConfigController(localeCode: 'en'),
            ),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            artistDetailRepositoryProvider.overrideWithValue(repository),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: _buildTestApp(
            localeCode: 'en',
            child: const ArtistDetailPage(
              id: 'artist-1',
              platform: 'qq',
              title: 'Artist',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Albums'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      repository.completeSecondAlbumPage();
      await tester.pump();

      expect(find.text('No more'), findsOneWidget);
    },
  );

  testWidgets('artist detail reuses songs from detail payload on first paint', (
    tester,
  ) async {
    final repository = _TestArtistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          artistDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: _buildTestApp(
          localeCode: 'zh',
          child: const ArtistDetailPage(
            id: 'artist-1',
            platform: 'qq',
            title: '测试歌手',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.fetchDetailCallCount, 1);
    expect(repository.fetchSongsCallCount, 0);
    expect(find.text('首屏歌曲'), findsOneWidget);
  });

  testWidgets(
    'artist detail tabs load before transition and avoid empty flash',
    (tester) async {
      final repository = _PendingTabArtistDetailRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            artistDetailRepositoryProvider.overrideWithValue(repository),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: _buildTestApp(
            localeCode: 'zh',
            child: const ArtistDetailPage(
              id: 'artist-1',
              platform: 'qq',
              title: '测试歌手',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('专辑'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.fetchAlbumsPageCallCount, 1);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ArtistAlbumsLoadingView), findsOneWidget);
      expect(find.text('暂无专辑'), findsNothing);

      repository.completeAlbumsPage();
      await tester.pumpAndSettle();
      expect(find.byType(ArtistAlbumsLoadingView), findsNothing);

      await tester.tap(find.text('视频'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.fetchVideosPageCallCount, 1);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ArtistVideosLoadingView), findsOneWidget);
      expect(find.text('暂无视频'), findsNothing);

      repository.completeVideosPage();
      await tester.pumpAndSettle();
      expect(find.byType(ArtistVideosLoadingView), findsNothing);
    },
  );

  testWidgets(
    'artist detail does not reload tabs whose first result is empty',
    (tester) async {
      final repository = _EmptyTabArtistDetailRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            artistDetailRepositoryProvider.overrideWithValue(repository),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: _buildTestApp(
            localeCode: 'zh',
            child: const ArtistDetailPage(
              id: 'artist-1',
              platform: 'qq',
              title: '测试歌手',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.fetchSongsCallCount, 1);

      await tester.tap(find.text('专辑'));
      await tester.pumpAndSettle();
      expect(repository.fetchAlbumsPageCallCount, 1);

      await tester.tap(find.text('视频'));
      await tester.pumpAndSettle();
      expect(repository.fetchVideosPageCallCount, 1);

      await tester.tap(find.text('歌曲'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('专辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('视频'));
      await tester.pumpAndSettle();

      expect(repository.fetchSongsCallCount, 1);
      expect(repository.fetchAlbumsPageCallCount, 1);
      expect(repository.fetchVideosPageCallCount, 1);
    },
  );

  testWidgets('artist albums tab shows first page before later pages finish', (
    tester,
  ) async {
    final repository = _PagedArtistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          artistDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: _buildTestApp(
          localeCode: 'zh',
          child: const ArtistDetailPage(
            id: 'artist-1',
            platform: 'qq',
            title: '测试歌手',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('专辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('第一页专辑'), findsOneWidget);
    expect(find.text('第二页专辑'), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);

    repository.completeSecondAlbumPage();
    await tester.pump();

    expect(find.text('第二页专辑'), findsOneWidget);
  });

  testWidgets(
    'artist detail favorite action uses white icon theme when expanded',
    (tester) async {
      const themeIconColor = Colors.teal;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            artistDetailRepositoryProvider.overrideWithValue(
              _TestArtistDetailRepository(),
            ),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: _buildTestApp(
            localeCode: 'zh',
            theme: ThemeData(
              iconTheme: const IconThemeData(color: themeIconColor),
            ),
            child: const ArtistDetailPage(
              id: 'artist-1',
              platform: 'qq',
              title: '测试歌手',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final iconElement = tester.element(
        find.byIcon(Icons.favorite_border_rounded).first,
      );
      expect(IconTheme.of(iconElement).color, Colors.white);
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-expanded-title'),
        ),
        1,
      );
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-collapsed-title'),
        ),
        0,
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await tester.pump();

      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-expanded-title'),
        ),
        0,
      );
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-collapsed-title'),
        ),
        greaterThan(0),
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
      await tester.pumpAndSettle();

      final overlayStyle = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byWidgetPredicate(
              (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
            ),
          )
          .last
          .value;
      expect(overlayStyle.statusBarIconBrightness, Brightness.dark);
      expect(overlayStyle.statusBarBrightness, Brightness.light);
    },
  );

  testWidgets('artist songs batch mode clears when leaving songs tab', (
    tester,
  ) async {
    final repository = _TestArtistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          artistDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: _buildTestApp(
          localeCode: 'zh',
          child: const ArtistDetailPage(
            id: 'artist-1',
            platform: 'qq',
            title: '测试歌手',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('批量操作'));
    await tester.pump();
    await tester.tap(find.text('首屏歌曲'));
    await tester.pump();

    expect(find.text('已选 1 首'), findsOneWidget);

    await tester.tap(find.text('专辑'));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 首'), findsNothing);
  });
}

const _artistPreviewKey = ValueKey<String>('artist-controls-preview');
const _artistPhotoUrl = 'https://example.test/artist-controls.png';

Future<ByteData> _artistFontData(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

Future<void> _cacheArtistPhoto(WidgetTester tester) async {
  await tester.runAsync(() async {
    if (const bool.fromEnvironment('GENERATE_ARTIST_PREVIEWS')) {
      final text = FontLoader('ArtistPreview')
        ..addFont(_artistFontData('test/assets/fonts/Roboto-Regular.ttf'))
        ..addFont(_artistFontData('test/assets/fonts/Roboto-Medium.ttf'));
      final cjk = FontLoader('ArtistPreviewCjk')
        ..addFont(
          _artistFontData(
            Platform.isMacOS
                ? '/System/Library/Fonts/STHeiti Light.ttc'
                : 'test/assets/fonts/DroidSansFallback-PreviewSubset.ttf',
          ),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await Future.wait([text.load(), cjk.load(), icons.load()]);
    }
    final bytes = await File(
      'test/assets/player/artist_photo.png',
    ).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    PaintingBinding.instance.imageCache.putIfAbsent(
      const NetworkImage(_artistPhotoUrl),
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: frame.image)),
      ),
    );
  });
  addTearDown(() => PaintingBinding.instance.imageCache.clear());
}

Future<void> _saveArtistPreview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('GENERATE_ARTIST_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_artistPreviewKey),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final output = File('build/artist_detail_previews/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Widget _buildGlassArtistApp({
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  bool glassEnabled = true,
}) {
  final skin = customImageSkin(
    AppCustomSkinConfig(
      revision: 'artist-controls',
      lightAssetPath: 'skins/custom_image/artist-controls/wallpaper_light.png',
      darkAssetPath: 'skins/custom_image/artist-controls/wallpaper_dark.png',
      candidateColors: const [0xFF007C91],
      seedColor: 0xFF007C91,
      focalX: 0,
      focalY: 0,
      sourceWidth: 390,
      sourceHeight: 844,
    ),
  );
  final theme = brightness == Brightness.light
      ? AppTheme.light(skin)
      : AppTheme.dark(skin);
  final previewTheme = const bool.fromEnvironment('GENERATE_ARTIST_PREVIEWS')
      ? theme.copyWith(
          textTheme: theme.textTheme.apply(
            fontFamily: 'ArtistPreview',
            fontFamilyFallback: const ['ArtistPreviewCjk'],
          ),
        )
      : theme;
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      artistDetailRepositoryProvider.overrideWithValue(
        _GlassArtistDetailRepository(),
      ),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
    ],
    child: _buildTestApp(
      localeCode: 'zh',
      theme: previewTheme,
      child: AppGlassScope(
        enabled: glassEnabled,
        mode: glassEnabled ? AppGlassMode.low : AppGlassMode.off,
        child: GlassAdaptiveScope(
          minQuality: GlassQuality.minimal,
          maxQuality: GlassQuality.minimal,
          initialQuality: GlassQuality.minimal,
          child: MediaQuery(
            data: MediaQueryData(
              highContrast: highContrast,
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: _artistPreviewKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/skins/city_sound_creator/wallpaper_${brightness.name}.png',
                    fit: BoxFit.cover,
                  ),
                  const ArtistDetailPage(
                    id: 'artist-1',
                    platform: 'qq',
                    title: '梁静茹',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GlassArtistDetailRepository extends _TestArtistDetailRepository {
  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    return ArtistDetailContent(
      info: const ArtistInfo(
        id: 'artist-1',
        name: '梁静茹',
        cover: _artistPhotoUrl,
        platform: 'qq',
        description: '广告里这样诉说：告诉你一段感情故事，听梁静茹。',
        mvCount: '189',
        songCount: '20',
        albumCount: '39',
        alias: 'Fish Leong',
      ),
      songs: List.generate(
        20,
        (index) => SongInfo(
          name: '${['情歌', '暖暖', '勇气', '宁夏', '会呼吸的痛'][index % 5]} ${index + 1}',
          subtitle: '',
          id: 'song-$index',
          duration: 240,
          mvId: '',
          album: const SongInfoAlbumInfo(name: '情歌', id: 'album-1'),
          artists: const [SongInfoArtistInfo(id: 'artist-1', name: '梁静茹')],
          links: const [],
          platform: 'qq',
          cover: '',
        ),
      ),
    );
  }
}

double _nearestOpacity(WidgetTester tester, Key key) {
  final element = tester.element(find.byKey(key));
  double? opacity;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Opacity) {
      opacity = widget.opacity;
      return false;
    }
    return true;
  });
  return opacity!;
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({this.localeCode = 'zh'});

  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: localeCode);
  }
}

Widget _buildTestApp({
  required String localeCode,
  required Widget child,
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    locale: Locale(localeCode),
    supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: theme,
    home: child,
  );
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}

class _TestArtistDetailRepository implements ArtistDetailRepository {
  int fetchDetailCallCount = 0;
  int fetchSongsCallCount = 0;

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    fetchDetailCallCount += 1;
    return ArtistDetailContent(
      info: const ArtistInfo(
        id: 'artist-1',
        name: '测试歌手',
        cover: '',
        platform: 'qq',
        description: 'desc',
        mvCount: '1',
        songCount: '1',
        albumCount: '0',
        alias: '',
      ),
      songs: const <SongInfo>[
        SongInfo(
          name: '首屏歌曲',
          subtitle: '',
          id: 'song-1',
          duration: 240,
          mvId: '',
          album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
        ),
      ],
    );
  }

  @override
  Future<List<AlbumInfo>> fetchAlbums(ArtistDetailRequest request) async {
    return const <AlbumInfo>[];
  }

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    return const ArtistDetailPageChunk<AlbumInfo>(
      items: <AlbumInfo>[],
      hasMore: false,
      nextPageIndex: 2,
    );
  }

  @override
  Future<List<SongInfo>> fetchSongs(ArtistDetailRequest request) async {
    fetchSongsCallCount += 1;
    return const <SongInfo>[];
  }

  @override
  Future<ArtistDetailPageChunk<SongInfo>> fetchSongsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    fetchSongsCallCount += 1;
    return const ArtistDetailPageChunk<SongInfo>(
      items: <SongInfo>[],
      hasMore: false,
      nextPageIndex: 2,
    );
  }

  @override
  Future<List<MvInfo>> fetchVideos(ArtistDetailRequest request) async {
    return const <MvInfo>[];
  }

  @override
  Future<ArtistDetailPageChunk<MvInfo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    return const ArtistDetailPageChunk<MvInfo>(
      items: <MvInfo>[],
      hasMore: false,
      nextPageIndex: 2,
    );
  }
}

class _PendingTabArtistDetailRepository extends _TestArtistDetailRepository {
  final Completer<ArtistDetailPageChunk<AlbumInfo>> _albumsPageCompleter =
      Completer<ArtistDetailPageChunk<AlbumInfo>>();
  final Completer<ArtistDetailPageChunk<MvInfo>> _videosPageCompleter =
      Completer<ArtistDetailPageChunk<MvInfo>>();

  int fetchAlbumsPageCallCount = 0;
  int fetchVideosPageCallCount = 0;

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) {
    fetchAlbumsPageCallCount += 1;
    return _albumsPageCompleter.future;
  }

  @override
  Future<ArtistDetailPageChunk<MvInfo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) {
    fetchVideosPageCallCount += 1;
    return _videosPageCompleter.future;
  }

  void completeAlbumsPage() {
    _albumsPageCompleter.complete(
      const ArtistDetailPageChunk<AlbumInfo>(
        items: <AlbumInfo>[],
        hasMore: false,
        nextPageIndex: 2,
      ),
    );
  }

  void completeVideosPage() {
    _videosPageCompleter.complete(
      const ArtistDetailPageChunk<MvInfo>(
        items: <MvInfo>[],
        hasMore: false,
        nextPageIndex: 2,
      ),
    );
  }
}

class _EmptyTabArtistDetailRepository extends _TestArtistDetailRepository {
  int fetchAlbumsPageCallCount = 0;
  int fetchVideosPageCallCount = 0;

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    return ArtistDetailContent(
      info: const ArtistInfo(
        id: 'artist-1',
        name: '测试歌手',
        cover: '',
        platform: 'qq',
        description: 'desc',
        mvCount: '0',
        songCount: '0',
        albumCount: '0',
        alias: '',
      ),
      songs: const <SongInfo>[],
    );
  }

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    fetchAlbumsPageCallCount += 1;
    return super.fetchAlbumsPage(request, pageIndex: pageIndex);
  }

  @override
  Future<ArtistDetailPageChunk<MvInfo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    fetchVideosPageCallCount += 1;
    return super.fetchVideosPage(request, pageIndex: pageIndex);
  }
}

class _PagedArtistDetailRepository extends _TestArtistDetailRepository {
  final Completer<ArtistDetailPageChunk<AlbumInfo>> _secondAlbumPageCompleter =
      Completer<ArtistDetailPageChunk<AlbumInfo>>();

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    return ArtistDetailContent(
      info: const ArtistInfo(
        id: 'artist-1',
        name: '测试歌手',
        cover: '',
        platform: 'qq',
        description: 'desc',
        mvCount: '1',
        songCount: '1',
        albumCount: '2',
        alias: '',
      ),
      songs: const <SongInfo>[
        SongInfo(
          name: '首屏歌曲',
          subtitle: '',
          id: 'song-1',
          duration: 240,
          mvId: '',
          album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
        ),
      ],
    );
  }

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    if (pageIndex == 1) {
      return ArtistDetailPageChunk<AlbumInfo>(
        items: <AlbumInfo>[_buildAlbum(id: 'album-1', name: '第一页专辑')],
        hasMore: true,
        nextPageIndex: 2,
      );
    }
    return _secondAlbumPageCompleter.future;
  }

  void completeSecondAlbumPage() {
    if (_secondAlbumPageCompleter.isCompleted) {
      return;
    }
    _secondAlbumPageCompleter.complete(
      ArtistDetailPageChunk<AlbumInfo>(
        items: <AlbumInfo>[_buildAlbum(id: 'album-2', name: '第二页专辑')],
        hasMore: false,
        nextPageIndex: 3,
      ),
    );
  }

  AlbumInfo _buildAlbum({required String id, required String name}) {
    return AlbumInfo(
      name: name,
      id: id,
      cover: '',
      artists: const <SongInfoArtistInfo>[
        SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
      ],
      songCount: '10',
      publishTime: '2024-01-01',
      songs: const <SongInfo>[],
      description: '',
      platform: 'qq',
      language: '',
      genre: '',
      type: 0,
      isFinished: true,
      playCount: '0',
    );
  }
}

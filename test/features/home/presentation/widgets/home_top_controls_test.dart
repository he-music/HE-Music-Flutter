import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_result.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_state.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/discover_home_tab.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/home_search_field.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

const _previewKey = ValueKey('home-top-preview');
const _platformBarKey = ValueKey('home-platform-chips');

void main() {
  setUpAll(() async {
    final textLoader = FontLoader('HomePreview')
      ..addFont(
        File(
          'test/assets/fonts/Roboto-Regular.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final cupertinoIcons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await Future.wait([textLoader.load(), icons.load(), cupertinoIcons.load()]);
  });
  for (final style in AppUiStyle.values) {
    for (final brightness in Brightness.values) {
      for (final layout in [
        (width: 320.0, scale: 2.0),
        (width: 390.0, scale: 1.0),
        (width: 1024.0, scale: 1.0),
      ]) {
        testWidgets('$style $brightness home top fits $layout', (tester) async {
          tester.view.physicalSize = Size(layout.width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final harness = _HomeHarness(
            style: style,
            brightness: brightness,
            textScale: layout.scale,
          );
          addTearDown(harness.dispose);
          await tester.pumpWidget(harness.build());
          await tester.pumpAndSettle();

          final search = find.byType(HomeSearchField);
          expect(tester.getTopLeft(search).dx, 12);
          expect(tester.getSize(search).height, greaterThanOrEqualTo(48));
          final link = find.byTooltip('Parse Link');
          expect(tester.getSize(link).height, tester.getSize(search).height);
          if (style == AppUiStyle.cupertino) {
            final segments = find.byType(
              CupertinoSlidingSegmentedControl<HomePageKind>,
            );
            expect(segments, findsOneWidget);
            expect(tester.getSize(segments).height, greaterThanOrEqualTo(44));
            if (layout.scale == 1) {
              expect(tester.getSize(segments).height, lessThanOrEqualTo(44));
              expect(tester.getSize(segments).width, 240);
            }
            expect(find.byType(FilterChip), findsNothing);
          } else {
            expect(find.byType(TabBar), findsOneWidget);
            expect(find.byType(FilterChip), findsNWidgets(6));
          }
          final firstPlatform = _platform('Source 1');
          expect(
            tester.getSize(_platformButton(firstPlatform, style)).height,
            greaterThanOrEqualTo(style == AppUiStyle.cupertino ? 44 : 48),
          );
          expect(tester.takeException(), isNull);
          await _capturePreview(
            tester,
            '${style.name}_${brightness.name}_recommend',
            layout.width,
            layout.scale,
          );

          // Every platform remains reachable when the row is wider than the page.
          final lastPlatform = _platform('Source 6');
          await tester.ensureVisible(lastPlatform);
          await tester.pumpAndSettle();
          await tester.tap(lastPlatform);
          await tester.pumpAndSettle();
          expect(harness.state.recommend.selectedPlatformId, '6');
          await tester.ensureVisible(find.text('Browse'));
          await tester.tap(find.text('Browse'));
          await tester.pumpAndSettle();
          expect(harness.state.selectedPage, HomePageKind.discover);
          expect(harness.state.discover.selectedPlatformId, '6');
          expect(
            tester.getBottomLeft(find.text('Ranking')).dy,
            lessThan(tester.getTopLeft(_platform('Source 1')).dy),
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(_platform('Source 6'));
          await tester.pumpAndSettle();
          await _capturePreview(
            tester,
            '${style.name}_${brightness.name}_browse',
            layout.width,
            layout.scale,
          );
        });
      }
    }

    testWidgets(
      '$style tabs, swipe and style changes retain page and platform caches',
      (tester) async {
        tester.view.physicalSize = const Size(390, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = _HomeHarness(style: style);
        addTearDown(harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        final pageController = tester
            .widget<PageView>(find.byType(PageView))
            .controller;
        final navigator = tester.state(find.byType(Navigator).first);
        expect(harness.api.calls, ['recommend|1']);

        await tester.tap(_platform('Source 2'));
        await tester.pumpAndSettle();
        await tester.tap(_platform('Source 2'));
        await tester.pumpAndSettle();
        expect(harness.api.calls, ['recommend|1', 'recommend|2']);
        expect(harness.state.discover.selectedPlatformId, isNull);

        await tester.tap(find.text('Browse'));
        await tester.pumpAndSettle();
        expect(harness.api.calls.last, 'discover|2');
        await tester.tap(_platform('Source 1'));
        await tester.pumpAndSettle();
        expect(harness.state.recommend.selectedPlatformId, '2');
        final callsBeforeStyleChange = List<String>.of(harness.api.calls);
        final browseScroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView).last)
            .controller;
        browseScroll!.jumpTo(30);
        await tester.pumpAndSettle();
        harness.style.value = style == AppUiStyle.material
            ? AppUiStyle.cupertino
            : AppUiStyle.material;
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller,
          same(pageController),
        );
        expect(tester.state(find.byType(Navigator).first), same(navigator));
        expect(pageController!.page, 1);
        expect(browseScroll.offset, 30);
        expect(harness.state.discover.selectedPlatformId, '1');
        expect(harness.api.calls, callsBeforeStyleChange);

        await tester.dragFrom(
          tester.getBottomLeft(find.byType(PageView)) + const Offset(20, -20),
          const Offset(350, 0),
        );
        await tester.pumpAndSettle();
        expect(harness.state.selectedPage, HomePageKind.recommend);
        expect(harness.state.recommend.selectedPlatformId, '1');
        expect(harness.api.calls, callsBeforeStyleChange);
        await tester.tap(_platform('Source 2'));
        await tester.pumpAndSettle();
        expect(harness.state.recommend.selectedPlatformId, '2');
        expect(harness.api.calls, callsBeforeStyleChange);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$style reduced motion switches pages without animation', (
      tester,
    ) async {
      final harness = _HomeHarness(style: style, disableAnimations: true);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse'));
      await tester.pump();
      expect(harness.state.selectedPage, HomePageKind.discover);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      if (style == AppUiStyle.material) {
        expect(
          tester
              .widget<TabBar>(find.byType(TabBar))
              .controller!
              .indexIsChanging,
          isFalse,
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('$style search and link retain their route actions', (
      tester,
    ) async {
      final harness = _HomeHarness(style: style);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await tester.tap(_platform('Source 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(HomeSearchField));
      await tester.pumpAndSettle();
      expect(find.text('search platform=2'), findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Parse Link'));
      await tester.pumpAndSettle();
      expect(find.text('parse link'), findsOneWidget);
      expect(harness.api.calls, ['recommend|1', 'recommend|2']);
      expect(tester.takeException(), isNull);
    });
  }
}

Finder _platform(String label) => find.descendant(
  of: find.byKey(_platformBarKey),
  matching: find.text(label),
);

Finder _platformButton(Finder label, AppUiStyle style) => find.ancestor(
  of: label,
  matching: find.byType(
    style == AppUiStyle.cupertino ? CupertinoButton : FilterChip,
  ),
);

Future<void> _capturePreview(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  if (!const bool.fromEnvironment('GENERATE_HOME_TOP_PREVIEWS') ||
      width != 390 ||
      scale != 1) {
    return;
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory(
      '/tmp/he-home-top-previews',
    ).create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _HomeHarness {
  _HomeHarness({
    required AppUiStyle style,
    this.brightness = Brightness.light,
    this.textScale = 1,
    this.disableAnimations = false,
  }) : style = ValueNotifier(style);

  final ValueNotifier<AppUiStyle> style;
  final Brightness brightness;
  final double textScale;
  final bool disableAnimations;
  final api = _HomeApi();
  final containerKey = GlobalKey();
  late final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: RepaintBoundary(
            key: _previewKey,
            child: DiscoverHomeTab(key: containerKey),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.onlineSearch,
        builder: (context, state) => Scaffold(
          body: Text(
            'search platform=${state.uri.queryParameters['platform']}',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.parseSourceUrl,
        builder: (context, state) => const Scaffold(body: Text('parse link')),
      ),
    ],
  );

  HomePageState get state => ProviderScope.containerOf(
    containerKey.currentContext!,
  ).read(homePageControllerProvider);

  Widget build() {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.appleBlue,
    ).resolve('classic');
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWith(_Config.new),
        playerControllerProvider.overrideWith(_Player.new),
        onlinePlatformsProvider.overrideWith(_Platforms.new),
        homePageApiClientProvider.overrideWithValue(api),
        searchDefaultPlaceholderProvider.overrideWith(_Placeholder.new),
      ],
      child: ValueListenableBuilder<AppUiStyle>(
        valueListenable: style,
        builder: (context, value, child) {
          final baseTheme = brightness == Brightness.light
              ? AppTheme.light(skin, uiStyle: value)
              : AppTheme.dark(skin, uiStyle: value);
          return MaterialApp.router(
            routerConfig: router,
            theme: baseTheme.copyWith(
              textTheme: baseTheme.textTheme.apply(fontFamily: 'HomePreview'),
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: disableAnimations,
              ),
              child: AppUiStyleScope(style: value, child: child!),
            ),
          );
        },
      ),
    );
  }

  void dispose() {
    router.dispose();
    style.dispose();
    api.dio.close();
  }
}

class _HomeApi extends HomePageApiClient {
  factory _HomeApi() => _HomeApi._(Dio());
  _HomeApi._(this.dio) : super(dio);
  final Dio dio;
  final calls = <String>[];

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) async {
    calls.add('recommend|$platformId');
    return const HomePageResult(sections: [], hasMore: false);
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) async {
    calls.add('discover|$platformId');
    return const HomePageResult(sections: [], hasMore: false);
  }
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'en');
}

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() =>
      PlayerPlaybackState.initial(const <PlayerTrack>[]);
  @override
  Future<void> initialize() async {}
}

class _Platforms extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async => [
    for (var id = 1; id <= 6; id++)
      OnlinePlatform(
        id: '$id',
        name: 'Source $id',
        shortName: 'Source $id',
        status: 1,
        featureSupportFlag:
            PlatformFeatureSupportFlag.getRecommendPage |
            PlatformFeatureSupportFlag.getDiscoverPage,
      ),
  ];

  @override
  Future<List<OnlinePlatform>> ensureLoaded({bool forceRefresh = false}) =>
      future;
}

class _Placeholder extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() =>
      const SearchDefaultPlaceholderState();
}

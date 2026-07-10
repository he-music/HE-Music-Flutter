import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/video/playback/providers/video_playback_surface_provider.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_playback_surface.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_surface_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_content.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_link.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_request.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_feed_state.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_plaza_page_result.dart';
import 'package:he_music_flutter/features/video/domain/repositories/video_detail_repository.dart';
import 'package:he_music_flutter/features/video/presentation/controllers/video_feed_controller.dart';
import 'package:he_music_flutter/features/video/presentation/pages/video_detail_page.dart';
import 'package:he_music_flutter/features/video/presentation/providers/video_detail_providers.dart';
import 'package:he_music_flutter/features/video/presentation/providers/video_feed_providers.dart';
import 'package:he_music_flutter/features/video/presentation/providers/video_plaza_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  testWidgets('video detail uses light status bar icons', (tester) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        factory: _FakeVideoPlaybackSurfaceFactory(),
      ),
    );

    final overlayStyle = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .single
        .value;
    expect(overlayStyle.statusBarIconBrightness, Brightness.light);
    expect(overlayStyle.statusBarBrightness, Brightness.dark);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  testWidgets('video detail progress drag delegates seekTo to session', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    expect(factory.sessions, hasLength(1));

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);

    await tester.drag(slider, const Offset(200, 0));
    await tester.pump();

    expect(factory.sessions.single.seekTargets, isNotEmpty);
  });

  testWidgets('video detail progress listens to replacement session', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(
        id: 'mv-1',
        url: 'https://example.com/mv-1080.mp4',
        links: const <VideoDetailLink>[
          LinkInfo(
            name: '1080p',
            quality: 1080,
            format: 'mp4',
            size: '2MB',
            url: 'https://example.com/mv-1080.mp4',
          ),
          LinkInfo(
            name: '720p',
            quality: 720,
            format: 'mp4',
            size: '1MB',
            url: 'https://example.com/mv-720.mp4',
          ),
        ],
      ),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    expect(factory.sessions, hasLength(1));

    await tester.tap(find.byIcon(Icons.high_quality_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('720P'));
    await tester.pumpAndSettle();

    expect(factory.sessions, hasLength(2));

    factory.sessions.last.setState(
      factory.sessions.last.state.copyWith(
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 2),
      ),
    );
    await tester.pump();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, closeTo(0.25, 0.001));
  });

  testWidgets('video detail preloads next feed item after first load', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      details: <String, VideoDetailContent>{
        'mv-1': _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
        'mv-2': _buildDetail(id: 'mv-2', url: 'https://example.com/mv-2.mp4'),
      },
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        factory: factory,
        feedControllerFactory: () => _TestVideoFeedController(
          initialVideos: <MvInfo>[
            _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4').info,
            _buildDetail(id: 'mv-2', url: 'https://example.com/mv-2.mp4').info,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(factory.sessions, hasLength(2));
    expect(factory.sessions[0].state.isPlaying, isTrue);
    expect(factory.sessions[1].state.isPlaying, isFalse);
  });

  testWidgets(
    'video detail pauses previous session and plays next session on page change',
    (tester) async {
      final repository = _FakeVideoDetailRepository(
        details: <String, VideoDetailContent>{
          'mv-1': _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
          'mv-2': _buildDetail(id: 'mv-2', url: 'https://example.com/mv-2.mp4'),
        },
      );
      final factory = _FakeVideoPlaybackSurfaceFactory();

      await tester.pumpWidget(
        _buildTestApp(
          repository: repository,
          factory: factory,
          feedPlatforms: <OnlinePlatform>[_feedSupportedPlatform],
          feedControllerFactory: () => _TestVideoFeedController(
            initialVideos: <MvInfo>[
              _buildDetail(
                id: 'mv-1',
                url: 'https://example.com/mv-1.mp4',
              ).info,
              MvInfo(
                platform: 'qq',
                links: const <LinkInfo>[],
                id: 'mv-2',
                name: '测试-mv-2',
                cover: '',
                type: 0,
                playCount: '20',
                creator: '测试作者2',
                duration: 150,
                description: '',
              ),
            ],
          ),
          feedApiClient: _FakeVideoFeedApiClient(
            videos: <MvInfo>[
              MvInfo(
                platform: 'qq',
                links: const <LinkInfo>[],
                id: 'mv-2',
                name: '测试-mv-2',
                cover: '',
                type: 0,
                playCount: '20',
                creator: '测试作者2',
                duration: 150,
                description: '',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(factory.sessions, hasLength(greaterThanOrEqualTo(1)));
      final firstSession = factory.sessions.first;

      await tester.fling(
        find.byKey(const ValueKey<String>('video-detail-page-view')),
        const Offset(0, -500),
        1000,
      );
      await tester.pumpAndSettle();

      expect(factory.sessions, hasLength(greaterThanOrEqualTo(2)));
      expect(firstSession.pauseCallCount, greaterThan(0));
      expect(factory.sessions[1].state.isPlaying, isTrue);
    },
  );

  testWidgets('video detail shows error when created session reports error', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory(
      createErroredSession: true,
    );

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('video detail hides cover poster after first frame', (
    tester,
  ) async {
    final firstFrame = Completer<void>();
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(
        id: 'mv-1',
        url: 'https://example.com/mv-1.mp4',
        cover: 'https://example.com/cover.jpg',
      ),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory(
      firstFrame: firstFrame.future,
    );

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('video-detail-cover')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('video-detail-cover'))),
      const Size(800, 450),
    );

    firstFrame.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey<String>('video-detail-cover')),
      findsNothing,
    );
  });

  testWidgets('fullscreen action delegates to media-kit fullscreen', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    expect(
      factory.sessions.single.lastControls,
      VideoSurfaceControls.materialFullscreenOnly,
    );

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pumpAndSettle();

    expect(factory.sessions.single.enterFullscreenCallCount, 1);
    expect(
      factory.sessions.single.lastControls,
      VideoSurfaceControls.materialFullscreenOnly,
    );
  });

  testWidgets('video view rebuilds when session state changes', (tester) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('fake-video:${16 / 9}'), findsOneWidget);

    factory.sessions.single.setState(
      factory.sessions.single.state.copyWith(aspectRatio: 4 / 3),
    );
    await tester.pump();

    expect(find.text('fake-video:${4 / 3}'), findsOneWidget);
  });

  testWidgets('media-kit fullscreen keeps page state unchanged', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      details: <String, VideoDetailContent>{
        'mv-1': _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
        'mv-2': _buildDetail(id: 'mv-2', url: 'https://example.com/mv-2.mp4'),
      },
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        factory: factory,
        feedPlatforms: <OnlinePlatform>[_feedSupportedPlatform],
        feedControllerFactory: () => _TestVideoFeedController(
          initialVideos: <MvInfo>[
            _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4').info,
            _buildDetail(id: 'mv-2', url: 'https://example.com/mv-2.mp4').info,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final initialSessionCount = factory.sessions.length;
    final currentSession = factory.sessions.first;

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pumpAndSettle();

    expect(factory.sessions.first.enterFullscreenCallCount, 1);
    expect(
      factory.sessions.first.lastControls,
      VideoSurfaceControls.materialFullscreenOnly,
    );
    expect(
      find.byKey(
        const ValueKey<String>('video-detail-fullscreen-brightness-zone'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('video-detail-fullscreen-volume-zone')),
      findsNothing,
    );

    expect(factory.sessions, hasLength(initialSessionCount));
    expect(currentSession.pauseCallCount, 0);
    expect(currentSession.playCallCount, 0);
  });

  testWidgets('fullscreen waits for pending page playback switch', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      details: <String, VideoDetailContent>{
        'mv-1': _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
        'mv-2': _buildDetail(id: 'mv-2', url: 'https://example.com/mv-2.mp4'),
      },
    );
    final operationGate = Completer<void>();
    final factory = _FakeVideoPlaybackSurfaceFactory(
      operationGate: operationGate,
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        factory: factory,
        feedPlatforms: <OnlinePlatform>[_feedSupportedPlatform],
        feedControllerFactory: () => _TestVideoFeedController(
          initialVideos: <MvInfo>[
            _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4').info,
            _buildDetail(id: 'mv-2', url: 'https://example.com/mv-2.mp4').info,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final firstSession = factory.sessions[0];

    await tester.fling(
      find.byKey(const ValueKey<String>('video-detail-page-view')),
      const Offset(0, -500),
      1000,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pump();

    expect(
      factory.sessions[1].lastControls,
      VideoSurfaceControls.materialFullscreenOnly,
    );

    operationGate.complete();
    await tester.pumpAndSettle();

    expect(firstSession.state.isPlaying, isFalse);
    expect(factory.sessions[1].state.isPlaying, isTrue);
    expect(factory.sessions[1].enterFullscreenCallCount, 1);
    expect(
      factory.sessions[1].lastControls,
      VideoSurfaceControls.materialFullscreenOnly,
    );
  });

  testWidgets('fullscreen uses media-kit route instead of custom hud', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pumpAndSettle();

    expect(factory.sessions.single.enterFullscreenCallCount, 1);
    expect(
      factory.sessions.single.lastControls,
      VideoSurfaceControls.materialFullscreenOnly,
    );
    expect(
      find.byKey(const ValueKey<String>('video-detail-gesture-hud')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('video-detail-fullscreen-volume-zone')),
      findsNothing,
    );
  });

  testWidgets('fullscreen material controls show exit button and title', (
    tester,
  ) async {
    const title = '一首标题很长但不能溢出的测试 MV';
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(
        id: 'mv-1',
        url: 'https://example.com/mv-1.mp4',
        title: title,
      ),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();

    await tester.pumpWidget(
      _buildTestApp(repository: repository, factory: factory),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pumpAndSettle();

    expect(factory.sessions.single.enterFullscreenCallCount, 1);
    expect(
      factory.sessions.single.lastControls,
      VideoSurfaceControls.materialFullscreenOnly,
    );
    final topButtonBar =
        factory.sessions.single.lastMaterialTheme?.topButtonBar;
    expect(topButtonBar, isNotNull);
    expect(
      topButtonBar,
      contains(
        isA<Builder>().having(
          (builder) => builder.builder,
          'builder',
          isNotNull,
        ),
      ),
    );
    expect(
      topButtonBar,
      contains(
        isA<Expanded>().having(
          (expanded) => expanded.child,
          'child',
          isA<Text>().having((text) => text.data, 'data', title),
        ),
      ),
    );

    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
  });

  testWidgets('back button returns to video plaza instead of home', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final router = _buildVideoBackRouter();

    await tester.pumpWidget(
      _buildRouterTestApp(
        repository: repository,
        factory: factory,
        router: router,
      ),
    );

    expect(find.text('video plaza page'), findsOneWidget);

    await tester.tap(find.text('video plaza page'));
    await tester.pumpAndSettle();

    expect(find.byType(VideoDetailPage), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('video-detail-back-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('video plaza page'), findsOneWidget);
    expect(find.text('home page'), findsNothing);
  });

  testWidgets('system back returns to video plaza instead of home', (
    tester,
  ) async {
    final repository = _FakeVideoDetailRepository(
      detail: _buildDetail(id: 'mv-1', url: 'https://example.com/mv-1.mp4'),
    );
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final router = _buildVideoBackRouter();

    await tester.pumpWidget(
      _buildRouterTestApp(
        repository: repository,
        factory: factory,
        router: router,
      ),
    );

    await tester.tap(find.text('video plaza page'));
    await tester.pumpAndSettle();

    expect(find.byType(VideoDetailPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('video plaza page'), findsOneWidget);
    expect(find.text('home page'), findsNothing);
  });

  testWidgets('app router system back keeps video detail push stack', (
    tester,
  ) async {
    final detail = _buildDetail(
      id: 'mv-1',
      url: 'https://example.com/mv-1.mp4',
    );
    final repository = _FakeVideoDetailRepository(detail: detail);
    final factory = _FakeVideoPlaybackSurfaceFactory();
    GoRouter? router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          onlinePlatformsProvider.overrideWith(
            () => _TestOnlinePlatformsController(<OnlinePlatform>[
              _feedSupportedPlatform,
            ]),
          ),
          videoDetailRepositoryProvider.overrideWithValue(repository),
          videoPlaybackSurfaceFactoryProvider.overrideWithValue(factory),
          videoPlazaApiClientProvider.overrideWithValue(
            _FakeVideoPlazaApiClient(videos: <MvInfo>[detail.info]),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    router!.push(AppRoutes.videoPlaza);
    await tester.pumpAndSettle();

    expect(find.byType(VideoDetailPage), findsNothing);

    router!.push(
      Uri(
        path: AppRoutes.videoDetail,
        queryParameters: <String, String>{
          'id': detail.info.id,
          'platform': detail.info.platform,
          'title': detail.info.name,
        },
      ).toString(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VideoDetailPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(VideoDetailPage), findsNothing);
    expect(router!.state.uri.path, AppRoutes.videoPlaza);
    expect(find.text('首页'), findsNothing);
  });
}

Widget _buildTestApp({
  required VideoDetailRepository repository,
  required VideoPlaybackSurfaceFactory factory,
  List<OnlinePlatform>? feedPlatforms,
  VideoPlazaApiClient? feedApiClient,
  VideoFeedController Function()? feedControllerFactory,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlinePlatformsProvider.overrideWith(
        () => _TestOnlinePlatformsController(feedPlatforms ?? const []),
      ),
      videoDetailRepositoryProvider.overrideWithValue(repository),
      if (feedApiClient != null)
        videoFeedApiClientProvider.overrideWithValue(feedApiClient),
      if (feedControllerFactory != null)
        videoFeedControllerProvider.overrideWith(feedControllerFactory),
      videoPlaybackSurfaceFactoryProvider.overrideWithValue(factory),
    ],
    child: const MaterialApp(
      home: VideoDetailPage(id: 'mv-1', platform: 'qq', title: '测试 MV'),
    ),
  );
}

Widget _buildRouterTestApp({
  required VideoDetailRepository repository,
  required VideoPlaybackSurfaceFactory factory,
  required GoRouter router,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlinePlatformsProvider.overrideWith(
        () => _TestOnlinePlatformsController(const []),
      ),
      videoDetailRepositoryProvider.overrideWithValue(repository),
      videoPlaybackSurfaceFactoryProvider.overrideWithValue(factory),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

GoRouter _buildVideoBackRouter() {
  return GoRouter(
    initialLocation: AppRoutes.videoPlaza,
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const Text('home page')),
      GoRoute(
        path: AppRoutes.videoPlaza,
        builder: (context, _) => TextButton(
          onPressed: () => context.push(
            Uri(
              path: AppRoutes.videoDetail,
              queryParameters: const <String, String>{
                'id': 'mv-1',
                'platform': 'qq',
                'title': '测试 MV',
              },
            ).toString(),
          ),
          child: const Text('video plaza page'),
        ),
      ),
      GoRoute(
        path: AppRoutes.videoDetail,
        builder: (_, state) => VideoDetailPage(
          id: state.uri.queryParameters['id']!,
          platform: state.uri.queryParameters['platform']!,
          title: state.uri.queryParameters['title']!,
        ),
      ),
    ],
  );
}

final _feedSupportedPlatform = OnlinePlatform(
  id: 'qq',
  name: 'QQ音乐',
  shortName: 'QQ',
  status: 1,
  featureSupportFlag:
      PlatformFeatureSupportFlag.getMvInfo |
      PlatformFeatureSupportFlag.getMvUrl |
      PlatformFeatureSupportFlag.listMVFeeds,
);

VideoDetailContent _buildDetail({
  required String id,
  required String url,
  String cover = '',
  String? title,
  List<VideoDetailLink>? links,
}) {
  return VideoDetailContent(
    info: MvInfo(
      platform: 'qq',
      links: const <LinkInfo>[],
      id: id,
      name: title ?? '测试-$id',
      cover: cover,
      type: 0,
      playCount: '10',
      creator: '测试作者',
      duration: 120,
      description: '',
    ),
    links:
        links ??
        <VideoDetailLink>[
          LinkInfo(
            name: '720p',
            quality: 720,
            format: 'mp4',
            size: '1MB',
            url: url,
          ),
        ],
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      apiBaseUrl: 'https://api.example.com',
      authToken: 'token',
    );
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  @override
  Future<void> initialize() async {}
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  _TestOnlinePlatformsController(this._platforms);

  final List<OnlinePlatform> _platforms;

  @override
  Future<List<OnlinePlatform>> build() async {
    return _platforms;
  }
}

class _TestVideoFeedController extends VideoFeedController {
  _TestVideoFeedController({required this.initialVideos});

  final List<MvInfo> initialVideos;

  @override
  VideoFeedState build() {
    return VideoFeedState.initial.copyWith(videos: initialVideos);
  }

  @override
  void setInitialVideo(MvInfo video) {
    state = state.copyWith(
      videos: <MvInfo>[
        video,
        ...initialVideos.where((item) => item.id != video.id),
      ],
      currentIndex: 0,
    );
  }
}

class _FakeVideoDetailRepository implements VideoDetailRepository {
  _FakeVideoDetailRepository({
    VideoDetailContent? detail,
    Map<String, VideoDetailContent>? details,
  }) : _details = details ?? <String, VideoDetailContent>{detail!.id: detail};

  final Map<String, VideoDetailContent> _details;

  @override
  Future<VideoDetailContent> fetchDetail(VideoDetailRequest request) async {
    final detail = _details[request.id];
    if (detail == null) {
      throw StateError('missing detail: ${request.id}');
    }
    if (request.id == 'mv-1' && _details.length > 1) {
      return detail;
    }
    return detail;
  }
}

class _FakeVideoPlaybackSurfaceFactory implements VideoPlaybackSurfaceFactory {
  _FakeVideoPlaybackSurfaceFactory({
    this.createErroredSession = false,
    this.operationGate,
    Future<void>? firstFrame,
  }) : firstFrame = firstFrame ?? Future<void>.value();

  final bool createErroredSession;
  final Completer<void>? operationGate;
  final Future<void> firstFrame;
  final List<_FakeVideoPlaybackSurface> sessions =
      <_FakeVideoPlaybackSurface>[];

  @override
  Future<VideoPlaybackSurface> create({
    required Uri uri,
    bool autoplay = true,
    Duration? initialPosition,
  }) async {
    final session = _FakeVideoPlaybackSurface(
      firstFrame: firstFrame,
      operationGate: operationGate,
      state: VideoSurfaceState.initial.copyWith(
        isInitialized: !createErroredSession,
        isPlaying: autoplay,
        duration: const Duration(minutes: 2),
        hasError: createErroredSession,
      ),
    );
    sessions.add(session);
    if (initialPosition != null) {
      await session.seekTo(initialPosition);
    }
    return session;
  }
}

class _FakeVideoPlaybackSurface extends ChangeNotifier
    implements VideoPlaybackSurface {
  _FakeVideoPlaybackSurface({
    required this.firstFrame,
    this.operationGate,
    required VideoSurfaceState state,
  }) : _state = state;

  final Future<void> firstFrame;
  final Completer<void>? operationGate;
  VideoSurfaceState _state;
  int playCallCount = 0;
  int pauseCallCount = 0;
  VideoSurfaceControls lastControls = VideoSurfaceControls.none;
  MaterialVideoControlsThemeData? lastMaterialTheme;
  final List<Duration> seekTargets = <Duration>[];
  int enterFullscreenCallCount = 0;
  int exitFullscreenCallCount = 0;

  @override
  VideoSurfaceState get state => _state;

  void setState(VideoSurfaceState state) {
    _state = state;
    notifyListeners();
  }

  @override
  Future<void> get waitUntilFirstFrameRendered => firstFrame;

  @override
  Widget buildView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    VideoSurfaceControls controls = VideoSurfaceControls.none,
    MaterialVideoControlsThemeData? materialControlsTheme,
    MaterialDesktopVideoControlsThemeData? materialDesktopControlsTheme,
  }) {
    lastControls = controls;
    lastMaterialTheme = materialControlsTheme;
    return Stack(
      key: key,
      children: <Widget>[Text('fake-video:${_state.aspectRatio}')],
    );
  }

  @override
  Future<void> pause() async {
    await operationGate?.future;
    pauseCallCount += 1;
    _state = _state.copyWith(isPlaying: false);
    notifyListeners();
  }

  @override
  Future<void> play() async {
    await operationGate?.future;
    playCallCount += 1;
    _state = _state.copyWith(isPlaying: true);
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration position) async {
    seekTargets.add(position);
    _state = _state.copyWith(position: position);
    notifyListeners();
  }

  @override
  Future<void> setVolume(double volume) async {
    _state = _state.copyWith(volume: volume);
    notifyListeners();
  }

  @override
  Future<void> enterFullscreen() async {
    enterFullscreenCallCount += 1;
  }

  @override
  Future<void> exitFullscreen() async {
    exitFullscreenCallCount += 1;
  }

  @override
  Future<void> disposeSurface() async {}
}

class _FakeVideoFeedApiClient extends VideoPlazaApiClient {
  _FakeVideoFeedApiClient({required this.videos}) : super(Dio());

  final List<MvInfo> videos;

  @override
  Future<VideoPlazaPageResult> fetchMvFeed({
    required String id,
    required String platform,
    int pageIndex = 1,
  }) async {
    return VideoPlazaPageResult(list: videos, hasMore: false);
  }
}

class _FakeVideoPlazaApiClient extends VideoPlazaApiClient {
  _FakeVideoPlazaApiClient({required this.videos}) : super(Dio());

  final List<MvInfo> videos;

  @override
  Future<List<FilterInfo>> fetchFilters({required String platform}) async {
    return const <FilterInfo>[];
  }

  @override
  Future<VideoPlazaPageResult> fetchVideos({
    required String platform,
    required Map<String, String> filters,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    return VideoPlazaPageResult(list: videos, hasMore: false);
  }
}

class _TestFavoriteSongStatusController extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return const FavoriteSongStatusState(songKeys: <String>{}, ready: true);
  }
}

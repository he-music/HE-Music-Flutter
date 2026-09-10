import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/helpers/player_artwork_helper.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('mini cover bounds decode for memory, file and network artwork', () {
    final bytes = Uint8List.fromList([1]);
    for (final source in <(String?, Uint8List?, Type)>[
      (null, bytes, MemoryImage),
      ('/tmp/mini-cover.png', null, FileImage),
      ('https://example.com/mini-cover.png', null, CachedNetworkImageProvider),
    ]) {
      final image =
          miniPlayerArtworkProvider(
                source.$1,
                source.$2,
                devicePixelRatio: 2.75,
              )!
              as ResizeImage;
      expect(image.width, 127);
      expect(image.height, 127);
      expect(image.policy, ResizeImagePolicy.fit);
      expect(image.imageProvider.runtimeType, source.$3);
    }
    expect(miniPlayerArtworkProvider(null, null, devicePixelRatio: 3), isNull);
  });

  testWidgets('mini cover actually decodes large artwork at physical size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
      final picture = recorder.endRecording();
      final original = await picture.toImage(512, 512);
      final data = await original.toByteData(format: ui.ImageByteFormat.png);
      original.dispose();
      picture.dispose();
      final provider = miniPlayerArtworkProvider(
        null,
        data!.buffer.asUint8List(),
        devicePixelRatio: 3,
      )!;
      final decoded = Completer<ImageInfo>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, _) => decoded.complete(image),
      );
      stream.addListener(listener);
      final image = await decoded.future;
      expect(image.image.width, 138);
      expect(image.image.height, 138);
      stream.removeListener(listener);
      image.dispose();
      await provider.evict();
    });
  });

  testWidgets(
    'mini cover follows DPR and prewarms only adjacent thumbnails once',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _TestArtworkMiniPlayerController();
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      addTearDown(cache.clear);
      addTearDown(cache.clearLiveImages);
      await tester.pumpWidget(
        _buildMiniPlayerTestApp(controllerFactory: () => controller),
      );
      final keys = <Object>[];
      for (final track in controller.tracks) {
        keys.add(
          await miniPlayerArtworkProvider(
            null,
            track.artworkBytes,
            devicePixelRatio: 3,
          )!.obtainKey(ImageConfiguration.empty),
        );
      }
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).width, 138);
      expect((image.image as ResizeImage).height, 138);
      expect(cache.containsKey(keys[1]), isFalse);
      expect(cache.containsKey(keys[3]), isFalse);
      await tester.pump(const Duration(milliseconds: 220));
      // Previous and next are warmed serially; no whole-queue speculation.
      expect(cache.containsKey(keys[3]), isTrue);
      await tester.runAsync(() async {
        await precacheImage(image.image, tester.element(find.byType(Image)));
        await precacheImage(
          miniPlayerArtworkProvider(
            null,
            controller.tracks[3].artworkBytes,
            devicePixelRatio: 3,
          )!,
          tester.element(find.byType(Image)),
        );
      });
      await tester.pump(const Duration(milliseconds: 220));
      expect(cache.containsKey(keys[1]), isTrue);
      expect(cache.containsKey(keys[2]), isFalse);
      await tester.runAsync(() async {
        await precacheImage(
          miniPlayerArtworkProvider(
            null,
            controller.tracks[1].artworkBytes,
            devicePixelRatio: 3,
          )!,
          tester.element(find.byType(Image)),
        );
      });
      cache.evict(keys[1]);
      cache.evict(keys[3]);
      controller.updatePlayback();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(cache.containsKey(keys[1]), isFalse);
      expect(cache.containsKey(keys[3]), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mini prewarm waits until ballistic scrolling finishes', (
    tester,
  ) async {
    final controller = _TestArtworkMiniPlayerController();
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    addTearDown(cache.clear);
    addTearDown(cache.clearLiveImages);
    await tester.pumpWidget(
      _buildMiniPlayerTestApp(controllerFactory: () => controller),
    );
    final key = await miniPlayerArtworkProvider(
      null,
      controller.tracks[3].artworkBytes,
      devicePixelRatio: tester.view.devicePixelRatio,
    )!.obtainKey(ImageConfiguration.empty);
    final pageController = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    unawaited(
      pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.linear,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(cache.containsKey(key), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(cache.containsKey(key), isFalse);
    await tester.pump(const Duration(milliseconds: 220));
    expect(cache.containsKey(key), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mini thumbnail prewarm waits for held pointer and cancels on dispose',
    (tester) async {
      final controller = _TestArtworkMiniPlayerController();
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      addTearDown(cache.clear);
      addTearDown(cache.clearLiveImages);
      await tester.pumpWidget(
        _buildMiniPlayerTestApp(controllerFactory: () => controller),
      );
      final key = await miniPlayerArtworkProvider(
        null,
        controller.tracks[3].artworkBytes,
        devicePixelRatio: tester.view.devicePixelRatio,
      )!.obtainKey(ImageConfiguration.empty);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(cache.containsKey(key), isFalse);
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(cache.containsKey(key), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mini player hides queue entry in radio mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: _TestRadioMiniPlayerController.new,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
  });

  testWidgets('mini player shows radio icon in radio mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: _TestRadioMiniPlayerController.new,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.radio_rounded), findsOneWidget);
  });

  testWidgets('mini player ignores progress but rebuilds for track changes', (
    tester,
  ) async {
    late _TestMiniPlayerController controller;
    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: () {
          controller = _TestMiniPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final initialPageView = tester.widget<PageView>(find.byType(PageView));
    controller.updateDuration(const Duration(minutes: 3));
    await tester.pump();

    expect(
      tester.widget<PageView>(find.byType(PageView)),
      same(initialPageView),
    );

    controller.updatePosition(const Duration(seconds: 30));
    await tester.pump();

    expect(
      tester.widget<PageView>(find.byType(PageView)),
      same(initialPageView),
    );

    controller.replaceCurrentTrack(
      const PlayerTrack(id: 'song-2', title: '新歌曲', artist: '新歌手'),
    );
    await tester.pump();

    expect(
      tester.widget<PageView>(find.byType(PageView)),
      isNot(same(initialPageView)),
    );
    expect(find.text('新歌曲'), findsOneWidget);
  });

  testWidgets('mini player immediately displays pending track artwork', (
    tester,
  ) async {
    late _TestPendingTrackMiniPlayerController controller;
    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: () {
          controller = _TestPendingTrackMiniPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();

    expect(find.text('Track A'), findsOneWidget);
    final initialImage = tester.widget<Image>(find.byType(Image));
    expect(initialImage.image, isA<ResizeImage>());
    expect(
      ((initialImage.image as ResizeImage).imageProvider
              as CachedNetworkImageProvider)
          .url,
      'https://example.com/cover-a.png',
    );
    expect(initialImage.gaplessPlayback, isTrue);

    controller.requestTrack(1);
    await tester.pump();

    expect(controller.snapshot.currentTrack?.id, 'track-a');
    expect(controller.snapshot.displayTrack?.id, 'track-b');
    expect(find.text('Track B'), findsOneWidget);
    expect(
      _findNetworkImage('https://example.com/cover-a.png'),
      findsOneWidget,
    );
    expect(
      _findNetworkImage('https://example.com/cover-b.png'),
      findsOneWidget,
    );

    await tester.pumpAndSettle();

    expect(_findNetworkImage('https://example.com/cover-a.png'), findsNothing);
    final image = tester.widget<Image>(
      _findNetworkImage('https://example.com/cover-b.png'),
    );
    expect(image.image, isA<ResizeImage>());
    expect(
      ((image.image as ResizeImage).imageProvider as CachedNetworkImageProvider)
          .url,
      'https://example.com/cover-b.png',
    );
    expect(image.gaplessPlayback, isTrue);
  });

  testWidgets(
    'mini player uses unique cover keys during rapid track reversal',
    (tester) async {
      late _TestPendingTrackMiniPlayerController controller;
      await tester.pumpWidget(
        _buildMiniPlayerTestApp(
          controllerFactory: () {
            controller = _TestPendingTrackMiniPlayerController();
            return controller;
          },
        ),
      );
      await tester.pump();

      controller.requestTrack(1);
      await tester.pump();
      controller.commitTrack(1);
      await tester.pump();
      controller.commitTrack(0);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mini player previews each target during repeated next swipes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late _TestSwipeMiniPlayerController controller;
    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: () {
          controller = _TestSwipeMiniPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('歌曲 A').hitTestable(), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-900, 0), 1500);
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 1);
    expect(find.text('歌曲 B').hitTestable(), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-900, 0), 1500);
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 2);
    expect(find.text('歌曲 C').hitTestable(), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-900, 0), 1500);
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 3);
    expect(find.text('歌曲 D').hitTestable(), findsOneWidget);
  });

  testWidgets('mini player commits a swipe only after pointer release', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late _TestSwipeMiniPlayerController controller;
    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: () {
          controller = _TestSwipeMiniPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final pageView = find.byType(PageView);
    final cancelledGesture = await tester.startGesture(
      tester.getCenter(pageView),
    );
    for (var frame = 1; frame <= 8; frame += 1) {
      await cancelledGesture.moveBy(
        const Offset(-100, 0),
        timeStamp: Duration(milliseconds: frame * 16),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.nextCalls, 0);

    for (var frame = 9; frame <= 16; frame += 1) {
      await cancelledGesture.moveBy(
        const Offset(100, 0),
        timeStamp: Duration(milliseconds: frame * 16),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.nextCalls, 0);
    expect(controller.previousCalls, 0);

    await cancelledGesture.moveBy(
      Offset.zero,
      timeStamp: const Duration(milliseconds: 400),
    );
    await tester.pump(const Duration(milliseconds: 128));
    await cancelledGesture.up(timeStamp: const Duration(milliseconds: 416));
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 0);
    expect(controller.previousCalls, 0);

    final committedGesture = await tester.startGesture(
      tester.getCenter(pageView),
    );
    for (var frame = 1; frame <= 8; frame += 1) {
      await committedGesture.moveBy(
        const Offset(-100, 0),
        timeStamp: Duration(milliseconds: frame * 16),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.nextCalls, 0);

    await committedGesture.up(timeStamp: const Duration(milliseconds: 144));
    await tester.pump();

    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 0);

    await tester.pumpAndSettle();

    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 0);
  });

  testWidgets('mini player commits a ballistic page before scrolling ends', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late _TestSwipeMiniPlayerController controller;
    var scrollEndCount = 0;
    int? scrollEndCountWhenNextCalled;
    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: () {
          controller = _TestSwipeMiniPlayerController();
          controller.onNextCall = () {
            scrollEndCountWhenNextCalled = scrollEndCount;
          };
          return controller;
        },
        onScrollEnd: (_) {
          scrollEndCount += 1;
          return false;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final pageController = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
    );
    for (var frame = 0; frame < 30 && controller.nextCalls == 0; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.nextCalls, 1);
    expect(scrollEndCountWhenNextCalled, 0);

    await tester.pumpAndSettle();

    expect(scrollEndCount, greaterThan(0));
    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 0);
  });
}

Finder _findNetworkImage(String url) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Image || widget.image is! ResizeImage) {
      return false;
    }
    final provider = (widget.image as ResizeImage).imageProvider;
    return provider is CachedNetworkImageProvider && provider.url == url;
  });
}

Widget _buildMiniPlayerTestApp({
  PlayerController Function()? controllerFactory,
  bool Function(ScrollEndNotification)? onScrollEnd,
}) {
  final miniPlayer = MiniPlayerBar(onOpenFullPlayer: () {});
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(
        controllerFactory ?? _TestMiniPlayerController.new,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: onScrollEnd == null
            ? miniPlayer
            : NotificationListener<ScrollEndNotification>(
                onNotification: onScrollEnd,
                child: miniPlayer,
              ),
      ),
    ),
  );
}

class _TestArtworkMiniPlayerController extends PlayerController {
  final tracks = List.generate(
    4,
    (index) => PlayerTrack(
      id: 'artwork-$index',
      title: 'Artwork $index',
      artworkBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    ),
  );

  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(
    tracks,
  ).copyWith(currentIndex: 0, previousPreviewIndex: 3, nextPreviewIndex: 1);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playNext() async {}

  @override
  Future<void> playPrevious() async {}

  void updatePlayback() {
    state = state.copyWith(
      position: const Duration(seconds: 1),
      isPlaying: !state.isPlaying,
    );
  }
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}

class _TestMiniPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        platform: 'qq',
        links: <LinkInfo>[
          LinkInfo(
            name: 'SQ',
            quality: 500,
            format: 'mp3',
            size: '3145728',
            url: 'https://example.com/sq.mp3',
          ),
        ],
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}

  void updateDuration(Duration duration) {
    final track = state.currentTrack!;
    state = state.copyWith(
      duration: duration,
      queue: <PlayerTrack>[track.copyWith(duration: duration)],
    );
  }

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  void replaceCurrentTrack(PlayerTrack track) {
    state = state.copyWith(queue: <PlayerTrack>[track], currentIndex: 0);
  }
}

class _TestRadioMiniPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '电台歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        platform: 'qq',
      ),
    ]).copyWith(
      playMode: PlayerPlayMode.sequence,
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );
  }

  @override
  Future<void> initialize() async {}
}

class _TestPendingTrackMiniPlayerController extends PlayerController {
  PlayerPlaybackState get snapshot => state;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'track-a',
        title: 'Track A',
        artworkUrl: 'https://example.com/cover-a.png',
      ),
      PlayerTrack(
        id: 'track-b',
        title: 'Track B',
        artworkUrl: 'https://example.com/cover-b.png',
      ),
    ]).copyWith(currentIndex: 0);
  }

  @override
  Future<void> initialize() async {}

  void requestTrack(int index) {
    state = state.copyWith(
      requestedTrackIndex: index,
      requestedTransitionId: 1,
    );
  }

  void commitTrack(int index) {
    state = state.copyWith(
      currentIndex: index,
      clearRequestedTrackIndex: true,
      clearRequestedTransitionId: true,
    );
  }
}

class _TestSwipeMiniPlayerController extends PlayerController {
  int nextCalls = 0;
  int previousCalls = 0;
  VoidCallback? onNextCall;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'song-a', title: '歌曲 A', artist: '测试歌手'),
      PlayerTrack(id: 'song-b', title: '歌曲 B', artist: '测试歌手'),
      PlayerTrack(id: 'song-c', title: '歌曲 C', artist: '测试歌手'),
      PlayerTrack(id: 'song-d', title: '歌曲 D', artist: '测试歌手'),
      PlayerTrack(id: 'song-e', title: '歌曲 E', artist: '测试歌手'),
    ]).copyWith(currentIndex: 0, previousPreviewIndex: 4, nextPreviewIndex: 1);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playNext() async {
    nextCalls += 1;
    onNextCall?.call();
  }

  @override
  Future<void> playPrevious() async {
    previousCalls += 1;
  }
}

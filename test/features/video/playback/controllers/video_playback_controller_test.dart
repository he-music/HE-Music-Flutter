import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/video/playback/providers/video_playback_surface_provider.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_playback_surface.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_surface_state.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_content.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_link.dart';
import 'package:he_music_flutter/features/video/playback/controllers/video_playback_controller.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_slot_key.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('initialize opens current and preloads adjacent slots', () async {
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final controller = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: _buildUri,
    );

    await controller.initialize(contents: _contents, initialIndex: 1);

    expect(controller.state.currentIndex, 1);
    expect(controller.state.currentSlotKey, VideoSlotKey.current);
    expect(factory.createdUris, <Uri>[
      Uri.parse('https://example.com/1-1080.mp4'),
      Uri.parse('https://example.com/0-1080.mp4'),
      Uri.parse('https://example.com/2-1080.mp4'),
    ]);
    expect(factory.autoplayValues, <bool>[true, false, false]);
  });

  test('page change pauses old current and plays new current', () async {
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final controller = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: _buildUri,
    );
    await controller.initialize(contents: _contents, initialIndex: 0);
    final firstSurface = controller.surfaceForPage(0)! as _FakeVideoSurface;

    await controller.onPageChanged(1);

    final secondSurface = controller.surfaceForPage(1)! as _FakeVideoSurface;
    expect(firstSurface.pauseCallCount, 1);
    expect(secondSurface.playCallCount, greaterThan(0));
    expect(controller.state.currentIndex, 1);
    expect(controller.state.currentSlot?.contentId, 'mv-1');
  });

  test(
    'page change keeps only previous current and next slots attached',
    () async {
      final factory = _FakeVideoPlaybackSurfaceFactory();
      final controller = VideoPlaybackController(
        surfaceFactory: factory,
        uriBuilder: _buildUri,
      );
      await controller.initialize(contents: _contents, initialIndex: 1);

      await controller.onPageChanged(3);

      expect(controller.surfaceForPage(1), isNull);
      expect(controller.surfaceForPage(2), isNotNull);
      expect(controller.surfaceForPage(3), isNotNull);
      expect(factory.disposedContentIds, contains('1'));
    },
  );

  test('slot state content id changes when a distant slot is reused', () async {
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final controller = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: _buildUri,
    );
    await controller.initialize(contents: _contents, initialIndex: 0);

    await controller.onPageChanged(2);

    expect(controller.surfaceForPage(0), isNull);
    expect(
      controller.state.slotStates[VideoSlotKey.previous]?.contentId,
      'mv-1',
    );
    expect(
      controller.state.slotStates[VideoSlotKey.current]?.contentId,
      'mv-2',
    );
    expect(controller.state.slotStates[VideoSlotKey.next]?.contentId, 'mv-3');
  });

  test('disposeSessions disposes all attached surfaces', () async {
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final controller = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: _buildUri,
    );
    await controller.initialize(contents: _contents, initialIndex: 1);

    await controller.disposeSessions();

    expect(controller.surfaceForPage(0), isNull);
    expect(controller.surfaceForPage(1), isNull);
    expect(controller.surfaceForPage(2), isNull);
    expect(factory.disposedContentIds, containsAll(<String>['0', '1', '2']));
  });

  test('updateContent attaches asynchronously loaded adjacent page', () async {
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final controller = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: _buildUri,
    );
    await controller.initialize(
      contents: <VideoDetailContent>[_contents[0]],
      initialIndex: 0,
    );

    await controller.updateContent(
      pageIndex: 1,
      content: _contents[1],
      autoplay: false,
    );

    expect(controller.surfaceForPage(1), isNotNull);
    expect(
      factory.createdUris.last,
      Uri.parse('https://example.com/1-1080.mp4'),
    );
    expect(factory.autoplayValues.last, isFalse);
    expect(controller.state.slotStates[VideoSlotKey.next]?.contentId, 'mv-1');
  });

  test('switchQuality keeps position and playing state', () async {
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final controller = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: _buildUri,
    );
    await controller.initialize(contents: _contents, initialIndex: 0);
    final currentSurface = controller.currentSurface! as _FakeVideoSurface;
    currentSurface.setState(
      VideoSurfaceState.initial.copyWith(
        isInitialized: true,
        isPlaying: true,
        position: const Duration(seconds: 18),
      ),
    );

    await controller.switchQuality(_contents.first.links.last);

    expect(factory.lastInitialPosition, const Duration(seconds: 18));
    expect(factory.lastAutoplay, isTrue);
    expect(
      controller.state.currentSlot?.selectedQualityKey,
      '720|mp4|https://example.com/0-720.mp4',
    );
  });

  test(
    'switchQuality keeps old session when replacement reports error',
    () async {
      final factory = _FakeVideoPlaybackSurfaceFactory();
      final controller = VideoPlaybackController(
        surfaceFactory: factory,
        uriBuilder: _buildUri,
      );
      await controller.initialize(contents: _contents, initialIndex: 0);
      final oldSurface = controller.currentSurface! as _FakeVideoSurface;

      factory.failNextCreateWithErroredSession = true;
      await controller.switchQuality(_contents.first.links.last);

      expect(controller.currentSurface, same(oldSurface));
      expect(oldSurface.disposeCallCount, 0);
      expect(controller.state.isSwitchingQuality, isFalse);
      expect(controller.state.activeError, isNotNull);
    },
  );

  test('slot state reflects session buffering state', () async {
    final factory = _FakeVideoPlaybackSurfaceFactory();
    final controller = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: _buildUri,
    );
    await controller.initialize(contents: _contents, initialIndex: 0);
    final currentSurface = controller.currentSurface! as _FakeVideoSurface;

    currentSurface.setState(currentSurface.state.copyWith(isBuffering: true));

    expect(controller.state.currentSlot?.isBuffering, isTrue);
  });
}

final List<VideoDetailContent> _contents = List<VideoDetailContent>.generate(
  4,
  (index) => VideoDetailContent(
    info: MvInfo(
      platform: 'qq',
      links: const <LinkInfo>[],
      id: 'mv-$index',
      name: '测试 MV $index',
      cover: '',
      type: 0,
      playCount: '$index',
      creator: '测试作者',
      duration: 120,
      description: '',
    ),
    links: <VideoDetailLink>[
      LinkInfo(
        name: '1080p',
        quality: 1080,
        format: 'mp4',
        size: '2MB',
        url: 'https://example.com/$index-1080.mp4',
      ),
      LinkInfo(
        name: '720p',
        quality: 720,
        format: 'mp4',
        size: '1MB',
        url: 'https://example.com/$index-720.mp4',
      ),
    ],
  ),
);

Uri _buildUri(VideoDetailContent content, VideoDetailLink link) {
  return Uri.parse(link.url);
}

class _FakeVideoPlaybackSurfaceFactory implements VideoPlaybackSurfaceFactory {
  final List<Uri> createdUris = <Uri>[];
  final List<bool> autoplayValues = <bool>[];
  final List<String> disposedContentIds = <String>[];
  bool failNextCreateWithErroredSession = false;
  Duration? lastInitialPosition;
  bool? lastAutoplay;

  @override
  Future<VideoPlaybackSurface> create({
    required Uri uri,
    bool autoplay = true,
    Duration? initialPosition,
  }) async {
    createdUris.add(uri);
    autoplayValues.add(autoplay);
    lastAutoplay = autoplay;
    lastInitialPosition = initialPosition;
    final hasError = failNextCreateWithErroredSession;
    failNextCreateWithErroredSession = false;
    final surface = _FakeVideoSurface(
      contentId: uri.pathSegments.first.split('-').first,
      onDispose: disposedContentIds.add,
      state: VideoSurfaceState.initial.copyWith(
        isInitialized: !hasError,
        isPlaying: !hasError && autoplay,
        duration: const Duration(minutes: 2),
        hasError: hasError,
      ),
    );
    if (initialPosition != null) {
      await surface.seekTo(initialPosition);
    }
    return surface;
  }
}

class _FakeVideoSurface extends ChangeNotifier implements VideoPlaybackSurface {
  _FakeVideoSurface({
    required this.contentId,
    required this.onDispose,
    required VideoSurfaceState state,
  }) : _state = state;

  final String contentId;
  final void Function(String contentId) onDispose;
  VideoSurfaceState _state;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int disposeCallCount = 0;

  @override
  VideoSurfaceState get state => _state;

  @override
  Future<void> get waitUntilFirstFrameRendered => Future<void>.value();

  void setState(VideoSurfaceState state) {
    _state = state;
    notifyListeners();
  }

  @override
  Widget buildView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    VideoSurfaceControls controls = VideoSurfaceControls.none,
    MaterialVideoControlsThemeData? materialControlsTheme,
    MaterialDesktopVideoControlsThemeData? materialDesktopControlsTheme,
  }) {
    return SizedBox(key: key);
  }

  @override
  Future<void> disposeSurface() async {
    disposeCallCount += 1;
    onDispose(contentId);
    dispose();
  }

  @override
  Future<void> pause() async {
    pauseCallCount += 1;
    setState(_state.copyWith(isPlaying: false));
  }

  @override
  Future<void> play() async {
    playCallCount += 1;
    setState(_state.copyWith(isPlaying: true));
  }

  @override
  Future<void> seekTo(Duration position) async {
    setState(_state.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    setState(_state.copyWith(volume: volume));
  }

  @override
  Future<void> enterFullscreen() async {}

  @override
  Future<void> exitFullscreen() async {}
}

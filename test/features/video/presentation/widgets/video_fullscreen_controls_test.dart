import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_content.dart';
import 'package:he_music_flutter/features/video/playback/controllers/video_picture_in_picture_controller.dart';
import 'package:he_music_flutter/features/video/playback/controllers/video_playback_controller.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_playback_surface.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_surface_state.dart';
import 'package:he_music_flutter/features/video/playback/providers/video_playback_surface_provider.dart';
import 'package:he_music_flutter/features/video/presentation/widgets/video_fullscreen_controls.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  late _Factory factory;
  late VideoPlaybackController playback;
  late VideoPictureInPictureController pip;
  const channel = MethodChannel('com.hemusic/video_pip');
  final calls = <MethodCall>[];
  bool allowPip = true;
  int exits = 0;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'isSupported' ||
              (call.method == 'enter' && allowPip);
        });
    calls.clear();
    allowPip = true;
    exits = 0;
    factory = _Factory();
    playback = VideoPlaybackController(
      surfaceFactory: factory,
      uriBuilder: (_, link) => Uri.parse(link.url),
    );
    await playback.initialize(contents: [_content], initialIndex: 0);
    pip = VideoPictureInPictureController(platform: TargetPlatform.android);
    await pip.initialize();
  });

  tearDown(() {
    playback.dispose();
    pip.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(960, 540),
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: reduceMotion),
            child: RepaintBoundary(
              key: const ValueKey('fullscreen-capture'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1B4050), Color(0xFF372D48)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  VideoFullscreenControls(
                    playback: playback,
                    surface: factory.surface,
                    content: _content,
                    title: '测试视频 · Fullscreen controls',
                    gestureTheme: MaterialVideoControlsThemeData(
                      initialBrightness: 0.5,
                      onBrightnessChanged: (value) =>
                          factory.brightnessChanges.add(value),
                      onVolumeChanged: (value) =>
                          unawaited(factory.surface.setVolume(value * 100)),
                    ),
                    pictureInPicture: pip,
                    onExit: () async {
                      exits++;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder action(String name) => find.byKey(ValueKey('video-fullscreen-$name'));

  testWidgets('wide fullscreen exposes quality speed fit lock and PiP', (
    tester,
  ) async {
    await mount(tester);
    for (final name in ['quality', 'speed', 'fit', 'lock', 'pip', 'exit']) {
      expect(action(name), findsOneWidget);
    }
    expect(find.text('1080P'), findsOneWidget);
    expect(find.text('1.0×'), findsOneWidget);
    expect(action('more'), findsNothing);
    final timing = tester.getRect(find.text('00:00 / 02:00'));
    final quality = tester.getRect(action('quality'));
    expect(timing.center.dy, closeTo(quality.center.dy, 0.5));
    expect(timing.right, lessThanOrEqualTo(quality.left));
    if (const bool.fromEnvironment('CAPTURE_VIDEO_CONTROLS')) {
      await expectLater(
        find.byKey(const ValueKey('fullscreen-capture')),
        matchesGoldenFile(Uri.file('/tmp/he-video-fullscreen.png')),
      );
    }
    await tester.tap(action('exit'));
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('quality and speed selections preserve the fullscreen session', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(action('speed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1.5×'));
    await tester.tap(find.text('1.5×'));
    await tester.pumpAndSettle();
    expect(factory.surface.state.rate, 1.5);
    expect(find.text('1.5×'), findsOneWidget);

    await tester.tap(action('quality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('720P'));
    await tester.pumpAndSettle();
    expect(factory.creates, 1);
    expect(factory.surface.sourceChanges.single.path, '/720.mp4');
    expect(factory.surface.state.rate, 1.5);
    expect(find.text('720P'), findsOneWidget);
    expect(exits, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'picture fit changes the video surface and restores fit on exit',
    (tester) async {
      await mount(tester);
      await tester.tap(action('fit'));
      await tester.pumpAndSettle();
      expect(
        find.text('Fill the screen; edges may be cropped'),
        findsOneWidget,
      );
      await tester.tap(find.text('Fill screen'));
      await tester.pumpAndSettle();
      expect(factory.surface.fit, BoxFit.cover);
      await tester.tap(action('fit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stretch picture'));
      await tester.pumpAndSettle();
      expect(factory.surface.fit, BoxFit.fill);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(factory.surface.fit, BoxFit.contain);
    },
  );

  testWidgets(
    'lock blocks playback seek volume and brightness until unlocked',
    (tester) async {
      await mount(tester);
      await tester.tap(action('lock'));
      await tester.pumpAndSettle();
      expect(action('unlock'), findsOneWidget);
      await tester.dragFrom(const Offset(200, 220), const Offset(200, 0));
      await tester.dragFrom(const Offset(800, 250), const Offset(0, -120));
      await tester.dragFrom(const Offset(200, 250), const Offset(0, -120));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(factory.surface.seeks, isEmpty);
      expect(factory.surface.state.isPlaying, isTrue);
      expect(factory.surface.state.volume, 100);
      expect(factory.brightnessChanges, isEmpty);
      await tester.tap(action('unlock'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(factory.surface.state.isPlaying, isFalse);
      await tester.dragFrom(const Offset(200, 220), const Offset(200, 0));
      await tester.pump();
      expect(factory.surface.seeks, isNotEmpty);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('locked controls reveal unlock on tap after auto hide', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(action('lock'));
    await tester.pump(const Duration(seconds: 4));
    expect(action('unlock'), findsNothing);
    await tester.tapAt(const Offset(600, 200));
    await tester.pumpAndSettle();
    expect(action('unlock'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(action('lock'), findsOneWidget);
    expect(exits, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings suspend auto hide and reflect external rate updates', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(action('speed'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.ensureVisible(find.text('2.0×'));
    await tester.tap(find.text('2.0×'));
    await tester.pumpAndSettle();
    expect(action('speed').hitTestable(), findsOneWidget);
    expect(find.text('2.0×'), findsOneWidget);
    await factory.surface.setRate(0.75);
    await tester.pump();
    expect(find.text('0.75×'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'PiP hides all chrome and restores it on returning to fullscreen',
    (tester) async {
      await mount(tester);
      await tester.tap(action('pip'));
      await tester.pumpAndSettle();
      expect(pip.active, isTrue);
      expect(action('speed'), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(calls.last.method, 'enter');
      expect(calls.last.arguments['aspectRatio'], closeTo(16 / 9, 0.001));
      expect(calls.last.arguments['playing'], isTrue);
      await _nativeCall(channel, const MethodCall('modeChanged', false));
      await tester.pumpAndSettle();
      expect(action('speed'), findsOneWidget);
      expect(action('lock'), findsOneWidget);
      expect(exits, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('PiP refusal restores controls and shows actionable feedback', (
    tester,
  ) async {
    allowPip = false;
    await mount(tester);
    await tester.tap(action('pip'));
    await tester.pumpAndSettle();
    expect(pip.active, isFalse);
    expect(pip.entering, isFalse);
    expect(action('pip'), findsOneWidget);
    expect(
      find.text(
        'Unable to open picture in picture. Check the system permission.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'narrow screen keeps quality and speed direct and folds other actions',
    (tester) async {
      await mount(tester, size: const Size(360, 640));
      expect(action('speed'), findsOneWidget);
      expect(action('quality'), findsOneWidget);
      expect(
        tester.getCenter(find.text('00:00 / 02:00')).dy,
        closeTo(tester.getCenter(action('quality')).dy, 0.5),
      );
      expect(action('fit'), findsNothing);
      expect(action('pip'), findsNothing);
      await tester.tap(action('more'));
      await tester.pumpAndSettle();
      expect(find.text('Picture fit'), findsOneWidget);
      expect(find.text('Picture in picture'), findsOneWidget);
      await tester.tap(find.text('Picture fit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fit to screen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'progress ticks update timing without rebuilding fullscreen chrome',
    (tester) async {
      await mount(tester);
      final title = tester.widget(find.text('测试视频 · Fullscreen controls'));
      factory.surface.change(
        factory.surface.state.copyWith(position: const Duration(seconds: 42)),
      );
      await tester.pump();
      expect(find.text('00:42 / 02:00'), findsOneWidget);
      expect(
        tester.widget(find.text('测试视频 · Fullscreen controls')),
        same(title),
      );
      await factory.surface.pause();
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('fullscreen transitions respect system reduced motion', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      Duration.zero,
    );
    await mount(tester, reduceMotion: false);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      const Duration(milliseconds: 180),
    );
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _nativeCall(MethodChannel channel, MethodCall call) async {
  final completed = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(call),
        (_) => completed.complete(),
      );
  await completed.future;
}

const _content = VideoDetailContent(
  info: MvInfo(
    platform: 'qq',
    links: [],
    id: 'mv-1',
    name: 'Test MV',
    cover: '',
    type: 0,
    playCount: '1',
    creator: 'Artist',
    duration: 120,
    description: '',
  ),
  links: [
    LinkInfo(
      name: '1080P',
      quality: 1080,
      format: 'mp4',
      size: '',
      url: 'https://example.com/1080.mp4',
    ),
    LinkInfo(
      name: '720P',
      quality: 720,
      format: 'mp4',
      size: '',
      url: 'https://example.com/720.mp4',
    ),
  ],
);

class _Factory implements VideoPlaybackSurfaceFactory {
  final surface = _Surface();
  final List<double> brightnessChanges = [];
  int creates = 0;
  @override
  Future<VideoPlaybackSurface> create({
    required Uri uri,
    bool autoplay = true,
    Duration? initialPosition,
  }) async {
    creates++;
    return surface;
  }
}

class _Surface extends ChangeNotifier implements VideoPlaybackSurface {
  VideoSurfaceState _state = VideoSurfaceState.initial.copyWith(
    isInitialized: true,
    isPlaying: true,
    duration: const Duration(minutes: 2),
  );
  final List<Uri> sourceChanges = [];
  final List<Duration> seeks = [];
  BoxFit fit = BoxFit.contain;
  @override
  VideoSurfaceState get state => _state;
  void change(VideoSurfaceState state) {
    _state = state;
    notifyListeners();
  }

  @override
  Future<void> get waitUntilFirstFrameRendered async {}
  @override
  Future<void> play() async => change(state.copyWith(isPlaying: true));
  @override
  Future<void> pause() async => change(state.copyWith(isPlaying: false));
  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    change(state.copyWith(position: position));
  }

  @override
  Future<void> setRate(double rate) async => change(state.copyWith(rate: rate));
  @override
  Future<void> setVolume(double volume) async =>
      change(state.copyWith(volume: volume));
  @override
  void setFit(BoxFit fit) {
    this.fit = fit;
  }

  @override
  Future<void> replaceSource(Uri uri) async {
    sourceChanges.add(uri);
  }

  @override
  Future<void> enterFullscreen() async {}
  @override
  Future<void> exitFullscreen() async {}
  @override
  Future<void> disposeSurface() async => dispose();
  @override
  Widget buildView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    VideoSurfaceControls controls = VideoSurfaceControls.none,
    MaterialVideoControlsThemeData? materialControlsTheme,
    MaterialDesktopVideoControlsThemeData? materialDesktopControlsTheme,
    Widget Function(Widget materialControls)? fullscreenControlsBuilder,
    Future<void> Function()? onExitFullscreen,
  }) => const SizedBox();
}

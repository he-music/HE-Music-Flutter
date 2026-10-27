import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_content.dart';
import 'package:he_music_flutter/features/video/playback/controllers/video_picture_in_picture_controller.dart';
import 'package:he_music_flutter/features/video/playback/controllers/video_playback_controller.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_playback_surface.dart';
import 'package:he_music_flutter/features/video/playback/providers/video_playback_surface_provider.dart';
import 'package:he_music_flutter/features/video/presentation/widgets/video_fullscreen_controls.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

/// Run on a desktop host with two HTTP-served MP4s named 1080.mp4 and 720.mp4:
/// flutter test integration_test/video_fullscreen_smoke_test.dart -d macos
///   --dart-define-from-file=.env
///   --dart-define=VIDEO_FULLSCREEN_FIXTURE_ORIGIN=http://127.0.0.1:8876/
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const origin = String.fromEnvironment('VIDEO_FULLSCREEN_FIXTURE_ORIGIN');
  testWidgets(
    'native video retains fullscreen rendering across fit speed and quality changes',
    (tester) async {
      MediaKit.ensureInitialized();
      final content = VideoDetailContent(
        info: const MvInfo(
          platform: 'local',
          links: [],
          id: 'fixture',
          name: 'Fullscreen smoke test',
          cover: '',
          type: 0,
          playCount: '0',
          creator: '',
          duration: 60,
          description: '',
        ),
        links: [
          for (final quality in [1080, 720])
            LinkInfo(
              name: '${quality}P',
              quality: quality,
              format: 'mp4',
              size: '',
              url: Uri.parse(origin).resolve('$quality.mp4').toString(),
            ),
        ],
      );
      final playback = VideoPlaybackController(
        surfaceFactory: const DefaultVideoPlaybackSurfaceFactory(),
        uriBuilder: (_, link) => Uri.parse(link.url),
      );
      final pip = VideoPictureInPictureController();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      // VideoController initializes in a post-frame callback; keep pumping
      // frames while the factory asynchronously creates its player.
      bool initialized = false;
      Object? initializationError;
      playback
          .initialize(contents: [content], initialIndex: 0)
          .then(
            (_) {
              initialized = true;
            },
            onError: (Object error) {
              initializationError = error;
              initialized = true;
            },
          );
      final initializationDeadline = DateTime.now().add(
        const Duration(seconds: 20),
      );
      while (!initialized && DateTime.now().isBefore(initializationDeadline)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(initializationError, isNull);
      expect(initialized, isTrue, reason: 'Native player must initialize');
      final surface = playback.currentSurface!;
      final native = surface as MediaKitVideoPlaybackSurface;
      final errors = native.player.stream.error.listen(
        (value) => debugPrint('VIDEO_ERROR=$value'),
      );
      addTearDown(errors.cancel);
      const theme = MaterialVideoControlsThemeData();
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: surface.buildView(
              controls: VideoSurfaceControls.materialFullscreenOnly,
              materialControlsTheme: theme,
              fullscreenControlsBuilder: (_) => RepaintBoundary(
                key: captureKey,
                child: VideoFullscreenControls(
                  playback: playback,
                  surface: surface,
                  content: content,
                  title: content.title,
                  gestureTheme: theme,
                  pictureInPicture: pip,
                  onExit: surface.exitFullscreen,
                ),
              ),
            ),
          ),
        ),
      );
      bool firstFrame = false;
      surface.waitUntilFirstFrameRendered.then((_) => firstFrame = true);
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!firstFrame && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      debugPrint(
        'VIDEO_STATE initialized=${surface.state.isInitialized} error=${surface.state.hasError} '
        'duration=${surface.state.duration} playing=${surface.state.isPlaying} '
        'size=${native.player.state.width}x${native.player.state.height}',
      );
      expect(
        firstFrame,
        isTrue,

        reason: 'Native video must render its first frame',
      );
      await surface.pause();
      await surface.seekTo(const Duration(seconds: 3));
      await surface.setVolume(42);
      await surface.enterFullscreen();
      await tester.pumpAndSettle();
      expect(find.byType(VideoFullscreenControls), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('video-fullscreen-speed')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('1.5×'));
      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      expect(surface.state.rate, 1.5);

      await tester.tap(find.byKey(const ValueKey('video-fullscreen-fit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill screen'));
      await tester.pumpAndSettle();
      expect(find.byType(VideoFullscreenControls), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('video-fullscreen-quality')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('720P'));
      await tester.pumpAndSettle();
      expect(playback.currentSurface, same(surface));
      expect(find.byType(VideoFullscreenControls), findsOneWidget);
      expect(find.text('720P'), findsOneWidget);
      expect(surface.state.rate, 1.5);
      expect(surface.state.volume, 42);
      expect(surface.state.isPlaying, isFalse);
      expect(surface.state.position.inMilliseconds, closeTo(3000, 500));
      expect(
        tester.widget<Video>(find.byType(Video).last).controller,
        same(native.controller),
      );
      expect(surface.state.hasError, isFalse);

      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        '${Directory.systemTemp.path}/fullscreen-native.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
      debugPrint(
        'VIDEO_FULLSCREEN_CAPTURE=${Directory.systemTemp.path}/fullscreen-native.png',
      );

      await tester.tap(find.byKey(const ValueKey('video-fullscreen-lock')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('video-fullscreen-unlock')),
        findsOneWidget,
      );
      // System back can always leave fullscreen, including while touch is locked.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VideoFullscreenControls), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await playback.disposeSessions();
      playback.dispose();
      pip.dispose();
    },
    skip: origin.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'video_surface_state.dart';

enum VideoSurfaceControls {
  none,
  material,
  materialFullscreenOnly,
  materialDesktop,
}

abstract class VideoPlaybackSurface extends Listenable {
  VideoSurfaceState get state;

  Future<void> get waitUntilFirstFrameRendered;

  Widget buildView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    VideoSurfaceControls controls = VideoSurfaceControls.none,
    MaterialVideoControlsThemeData? materialControlsTheme,
    MaterialDesktopVideoControlsThemeData? materialDesktopControlsTheme,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setVolume(double volume);

  Future<void> enterFullscreen();

  Future<void> exitFullscreen();

  Future<void> disposeSurface();
}

class MediaKitVideoPlaybackSurface extends ChangeNotifier
    implements VideoPlaybackSurface {
  MediaKitVideoPlaybackSurface._({
    required this.player,
    required this.controller,
  });

  /// media-kit 播放器实例。播放槽位长期持有并由控制器统一释放。
  final Player player;

  /// media-kit 视频渲染控制器，与 [player] 一一绑定。
  final VideoController controller;

  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  VideoSurfaceState _state = VideoSurfaceState.initial;
  int? _videoWidth;
  int? _videoHeight;

  static Future<MediaKitVideoPlaybackSurface> create({
    required Uri uri,
    bool autoplay = true,
    Duration? initialPosition,
  }) async {
    final player = Player();
    final controller = VideoController(player);
    final surface = MediaKitVideoPlaybackSurface._(
      player: player,
      controller: controller,
    );
    surface._bindStreams();
    try {
      await player.open(Media(uri.toString()), play: autoplay);
      surface._updateState(
        surface._state.copyWith(isInitialized: true, hasError: false),
      );
      if (initialPosition != null && initialPosition > Duration.zero) {
        await player.seek(initialPosition);
      }
    } catch (error) {
      surface._updateState(surface._state.copyWith(hasError: true));
      await surface.disposeSurface();
      throw StateError('Failed to open media-kit video: $error');
    }
    return surface;
  }

  @override
  VideoSurfaceState get state => _state;

  @override
  Future<void> get waitUntilFirstFrameRendered =>
      controller.waitUntilFirstFrameRendered;

  void _bindStreams() {
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      player.stream.playing.listen((dynamic value) {
        _updateState(_state.copyWith(isPlaying: value as bool));
      }),
      player.stream.buffering.listen((dynamic value) {
        _updateState(_state.copyWith(isBuffering: value as bool));
      }),
      player.stream.position.listen((dynamic value) {
        _updateState(_state.copyWith(position: value as Duration));
      }),
      player.stream.duration.listen((dynamic value) {
        _updateState(
          _state.copyWith(duration: value as Duration? ?? Duration.zero),
        );
      }),
      player.stream.volume.listen((dynamic value) {
        _updateState(_state.copyWith(volume: value as double));
      }),
      player.stream.error.listen((dynamic value) {
        _updateState(_state.copyWith(hasError: true));
      }),
      player.stream.width.listen((dynamic value) {
        _videoWidth = value as int?;
        _updateAspectRatio();
      }),
      player.stream.height.listen((dynamic value) {
        _videoHeight = value as int?;
        _updateAspectRatio();
      }),
    ]);
  }

  void _updateAspectRatio() {
    _updateState(
      _state.copyWith(
        aspectRatio: VideoSurfaceState.aspectRatioForSize(
          _videoWidth,
          _videoHeight,
        ),
      ),
    );
  }

  void _updateState(VideoSurfaceState nextState) {
    _state = nextState;
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
    final video = Video(
      key: key ?? _videoKey,
      controller: controller,
      fit: fit,
      controls: switch (controls) {
        VideoSurfaceControls.none => NoVideoControls,
        VideoSurfaceControls.material => MaterialVideoControls,
        VideoSurfaceControls.materialFullscreenOnly => (state) {
          if (isFullscreen(state.context)) {
            return MaterialVideoControls(state);
          }
          return const SizedBox.shrink();
        },
        VideoSurfaceControls.materialDesktop => MaterialDesktopVideoControls,
      },
    );
    return switch (controls) {
      VideoSurfaceControls.none => video,
      VideoSurfaceControls.materialFullscreenOnly ||
      VideoSurfaceControls.material => MaterialVideoControlsTheme(
        normal: materialControlsTheme ?? const MaterialVideoControlsThemeData(),
        fullscreen:
            materialControlsTheme ?? const MaterialVideoControlsThemeData(),
        child: video,
      ),
      VideoSurfaceControls.materialDesktop => MaterialDesktopVideoControlsTheme(
        normal:
            materialDesktopControlsTheme ??
            const MaterialDesktopVideoControlsThemeData(),
        fullscreen:
            materialDesktopControlsTheme ??
            const MaterialDesktopVideoControlsThemeData(),
        child: video,
      ),
    };
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> play() => player.play();

  @override
  Future<void> seekTo(Duration position) => player.seek(position);

  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);

  @override
  Future<void> enterFullscreen() async {
    await _videoKey.currentState?.enterFullscreen();
  }

  @override
  Future<void> exitFullscreen() async {
    await _videoKey.currentState?.exitFullscreen();
  }

  @override
  Future<void> disposeSurface() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    dispose();
  }
}

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
    Widget Function(Widget materialControls)? fullscreenControlsBuilder,
    Future<void> Function()? onExitFullscreen,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setRate(double rate);

  void setFit(BoxFit fit);

  /// Reopen media without replacing the Video widget or its fullscreen route.
  Future<void> replaceSource(Uri uri);
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
      player.stream.rate.listen((value) {
        _updateState(_state.copyWith(rate: value));
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
    Widget Function(Widget materialControls)? fullscreenControlsBuilder,
    Future<void> Function()? onExitFullscreen,
  }) {
    final video = Video(
      key: key ?? _videoKey,
      controller: controller,
      fit: fit,
      // The page handles lifecycle pauses, allowing Android PiP to keep playing.
      pauseUponEnteringBackgroundMode: false,
      onExitFullscreen: onExitFullscreen ?? defaultExitNativeFullscreen,
      controls: switch (controls) {
        VideoSurfaceControls.none => NoVideoControls,
        VideoSurfaceControls.material => MaterialVideoControls,
        VideoSurfaceControls.materialFullscreenOnly => (state) {
          if (isFullscreen(state.context)) {
            final material = MaterialVideoControls(state);
            return fullscreenControlsBuilder?.call(material) ?? material;
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
  Future<void> setRate(double rate) => player.setRate(rate);

  @override
  void setFit(BoxFit fit) => _videoKey.currentState?.update(fit: fit);

  @override
  Future<void> replaceSource(Uri uri) async {
    final previous = _state;
    _updateState(_state.copyWith(hasError: false));
    final ready = Completer<String?>();
    final errors = player.stream.error.listen((message) {
      if (!ready.isCompleted) ready.complete(message);
    });
    StreamSubscription<Duration>? duration;
    try {
      await player.open(Media(uri.toString()), play: false);
      // open() queues the load; seeking before duration arrives can lose progress.
      duration = player.stream.duration.listen((value) {
        if (value > Duration.zero && !ready.isCompleted) ready.complete(null);
      });
      if (player.state.duration > Duration.zero && !ready.isCompleted) {
        ready.complete(null);
      }
      final error = await ready.future.timeout(const Duration(seconds: 20));
      if (error != null || _state.hasError) {
        throw StateError(error ?? 'Failed to open video source');
      }
      await player.seek(previous.position);
      await player.setVolume(previous.volume);
      await player.setRate(previous.rate);
      if (previous.isPlaying) await player.play();
    } finally {
      await duration?.cancel();
      await errors.cancel();
    }
  }

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

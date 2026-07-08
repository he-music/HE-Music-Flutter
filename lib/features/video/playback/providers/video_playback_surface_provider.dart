import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../entities/video_playback_surface.dart';

abstract class VideoPlaybackSurfaceFactory {
  Future<VideoPlaybackSurface> create({
    required Uri uri,
    bool autoplay = true,
    Duration? initialPosition,
  });
}

class DefaultVideoPlaybackSurfaceFactory
    implements VideoPlaybackSurfaceFactory {
  const DefaultVideoPlaybackSurfaceFactory();

  @override
  Future<VideoPlaybackSurface> create({
    required Uri uri,
    bool autoplay = true,
    Duration? initialPosition,
  }) {
    return MediaKitVideoPlaybackSurface.create(
      uri: uri,
      autoplay: autoplay,
      initialPosition: initialPosition,
    );
  }
}

final videoPlaybackSurfaceFactoryProvider =
    Provider<VideoPlaybackSurfaceFactory>(
      (ref) => const DefaultVideoPlaybackSurfaceFactory(),
    );

class VideoSurfaceState {
  const VideoSurfaceState({
    required this.isInitialized,
    required this.isBuffering,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.aspectRatio,
    required this.volume,
    required this.hasError,
  });

  final bool isInitialized;
  final bool isBuffering;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final double volume;
  final bool hasError;

  VideoSurfaceState copyWith({
    bool? isInitialized,
    bool? isBuffering,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? aspectRatio,
    double? volume,
    bool? hasError,
  }) {
    return VideoSurfaceState(
      isInitialized: isInitialized ?? this.isInitialized,
      isBuffering: isBuffering ?? this.isBuffering,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      volume: volume ?? this.volume,
      hasError: hasError ?? this.hasError,
    );
  }

  static const initial = VideoSurfaceState(
    isInitialized: false,
    isBuffering: false,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    aspectRatio: 16 / 9,
    volume: 100,
    hasError: false,
  );

  static double aspectRatioForSize(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return initial.aspectRatio;
    }
    return width / height;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_surface_state.dart';

void main() {
  test('video surface state exposes expected defaults', () {
    const state = VideoSurfaceState.initial;

    expect(state.isInitialized, isFalse);
    expect(state.isBuffering, isFalse);
    expect(state.isPlaying, isFalse);
    expect(state.position, Duration.zero);
    expect(state.duration, Duration.zero);
    expect(state.aspectRatio, 16 / 9);
    expect(state.volume, 100);
    expect(state.hasError, isFalse);
  });

  test('video surface state copyWith updates selected fields only', () {
    const initial = VideoSurfaceState.initial;

    final updated = initial.copyWith(
      isInitialized: true,
      isBuffering: true,
      isPlaying: true,
      position: const Duration(seconds: 12),
      duration: const Duration(minutes: 2),
      aspectRatio: 4 / 3,
      volume: 42,
      hasError: true,
    );

    expect(updated.isInitialized, isTrue);
    expect(updated.isBuffering, isTrue);
    expect(updated.isPlaying, isTrue);
    expect(updated.position, const Duration(seconds: 12));
    expect(updated.duration, const Duration(minutes: 2));
    expect(updated.aspectRatio, 4 / 3);
    expect(updated.volume, 42);
    expect(updated.hasError, isTrue);
    expect(initial.isInitialized, isFalse);
    expect(initial.isBuffering, isFalse);
    expect(initial.isPlaying, isFalse);
  });

  test('aspectRatioForSize uses real dimensions with safe fallback', () {
    expect(VideoSurfaceState.aspectRatioForSize(720, 1280), 720 / 1280);
    expect(VideoSurfaceState.aspectRatioForSize(1440, 1080), 4 / 3);
    expect(VideoSurfaceState.aspectRatioForSize(null, 1080), 16 / 9);
    expect(VideoSurfaceState.aspectRatioForSize(1920, 0), 16 / 9);
  });
}

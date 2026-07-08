import 'video_slot_key.dart';

class VideoSlotState {
  const VideoSlotState({
    required this.slotKey,
    required this.pageIndex,
    required this.contentId,
    required this.isAttached,
    required this.isInitialized,
    required this.isBuffering,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.aspectRatio,
    required this.selectedQualityKey,
    required this.error,
  });

  final VideoSlotKey slotKey;
  final int pageIndex;
  final String contentId;
  final bool isAttached;
  final bool isInitialized;
  final bool isBuffering;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final String? selectedQualityKey;
  final Object? error;

  VideoSlotState copyWith({
    VideoSlotKey? slotKey,
    int? pageIndex,
    String? contentId,
    bool? isAttached,
    bool? isInitialized,
    bool? isBuffering,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? aspectRatio,
    String? selectedQualityKey,
    Object? error,
  }) {
    return VideoSlotState(
      slotKey: slotKey ?? this.slotKey,
      pageIndex: pageIndex ?? this.pageIndex,
      contentId: contentId ?? this.contentId,
      isAttached: isAttached ?? this.isAttached,
      isInitialized: isInitialized ?? this.isInitialized,
      isBuffering: isBuffering ?? this.isBuffering,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      selectedQualityKey: selectedQualityKey ?? this.selectedQualityKey,
      error: error ?? this.error,
    );
  }
}

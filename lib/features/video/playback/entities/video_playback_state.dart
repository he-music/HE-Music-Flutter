import 'video_slot_key.dart';
import 'video_slot_state.dart';

class VideoPlaybackState {
  const VideoPlaybackState({
    required this.currentIndex,
    required this.currentSlotKey,
    required this.isSwitchingQuality,
    required this.activeError,
    required this.slotStates,
  });

  final int currentIndex;
  final VideoSlotKey currentSlotKey;
  final bool isSwitchingQuality;
  final Object? activeError;
  final Map<VideoSlotKey, VideoSlotState> slotStates;

  VideoSlotState? get currentSlot => slotStates[currentSlotKey];

  static const initial = VideoPlaybackState(
    currentIndex: 0,
    currentSlotKey: VideoSlotKey.current,
    isSwitchingQuality: false,
    activeError: null,
    slotStates: <VideoSlotKey, VideoSlotState>{},
  );

  VideoPlaybackState copyWith({
    int? currentIndex,
    VideoSlotKey? currentSlotKey,
    bool? isSwitchingQuality,
    Object? activeError,
    Map<VideoSlotKey, VideoSlotState>? slotStates,
  }) {
    return VideoPlaybackState(
      currentIndex: currentIndex ?? this.currentIndex,
      currentSlotKey: currentSlotKey ?? this.currentSlotKey,
      isSwitchingQuality: isSwitchingQuality ?? this.isSwitchingQuality,
      activeError: activeError ?? this.activeError,
      slotStates: slotStates ?? this.slotStates,
    );
  }
}

import 'player_play_mode.dart';
import 'player_quality_option.dart';
import 'player_queue_snapshot.dart';
import 'player_queue_source.dart';
import 'player_track.dart';

const defaultPlayerVolume = 1.0;
const defaultPlayerSpeed = 1.0;

class PlayerPlaybackState {
  const PlayerPlaybackState({
    required this.queue,
    required this.currentIndex,
    required this.historyCount,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.volume,
    required this.speed,
    required this.playMode,
    required this.currentAvailableQualities,
    required this.isRadioMode,
    this.queueSource,
    this.previousQueueSnapshot,
    this.currentSelectedQualityName,
    this.currentRadioId,
    this.currentRadioPlatform,
    this.currentRadioPageIndex,
    this.previousPlayModeBeforeRadio,
    this.previousPreviewIndex,
    this.nextPreviewIndex,
    this.errorMessage,
  });

  final List<PlayerTrack> queue;
  final int currentIndex;
  final int historyCount;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double volume;
  final double speed;
  final PlayerPlayMode playMode;
  final List<PlayerQualityOption> currentAvailableQualities;
  final bool isRadioMode;
  final PlayerQueueSource? queueSource;
  final PlayerQueueSnapshot? previousQueueSnapshot;
  final String? currentSelectedQualityName;
  final String? currentRadioId;
  final String? currentRadioPlatform;
  final int? currentRadioPageIndex;
  final PlayerPlayMode? previousPlayModeBeforeRadio;
  final int? previousPreviewIndex;
  final int? nextPreviewIndex;
  final String? errorMessage;

  PlayerTrack? get currentTrack {
    if (queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length) {
      return null;
    }
    return queue[currentIndex];
  }

  PlayerPlaybackState copyWith({
    List<PlayerTrack>? queue,
    int? currentIndex,
    int? historyCount,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    double? volume,
    double? speed,
    PlayerPlayMode? playMode,
    List<PlayerQualityOption>? currentAvailableQualities,
    bool? isRadioMode,
    PlayerQueueSource? queueSource,
    bool clearQueueSource = false,
    PlayerQueueSnapshot? previousQueueSnapshot,
    bool clearPreviousQueueSnapshot = false,
    String? currentSelectedQualityName,
    bool clearCurrentSelectedQuality = false,
    String? currentRadioId,
    bool clearCurrentRadioId = false,
    String? currentRadioPlatform,
    bool clearCurrentRadioPlatform = false,
    int? currentRadioPageIndex,
    bool clearCurrentRadioPageIndex = false,
    PlayerPlayMode? previousPlayModeBeforeRadio,
    bool clearPreviousPlayModeBeforeRadio = false,
    int? previousPreviewIndex,
    bool clearPreviousPreviewIndex = false,
    int? nextPreviewIndex,
    bool clearNextPreviewIndex = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerPlaybackState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      historyCount: historyCount ?? this.historyCount,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      playMode: playMode ?? this.playMode,
      currentAvailableQualities:
          currentAvailableQualities ?? this.currentAvailableQualities,
      isRadioMode: isRadioMode ?? this.isRadioMode,
      queueSource: clearQueueSource ? null : queueSource ?? this.queueSource,
      previousQueueSnapshot: clearPreviousQueueSnapshot
          ? null
          : previousQueueSnapshot ?? this.previousQueueSnapshot,
      currentSelectedQualityName: clearCurrentSelectedQuality
          ? null
          : currentSelectedQualityName ?? this.currentSelectedQualityName,
      currentRadioId: clearCurrentRadioId
          ? null
          : currentRadioId ?? this.currentRadioId,
      currentRadioPlatform: clearCurrentRadioPlatform
          ? null
          : currentRadioPlatform ?? this.currentRadioPlatform,
      currentRadioPageIndex: clearCurrentRadioPageIndex
          ? null
          : currentRadioPageIndex ?? this.currentRadioPageIndex,
      previousPlayModeBeforeRadio: clearPreviousPlayModeBeforeRadio
          ? null
          : previousPlayModeBeforeRadio ?? this.previousPlayModeBeforeRadio,
      previousPreviewIndex: clearPreviousPreviewIndex
          ? null
          : previousPreviewIndex ?? this.previousPreviewIndex,
      nextPreviewIndex: clearNextPreviewIndex
          ? null
          : nextPreviewIndex ?? this.nextPreviewIndex,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static PlayerPlaybackState initial(List<PlayerTrack> tracks) {
    return PlayerPlaybackState(
      queue: tracks,
      currentIndex: 0,
      historyCount: 0,
      isPlaying: false,
      isLoading: false,
      position: Duration.zero,
      duration: Duration.zero,
      volume: defaultPlayerVolume,
      speed: defaultPlayerSpeed,
      playMode: PlayerPlayMode.sequence,
      currentAvailableQualities: const <PlayerQualityOption>[],
      isRadioMode: false,
      queueSource: null,
      previousQueueSnapshot: null,
      previousPlayModeBeforeRadio: null,
      previousPreviewIndex: null,
      nextPreviewIndex: null,
    );
  }
}

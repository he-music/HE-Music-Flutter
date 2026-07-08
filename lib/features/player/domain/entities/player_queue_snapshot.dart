import 'player_play_mode.dart';
import 'player_queue_source.dart';
import 'player_track.dart';

class PlayerQueueSnapshot {
  const PlayerQueueSnapshot({
    required this.queue,
    required this.currentIndex,
    required this.playMode,
    required this.isRadioMode,
    this.source,
    this.previousSnapshot,
    this.currentRadioId,
    this.currentRadioPlatform,
    this.currentRadioPageIndex,
    this.previousPlayModeBeforeRadio,
  });

  final List<PlayerTrack> queue;
  final int currentIndex;
  final PlayerPlayMode playMode;
  final bool isRadioMode;
  final PlayerQueueSource? source;
  final PlayerQueueSnapshot? previousSnapshot;
  final String? currentRadioId;
  final String? currentRadioPlatform;
  final int? currentRadioPageIndex;
  final PlayerPlayMode? previousPlayModeBeforeRadio;

  bool get isEmpty => queue.isEmpty;
}

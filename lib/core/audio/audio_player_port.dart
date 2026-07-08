import 'audio_track.dart';
import '../../features/lyrics/domain/entities/lyric_document.dart';
import '../../features/lyrics/domain/entities/lyric_request.dart';

class CurrentLyricStateSnapshot {
  const CurrentLyricStateSnapshot({
    this.request,
    this.document = const LyricDocument.empty(),
    this.isLoading = false,
    this.errorMessage,
  });

  final LyricRequest? request;
  final LyricDocument document;
  final bool isLoading;
  final String? errorMessage;
}

abstract class AudioPlayerPort {
  Stream<bool> get playingStream;
  Stream<bool> get loadingStream;
  Stream<bool> get completedStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<int?> get currentIndexStream;
  Stream<dynamic> get customEventStream;
  Future<CurrentLyricStateSnapshot> getCurrentLyricState();

  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  });
  Future<void> setSource(AudioTrack track);
  Future<void> playAt(int index);
  Future<void> seekToNext();
  Future<void> seekToPrevious();
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  Future<void> setSingleLoop(bool enabled);
  Future<void> setShuffle(bool enabled);
  Future<void> dispose();
}

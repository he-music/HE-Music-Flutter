import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../error/app_exception.dart';
import '../error/failure.dart';
import 'audio_player_port.dart';
import 'audio_player_factory.dart';
import 'audio_track.dart';

class JustAudioPlayerAdapter implements AudioPlayerPort {
  static const _positionPeriod = Duration(milliseconds: 33);

  JustAudioPlayerAdapter() : _player = createHeAudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<bool> get playingStream => _player.playingStream.distinct();

  @override
  Stream<bool> get loadingStream {
    return _player.playerStateStream.map((state) {
      final processingState = state.processingState;
      return processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering;
    }).distinct();
  }

  @override
  Stream<bool> get completedStream {
    return _player.playerStateStream.map((state) {
      return state.processingState == ProcessingState.completed;
    }).distinct();
  }

  @override
  Stream<Duration> get positionStream {
    return _player.createPositionStream(
      minPeriod: _positionPeriod,
      maxPeriod: _positionPeriod,
    );
  }

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<dynamic> get customEventStream => const Stream<dynamic>.empty();

  @override
  Future<CurrentLyricStateSnapshot> getCurrentLyricState() async {
    return const CurrentLyricStateSnapshot();
  }

  @override
  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    if (tracks.isEmpty) {
      throw const AppException(
        ValidationFailure('Track queue cannot be empty.'),
      );
    }
    final maxIndex = tracks.length - 1;
    if (initialIndex < 0 || initialIndex > maxIndex) {
      throw const AppException(
        ValidationFailure('Initial index is out of range for the track queue.'),
      );
    }
    final sources = tracks.map(_buildSource).toList(growable: false);
    await _player.setAudioSources(
      sources,
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
    );
  }

  @override
  Future<void> setSource(AudioTrack track) async {
    await setQueue(<AudioTrack>[track]);
  }

  @override
  Future<void> playAt(int index) async {
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  @override
  Future<void> seekToNext() async {
    if (!_player.hasNext) {
      throw const AppException(ValidationFailure('No next track available.'));
    }
    await _player.seekToNext();
  }

  @override
  Future<void> seekToPrevious() async {
    if (!_player.hasPrevious) {
      throw const AppException(
        ValidationFailure('No previous track available.'),
      );
    }
    await _player.seekToPrevious();
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  @override
  Future<void> setSingleLoop(bool enabled) async {
    await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    if (enabled) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }

  UriAudioSource _buildSource(AudioTrack track) {
    final artwork = track.artworkUrl?.trim() ?? '';
    final artUri = artwork.isEmpty
        ? null
        : (Uri.tryParse(artwork)?.hasScheme == true
              ? Uri.parse(artwork)
              : Uri.file(artwork));
    return AudioSource.uri(
      Uri.parse(track.url),
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        artUri: artUri,
      ),
    );
  }
}

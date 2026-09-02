import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioSessionChannel = MethodChannel('com.ryanheise.audio_session');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioSessionChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioSessionChannel, null);
  });

  test('position stays at the target while seek is pending', () async {
    final originalPlatform = JustAudioPlatform.instance;
    final platform = _TestJustAudioPlatform();
    JustAudioPlatform.instance = platform;
    addTearDown(() => JustAudioPlatform.instance = originalPlatform);

    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    await player.setUrl('https://example.com/audio.mp3');
    unawaited(player.play());
    await Future<void>.delayed(Duration.zero);

    const target = Duration(seconds: 10);
    final seekFuture = player.seek(target);
    await platform.player.seekStarted.future;

    expect(player.position, target);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(player.position, target);

    platform.player.completeSeek();
    await seekFuture;
  });
}

class _TestJustAudioPlatform extends JustAudioPlatform {
  late final _SeekBlockingAudioPlayer player;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    player = _SeekBlockingAudioPlayer(request.id);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await player.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }
}

class _SeekBlockingAudioPlayer extends AudioPlayerPlatform {
  _SeekBlockingAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final seekStarted = Completer<void>();
  final _seekGate = Completer<void>();
  final _playGate = Completer<void>();

  Duration _position = Duration.zero;
  DateTime _updateTime = DateTime.now();
  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<VisualizerWaveformCaptureMessage> get visualizerWaveformStream =>
      const Stream<VisualizerWaveformCaptureMessage>.empty();

  @override
  Stream<VisualizerFftCaptureMessage> get visualizerFftStream =>
      const Stream<VisualizerFftCaptureMessage>.empty();

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _processingState = ProcessingStateMessage.loading;
    _emitEvent();
    _position = request.initialPosition ?? Duration.zero;
    _updateTime = DateTime.now();
    _processingState = ProcessingStateMessage.ready;
    _emitEvent();
    return LoadResponse(duration: const Duration(minutes: 3));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    await _playGate.future;
    return PlayResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    if (!seekStarted.isCompleted) seekStarted.complete();
    await _seekGate.future;
    _position = request.position ?? Duration.zero;
    _updateTime = DateTime.now();
    _emitEvent();
    return SeekResponse();
  }

  void completeSeek() {
    if (!_seekGate.isCompleted) _seekGate.complete();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async =>
      SetShuffleOrderResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async =>
          SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async =>
      SetAndroidAudioAttributesResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    if (!_seekGate.isCompleted) _seekGate.complete();
    if (!_playGate.isCompleted) _playGate.complete();
    await _events.close();
    return DisposeResponse();
  }

  void _emitEvent() {
    _events.add(
      PlaybackEventMessage(
        processingState: _processingState,
        updatePosition: _position,
        updateTime: _updateTime,
        bufferedPosition: _position,
        duration: const Duration(minutes: 3),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );
  }
}

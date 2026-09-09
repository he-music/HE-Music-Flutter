import 'dart:async';

// The fake implements the protocol used by the vendored player's real Dart API.
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

class NativeAudioTestPlatform extends JustAudioPlatform {
  final players = <String, NativeAudioTestPlayer>{};
  late NativeAudioTestPlayer current;
  Future<void> Function()? beforeDispose;
  Future<void> Function(LoadRequest request)? beforeLoad;
  Future<void> Function(LoadRequest request)? afterLoad;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    current = NativeAudioTestPlayer(request.id)
      ..beforeLoad = beforeLoad
      ..afterLoad = afterLoad;
    players[request.id] = current;
    return current;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await beforeDispose?.call();
    await players.remove(request.id)?.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }
}

class NativeAudioTestPlayer extends AudioPlayerPlatform {
  NativeAudioTestPlayer(super.id);

  final events = StreamController<PlaybackEventMessage>.broadcast();
  final playGate = Completer<void>();
  LoadRequest? lastLoad;
  Future<void> Function(LoadRequest request)? beforeLoad;
  Future<void> Function(LoadRequest request)? afterLoad;
  bool disposed = false;

  void emitError(int code) => events.add(event(errorCode: code));

  PlaybackEventMessage event({int? errorCode}) => PlaybackEventMessage(
    processingState: ProcessingStateMessage.ready,
    updatePosition: Duration.zero,
    updateTime: DateTime.now(),
    bufferedPosition: Duration.zero,
    duration: const Duration(minutes: 3),
    icyMetadata: null,
    currentIndex: 0,
    androidAudioSessionId: null,
    errorCode: errorCode,
    errorMessage: errorCode == null ? null : 'native decode failure',
  );

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;
  @override
  Stream<VisualizerWaveformCaptureMessage> get visualizerWaveformStream =>
      const Stream.empty();
  @override
  Stream<VisualizerFftCaptureMessage> get visualizerFftStream =>
      const Stream.empty();

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    await beforeLoad?.call(request);
    lastLoad = request;
    events.add(event());
    await afterLoad?.call(request);
    return LoadResponse(duration: const Duration(minutes: 3));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    await playGate.future;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();
  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();
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
  ) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();
  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();
  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async => ConcatenatingRemoveRangeResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    disposed = true;
    if (!playGate.isCompleted) playGate.complete();
    await events.close();
    return DisposeResponse();
  }
}

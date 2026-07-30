import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_spectrum_frame.dart';
import '../../../../core/audio/audio_spectrum_port.dart';
import '../providers/player_audio_provider.dart';
import '../providers/player_providers.dart';

enum RealtimeSpectrumStatus {
  idle,
  starting,
  running,
  stopping,
  unavailable,
  failed,
}

@immutable
class RealtimeSpectrumState {
  const RealtimeSpectrumState({required this.status, required this.bands});

  factory RealtimeSpectrumState.initial() {
    return RealtimeSpectrumState(
      status: RealtimeSpectrumStatus.idle,
      bands: AudioSpectrumFrame.zero.bands,
    );
  }

  final RealtimeSpectrumStatus status;
  final List<double> bands;
}

final realtimeSpectrumControllerProvider =
    NotifierProvider<RealtimeSpectrumController, RealtimeSpectrumState>(
      RealtimeSpectrumController.new,
    );

typedef _SpectrumPlaybackInput = ({
  String? trackKey,
  bool isPlaying,
  bool isLoading,
});

class RealtimeSpectrumController extends Notifier<RealtimeSpectrumState> {
  static const tickPeriod = Duration(milliseconds: 33);
  static const frameTimeout = Duration(milliseconds: 100);
  static const attackDuration = Duration(milliseconds: 70);
  static const releaseDuration = Duration(milliseconds: 200);
  static const zeroDuration = Duration(milliseconds: 300);
  static const _zeroEpsilon = 0.001;

  AudioSpectrumPort? _port;
  StreamSubscription<AudioSpectrumFrame>? _frameSubscription;
  Timer? _ticker;
  DateTime? _lastTickAt;
  DateTime? _lastFrameAt;
  List<double> _targetBands = AudioSpectrumFrame.zero.bands;
  _SpectrumPlaybackInput _playback = (
    trackKey: null,
    isPlaying: false,
    isLoading: false,
  );
  bool _consumerVisible = false;
  bool _captureStarted = false;
  bool _captureSyncRunning = false;
  bool _restartRequested = false;
  bool _startFailureBlocked = false;
  bool _fatalFailure = false;
  bool _disposed = false;

  @override
  RealtimeSpectrumState build() {
    _port = ref.read(audioSpectrumPortProvider);
    _playback = _readPlaybackInput();
    final port = _port;
    if (port != null) {
      _frameSubscription = port.spectrumFrameStream.listen(
        _acceptFrame,
        onError: (Object error, StackTrace _) {
          _fatalFailure = true;
          _startFailureBlocked = true;
          _clearTargetBands();
          _publishStatus(RealtimeSpectrumStatus.failed);
          _requestCaptureSync();
          _logFailure('stream', error);
        },
      );
    }
    ref.listen<_SpectrumPlaybackInput>(
      playerControllerProvider.select(
        (playback) => (
          trackKey: _trackKey(
            playback.currentTrack?.platform,
            playback.currentTrack?.id,
          ),
          isPlaying: playback.isPlaying,
          isLoading: playback.isLoading,
        ),
      ),
      (previous, next) => _handlePlaybackChanged(previous, next),
    );
    ref.onDispose(() {
      unawaited(_disposeController());
    });
    return RealtimeSpectrumState.initial();
  }

  void setConsumerVisible(bool visible) {
    if (_disposed || _consumerVisible == visible) {
      return;
    }
    _consumerVisible = visible;
    if (!visible) {
      _startFailureBlocked = false;
      _fatalFailure = false;
      _restartRequested = false;
      _clearTargetBands();
    }
    _requestCaptureSync();
  }

  _SpectrumPlaybackInput _readPlaybackInput() {
    final playback = ref.read(playerControllerProvider);
    return (
      trackKey: _trackKey(
        playback.currentTrack?.platform,
        playback.currentTrack?.id,
      ),
      isPlaying: playback.isPlaying,
      isLoading: playback.isLoading,
    );
  }

  void _handlePlaybackChanged(
    _SpectrumPlaybackInput? previous,
    _SpectrumPlaybackInput next,
  ) {
    final trackChanged = previous != null && previous.trackKey != next.trackKey;
    _playback = next;
    if (trackChanged) {
      // 原始 FFT 订阅带有音源 generation；切歌后必须重绑，旧帧才不会泄漏到新歌。
      _restartRequested = _captureStarted || _captureSyncRunning;
      _clearTargetBands();
    }
    if (!next.isPlaying || next.isLoading || next.trackKey == null) {
      _clearTargetBands();
    }
    _requestCaptureSync();
  }

  bool get _captureDesired {
    return !_disposed &&
        !_fatalFailure &&
        _port != null &&
        _consumerVisible &&
        _playback.trackKey != null &&
        _playback.isPlaying &&
        !_playback.isLoading;
  }

  bool get _needsCaptureSync {
    if (_captureStarted && (_restartRequested || !_captureDesired)) {
      return true;
    }
    return _captureDesired && !_captureStarted && !_startFailureBlocked;
  }

  void _requestCaptureSync() {
    if (_port == null) {
      if (_consumerVisible) {
        _publishStatus(RealtimeSpectrumStatus.unavailable);
      }
      return;
    }
    if (!_captureDesired) {
      _clearTargetBands();
      if (!_captureStarted &&
          !_captureSyncRunning &&
          !_fatalFailure &&
          !_startFailureBlocked) {
        _publishStatus(RealtimeSpectrumStatus.idle);
      }
    }
    if (_captureSyncRunning || !_needsCaptureSync) {
      return;
    }
    unawaited(_drainCaptureSync());
  }

  Future<void> _drainCaptureSync() async {
    _captureSyncRunning = true;
    try {
      while (_needsCaptureSync) {
        if (_captureStarted && (_restartRequested || !_captureDesired)) {
          await _stopCapture();
          _restartRequested = false;
          continue;
        }
        if (_captureDesired && !_captureStarted) {
          await _startCapture();
        }
      }
    } finally {
      _captureSyncRunning = false;
      if (_needsCaptureSync) {
        unawaited(_drainCaptureSync());
      }
    }
  }

  Future<void> _startCapture() async {
    final port = _port;
    if (port == null) {
      return;
    }
    _publishStatus(RealtimeSpectrumStatus.starting);
    try {
      await port.startSpectrumCapture();
      _captureStarted = true;
      if (!_disposed) {
        _publishStatus(RealtimeSpectrumStatus.running);
      }
    } catch (error) {
      _captureStarted = false;
      _startFailureBlocked = true;
      _clearTargetBands();
      _publishStatus(RealtimeSpectrumStatus.failed);
      _logFailure('start', error);
    }
  }

  Future<void> _stopCapture() async {
    final port = _port;
    if (port == null) {
      _captureStarted = false;
      return;
    }
    if (!_disposed) {
      _publishStatus(RealtimeSpectrumStatus.stopping);
    }
    try {
      await port.stopSpectrumCapture();
    } catch (error) {
      _fatalFailure = true;
      _logFailure('stop', error);
    } finally {
      _captureStarted = false;
    }
    if (!_disposed) {
      _publishStatus(
        _fatalFailure
            ? RealtimeSpectrumStatus.failed
            : RealtimeSpectrumStatus.idle,
      );
    }
  }

  void _acceptFrame(AudioSpectrumFrame frame) {
    if (!_captureStarted || !_captureDesired || _disposed) {
      return;
    }
    _targetBands = frame.bands;
    _lastFrameAt = DateTime.now();
    _ensureTicker();
  }

  void _clearTargetBands() {
    _targetBands = AudioSpectrumFrame.zero.bands;
    _lastFrameAt = null;
    if (_hasVisibleEnergy(state.bands)) {
      _ensureTicker();
    }
  }

  void _ensureTicker() {
    if (_ticker != null || _disposed) {
      return;
    }
    _lastTickAt = DateTime.now();
    _ticker = Timer.periodic(tickPeriod, _tick);
  }

  void _tick(Timer timer) {
    if (_disposed) {
      timer.cancel();
      _ticker = null;
      return;
    }
    final now = DateTime.now();
    final lastTickAt = _lastTickAt ?? now.subtract(tickPeriod);
    _lastTickAt = now;
    final measuredElapsed = now.difference(lastTickAt);
    final elapsed = measuredElapsed < tickPeriod ? tickPeriod : measuredElapsed;
    final frameIsStale =
        _captureStarted &&
        (_lastFrameAt == null || now.difference(_lastFrameAt!) > frameTimeout);
    final forceZero = !_captureDesired || frameIsStale;
    final target = forceZero ? AudioSpectrumFrame.zero.bands : _targetBands;
    final nextBands = List<double>.filled(AudioSpectrumFrame.bandCount, 0);
    var changed = false;
    var hasTargetEnergy = false;
    var hasOutputEnergy = false;

    for (var index = 0; index < AudioSpectrumFrame.bandCount; index += 1) {
      final current = state.bands[index];
      final desired = target[index];
      hasTargetEnergy = hasTargetEnergy || desired > _zeroEpsilon;
      final duration = forceZero
          ? zeroDuration
          : desired > current
          ? attackDuration
          : releaseDuration;
      final alpha = _smoothingAlpha(elapsed, duration);
      var next = current + (desired - current) * alpha;
      if (desired == 0 && next.abs() <= _zeroEpsilon) {
        next = 0;
      }
      nextBands[index] = next;
      hasOutputEnergy = hasOutputEnergy || next > _zeroEpsilon;
      changed = changed || (next - current).abs() > 0.000001;
    }

    if (changed) {
      state = RealtimeSpectrumState(
        status: state.status,
        bands: List<double>.unmodifiable(nextBands),
      );
    }
    if (!hasTargetEnergy && !hasOutputEnergy) {
      timer.cancel();
      _ticker = null;
      _lastTickAt = null;
    }
  }

  double _smoothingAlpha(Duration elapsed, Duration responseDuration) {
    final elapsedMs = math.max(1, elapsed.inMicroseconds) / 1000;
    final responseMs = responseDuration.inMicroseconds / 1000;
    // 对外配置的是用户感知的收敛时间，约五个指数时间常数后达到 99%。
    return 1 - math.exp(-5 * elapsedMs / responseMs);
  }

  bool _hasVisibleEnergy(List<double> bands) {
    return bands.any((value) => value > _zeroEpsilon);
  }

  void _logFailure(String operation, Object error) {
    developer.log(
      'Realtime spectrum $operation failed type=${error.runtimeType}',
      name: 'RealtimeSpectrumController',
    );
  }

  void _publishStatus(RealtimeSpectrumStatus status) {
    if (_disposed || state.status == status) {
      return;
    }
    state = RealtimeSpectrumState(status: status, bands: state.bands);
  }

  Future<void> _disposeController() async {
    _disposed = true;
    _consumerVisible = false;
    _restartRequested = false;
    _startFailureBlocked = false;
    _fatalFailure = false;
    _targetBands = AudioSpectrumFrame.zero.bands;
    _ticker?.cancel();
    _ticker = null;
    await _drainOrJoinCaptureSync();
    await _frameSubscription?.cancel();
    _frameSubscription = null;
  }

  Future<void> _drainOrJoinCaptureSync() async {
    while (_captureSyncRunning) {
      await Future<void>.delayed(Duration.zero);
    }
    if (_captureStarted) {
      await _stopCapture();
    }
  }

  static String? _trackKey(String? platform, String? id) {
    if (id == null) {
      return null;
    }
    return '${platform ?? ''}:$id';
  }
}

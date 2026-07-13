import 'dart:async';

import '../../../../core/audio/audio_handler_player_adapter.dart';
import '../../../../core/audio/audio_player_port.dart';
import '../../../lyrics_overlay/data/overlay_message.dart';
import 'player_controller_callback.dart';
import 'player_progress_manager.dart';

/// 音频流管理器。
///
/// 负责 AudioPlayerPort 的 StreamSubscription 生命周期管理（绑定、解绑）
/// 和底层事件处理。通过回调函数将事件转发给 Controller 处理。
class PlayerStreamManager {
  PlayerStreamManager({
    required AudioPlayerPort Function() audioPlayerReader,
    required Stream<OverlayMessage> Function() overlayMessageStreamReader,
    required PlayerControllerCallback Function() callbackReader,
    required PlayerProgressManager progressManager,
    required Future<void> Function(int? nextIndex) onCurrentIndexChanged,
    required void Function(dynamic event) onCustomEvent,
    required Future<void> Function() onPlaybackCompleted,
    required void Function(Object error, StackTrace stack) onStreamError,
    required void Function(Duration duration) onDurationChanged,
    required void Function(OverlayMessage message) onOverlayMessage,
  }) : _audioPlayerReader = audioPlayerReader,
       _overlayMessageStreamReader = overlayMessageStreamReader,
       _callbackReader = callbackReader,
       _progressManager = progressManager,
       _onCurrentIndexChanged = onCurrentIndexChanged,
       _onCustomEvent = onCustomEvent,
       _onPlaybackCompleted = onPlaybackCompleted,
       _onStreamError = onStreamError,
       _onDurationChanged = onDurationChanged,
       _onOverlayMessage = onOverlayMessage;

  final AudioPlayerPort Function() _audioPlayerReader;
  final Stream<OverlayMessage> Function() _overlayMessageStreamReader;
  final PlayerControllerCallback Function() _callbackReader;
  final PlayerProgressManager _progressManager;
  final Future<void> Function(int? nextIndex) _onCurrentIndexChanged;
  final void Function(dynamic event) _onCustomEvent;
  final Future<void> Function() _onPlaybackCompleted;
  final void Function(Object error, StackTrace stack) _onStreamError;
  final void Function(Duration duration) _onDurationChanged;
  final void Function(OverlayMessage message) _onOverlayMessage;

  /// position 更新最小间隔（约 60fps）。
  static const _positionUpdateMinDeltaMs = 16;

  /// 新鲜位置接受最大值。
  static const _freshPositionAcceptMaxMs = 800;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _loadingSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<dynamic>? _customEventSubscription;
  StreamSubscription<OverlayMessage>? _overlayMessageSub;

  bool _awaitingFreshPosition = false;
  int? _suppressedCurrentIndexEvent;

  /// 绑定所有音频流。在 initialize() 时调用。
  void bindStreams() {
    final audioPlayer = _audioPlayerReader();
    final callback = _callbackReader();

    _playingSubscription = audioPlayer.playingStream.listen((isPlaying) {
      callback.updateState((s) => s.copyWith(isPlaying: isPlaying));
    }, onError: _handleStreamError);

    _loadingSubscription = audioPlayer.loadingStream.listen((isLoading) {
      callback.updateState((s) => s.copyWith(isLoading: isLoading));
    }, onError: _handleStreamError);

    _customEventSubscription = audioPlayer.customEventStream.listen((event) {
      _onCustomEvent(event);
    }, onError: _handleStreamError);

    _currentIndexSubscription = audioPlayer.currentIndexStream.listen((
      nextIndex,
    ) {
      unawaited(_onCurrentIndexChanged(nextIndex));
    }, onError: _handleStreamError);

    _positionSubscription = audioPlayer.positionStream.listen((position) {
      if (_awaitingFreshPosition) {
        if (position.inMilliseconds > _freshPositionAcceptMaxMs) {
          return;
        }
        _awaitingFreshPosition = false;
      }
      final state = callback.currentState;
      final deltaMs = (position.inMilliseconds - state.position.inMilliseconds)
          .abs();
      if (deltaMs < _positionUpdateMinDeltaMs && position > Duration.zero) {
        return;
      }
      callback.updateState((s) => s.copyWith(position: position));
      _progressManager.onPositionUpdateFromStream(
        callback: callback,
        currentTrack: state.currentTrack,
        position: position,
        isPlaying: state.isPlaying,
      );
    }, onError: _handleStreamError);

    _durationSubscription = audioPlayer.durationStream.listen((duration) {
      if (duration == null || duration <= Duration.zero) {
        return;
      }
      callback.updateState((s) => s.copyWith(duration: duration));
      _onDurationChanged(duration);
    }, onError: _handleStreamError);

    if (audioPlayer is! AudioHandlerPlayerAdapter) {
      _completedSubscription = audioPlayer.completedStream.listen((completed) {
        if (!completed) {
          return;
        }
        unawaited(_onPlaybackCompleted());
      }, onError: _handleStreamError);
    }

    _overlayMessageSub = _overlayMessageStreamReader().listen(
      _handleOverlayMessage,
    );
  }

  /// 取消所有订阅。在 dispose 时调用。
  void dispose() {
    _playingSubscription?.cancel();
    _loadingSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completedSubscription?.cancel();
    _customEventSubscription?.cancel();
    _overlayMessageSub?.cancel();
  }

  /// 切歌后标记等待新的起始位置。
  void markFreshPositionPending() {
    _awaitingFreshPosition = true;
  }

  /// 抑制下一次 currentIndex 事件。
  void suppressNextCurrentIndexEvent(int index) {
    _suppressedCurrentIndexEvent = index;
  }

  /// 检查并清除抑制的 currentIndex 事件。
  bool checkAndClearSuppressedIndex(int index) {
    if (_suppressedCurrentIndexEvent == index) {
      _suppressedCurrentIndexEvent = null;
      return true;
    }
    _suppressedCurrentIndexEvent = null;
    return false;
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _onStreamError(error, stackTrace);
  }

  void _handleOverlayMessage(OverlayMessage msg) {
    _onOverlayMessage(msg);
  }
}

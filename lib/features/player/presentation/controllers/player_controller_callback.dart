import '../../domain/entities/player_playback_state.dart';

/// Manager 用来读取和更新 Controller 状态的接口。
///
/// 通过此接口，Manager 类可以与 Riverpod Notifier 解耦，
/// 不直接依赖 PlayerController 实现。
abstract class PlayerControllerCallback {
  /// 读取当前状态快照。
  PlayerPlaybackState get currentState;

  /// 通过 updater 函数原子更新状态。
  void updateState(
    PlayerPlaybackState Function(PlayerPlaybackState current) updater,
  );
}

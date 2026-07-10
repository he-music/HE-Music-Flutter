import '../../../../app/config/app_config_state.dart';
import '../../../lyrics/domain/entities/lyric_document.dart';
import '../../data/overlay_message.dart';

/// 悬浮歌词窗通信通道的抽象接口。
///
/// 封装了主进程与悬浮窗进程之间的消息传递能力，
/// 使 presentation 层不直接依赖 FlutterOverlayWindow 平台 API。
abstract class OverlayChannelService {
  /// 从悬浮窗流向主进程的消息流。
  Stream<OverlayMessage> get overlayToMainMessages;

  /// 悬浮窗权限是否已授予。
  Future<bool> isPermissionGranted();

  /// 请求悬浮窗权限。
  Future<bool?> requestPermission();

  /// 悬浮窗是否处于活跃状态。
  Future<bool> isActive();

  /// 打开悬浮窗。
  Future<void> open();

  /// 关闭悬浮窗。
  Future<void> close();

  /// 锁定悬浮窗位置。
  Future<void> lock();

  /// 解锁悬浮窗位置。
  Future<void> unlock();

  /// 发送歌词文档到悬浮窗。
  Future<void> sendDocument(
    LyricDocument document,
    AppConfigState config, {
    int? autoHighlightColorValue,
  });

  /// 发送播放进度到悬浮窗。
  Future<void> sendPosition(Duration position);

  /// 发送歌曲切换通知到悬浮窗。
  Future<void> sendTrackChanged({
    required String title,
    required String artist,
  });

  /// 发送样式更新到悬浮窗。
  Future<void> sendStyleUpdate(
    AppConfigState config, {
    int? autoHighlightColorValue,
  });

  /// 发送关闭指令到悬浮窗。
  Future<void> sendClose();
}

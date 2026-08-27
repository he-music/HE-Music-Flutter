class LayoutTokens {
  const LayoutTokens._();

  static const double compactPageGutter = 12;
  static const double listItemInnerGutter = 6;

  /// 歌曲动作、队列、下载菜单这类底部列表弹窗的统一最大高度比例。
  static const double actionSheetMaxHeightFactor = 0.60;

  /// 多歌手选择弹窗只承载短列表，保持比通用动作弹窗更轻。
  static const double artistSelectionSheetMaxHeightFactor = 0.52;

  /// 全屏播放器与其他宽屏工具切换桌面布局的统一断点。
  static const double desktopBreakpoint = 840;
}

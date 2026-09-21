class LayoutTokens {
  const LayoutTokens._();

  static const double compactPageGutter = 12;
  static const double listItemInnerGutter = 6;

  /// 歌曲动作、下载菜单这类底部列表弹窗的统一最大高度比例。
  static const double actionSheetMaxHeightFactor = 0.72;

  /// 选择列表与表单的最高单档高度。
  static const double selectionSheetMaxHeightFactor = 0.80;

  /// 播放器可滚动操作面板的单档高度，保留更多内容空间。
  static const double playerActionSheetHeightFactor = 0.72;

  /// 长列表和正文一次打开到高屏，材质跟随全局玻璃设置。
  static const double contentSheetHeightFactor = 0.88;

  /// 播放队列从所有入口一次打开到同一高度，不设中间停靠档位。
  static const double queueSheetHeightFactor = contentSheetHeightFactor;

  /// 多歌手选择按内容撑高，长列表最多占 72%。
  static const double artistSelectionSheetMaxHeightFactor = 0.72;

  /// 全屏播放器与其他宽屏工具切换桌面布局的统一断点。
  static const double desktopBreakpoint = 840;
}

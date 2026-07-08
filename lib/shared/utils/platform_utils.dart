import 'package:flutter/material.dart';

/// 是否应使用桌面端上下文菜单（而非底部弹出面板）
///
/// 规则：仅桌面平台（macOS/Windows/Linux）使用上下文菜单，宽度不再触发。
bool shouldUseDesktopMenu(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

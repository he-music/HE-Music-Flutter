# HE Music 本地补丁

基于 pub.dev `liquid_glass_widgets` **1.6.1**，保留原始 `lib/`、`shaders/`、包配置与许可证。应用通过根目录 `pubspec.yaml` 的 `dependency_overrides` 使用本副本。

本地改动：

- `GlassTextField`（含 `.search`）新增 `showFocusRing` 公共参数，默认 `true`，保持上游默认行为。
- `GlassFocusRegion` 接收该参数，仅控制焦点圈绘制，保留焦点监听、语义和键盘事件。
- 焦点圈外层 `Stack` 始终保留，避免显示或隐藏边框时重新创建输入框、丢失光标或输入法状态。

应用只在 `AppSearchField` 中控制该参数：Tab / Shift+Tab 导航进入时显示，点击或编辑时隐藏。不修改全局 `FocusManager.highlightStrategy`，其他玻璃控件继续使用默认焦点提示。

回归验证：`flutter test test/shared/widgets/app_search_field_focus_test.dart test/shared/widgets/app_search_field_test.dart test/shared/widgets/app_search_field_glass_test.dart`。

- `GlassDialog` 保留原生公共 API 和玻璃卡片，操作区改用无折射的 `CupertinoButton`，移除卡片内的玻璃按钮及其分组层，遵循项目禁止嵌套折射玻璃的规则。
- 对比上游默认实现，按钮背景填满等宽操作区域，标签居中；按钮高度至少 44，随字号和换行增长，避免玻璃背景缩成贴字小块及固定高度裁切文字。保留主操作与破坏性操作的颜色、点击回调和键盘焦点。
- 弹窗回归验证：`flutter test test/shared/widgets/app_alert_dialog_test.dart test/shared/widgets/app_glass_popups_test.dart test/features/settings/presentation/widgets/lyric_storage_settings_tile_test.dart`，覆盖浅色/深色、320 宽度、两倍字号及确认/取消返回值。

升级依赖时，还需检查上游弹窗是否消除了嵌套折射、按钮是否正确填满操作区并适配大字号，再移除弹窗补丁。

升级依赖时，应先检查上游是否提供等效的焦点圈配置及稳定的输入框子树，再移除本地覆盖。应用继续只导入包的公共入口，不依赖内部实现。

# HE Music 本地补丁

基于 pub.dev `liquid_glass_widgets` **1.16.0**，保留上游 `lib/`、`shaders/`、`ios/`、包配置、更新日志与许可证。应用通过根目录 `pubspec.yaml` 的 `dependency_overrides` 使用本副本；iOS 原生插件要求最低 iOS 15。

本地改动仅涉及以下三个源码文件：

- `lib/widgets/input/glass_text_field.dart`：`GlassTextField`（含 `.search`）新增 `showFocusRing` 公共参数，默认 `true`，保持上游默认焦点圈策略。
- `lib/widgets/shared/glass_focus_region.dart`：接收该参数，仅控制焦点圈绘制，保留上游焦点监听、语义和键盘事件。焦点圈外层 `Stack` 始终保留，减少显隐时对子树的结构调整。
- `lib/widgets/overlays/glass_dialog.dart`：保留原生公共 API 和 `GlassContainer.card`，操作区改用无折射的 `CupertinoButton`，移除卡片内的玻璃按钮及其分组层，遵循项目禁止嵌套折射玻璃的规则。

应用只在 `AppSearchField` 中控制 `showFocusRing`：Tab / Shift+Tab 导航进入时显示，点击或编辑时隐藏。不修改全局 `FocusManager.highlightStrategy`，其他玻璃控件继续使用上游默认焦点提示。

弹窗按钮背景填满操作区域，标签居中；按钮高度至少 44，随字号和换行增长，保留主操作与破坏性操作的颜色、点击回调和键盘焦点。同时保留上游 1.14.2 引入的标签测量：两个操作在并排空间不足时改为纵向排列。

回归验证：

```sh
flutter test test/shared/widgets/app_search_field_focus_test.dart test/shared/widgets/app_search_field_test.dart test/shared/widgets/app_search_field_glass_test.dart
flutter test test/shared/widgets/app_alert_dialog_test.dart test/shared/widgets/app_glass_popups_test.dart test/features/settings/presentation/widgets/lyric_storage_settings_tile_test.dart
```

覆盖搜索框导航与编辑切换、输入状态保留，以及弹窗浅色/深色、320 宽度、两倍字号、长标签和确认/取消返回值。

后续升级时，应先检查上游是否提供等效的焦点圈配置，再决定是否移除输入框补丁；1.16.0 的最小测试已确认上游焦点圈出现时仍保留 `EditableText` 状态，稳定 `Stack` 并非已证实的上游缺陷修复。还需检查上游弹窗是否消除了嵌套折射、按钮是否填满操作区并适配大字号，再移除弹窗补丁。应用继续只导入包的公共入口，不依赖内部实现。

# HE Music 本地补丁

基于 pub.dev `liquid_glass_widgets` **1.6.1**，保留原始 `lib/`、`shaders/`、包配置与许可证。应用通过根目录 `pubspec.yaml` 的 `dependency_overrides` 使用本副本。

本地改动：

- `GlassTextField`（含 `.search`）新增 `showFocusRing` 公共参数，默认 `true`，保持上游默认行为。
- `GlassFocusRegion` 接收该参数，仅控制焦点圈绘制，保留焦点监听、语义和键盘事件。
- 焦点圈外层 `Stack` 始终保留，避免显示或隐藏边框时重新创建输入框、丢失光标或输入法状态。

应用只在 `AppSearchField` 中控制该参数：Tab / Shift+Tab 导航进入时显示，点击或编辑时隐藏。不修改全局 `FocusManager.highlightStrategy`，其他玻璃控件继续使用默认焦点提示。

回归验证：`flutter test test/shared/widgets/app_search_field_focus_test.dart test/shared/widgets/app_search_field_test.dart test/shared/widgets/app_search_field_glass_test.dart`。

升级依赖时，应先检查上游是否提供等效的焦点圈配置及稳定的输入框子树，再移除本地覆盖。应用继续只导入包的公共入口，不依赖内部实现。

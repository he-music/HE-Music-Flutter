# Cupertino 控件覆盖核查

对照 [Flutter 官方 Cupertino 组件目录](https://docs.flutter.dev/ui/widgets/cupertino)，本轮已把共享适配接入实际业务入口。界面由用户选择的 `AppUiStyle` 决定；继续使用 Flutter SDK Material / Cupertino，不引入第三方界面依赖，也不修改 `ThemeData.platform` 模拟平台。

## 操作菜单

| 实际入口 | Cupertino 实现与保留行为 |
| --- | --- |
| [歌曲更多](../lib/shared/widgets/song_actions_sheet.dart) | 手机接入 `CupertinoActionSheet`，保留歌曲说明、禁用项、取消及 `SongActionsSheetController` 的关闭跟踪。 |
| [本地歌曲更多](../lib/features/music_library/presentation/pages/local_library_page.dart) | 播放、队列、分享和元数据编辑共用自适应菜单。 |
| [下载任务更多](../lib/features/download/presentation/pages/download_page.dart) | 原生操作菜单保留暂停、重试、分享、禁用态和删除文件的二次确认。 |
| [已下载歌曲操作](../lib/features/download/presentation/widgets/downloaded_music_content.dart) | 加入队列、重新下载和移除接入统一入口。 |
| [用户歌单更多](../lib/features/my/presentation/pages/user_playlist_detail_page.dart) | 编辑／删除接入原生菜单，保留默认歌单的删除限制及删除确认。 |
| [播放器更多](../lib/features/player/presentation/pages/player_page.dart) | 使用播放器专属主题的 `CupertinoActionSheet`。复用原有 Consumer、操作行和类型化返回值，保留实时倍速、音量、睡眠摘要、可用状态、播放器亮暗色板和系统栏保护；强调色取所选 Navigator 的应用主题，避免画布浅色影响亮色菜单对比。 |
| [多歌手选择](../lib/shared/helpers/song_artist_navigation_helper.dart) | 使用统一选择入口，保留歌手标签与选择返回值。 |
| [视频菜单](../lib/features/video/presentation/widgets/video_fullscreen_controls.dart) | 倍速、画面适配、音质及窄屏更多菜单接入共享入口，保留自动隐藏暂停／恢复、全屏和画中画流程。 |

桌面定位菜单继续保留鼠标位置和已有桌面交互。操作菜单使用 ActionSheet；复杂编辑、浏览和滚动面板继续使用适配后的底部面板。

## 输入、等待、刷新和播放控制

| 范围 | 实际接入与约束 |
| --- | --- |
| [普通输入与表单](../lib/shared/widgets/app_text_field.dart) | `AppTextField` / `AppTextFormField` 在 Cupertino 使用 SDK 输入控件；登录、资料、密码、元数据、歌词搜索、链接解析、歌单、扫描路径和皮肤编辑已接入。保留控制器、焦点、选区、组合输入、校验、自动填充和提交。 |
| 表单重置 | 重置恢复当前记录的初值或新控制器的初值；普通输入导致的重建不重新定义初值。控制器替换时同步 FormField 的值，不在构建期间通知上层 Form。 |
| [等待反馈](../lib/shared/widgets/app_activity_indicator.dart) | `AppLoadingIndicator` 及启动、搜索、歌词、设备等等待态使用共享指示器。Cupertino 使用 `CupertinoActivityIndicator`，保留尺寸、颜色、读屏标签及本地系统减少动画设置。 |
| [普通按钮](../lib/shared/widgets/app_button.dart) | 重试、下载、应用、保存及普通文本／图标动作使用共享按钮；Material 保留对应 SDK 按钮，Cupertino 使用 SDK 按钮，保留回调、禁用态、样式与图标位置。 |
| [下拉刷新](../lib/shared/widgets/app_refreshable_scroll_view.dart) | 首页、评论／回复和设备列表使用稳定的 sliver 结构；Cupertino 接入 `CupertinoSliverRefreshControl`，Material 保留 `RefreshIndicator`。保留控制器、空态、分页、错误态和滚动位置。 |
| 刷新请求顺序 | 首屏与重置刷新共享在途请求；过期分页响应不能覆盖刷新结果或推进游标。刷新失败保留旧内容，底部重试继续执行重置请求，成功后下一页为第 2 页。设备删除后仍执行新的列表刷新。 |
| [播放进度](../lib/features/player/presentation/widgets/player_progress_bar.dart) | Cupertino 使用原生滑块并单独绘制真实缓冲轨道；保留拖动预览、异步 seek 防回跳、键盘、RTL、读屏增减和禁用态。缓冲轨道与 SDK 滑块同宽并按文字方向绘制。 |
| 宽屏音量 | 使用 `AppSlider`，沿用局部 volume 监听和播放器颜色，不扩大页面重建范围。 |
| [GitHub 下载代理](../lib/features/settings/presentation/pages/github_download_acceleration_page.dart) | Cupertino 使用带勾选和 selected semantics 的原生列表行，与 Material 单选项共用代理配置及持久化逻辑。 |
| [对话框入口](../lib/shared/widgets/app_dialog.dart) | 业务确认与表单展示使用自适应入口，保留遮罩关闭策略、Navigator、返回值、焦点及键盘避让。`AppAlertDialog` 内的 Material 动作描述仍由共享组件转换。 |
| [滚动条](../lib/shared/widgets/app_scrollbar.dart) | 显式样式网格与桌面自动滚动条按用户风格选择；切换时保留滚动子树、浏览位置、输入内容和焦点。移动端自动滚动条的启用范围沿用 SDK 约定。 |

真实下载百分比、缓冲和 seek 进度继续表达可测量进度。系统 `MediaQuery.disableAnimations` 与应用内皮肤动画开关独立，皮肤开关不改变页面收到的系统减少动画设置。

## 保留的结构和可选优化

- 保留 `MaterialApp.router`、GoRouter、分支 Navigator、Riverpod 和路由观察器。
- 队列重排、歌单搜索选择、睡眠设置、样式网格、歌谱缩略图、评论回复和更新说明保留 `PopupRoute`、滚动、键盘及返回值语义。
- 歌谱页选择保留缩略图网格与选择回调，使用自适应面板及原有 0.55 高度上限；阅读器的翻页、缩放与全屏手势继续保留。
- `AppSearchField` 已使用 `CupertinoTextField`，保留清空、焦点、搜索提交和皮肤规则。未查到旧 `SearchInput` 的业务实例化调用，不把其内部旧 TextField 计入用户可见入口。
- 自定义睡眠时长已使用 `CupertinoPicker`。进一步改用 `CupertinoTimerPicker` 属于可选简化，不能改变 23:59 上限、零时长校验、循环选择和编辑值。
- 大标题导航、`CupertinoContextMenu` 长按预览和主要面向 macOS 的 `CupertinoRadio` 属于具体交互选择，无需为了组件目录覆盖率全部引入。
- 定制媒体视图、播放器美术和警告弹窗的动作描述可以保留对应 Material 类型；判定是否遗漏时应追踪实际渲染分支。

## 验证范围

组件与业务测试覆盖两种风格、输入与重置、原生菜单返回及取消、刷新竞态与失败重试、视频菜单、播放器缓冲与 seek、滚动及重建范围。本轮最终 `make analyze` 无问题，完整 `make test` 为 **3,070 通过、23 跳过**；格式检查及 `git diff --check` 通过。独立只读复核覆盖共享输入、菜单、刷新和播放器增量，未报告未解决的 P1/P2。`make player-interface-previews` 已导出双风格浅深色共 20 张真实组件截图；首页基线比较和 Cupertino 皮肤预览随完整测试通过。

自动化验证不代替真机的 IME、读屏、全屏／画中画和 profile 帧率验收；对应操作清单保留在 [界面风格验收](interface-style-acceptance.md)。

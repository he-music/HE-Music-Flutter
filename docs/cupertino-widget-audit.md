# Cupertino 控件覆盖核查

对照 [Flutter 官方 Cupertino 组件目录](https://docs.flutter.dev/ui/widgets/cupertino)，本轮已把共享适配接入实际业务入口。界面风格来源为“跟随系统平台／Material／Cupertino”：Apple 平台默认 Cupertino，其余平台默认 Material，用户手动选择优先，最终解析为 `AppUiStyle`；继续使用 Flutter SDK Material / Cupertino，不引入第三方界面依赖，也不修改 `ThemeData.platform` 模拟平台。

## 操作菜单

| 实际入口 | Cupertino 实现与保留行为 |
| --- | --- |
| [歌曲更多](../lib/shared/widgets/song_actions_sheet.dart) | 手机使用单层、可滚动的歌曲操作面板，Cupertino 按播放／内容导航／分享复制／移除分组；歌曲摘要和关闭入口固定，不再嵌套“更多操作”。无 MV 时隐藏对应入口，保留危险操作红色、背景开关及 `SongActionsSheetController` 的关闭跟踪。Material 共用操作数据，播放类图标使用应用主题色。 |
| [本地歌曲更多](../lib/features/music_library/presentation/pages/local_library_page.dart) | 接入共享歌曲面板，立即播放与下一首播放语义独立，保留加入队列、文件分享和元数据编辑。 |
| [下载任务更多](../lib/features/download/presentation/pages/download_page.dart) | 原生操作菜单保留暂停、重试、分享、禁用态和删除文件的二次确认。 |
| [已下载歌曲操作](../lib/features/download/presentation/widgets/downloaded_music_content.dart) | 加入队列、重新下载和移除接入统一入口。 |
| [用户歌单更多](../lib/features/my/presentation/pages/user_playlist_detail_page.dart) | 编辑／删除接入原生菜单，保留默认歌单的删除限制及删除确认。 |
| [播放器歌曲操作与播放设置](../lib/features/player/presentation/pages/player_page.dart) | 歌曲“更多”复用共享歌曲面板，省去重复的立即播放；倍速、音量、睡眠、音质和样式使用独立“播放设置”入口。保留播放器主题、系统栏保护、返回值及局部睡眠摘要监听。歌曲面板的 Material 强调色单独启用，不改变其他播放器面板的配色。 |
| [多歌手选择](../lib/shared/helpers/song_artist_navigation_helper.dart) | 使用统一选择入口，保留歌手标签与选择返回值。 |
| [视频菜单](../lib/features/video/presentation/widgets/video_fullscreen_controls.dart) | 倍速、画面适配、音质及窄屏更多菜单接入共享入口，保留自动隐藏暂停／恢复、全屏和画中画流程。 |

桌面定位菜单继续保留鼠标位置和已有桌面交互。短操作菜单使用 ActionSheet；复杂编辑、浏览和滚动面板继续使用适配后的底部面板。

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

## 音质选择与样式预览

- 播放和下载音质共用 `PlayerQualitySelectionSheet`，标题区固定显示“播放音质”或“下载音质”和关闭按钮。点击选项立即生效并关闭，直接关闭不修改选择。Cupertino 使用分组列表、内缩分隔线和强调色勾选，不重复展示每行的均衡器图标；格式、描述与文件大小使用次级文字。
- 样式预览保留三轴分类、实时预览和独立滚动位置。Cupertino 选项使用原生按钮按压反馈、强调色描边及实心勾选徽标；大字号减少列数并允许名称换行。选择即时应用，“完成”仅关闭面板。
- 多操作的“更多”使用分组功能面板；短小即时操作继续使用 `CupertinoActionSheet`，不把长设置列表塞入 ActionSheet。
- 播放器“播放设置”和歌词选项共用 `PlayerSheetSection`。分组项底色局部监听“显示内容背景”：关闭时透明，保留内缩分隔线和按压反馈；面板外壳始终不透明。切换该设置不重新挂载面板、不重置滚动位置。
- 歌词选项在 Cupertino 下分为“歌词来源／显示与同步”，固定显示标题和“完成”，使用原生列表、开关及图标；歌词底部入口和播放控制使用 Cupertino 按钮反馈。保留搜索／偏移跳转等待旧面板退出的顺序，以及嵌套字号、颜色、样式选择。逐字歌词开关有独立的必要配置监听，修改后立即更新显示。
- 音质、样式和“更多”继续通过 `showPlayerStyledBottomSheet`／`showAppThemedBottomSheet` 呈现，保留真实下拉关闭、`PopupRoute` 和安全区底色。取消先前仅绘制拖动条却没有拖动手势的 `showCupertinoModalPopup` 包装；原生操作表仍通过 Cupertino popup 呈现。
- 实际播放器入口回归验证音质关闭、样式完成、分组列表和拖动关闭；下载入口验证普通页面／播放器上下文、浅深色、取消及选择结果。

## 保留的结构和可选优化

- 保留 `MaterialApp.router`、GoRouter、分支 Navigator、Riverpod 和路由观察器。
- 队列重排、歌单搜索选择、睡眠设置、样式网格、歌谱缩略图、评论回复和更新说明保留 `PopupRoute`、滚动、键盘及返回值语义。
- 歌谱页选择保留缩略图网格与选择回调，使用自适应面板及原有 0.55 高度上限；阅读器的翻页、缩放与全屏手势继续保留。
- `AppSearchField` 已使用 `CupertinoTextField`，保留清空、焦点、搜索提交和皮肤规则。未查到旧 `SearchInput` 的业务实例化调用，不把其内部旧 TextField 计入用户可见入口。
- 自定义睡眠时长已使用 `CupertinoPicker`。进一步改用 `CupertinoTimerPicker` 属于可选简化，不能改变 23:59 上限、零时长校验、循环选择和编辑值。
- 大标题导航、`CupertinoContextMenu` 长按预览和主要面向 macOS 的 `CupertinoRadio` 属于具体交互选择，无需为了组件目录覆盖率全部引入。
- 定制媒体视图、播放器美术和警告弹窗的动作描述可以保留对应 Material 类型；判定是否遗漏时应追踪实际渲染分支。

## 验证范围

本轮 `flutter analyze` 无问题，完整 `flutter test --machine` 统计用户可见测试为 **3,079 通过、23 跳过**（不计测试运行器隐藏的加载项）。新增真实播放器入口与下载入口回归覆盖音质选中及关闭、Cupertino 分组、样式完成、大字号和真实拖动关闭。`git diff --check` 通过。双风格浅深色预览导出共 28 张，新增播放音质与下载音质截图，并核对 Cupertino 浅深色的列表分组、强调色选中、标题对齐、样式卡片和底部安全区。

另导出歌词选项的浅深色、内容背景开启／关闭共 4 张组件预览；回归测试验证背景设置切换不改变路由和滚动位置，歌词字号嵌套选择正确返回，逐字歌词开关及时同步。

自动化验证不代替真机的 IME、读屏、全屏／画中画和 profile 帧率验收；对应操作清单保留在 [界面风格验收](interface-style-acceptance.md)。

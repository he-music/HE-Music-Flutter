# 曲谱接入说明

“查看曲谱”入口位于歌曲操作菜单（歌曲详情、歌单等共用菜单、搜索结果，以及播放器“更多”菜单）。入口依据平台下发的能力位显示，不硬编码平台白名单。当前后端仅 QQ、网易云声明支持。

## 请求与模型

- 列表：`GET /v1/song/sheet-music?platform=qq&song_id=...`，不分页。
- 详情：`GET /v1/sheet-music?platform=qq&id=...&song_id=...`。
- 详情响应直接解码为 `SheetMusicInfo`，不读取 `info`。列表和详情复用此模型，缺失字段使用空字符串、空数组或 0。
- 列表打开详情时始终重新请求，保留列表所属的 `platform` 和原歌曲 `song_id`。所有 ID 在模型、Provider 参数、路由和请求中均使用字符串。
- 两个新能力位沿用 `PlatformFeatureSupportFlag` 的 BigInt 实现：`listSheetMusic = BigInt.one << 49`、`getSheetMusic = BigInt.one << 50`。
- 列表入口只要求列表能力；详情点击和直接访问详情路由都要求详情能力，并检查歌曲及曲谱 ID。

请求复用 `apiDioProvider`，沿用认证、语言、超时、验证码及刷新 Token 等拦截器。页面使用 Riverpod 的按请求参数区分的 `FutureProvider.autoDispose.family`；失败由页面处理，沿用 `NetworkErrorMessage` 并提供显式重试。曲谱请求关闭 Riverpod 的后台自动重试，避免持续调用尚未实现的平台接口。

## 状态与阅读行为

| 场景 | 显示或行为 |
| --- | --- |
| 请求中 | 列表条目或详情信息、谱面与工具栏骨架；图片解码期间显示谱面骨架 |
| 成功且列表为空 | 暂无曲谱 |
| HTTP 501 或响应明确标记 NotImplemented / NOT_IMPLEMENTED | 曲谱功能暂未开放，可重试 |
| 其他网络错误 | 项目通用网络错误信息，可重试 |
| 平台未声明所需能力 | 不显示列表入口；直接访问受保护路由显示不支持提示 |
| 详情 `page_urls` 为空 | 曲谱资源暂不可用，不猜测图片地址 |
| 详情有页面 | 保持 `page_urls` 顺序，单页横向翻页；点击图片进入多图全屏阅读 |
| 图片加载失败 | 图片级错误提示和重试，不影响其他页面 |
| `bpm = 0` | 不显示速度信息 |

列表仅显示有值的元数据，不显示上传者。列表将原调和总页数合并为一行，如 `C调 · 10页`；没有原调时只显示 `10页`，没有页数时只显示调，两者都没有则隐藏该行。详情在谱面上方直接显示歌曲名、上传者、原调、速度和后端声明的总页数，信息自动换行，不重复与标题相同的歌曲名；曲谱模型不包含 artist 字段。阅读页码以实际可读取的图片数计算；即使 `page_count` 更大，也不会构造额外页面。

曲谱内容使用普通 Material 控件：AppBar、IconButton、TextButton、OutlinedButton 和 showModalBottomSheet，不为翻页、下载、信息或重试添加玻璃表面。页面仅沿用现有 `DetailPageShell`，全局玻璃启用时由该共享外壳处理；全屏图片查看器使用普通 Scaffold。页面只监听曲谱请求、所需平台能力和语言，不监听播放进度，也不使用应用内皮肤动画开关控制页面动画。

## 阅读与保存

- 底部使用紧凑、中性色工具栏提供上一页、下一页、实际页码、放大/整页切换和下载全部；点击页码打开缩略图跳转。普通阅读由曲谱壳的 SafeArea 消费全局外壳传入的底部占用空间：玻璃模式避让浮动迷你播放器及系统安全区，普通模式沿用原生 Scaffold 已扣除的播放器高度，不重复留白；全屏时只避让系统安全区。
- 骨架复用共享 SkeletonBox；仅跟随系统“减少动画”设置停用渐变动画，与应用内“皮肤动画”开关独立。加载骨架使用局部重绘边界，完成请求后即移除。
- 使用成熟组件 `photo_view` 的 `PhotoViewGallery.builder` 处理双指缩放、双击缩放、拖动与翻页手势，不维护自建手势识别器或缩放动画。放大后可平移谱面，拖到图片边界后可继续翻页；按钮及键盘方向键也可切页。
- 系统“减少动画”设置下，按钮翻页和全屏转场直接切换；图片内部交互采用 PhotoView 自带的缩放行为。
- 全屏从当前页开始，左右滑动连续阅读所有图片；点击图片隐藏/恢复工具栏，返回后同步详情页页码。全屏覆盖迷你播放器，音频播放继续。
- 详情使用独立、统一的阅读底色，避免皮肤壁纸在顶部形成割裂色块；标题与标签放在同一条导航栏，歌曲名、上传者、原调、速度和页数紧凑显示在谱面上方，不再通过更多按钮打开面板。默认采用 PhotoView 的 contained 整页总览，可切换到 covered 放大模式并从页面顶端阅读；切换模式和进出全屏均保留当前页码。
- “下载全部”位于底部右侧，替代重复的全屏按钮；点击谱面进入全屏，支持悬停提示和辅助功能操作。全屏提供“保存当前页”。保存数量来自实际 `page_urls`。
- 移动端复制原图到相册；iOS 仅请求添加照片权限，Android 10+ 使用 MediaStore 写入新文件，不申请相册读取权限。桌面端选择目录后，在独立曲谱文件夹中按 `标题_001.png` 等页序保存，扩展名由实际图片格式识别。
- 每批只选择一次保存位置。显示已处理页数、完成数量和失败数量；重试只处理失败页，复用同一保存位置；取消目录选择恢复之前的任务状态。
- 图片下载使用独立 Dio 传输，不向第三方图片 URL 添加 API Bearer Token；仅将可识别的图片字节写入目标，不保存空响应或 HTML 错误页。
- 下载状态只在按钮与结果提示处监听，测试验证进度更新不会重建阅读器。页面已关闭时，已开始的批量保存仍继续完成。

曲谱数据契约已删除 `artist`，模型、JSON 解析、UI 和 mock 均同步移除；本仓库没有 JS 曲谱客户端或 Protobuf 生成客户端，无需重新生成代码。

## 正式请求与测试数据

正式运行始终使用真实接口，没有演示数据开关或失败后自动切换 mock 的逻辑。后端尚未实现时显示未开放状态。

mock 仅位于 `test/features/sheet_music/`，通过显式覆盖 `sheetMusicRepositoryProvider` 或测试 Dio 拦截器注入，不进入生产构建。运行应用与运行测试即可明确区分：

```sh
# 正式 API；仓库 Makefile 会读取 .env
flutter run --dart-define-from-file=.env

# mock 接口契约和页面状态验证
flutter test test/features/sheet_music \
  test/features/online/domain/entities/online_platform_test.dart \
  test/shared/helpers/song_detail_navigation_helper_test.dart

# Chrome 中验证 BigInt 高位解析和能力判断
flutter test --platform chrome test/web/online_platform_test.dart

# 仓库完整检查
make analyze
make test
```

可选生成阅读区域布局预览（仅测试夹具；本地谱面路径不会进入应用或提交到仓库）：

```sh
flutter test test/features/sheet_music/presentation/sheet_music_page_test.dart \
  --plain-name 'compact neutral reading layout' \
  --dart-define=GENERATE_SHEET_MUSIC_PREVIEWS=true \
  --dart-define=SHEET_MUSIC_PREVIEW_IMAGE=/path/to/score.png
```

输出到 `build/sheet_music_previews/reading.png`、`fit-page.png` 和 `with-mini-player.png`。前两张仅包含曲谱区域，第三张包含真实迷你播放器及玻璃外壳的底部避让；均不模拟操作系统状态栏。页面回归测试还覆盖玻璃与普通模式、底部安全区、大字体、播放器显隐和全屏切换。

平台返回实际资源后，需使用真实账号和歌曲补充端到端联调，确认图片鉴权、加载及真机缩放效果。

## 修改文件清单

新增曲谱模块：

- `lib/features/sheet_music/domain/entities/sheet_music_info.dart`
- `lib/features/sheet_music/domain/entities/sheet_music_not_implemented_exception.dart`
- `lib/features/sheet_music/domain/repositories/sheet_music_repository.dart`
- `lib/features/sheet_music/data/datasources/sheet_music_api_client.dart`
- `lib/features/sheet_music/data/repositories/sheet_music_repository_impl.dart`
- `lib/features/sheet_music/data/providers/sheet_music_providers.dart`
- `lib/features/sheet_music/presentation/providers/sheet_music_providers.dart`
- `lib/features/sheet_music/presentation/pages/sheet_music_page.dart`
- `lib/features/sheet_music/domain/entities/sheet_music_download_state.dart`
- `lib/features/sheet_music/domain/repositories/sheet_music_download_repository.dart`
- `lib/features/sheet_music/data/repositories/sheet_music_download_repository_impl.dart`
- `lib/features/sheet_music/presentation/controllers/sheet_music_download_controller.dart`
- `lib/features/sheet_music/presentation/widgets/sheet_music_reader.dart`
- `lib/features/sheet_music/presentation/widgets/sheet_music_loading.dart`
- `lib/features/sheet_music/presentation/widgets/sheet_music_download_button.dart`

现有入口、能力位和路由：

- `lib/features/online/domain/entities/online_platform.dart`
- `lib/shared/helpers/song_detail_navigation_helper.dart`
- `lib/shared/helpers/detail_song_action_handler.dart`
- `lib/shared/widgets/song_actions_sheet.dart`
- `lib/features/online/presentation/pages/online_search_song_actions.dart`
- `lib/features/online/presentation/pages/online_search_page.dart`
- `lib/features/player/presentation/pages/player_page.dart`
- `lib/app/router/app_routes.dart`
- `lib/app/router/app_router.dart`
- `lib/app/i18n/app_i18n.dart`

测试与说明：

- `test/features/sheet_music/data/sheet_music_api_client_test.dart`
- `test/features/sheet_music/presentation/sheet_music_page_test.dart`
- `test/features/sheet_music/data/sheet_music_download_repository_test.dart`
- `test/features/sheet_music/presentation/sheet_music_download_controller_test.dart`
- `test/features/sheet_music/presentation/sheet_music_reader_test.dart`
- `test/features/sheet_music/presentation/cache_sheet_images.dart`（加载成功的图片测试夹具）
- `pubspec.yaml` / `pubspec.lock`（使用 photo_view 画廊；将原有间接依赖 mime 声明为直接依赖，用于识别原图格式）
- `test/features/online/domain/entities/online_platform_test.dart`
- `test/shared/helpers/song_detail_navigation_helper_test.dart`
- `test/web/online_platform_test.dart`
- `test/web/flutter_test_config.dart`（独立浏览器测试不加载原生 SQLite 夹具）
- `docs/sheet-music.md`
- `.gitignore`（允许提交本说明）

# 仓库指南

## 项目结构与模块组织
`lib/` 存放应用源码。`lib/app/` 用于启动、路由、主题和全局配置，`lib/core/` 放置音频、网络、错误处理等共享基础设施，`lib/features/` 按功能划分业务模块，`lib/shared/` 存放可复用组件、辅助方法、模型和工具。测试位于 `test/`，尽量与源码路径保持对应，例如 `test/app/config/app_config_data_source_test.dart`。静态资源放在 `assets/`，平台壳工程保留在 `android/`、`ios/` 和 `macos/`。`third_party/flutter_lyric/` 是本地覆盖依赖，应按 vendored code 对待。

## 构建、测试与开发命令
优先使用 `Makefile` 中定义的入口命令：

- `make get`：安装或刷新 Dart、Flutter 依赖。
- `make run`：在当前选定设备上启动应用。
- `make analyze`：按仓库静态检查规则执行分析。
- `make test`：运行完整 Flutter 测试集。
- `make format`：使用 `dart format` 格式化 `lib/` 和 `test/`。
- `make fix`：应用 Dart 可安全自动修复项。
- `make gen`：通过 `build_runner` 重新生成代码。
- `make build-apk` / `make build-aab`：生成 Android Release 包。
- `make release-check`：发布前执行 `analyze` 和 `test` 校验。
- 用户明确要求发布正式版本时，确认目标版本号后执行 `./scripts/release.sh <x.y.z> --yes`；该脚本负责检查、版本提交、推送和创建 Tag。

## 编码风格与命名约定
遵循 `analysis_options.yaml` 中启用的 `flutter_lints` 规则。Dart 代码使用标准 2 空格缩进。文件名保持 `snake_case.dart`，类、枚举和类型别名使用 `UpperCamelCase`，方法、变量和 provider 使用 `lowerCamelCase`。保持现有的 feature-first 结构，优先沿用当前 Riverpod、GoRouter 和 repository 模式，不要额外引入平行抽象层。

## Material 与 Cupertino 界面风格

- 应用仅维护 Flutter SDK 的 Material 与 Cupertino 两种界面风格，不引入第三方液态玻璃渲染库。
- `AppUiStyle` 是用户明确选择的设计语言，独立于皮肤、主题色、深浅色、系统平台和皮肤动画。不得通过伪造 `ThemeData.platform` 实现风格切换。
- 优先在共享组件中适配两种风格，共用业务页面、GoRouter 和 Riverpod 状态。切换风格不得重新挂载 Navigator 或丢失播放、输入和浏览状态。
- Cupertino 的普通顶部标题栏跟随实际页面背景：透明壁纸页面使用透明标题栏并关闭背景模糊，经典或实色页面保留正常底色。底部导航、持续播放控制和弹窗面板保持稳定的不透明底色。复杂底部面板保留 PopupRoute 语义、键盘避让及返回值；不得直接全量换为 PageRoute 类型的 Cupertino Sheet。
- Material 使用全宽 M3 导航与贴合其上的播放条；Cupertino 使用全宽标签栏与独立浮动播放条。两者都正确覆盖或避让安全区，并在键盘开合时保持位置稳定。MiniPlayer 和播放器详情的队列共用 `showPlayerStyledBottomSheet`，播放器嵌套面板须保留主题标记、系统栏保护和弹层返回语义。
- “显示内容背景”控制全部 Cupertino 内容卡片，包括设置分组和功能入口；关闭后保留排版、分隔线和交互反馈。搜索输入框、固定播放控制、底栏及弹窗使用独立的控制表面。
- 规范与人工验收见 [界面风格设计决策](docs/adr/0010-use-sdk-interface-styles.md) 和 [验收指南](docs/interface-style-acceptance.md)。

## 动画设置的作用范围

- 应用内“皮肤动画”配置 `enableSkinAnimation` 仅控制当前皮肤背景的环境动画（如 Rive），不得用于控制页面转场、加载骨架、歌词、播放器效果、导航或标签动画。
- `MediaQuery.disableAnimationsOf(context)` / `MediaQueryData.disableAnimations` 表示操作系统的辅助功能“减少动画”设置，与皮肤动画开关独立；页面组件可据此减少或停用动画，皮肤动画也应尊重该系统设置。
- 不得将 `enableSkinAnimation` 映射或写入全局 `MediaQuery.disableAnimations`，也不得因关闭皮肤动画而停用其他页面的动画。
- 开发和审查时先追踪设置来源及作用范围；说明行为时明确区分“应用内皮肤动画开关”和“系统减少动画设置”。涉及两者的改动，应验证皮肤开关不改变页面收到的系统设置，且页面动画仍按系统设置正确更新。

## 避免无效重建
控制组件重建范围，避免高频状态变化导致无关 UI 重建。

编写或修改 Flutter UI 时：

- 不要在页面根组件监听仅局部 UI 使用的状态。
- Riverpod 优先使用 `select` 监听实际需要的字段，避免监听整个状态对象。
- 播放进度、动画帧、输入内容等高频状态，应下沉到最小消费组件。
- 不要因方便而扩大 `ref.watch`、`setState`、`Consumer` 或监听器的作用范围。
- 新增监听前，确认状态变化频率、实际依赖组件及重建子树大小。
- 回调、样式对象和派生集合避免在高频重建路径中重复执行昂贵计算。
- 低频且业务相关的重建可以接受，不为消除少量重建引入复杂抽象。

完成 UI 修改后检查：

1. 高频状态变化是否只重建必要组件。
2. 页面根组件是否新增了宽泛状态监听。
3. `select` 的结果是否足够稳定，避免返回每次新建的对象或集合。
4. 必要时通过 Flutter DevTools、重建计数测试或日志验证重建范围。

判断原则：状态变化时，不依赖该状态的组件不应随之重建；依赖该状态的 UI 必须及时、正确更新。不得以减少重建为由跳过必要监听、缓存过期状态或破坏业务状态同步。

验收标准：

- 高频无关状态不再触发目标 widget 重建。
- 必要业务状态变化仍正常更新。

## 测试指南
使用 `flutter_test` 编写单元测试和组件测试。测试文件命名为 `*_test.dart`，并尽量与被测源码路径对应。测试描述应聚焦具体行为，例如 `testWidgets('home shell renders with two tabs', ...)`。提交 PR 前至少运行 `make test`，代码变更同时运行 `make analyze`。

## 提交与 Pull Request 规范
当前历史中可见的提交格式是 Conventional Commits 风格，例如 `feat: init`；后续继续使用简短前缀，如 `feat:`、`fix:`、`refactor:`、`docs:`。提交消息的描述使用中文，并以清楚、完整地表达逻辑变更为准，不必刻意压缩到极短。PR 说明应写清改动范围、列出已执行命令，并关联相关 issue。涉及 UI 的改动应附截图或录屏；涉及配置或资源调整时，请明确说明如 `assets/app_config.json` 或 `env/` 的变化。

## 配置提示
不要在源码中硬编码环境相关值。执行 `flutter run` 时必须传入参数 `--dart-define-from-file=.env`。新增资源后要同步更新 `pubspec.yaml` 中的 assets 声明。涉及 Retrofit 或 JSON 模型生成代码的改动，通常都需要执行 `make gen`。生成图片时，使用 `openai-image-api` 这个 skill。

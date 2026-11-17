# 森林秘境 · Forest Sanctuary

这是一套应用全局皮肤。视觉方向为原创手绘动画电影中的森林秘境：树冠形成入口、林间流雾延伸空间，近处枝叶和萤光建立景深。全屏播放器继续由独立的播放器配置控制。

## 组成

- 日夜双场景：同一森林构图，白天为鼠尾草绿与奶油色散射光，夜间为翡翠、青蓝与暖萤光。
- 远景：森林与溪流保持静止，放在独立 RepaintBoundary 中，不再整张移动或随环境帧重新绘制。
- 中景：两层流雾以约 18 秒周期移动，稀疏萤光以约 9 秒周期明暗起伏，由原生 Canvas 绘制。
- 近景：两侧枝叶使用路径绘制，摆动幅度与远景不同，保留前后层次。
- 组件：纸色/苔绿控制表面、叶脉纹理、柔和圆角、森林配色和焦点反馈。关闭内容背景时，普通列表恢复透明；搜索框和固定控制保留独立材质。弹层保持不透明。
- 图标：9 个原生 SVG 构成统一的植物线条语言，覆盖三个主导航入口及搜索、播放控制、队列、收藏等角色。角色仍保留经典图标回退。资料库入口已接入共享皮肤图标角色。
- 首页直接展示搜索、来源与音乐内容，不显示固定开场文案；“在森林里，慢慢听”保留在皮肤介绍中。
- MiniPlayer 不透明度为夜间 76%、日间 80%，底部 Tab 为夜间 54%、日间 58%，两者都保留现有磨砂模糊。

Material 和 Cupertino 保留各自的 SDK 控件、导航与安全区约定。Cupertino 不新增装饰边框和阴影。

## 动画边界与性能

森林环境使用约 30 Hz 的定时绘制时钟，36 秒为一个完整运动周期；不使用随屏幕 90/120 Hz 持续唤醒的动画 ticker。时钟只通知 `CustomPainter(repaint:)`，静态森林图片保持独立缓存，页面和图片不在每帧重新 build。不监听播放进度，也不创建页面级 Riverpod 监听。

- 应用内“皮肤动画”只暂停/继续森林环境时钟，静止时仍显示完整场景。
- 系统“减少动画”优先，打开后暂停，关闭后恢复，不修改全局 MediaQuery。
- `TickerMode` 禁用或应用退到后台时暂停；销毁组件时释放时钟与生命周期观察器。
- 专项测试覆盖子组件不随动画重建、开关与系统偏好独立、实时减少动画切换、隐藏与后台暂停。
- 组件测试不代表功耗、温升或真机帧率。用户反馈发热后，先限制环境绘制频率并取消整张远景位移；仍需在真机比较长时间运行时的温度与耗电。当前没有等效 Rive 素材和功耗对照，不因使用 Dart 或 Rive 就推断哪种更省电。

以下数据来自本轮限制绘制频率之前的版本，不能作为耗电或温升验证。在连接的 Android 设备 `24122RKC7C` 上使用独立包名做了 Profile 采样，渲染器为 Impeller Vulkan，屏幕报告约 120 Hz。测试复用实际场景、主题与磨砂表面，使用静态列表和控制条；每种状态先预热 3 秒，再采样约 6 秒，两轮反向排序。

动效与磨砂同时开启时，两轮 UI 线程 P99 为 2.621–2.637 ms，raster 线程 P99 为 2.662–2.788 ms。该设备 120 Hz 对应的帧预算约 8.33 ms；这两轮共 1453 个采样帧中，有 3 帧的任一线程耗时超过预算。暂停场景时保留相同的 2×2 前景刷新探针，以维持可比较的帧提交。

这些数据仅反映这台设备的独立场景，不代表完整业务、滚动、播放或所有机型表现，也没有与等效 Rive 动画比较。raster 耗时不等同于完整 GPU 执行时长。原始指标与测试入口保留在本地 `.artifacts/forest-sanctuary/profile-summary.json` 和 `forest_profile/`；测试包已卸载。

## 素材与成本

森林日夜远景由 Pi `image-gen` 插件一次生成双联图集，返回 provider `openai`、model `gpt-image-2.6`。没有为两张图分别发起生成，也没有逐个生成图标。

原始图集保存在本地 `.artifacts/forest-sanctuary/forest-world-day-night-atlas.png`，实际尺寸 1536×1024。按左右两等分裁切为 768×1024 的日、夜远景，去元数据后保存为 JPEG quality 92；原图集不进入 Flutter 运行包。图标、组件叶脉、近景枝叶、雾和萤光均由本地 SVG/代码制作，不增加生成调用。

后续有位图装饰需求时，仍按固定网格整套生成和裁切，不采用逐个图标付费生成。功能性图标优先保持矢量和清晰的操作语义。

生成提示的关键约束：原创手绘动画电影背景；双联图集左右为相同构图的清晨与夜晚；巨大苔藓树木只在边缘，中间保留雾气与远处树木；林间小径与浅溪流入空地；下方蕨类、树根与野花形成前景。禁止人物、建筑、文字、UI、图标和 Logo。完整提示保留在生成会话。

## 真实界面预览

更新皮肤选择页所用的真实首页预览：

```sh
flutter test --update-goldens test/app/theme/skin_preview_golden_test.dart \
  --plain-name 'forest sanctuary previews match the real home scene'
```

导出两种界面风格、日夜模式下的首页、歌单、设置及宽屏页面：

```sh
flutter test --no-pub test/app/theme/skin_preview_golden_test.dart \
  --plain-name 'export immersive skin scenes' \
  --dart-define=SKIN_SCENE_PREVIEW_DIR=.artifacts/forest-sanctuary/previews \
  '--dart-define=MINI_PLAYER_PREVIEW_CJK_FONT=/System/Library/Fonts/STHeiti Light.ttc'
```

导出 240 帧、每帧间隔约 33.333ms（30fps，约 8 秒）的真实首页动画：

```sh
flutter test --no-pub test/app/theme/skin_preview_golden_test.dart \
  --plain-name 'export forest ambient motion' \
  --dart-define=FOREST_MOTION_PREVIEW_DIR=.artifacts/forest-sanctuary/motion \
  '--dart-define=MINI_PLAYER_PREVIEW_CJK_FONT=/System/Library/Fonts/STHeiti Light.ttc'
```

上述导出用例在常规回归中默认跳过；显式选中用例并启用 `--run-skipped` 时，也可使用默认的 `.artifacts/forest-sanctuary/` 输出目录。`export forest selection previews` 用于单独更新森林皮肤的首页缩略图。显式页面导出在未指定字体时可使用本机可用的完整中文字库，常规 golden 始终使用仓库字体。

字体路径可替换为当地可用的完整中文字体。预览使用固定测试数据；日常 golden 使用仓库字体，避免依赖系统中文字体。

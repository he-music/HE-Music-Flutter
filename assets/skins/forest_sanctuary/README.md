# 森林秘境 · Forest Sanctuary

这是一套应用全局皮肤，视觉方向为原创手绘动画电影中的森林秘境。背景、主题配色、图标、控件材质及环境动画共同组成主题；全屏播放器继续使用独立的播放器配置。

## 视觉组成

- 日夜场景采用同一森林构图：白天为鼠尾草绿与奶油色散射光，夜间为翡翠、青蓝与暖萤光。森林和溪流远景保持静止。
- 流雾、萤光及近景枝叶全部由 `ambient.riv` 承载，通过共享 `AppSkinRiveAnimation` 播放，与城市声场皮肤使用同一运行入口及 Flutter renderer。
- 恢复明亮的萤光光晕、较浓的流雾及更明显的枝叶摆动；萤光与近景锚点收进竖屏可见区域，避免 `BoxFit.cover` 的两侧裁切隐藏动效。日间 / 夜间 Rive 叠加不透明度分别为 85% / 96%，萤光光晕直径 36 个画板单位。
- 底部透明度通过共享 `AppSkinTheme` 调整：所有壁纸皮肤的 MiniPlayer 配置不透明度乘 0.90，底部 Tab 乘 0.85；纯色皮肤保持不透明，磨砂模糊参数沿用原值。
- 搜索框、播放条及内容表面采用纸色/苔绿、静态叶脉纹理和柔和圆角。静态叶脉仍由共享组件绘制，不创建动画时钟。
- 关闭内容背景时，普通列表保持透明；搜索框、固定播放控制和底栏保留独立表面，弹层不透明。
- MiniPlayer 不透明度为夜间 68.4%、日间 72%；底部 Tab 为夜间 45.9%、日间 49.3%。两者保留现有磨砂模糊。
- 9 个项目原创 SVG 构成植物线条图标语言，覆盖主导航、搜索、播放、队列和收藏等角色；其余角色沿用现有回退。
- 首页直接展示搜索、来源和音乐内容；“在森林里，慢慢听”保留在皮肤介绍中。
- Material 与 Cupertino 保留各自 SDK 控件、导航及安全区规则；Cupertino 不新增装饰边框和阴影。

## Rive 资源与制作

- 运行资源：`assets/skins/forest_sanctuary/ambient.riv`，38133 字节。
- SHA-256：`aa26cb4eb9b75dac48679185951e248be7cbb332871bd8ccc773ce520b1f6e42`。
- 两个透明画板：`ForestDay` / `ForestNight`，均为 768×1024，与森林远景同比例。
- 两个画板均使用 `AmbientLoop` 状态机，无输入；状态机自动进入 `forest_ambient` 循环。
- 动画时间轴：36 秒、30 fps；流雾以约 18 秒周期移动，萤光以约 9 秒周期起伏，枝叶缓慢摆动。时间轴 fps 不代表运行时被限制为每秒绘制 30 次。
- 只包含原创矢量形状、渐变及关键帧，不内嵌壁纸、字体、音频或外部文件。
- 可重建源：`scripts/generate_forest_ambient.mjs`。
- 制作工具：`rive-mcp-server` **0.3.0**，与城市声场资源记录使用同版本。其 Freeware License 允许个人/商业使用及无限制使用、修改、分发生成的 `.riv`；生成器自身及依赖不打入应用，也不纳入仓库。
- 二进制 lint 无发现；官方 Rive Web 运行时检查了两个画板、时间轴和状态机，并导出多时刻透明帧。Flutter 集成测试实际加载并推进两个画板。

重建资源：

```sh
npm install --prefix .artifacts/rive-tools rive-mcp-server@0.3.0 --ignore-scripts --no-audit --no-fund
node scripts/generate_forest_ambient.mjs
```

可用 `RIVE_GENERATOR_DIR` 指定生成器安装目录。不需要 Rive 云服务或图片生成调用。

## 动画控制与验证边界

不再保留森林专用的 Dart Timer、AnimationController、Flow 或环境 CustomPainter。Rive 复用统一加载、控制器缓存与销毁逻辑：

- 应用内“皮肤动画”只控制环境动画，不修改页面收到的系统减少动画设置。
- 系统“减少动画”、`TickerMode` 禁用或应用退到后台时停止 Rive 控制器；恢复后复用原控制器。
- 关闭动画、资源失败或解码失败时，静态森林壁纸及主题继续正常显示。
- Flutter 测试覆盖日夜实际资源、控制器复用、动画开关、系统减少动画、隐藏及后台恢复；旧城市声场 Rive 测试同时回归。
- 之前原生绘制版的短时 Profile 不适用于本 Rive 版本，也不证明温升或耗电。当前真机已断开，Rive 版本的持续运行功耗与温升仍待真机实测。

## 背景素材与成本

森林日夜远景由 Pi `image-gen` 插件一次生成双联图集，返回 provider `openai`、model `gpt-image-2.6`。原始图集为 1536×1024，保存在本地 `.artifacts/forest-sanctuary/forest-world-day-night-atlas.png`；按左右等分裁切为 768×1024 的日夜背景，去元数据后保存为 JPEG quality 92。原始图集不进入 Flutter 运行包。

图标、叶脉及 Rive 形状均由本地矢量/代码制作，没有逐个付费生图。后续位图装饰仍按固定网格整套生成与裁切，功能图标优先使用清晰的矢量轮廓。

## 真实界面预览

皮肤选择页缩略图由真实 Flutter 首页导出，常规 golden 使用仓库字体。导出用例日常跳过，显式选中并使用 `--run-skipped` 才会写入文件：

```sh
flutter test test/app/theme/skin_preview_golden_test.dart --run-skipped \
  --plain-name 'export wallpaper skin selection previews'
flutter test test/app/theme/skin_preview_golden_test.dart --run-skipped \
  --plain-name 'export immersive skin scenes'
flutter test test/app/theme/skin_preview_golden_test.dart --run-skipped \
  --plain-name 'export forest ambient motion'
```

真实页面默认导出至 `.artifacts/forest-sanctuary/previews`；动态导出先等待 Rive 成功加载，再按 30 fps 采样 240 帧至 `.artifacts/forest-sanctuary/motion`，约 8 秒。显式预览可使用本机完整中文字库，或以 `MINI_PLAYER_PREVIEW_CJK_FONT` 指定。所有预览使用固定示例数据，不代表真机帧率。

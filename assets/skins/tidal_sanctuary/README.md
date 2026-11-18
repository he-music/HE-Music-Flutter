# 潮汐秘境 · Tidal Sanctuary

一句话方向：在一片有日光、水流和生物微光的安静珊瑚海中听音乐。

## 场景与材质

- 同一海底沙道的两个时段。日间为浅青海水、海盐白光束和暖珊瑚；夜间为深海蓝、青紫珊瑚与浮游微光。夜间重新设计光照和颜色，未对日间图片简单加黑。
- 原创分层矢量插画承担静态环境：上方折射水纹、中景礁石、近景海扇/海草/管状珊瑚及贝壳。中央保留阅读空间，场景不整体缩放或平移。
- 明暗背景均为 900×1600，与透明 Rive 画板同比例、同锚点，使用 `BoxFit.cover` / `Alignment.center`。高屏只裁掉两侧少量内容；横屏保留海水光照，近景可能落在裁切区。
- 搜索与播放控件为海玻璃青/海盐白，强调色为海青、珍珠紫和暖珊瑚色。Material 使用圆润边缘、细描边与微弱阴影；Cupertino 沿用 SDK 组件与共享无描边规则。
- MiniPlayer 生效不透明度为日间 75.6%、夜间 72%；底部导航为日间 54.4%、夜间 52.7%，按共享乘数 0.90 / 0.85 计算；磨砂 sigma 为 12，滤镜局限在控件内。
- 应用和播放器弹窗使用同一皮肤配色，但分别维护绘制器。外壳不透明，顶部 168 逻辑像素内绘制少量静态潮纹与珍珠环，不增加动画或模糊。
- 九个原创 SVG 覆盖主导航、搜索、播放/暂停、队列、收藏、皮肤等高频角色，其余角色保留 SDK 回退。图标源色 `#438F9B` 由皮肤图标入口映射到所需主题色。
- 沿用业务页面、路由、播放器与 Riverpod 状态。首页没有宣传横幅。全屏播放器保留独立外观配置，弹窗跟随全局皮肤。
- “显示内容背景”仅影响普通内容；搜索、播放控制、导航和弹窗维持独立表面。

## 资源来源与许可

背景、图标、海草、鱼群、水母及粒子几何均为本项目新作的程序化矢量美术，完整源在 `scripts/generate_tidal_scenes.mjs`、`scripts/generate_tidal_ambient.mjs` 和 `scripts/tidal_fish_art.mjs`，随项目代码使用。没有使用第三方图片、字体、音频或嵌入式 UI。制作时尝试 image-gen，其配置的 `gpt-image-2.6` 无法加载，未返回图片；最终资源全部来自原创脚本。

场景脚本以固定种子 2718 生成两张 SVG，使用 librsvg 栅格化，再以 ImageMagick JPEG quality 91、4:2:0 去元数据压缩。原始 SVG/PNG、双联图集和视频留在 `.artifacts/tidal-sanctuary/`，不打入运行包。只有选用的 JPEG、Rive、SVG 图标与真实首页缩略图在 `pubspec.yaml` 中声明。

Rive 制作工具沿用本仓库的 `rive-mcp-server` 0.3.0，仅在本地制作目录安装。其 Freeware License 允许个人/商业使用，以及无限制使用、修改和分发生成的 `.riv`。未修改或随应用分发生成器本身。Rive runtime 沿用项目现有依赖。

## Rive 与重建

- 运行文件 `ambient.riv` 为 312,614 字节，两个透明画板 `TidalDay` / `TidalNight`，均为 900×1600。
- 状态机均为 `AmbientLoop`，无输入，从入口自动进入 `tidal_current` 循环；时间轴 24 秒、30 fps。时间轴采样率不等于设备运行帧率。
- 日间：11 个有色轮廓气泡分别以 12/24 秒周期上升、横向漂移，入场及复位前完全渐隐；小丑鱼、蓝吊鱼和两条远景花鲈有独立关节与体色。近景海草随水流微摆。
- 夜间：保留小丑鱼和蓝吊鱼，以低饱和暖色、月光蓝和金色尾鳍表现暗部体色；15 个青/紫浮游微光独立漂移与明灭，两只小水母缓慢浮动。近景海草幅度更低。
- 鱼体是有鳃、眼睛、条纹及渐变明暗的原创矢量美术，鳍上有半透明膜和鳍条；不再使用静态鱼影。390×844 预览中两条主体鱼约 70–90 逻辑像素长，主要游动范围在首页音乐列表下方的开阔海水，远景花鲈更小。
- 鱼群沿连续弧线游过海水，朝向随前进速度变化，转弯时通过透视压缩逐渐转身；没有倒着横滑或在原地反复缩放整条鱼。鱼体、尾柄、尾鳍、背鳍和胸鳍分别成组，尾柄与尾鳍有相位差。小丑鱼尾拍周期 0.8 秒、蓝吊鱼 1 秒、胸鳍 1.2 秒，快动作每 3 个时间轴帧采样，与缓慢的游动轨迹独立。
- 所有关键帧使用可复现参数；周期均整除 24 秒时间轴，首尾位置/旋转/亮度一致。气泡在完全不可见时复位。没有 Dart Timer 或额外动画控制器。
- 共享 `AppSkinRiveAnimation` 采用项目实际 Flutter renderer；应用动画开关、系统减少动画、`TickerMode` 和前后台继续由共享生命周期控制。关闭后环境隐藏，静态壁纸完整保留；恢复复用已解码控制器。

```sh
# 制作依赖只进入本地 .artifacts，不加入 Flutter 依赖。
npm install --prefix .artifacts/rive-tools rive-mcp-server@0.3.0 --ignore-scripts --no-audit --no-fund
node scripts/generate_tidal_scenes.mjs
node scripts/generate_tidal_ambient.mjs
```

场景脚本需要 Node.js、`rsvg-convert`、`magick`。Rive 脚本可通过 `RIVE_GENERATOR_DIR` 指定已安装的生成器目录。重新生成背景/图标不会覆盖真实 Flutter 缩略图。

## 真实 Flutter 预览

缩略图来自 360×640 的真实 Flutter 首页与固定示例数据，使用仓库固定字体；动态和扩展场景导出使用本机完整中文字体（缺失时使用仓库字体），等待壁纸、字体和 Rive 完成加载。

```sh
make skin-previews
# 仅写入所有壁纸皮肤的真实选择缩略图：
flutter test test/app/theme/skin_preview_golden_test.dart --run-skipped \
  --plain-name 'export wallpaper skin selection previews'
# 两种界面风格 × 日夜：首页、歌单详情、设置、内容底色、双倍字号窄屏、宽屏。
flutter test test/app/theme/skin_preview_golden_test.dart --run-skipped \
  --plain-name 'export immersive skin scenes for tidal_sanctuary'
# 日夜各 240 帧，390×844 / 30 fps / 8 秒，使用真实首页和 Flutter Rive renderer。
flutter test test/app/theme/skin_preview_golden_test.dart --run-skipped \
  --plain-name 'export tidal ambient motion'
node scripts/encode_tidal_motion.mjs
```

扩展页面位于 `.artifacts/tidal-sanctuary/previews/`，夜间帧位于 `motion/`、日间位于 `motion-day/`。视频/动图是视觉预览，不是真机性能报告。代理环境执行测试时优先使用专用 Dart MCP 测试工具，参数等价于上述入口。

视频由 `scripts/encode_tidal_motion.mjs` 调用 FFmpeg 无音轨编码为 H.264，左右分别为日间与夜间，780×844 / 30 fps / 8 秒；GIF 缩至宽 624、15 fps。GIF 为短片循环，实际 Rive 的完整循环是 24 秒。

## 验证边界

`immersive_skin_rive_test.dart` 在实际 Flutter renderer 中加载日夜画板，推进 37 秒跨过完整循环，并检查动画开关、系统减少动画、隐藏、后台与恢复时控制器复用。共享背景测试继续覆盖资源失败和更换资源时的异步过期回退。共享弹窗用例覆盖两种风格、双倍字号长列表及结果返回，并核对滚动时静态装饰绘制记录复用。新增皮肤进入已有配置持久化、选择页及真实页面测试矩阵。

真机 Profile 下的持续帧耗时、功耗、电量和温升尚未验证；不能由组件测试或导出帧推断。不改变播放进度的监听范围，没有新增页面根部高频状态监听。Rive 环境层沿用原有重绘隔离。

首版全局皮肤验证记录（鱼群重做前）：

- Dart MCP 全项目静态分析返回 `No errors`，`git diff --check` 无输出。
- 全部 `test/` 默认用例按目录分为 7 组执行：3,573 项通过、31 项跳过、0 失败。应用 357、基础设施等 476、共享组件 461、播放器 594、首页/在线/我的/设置 562、歌词/本地资料库 504、其余内容模块 619。完整范围的最初调用和一次 runner 分片调用触发 MCP 超时；最终以明确目录分组完成覆盖，未将超时视为通过。
- 最终 Rive 调整后补跑：日夜实际资源、生命周期、资源哈希和真实动态帧导出共 7 项通过。生成器额外检查时间轴首尾数值一致，以及气泡纵向复位相邻关键帧均完全透明。
- 真实页面导出：两种风格 × 日夜共 28 张首页/详情/设置/内容底色/窄屏双倍字号/宽屏截图；另有 8 张该皮肤歌曲菜单与歌单选择截图。按 30 fps 导出日夜各 240 帧，编码日夜并排 MP4 与 GIF。
- JSON 报告位于 `.artifacts/tidal-sanctuary/tests-{app,core,shared,player,interface,lyrics-library,catalog,final-rive}.json`，各报告均有 `success:true` 的最终 `done` 事件。

鱼群重做后的验证：

- 当前皮肤资源与真实页面回归：94 项通过、7 项显式预览导出跳过，0 失败；报告为 `.artifacts/tidal-sanctuary/tests-fish-regression.json`。包含新 Rive 日夜画板实际解码、推进 37 秒、暂停/恢复与控制器复用、资源 SHA-256，以及全部皮肤缩略图基线。
- 重导了日夜各 240 帧的真实 Flutter 动态、两种界面风格的静态页面及弹窗，分别记录于 `tests-fish-motion.json` / `tests-fish-scenes.json`。视频中可见鱼体前进、转向、独立尾拍和胸鳍动作，壁纸不再带固定鱼影。
- 固定字体缩略图需按上面的 `export wallpaper skin selection previews` 单独启动测试进程导出，不与使用完整系统中文字体的场景/弹窗导出合并调用；合并时字体注册会影响固定基线。本次已单独重导，城市、星轨和森林缩略图与原版本逐字节一致，最终基线回归通过。
- 这次修改范围为潮汐皮肤资源与制作脚本；首版的全量测试记录保留在上一节，未把首版全量结果当作此次重跑。真机持续功耗与温升仍待实测。

## 运行资源 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| wallpaper_light.jpg | `3a8f98ec475355110e22ceb5822a601d072ed77dd93ee5ae328f483acda66dbd` |
| wallpaper_dark.jpg | `3f16e3f0d90ebd1e237b01c2979e617fa6d08ab2a7e7a6cc4523b29cf7305fd6` |
| preview_light.png | `a7639db0d7f22358bd4071fb4c4f336e022f3279d3315cf8756694bf4f9d23c7` |
| preview_dark.png | `a937729e4811e7c4a3fe71cc089abd55534e3c4c2b2421c395cd2bc865bbbc7a` |
| ambient.riv | `3e09fb9fcd430ba4ffb91df2642741989e3f35f56461b61afaecc467306d3f65` |
| icons/heart.svg | `0b5378ecbe86a9ada8d3f6fd8b8470c2c05bde59a21692bcd326d75b9fce94e9` |
| icons/home.svg | `92acfda6496aa85bdc9285ecf59788bf6ffa7efebc0da4fa924a15758fd82228` |
| icons/library.svg | `291a6b9520700dac78318f3f261ac52d11403a75f758e9155464116418d3ad16` |
| icons/pause.svg | `79a781b4f47b16ba8f37daed60ce555c6f42ef6a31fbf5d8235d9db24becfd89` |
| icons/person.svg | `a8f28862445c02e2d3a94dc06f4e0aeb0e64d86d2482ee3dde6402f169866170` |
| icons/play.svg | `90fdb5ebc1b81d74b0fdb42fa44ad43c5f865351b6c3551abde24db56b69a76b` |
| icons/queue.svg | `4eead7489440105086eb8ca4991e8bb615c138f6e05fe6596773304461fb00c4` |
| icons/search.svg | `313626c139360a832231eaac734510bf63a6530a5617f6ee940a1e8f6f7115c3` |
| icons/tide.svg | `cd3aad14f66b4e0fcaae6f7b4a6f4dd84b6c542684791abfd8fee909a5cf7f8e` |

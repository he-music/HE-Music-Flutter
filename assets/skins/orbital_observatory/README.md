# 近地轨道 · 极光

## 方向与范围

直接悬浮在开放太空，俯瞰延伸出画幅的巨大地球。日间为海洋、立体云层与大气边缘，夜间为固定星空、城市灯火和极光。保留写实壁纸质感，不使用舱体、窗框、HUD 或漂浮粒子。

覆盖共享首页、搜索、资料库、设置、内容详情、MiniPlayer、导航与弹窗表面；沿用业务页面、路由和播放状态。全屏播放器主体继续使用独立样式。弹窗复用现有星轨静态母题和全局配色，应用与播放器继续使用各自的表面实现。

## 场景来源与运行资源

- 图像由 `image_generate` 制作，返回 provider `openai`、模型 `gpt-image-2.6-flare`。采用上一版开放太空图集作为编辑目标，补充有亮度与疏密差异的夜间星点，并调整极光和日间云层；图片是 AI 生成的写实美术，不是实拍或科学观测资料。
- 最终图集：本地 `.artifacts/orbital-observatory/source/orbital-earth-stars-day-night-atlas.png`。请求 2048×2048，实际返回 **1254×1254**，左日间、右夜间，各 **627×1254**。
- 没有引入第三方摄影、NASA 标识、品牌资源或嵌入式应用 UI；生成服务的输出使用条款适用，本说明不额外授予许可。
- 壁纸采用 JPEG quality 93、4:4:4，清除元数据。夜间以受地球曲线约束的绿色超量遮罩分离极光，并按遮罩降低静态极光的亮度，把主要光带的表现交给动画层；关闭动画时仍保留完整静态地球与星空场景。
- 极光透明层为原图派生的 627×380 图层（原图 y=100..480），经颜色与空间限制、去除孤立亮点和柔边处理后，分成三片交叠淡化的纹理。日间另分离 627×500 的柔边薄云层（y=500..1000）。派生 PNG 只嵌入 `.riv`，不单独打包。
- `preview_light.png`、`preview_dark.png` 为 **360×640 真实 Flutter 首页截图**，固定示例数据，等待字体、壁纸及 SVG 加载，关闭环境动画以保持选择缩略图稳定。
- 运行包仅包含两张 JPEG、两张真实缩略图、`ambient.riv` 和 `icons/` 下 11 个 SVG。源图集、透明层、制作依赖、试验帧、GIF 和视频均留在本地制作目录。

## 图标与组件材质

11 个原创 SVG 覆盖 27 个高频角色：主导航、搜索、播放/暂停、队列、收藏、下载、更多与皮肤设置。其余角色保留 SDK 回退。图标采用 24px 坐标、1.7px 圆角线条，部分采用轨道弧线；源色 `#6FB7CE` 通过共享入口映射为当前主题色，不把发光效果或主题文字画入图标。

日间采用银灰和航天蓝，夜间采用深蓝灰、冰蓝和少量极光绿。搜索、MiniPlayer、底栏使用独立控制表面；MiniPlayer / 导航的不透明度配置分别为日间 0.82 / 0.64、夜间 0.74 / 0.58，再由共享规则乘 0.90 / 0.85。模糊 sigma=10，范围局限于控件边界。

日间不再整体叠加 46% 白色遮罩：基础遮罩降到 4%，以顶部较强、向云海逐渐减弱的 `readingGradient` 承载阅读。夜间基础遮罩 8%，顶部仅增加克制的暗色阅读渐变。新配置为可选项，其他皮肤维持原行为；声明专属渐变的皮肤不再叠加通用 Cupertino 全屏阅读遮罩。渐变独立于环境动画和内容底色开关。

壁纸与 Rive 使用一致的 `BoxFit.cover` / `Alignment(0, -0.45)`。手机主要裁切左右，宽屏上移可见区域，保留地球边缘与极光。

## Rive 与运动

- `ambient.riv`：**1,104,500 字节**，两个透明 **627×1254** 画板 `OrbitalDay` / `OrbitalNight`。
- 状态机 `AmbientLoop`，无输入，从入口进入 `orbital_atmosphere`；完整时间轴 **24 秒 / 30 fps**，夜间极光每 8 秒完成一次流动，日间薄云每 12 秒漂移并渐隐复位。时间轴采样率不等于设备刷新率。
- 夜间用三层柔边极光纹理沿地球曲率移动，并轻微改变高度和亮度；不同相位形成连续光带。原先小幅网格形变不易察觉，扩大后实际 renderer 会出现三角硬边，因此最终采用纹理分层与仿射运动。星点、地球与文字不随之运动，不做全屏运镜或整张背景缩放。
- 日间保留大气薄光，并增加从原图分离的前景薄云。薄云沿固定方向漂移，边缘及复位前后完全渐隐，主体地球和主云层保持稳定。
- 生成脚本检查全部关键帧的首尾值一致。使用实际 Flutter renderer 解码、推进并渲染，未将制作工具预览作为可用性证据。
- 复用 `AppSkinRiveAnimation`：皮肤开关只控制环境动画；系统减少动画、TickerMode 隐藏与后台均停止推进。恢复复用控制器，资源失败保留静态场景。
- 生成器为本地 `rive-mcp-server@0.3.0`，其 Freeware License 允许使用、修改及分发生成的 `.riv`；没有修改或分发生成器。图标及脚本为本项目原创，随项目代码使用；极光纹理沿用源图的使用条款。

## 重建

需要 Node.js、ImageMagick、FFmpeg。制作依赖仅进入本地 `.artifacts/rive-tools/`：

```sh
npm install --prefix .artifacts/rive-tools rive-mcp-server@0.3.0 --ignore-scripts --no-audit --no-fund
bash scripts/prepare_orbital_observatory.sh
node scripts/generate_orbital_icons.mjs
node scripts/generate_orbital_ambient.mjs
```

裁切脚本可以接收原始图集路径。它先检查实际尺寸；本版极光遮罩与分层纹理专用于 627×1254 面板，源尺寸变化时会拒绝运行，需要一起调整遮罩、透明层和 Rive 坐标。重新生成 AI 图片不保证像素一致，确定性重建须保留原始图集。

Rive 生成器可通过 `RIVE_GENERATOR_DIR` 指向已有安装。可编辑的场景规格保存在本地 `source/ambient-spec.json`，权威重建源为脚本及保留的图集。

## 真实预览与验证

使用项目的专用 Flutter 测试工具，显式运行 `test/app/theme/skin_preview_golden_test.dart` 中以下跳过的导出用例：

- `export orbital skin selection previews`：更新两张真实运行缩略图，使用固定仓库字体。
- `export immersive skin scenes for orbital_observatory`：导出 Material / Cupertino × 日夜的首页、歌单、设置、内容底色、大字号窄屏和宽屏，共 **28 张**。
- 分别执行 `export orbital ambient motion dark` / `export orbital ambient motion light`：真实 Flutter 首页各 **240 帧**，390×844 / 30 fps / 8 秒，使用实际 Rive renderer。拆分执行以避免单次 MCP 请求超时，随后运行 `node scripts/encode_orbital_motion.mjs`。

缩略图与使用完整系统中文字库的场景/动态应在独立测试进程导出，避免字体注册影响固定 golden 基线。

最终动态预览位于 `.artifacts/orbital-observatory/orbital-motion-visible-v2.mp4`（日夜并排，780×844 / 30 fps / 8 秒）及同名 GIF（624×675 / 15 fps），另有夜间单独的 `orbital-night-visible-v2.gif`（390×844 / 20 fps）。新文件名避免复用旧预览缓存。这是完整时间轴中的 8 秒片段；日间片段重播点不代表实际循环接缝。

本次验证：

- `make analyze` 已执行，另以 `flutter analyze --no-pub` 确认 **No issues found**。
- 基础版本主题、皮肤、配置和选择页回归曾有 159 项通过。此次可见性修正后，专项的实际资源生命周期、手机尺寸像素变化、真实缩略图与场景导出 **6 项通过**；完整发布检查单独执行并记录。
- v1.0.22 发布前实际执行 `/usr/bin/make release-check`：静态分析无问题，完整测试 **3,584 项通过、37 项按预期跳过**，命令退出码 0。全仓格式检查 1,128 个文件无改动，`git diff --check` 通过。
- 日夜实际 Rive 资源推进 37 秒跨越完整循环，检查动画开关、系统减少动画、隐藏、后台、恢复及控制器复用；新增皮肤专属阅读渐变在两种 UI 风格和动画状态下保持稳定，主题过渡保留渐变。
- 11 个图标在 20 / 24 尺寸、日夜主题下实际解码测试通过。
- 最终两张缩略图、28 张场景和日夜各 240 帧动态均显式导出成功。已检查实际首页、设置与动态采样帧。夜间第 0 / 120 帧选取的开放星空区域（x=280..389，y=0..79）像素差为 0，极光区域则有变化。
- 新增 `orbital_motion_visibility_test.dart`：旧资源日夜均失败，新资源日夜均通过；正常手机尺寸两秒内，夜间极光区域至少 8%、日间薄云区域至少 4% 的像素亮度变化超过 3%，同时检查开放星空稳定。最终真实首页测得夜间约 12.50%、日间约 18.39%；像素门槛用于回归，视觉仍以实际预览判断。
- 没有新增页面根部高频状态监听；环境层继续复用原有重绘隔离。

**尚未验证：真机 Profile 下持续帧耗时、功耗、电量与温升。** 预览和组件测试不作为真机性能结论。

## SHA-256

| 资源 | SHA-256 |
| --- | --- |
| 最终源图集 | `c69257bfb1756661d52951b555fa58d6b6e89a138fa8d49dc702bc00877458c6` |
| wallpaper_light.jpg | `1dc94da402960b05dbd84a134588d95bd3193708856ae06f3217704c362be592` |
| wallpaper_dark.jpg | `018d2bae7f23e25d0034974f105b529e94e62fa3ab14e87acf9657d0aedaa762` |
| preview_light.png | `4ea90420da86954ad9ed0c795ac8d5a19ef49855f37b7ef6843810c8e8dc4e0b` |
| preview_dark.png | `e88da910ddab1df39a9b2d19f3c7645079c49678bcef741915544f527680e93b` |
| ambient.riv | `b4f4cbbc81a6ac84886bc39359f5b3981e2b85cd404b62fc64257f6423bb670e` |
| icons/download.svg | `f8d6ccb05092d8599088e3d4e7af4f40852fa8275c03e1627869e4fe71263bf1` |
| icons/heart.svg | `663c094db51270aaab2a6c5cfd6e70ba32fd299bb3226ae1f01a9510246f1692` |
| icons/home.svg | `e1c2b7c9b1b9e1871fe8857f3551e1e57bf57a675482dc6e2e1ebbe603648717` |
| icons/library.svg | `d145a45e7b842508b126e66550f0d051a4bd0dbbd4aab4f68392d750b2cf7e6f` |
| icons/more.svg | `b5bd6cae885f7c1c8000bc2c207083aac87235d3382118b03e23abae70c9b71a` |
| icons/orbit.svg | `6ea93cc4aa0caca5128c7f7626eef7d8ea145763ae79d656b64b96038e8e31c4` |
| icons/pause.svg | `6501aa8690a4efca54d021ab10c0f9c9d94858499c9fa7dc1f95701c5193749f` |
| icons/person.svg | `9c174e719f5cdc253b761f141029bca0b388a7829ca96e3c24a1538159141bf8` |
| icons/play.svg | `ec27f3d1f8ebacde1bfed97ff888e1f62b69ab3445792fd0436b0c5b245a2172` |
| icons/queue.svg | `f9993557e325d316c0c20ad7130a0dffdec6b7886d68164b5a285a4a72f9f027` |
| icons/search.svg | `cc780ebcf0d05b694cc5ebbfc3db1ba59774d68708c108992e25aae9e7ac7765` |

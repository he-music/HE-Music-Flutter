# HE Music Flutter

HE Music Flutter 是一个基于 Flutter 的跨平台音乐应用项目，延续 [HE-Music](https://github.com/he-music/HE-Music) 的产品方向，面向移动端与桌面端场景持续迭代。

项目代码采用 feature-first 结构组织，当前已经包含播放器、在线内容浏览、本地音乐、下载管理、登录、个人中心、设置和更新检查等核心能力，适合作为 Flutter 音乐应用的学习与工程实践参考。

## 项目状态

本项目处于持续开发阶段，功能、接口和页面体验仍可能调整。欢迎通过 Issue 或 PR 一起完善功能、体验与文档。

## 功能概览

- 播放器：迷你播放器、全屏播放器、播放队列、播放进度、播放模式、后台播放控制
- 歌词：播放器歌词面板、歌词解析、桌面悬浮歌词窗口
- 在线内容：搜索、热搜、联想、评论、歌单、专辑、歌手、歌曲详情
- 内容广场：排行榜、新歌、新碟、歌单广场、歌手广场、视频、电台
- 本地音乐：本地音频扫描、歌手/专辑/风格聚合、元数据读取与编辑
- 下载管理：歌曲下载、下载任务管理、歌词与音频元数据写入
- 账号相关：登录、验证码、二维码扫码登录与确认流程
- 我的页面：个人信息、收藏、历史记录、用户歌单详情
- 设置与更新：主题、播放、歌词、设备管理、关于页、GitHub Release 更新检查

## 技术栈

- Flutter / Dart
- Riverpod：状态管理与依赖注入
- GoRouter：路由与导航
- Dio / Retrofit / JSON Annotation：网络请求与模型序列化
- just_audio / audio_service：音频播放与后台控制
- Drift / SQLite：本地数据存储
- background_downloader：下载任务调度
- media-kit：视频播放
- local_audio_scan / audiotags：本地音乐扫描与音频标签读写
- flutter_lyric / flutter_overlay_window：歌词展示与悬浮歌词窗口

## 目录结构

```text
lib/
  app/       应用启动、路由、主题、国际化、全局配置
  core/      音频、网络、数据库、错误处理、设备信息等基础设施
  features/  按业务功能划分的模块
  shared/    复用组件、布局规则、辅助方法、模型与工具
test/        测试代码
assets/      静态资源
third_party/ 本地覆盖依赖
```

主要业务模块位于 `lib/features/`：

```text
album          专辑详情
artist         歌手详情与歌手广场
auth           登录、验证码、二维码登录
download       下载任务与下载后处理
home           首页发现
lyrics         歌词数据与解析
lyrics_overlay 桌面悬浮歌词
music_library  本地音乐库
my             我的、收藏、历史记录、用户歌单
new_release    新歌与新碟
online         在线搜索与在线聚合页
playlist       歌单广场与歌单详情
player         播放器
ranking        排行榜
radio          电台
settings       设置、设备管理、关于页
song           歌曲详情
update         版本更新检查
video          视频广场、视频详情与播放状态
```

## 快速开始

### 环境要求

- Flutter SDK
- Dart SDK
- Android Studio / Xcode / 对应平台构建工具

本项目 `pubspec.yaml` 当前要求 Dart SDK `^3.11.0`。

### 安装依赖

```bash
make get
```

### 启动应用

```bash
make run
```

### 常用开发命令

项目根目录提供 `Makefile`，日常开发优先使用以下命令：

```bash
make get            安装或同步依赖
make upgrade        升级依赖
make run            启动应用
make analyze        执行静态检查
make test           运行测试
make format         格式化 Dart 代码
make fix            自动应用 Dart 可修复项
make gen            执行代码生成
make clean          清理构建产物
make build-apk      构建 Android release APK（按 ABI 拆分）
make build-aab      构建 Android release AAB
make release-check  发布前执行检查与测试
```

涉及 Retrofit、Drift 或 JSON 模型生成代码的改动，通常需要执行：

```bash
make gen
```

提交前建议至少执行：

```bash
make analyze
make test
```

## 配置说明

应用基础配置位于 `assets/app_config.json`。仓库中的 `api_base_url` 只保留占位值，不要提交真实接口地址：

```json
{
  "api_base_url": "https://example.com",
  "github_owner": "he-music",
  "github_repo": "HE-Music-Flutter"
}
```

Release 构建由 CI 使用 GitHub Secret `API_BASE_URL` 在构建前生成真实配置；不要把真实接口地址放到 GitHub Variables。本地调试时可临时修改 `assets/app_config.json`，但提交前必须还原为占位值。

不要在源码中硬编码环境相关值。新增资源后，需要同步更新 `pubspec.yaml` 中的 `flutter.assets` 声明。

## Android 发布签名

Android release 构建需要使用 release keystore。`android/key.properties` 与 `android/keystore/*.jks` 都属于敏感文件，不要提交到仓库。

如果应用已经用旧 keystore 对外发布过，更换 keystore 可能导致旧用户无法直接覆盖升级。确认可以更换后，再重新生成发布签名文件。

### 生成新的 keystore

建议生成新文件，不要直接覆盖旧文件：

```bash
mkdir -p android/keystore

keytool -genkeypair -v \
  -keystore android/keystore/release.jks \
  -storetype PKCS12 \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias he-music
```

命令执行时需要输入 keystore 密码、证书信息和 key 密码。对应关系如下：

```text
ANDROID_STORE_PASSWORD = keystore 密码
ANDROID_KEY_PASSWORD   = key 密码
ANDROID_KEY_ALIAS      = he-music
```

### 验证 keystore

生成后先确认 keystore 能被正确读取：

```bash
keytool -list -v \
  -keystore android/keystore/release.jks \
  -alias he-music
```

如果密码或 alias 错误，命令会失败。也可以不带 `-alias` 查看 keystore 内的 alias 列表：

```bash
keytool -list -v \
  -keystore android/keystore/release.jks
```

### 本地 release 构建测试

在本地创建 `android/key.properties`：

```properties
storePassword=你的keystore密码
keyPassword=你的key密码
keyAlias=he-music
storeFile=keystore/release.jks
```

然后执行 release 构建：

```bash
make build-apk
```

如果签名配置正确，构建会生成 release APK；如果密码、alias 或文件路径不正确，构建会在签名阶段失败。

### 配置 GitHub Actions Secrets

CI 不直接提交 keystore 文件，而是从 GitHub Secret 恢复。生成 base64 内容：

```bash
base64 -i android/keystore/release.jks | tr -d '\n' | pbcopy
```

在 GitHub 仓库的 Actions Secrets 中填写：

```text
ANDROID_KEYSTORE_BASE64 = 上面命令复制的 base64 内容
ANDROID_STORE_PASSWORD  = keystore 密码
ANDROID_KEY_PASSWORD    = key 密码
ANDROID_KEY_ALIAS       = he-music
```

CI 会把 `ANDROID_KEYSTORE_BASE64` 解码为 `android/keystore/release.jks`，上面的本地示例也使用同一个文件名，方便保持一致。

## 开发约定

- 代码主要位于 `lib/`，按 `app`、`core`、`features`、`shared` 分层组织
- 新功能优先放入对应 `lib/features/<feature>/` 模块
- 测试位于 `test/`，建议与源码路径保持对应
- 本地覆盖依赖位于 `third_party/`，按 vendored code 对待
- 提交信息使用 Conventional Commits，例如 `feat: add playlist page`
- 更多仓库约定可参考项目内 `AGENTS.md` 与 `Makefile`

## 许可证

本项目代码基于 [GNU Affero General Public License v3.0](./LICENSE) 开源。使用、修改、分发或部署本项目时，请遵守对应许可证条款。

## 免责声明

本项目仅供个人学习研究使用，禁止用于商业及非法用途。

歌曲、图片及歌词来源于网络，仅供学习、交流使用，不具有任何商业用途。如因使用本项目而引起任何纠纷或责任，均由使用者自行承担。本项目开发者不承担任何因使用本项目而导致的直接或间接责任，并保留追究使用者违法行为的权利。

请使用者在使用本项目时遵守相关法律法规，不要将本项目用于任何商业及非法用途。如有违反，一切后果由使用者自负。同时，使用者应自行承担因使用本项目而带来的风险和责任。本项目开发者不对本项目所提供的服务和内容作出任何保证。

感谢您的理解。

## 鸣谢

感谢 Flutter 及其生态为本项目提供跨平台应用基础，也感谢 Riverpod、GoRouter、Dio、Retrofit、just_audio、audio_service、Drift、background_downloader、flutter_lyric、media-kit、local_audio_scan、audiotags、mobile_scanner、qr_flutter 等开源项目为本项目提供基础能力。

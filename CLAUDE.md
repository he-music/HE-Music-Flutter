# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

HE-Music Flutter 是一个 AI 驱动的跨平台音乐客户端，是 [HE-Music](https://github.com/he-music/HE-Music)（Electron+Vue3 桌面版）的移动端伴侣应用。支持在线流媒体、本地音频、下载、歌词、视频和用户歌单等功能。

- **Dart SDK**: `^3.10.7`，**Flutter stable**
- **目标平台**: Android、iOS、macOS
- **包名**: `com.hemusic.music.flutter`

## 常用命令

项目根目录提供 `Makefile`，所有常用命令通过 make 调用：

```bash
make get              # flutter pub get
make run              # 启动应用
make analyze          # 静态分析
make test             # 运行全部测试
make gen              # build_runner 代码生成（JSON 序列化等）
make format           # dart format lib test
make fix              # dart fix --apply
make build-apk        # Android Release APK（split-per-abi）
make build-aab        # Android Release AAB
make release-check    # analyze + test，发布前校验
```

运行单个测试文件：
```bash
flutter test test/features/player/presentation/pages/player_page_test.dart
```

## 架构

### Feature-First 分层架构

```
lib/
  app/          # 启动、路由、主题、配置、国际化
  core/         # 共享基础设施（音频、网络、错误、Result）
  features/     # 业务模块（20 个功能模块）
  shared/       # 跨模块共享代码（模型、工具、组件）
```

每个 feature 模块遵循 `data/domain/presentation` 三层结构：

```
features/<feature>/
  data/datasources/       # Dio API 客户端
  data/repositories/      # Repository 实现
  domain/entities/        # 领域模型/状态类
  domain/repositories/    # 抽象 Repository 接口
  presentation/controllers/ # Riverpod Notifier
  presentation/pages/     # 页面 Widget
  presentation/widgets/   # 模块内组件
```

### 核心技术栈

- **状态管理**: Riverpod — `Notifier<T>` + `NotifierProvider`，状态不可变（`copyWith` 模式）
- **路由**: GoRouter — 路由路径集中定义在 `AppRoutes`，参数通过 query parameters 传递
- **网络**: Dio — 手写 API 客户端，拦截器链处理 token、验证码、未授权重定向、错误消息
- **音频**: just_audio + audio_service（后台播放）
- **持久化**: SharedPreferences

### 关键设计模式

- **Repository 模式**: `domain/repositories/` 定义抽象接口，`data/repositories/` 提供实现，委托给 API 客户端
- **Result 类型**: `core/result/result.dart` — `Result<T>` 密封类（`Success<T>` / `FailureResult<T>`）
- **Failure 层级**: `core/error/failure.dart` — `NetworkFailure`、`ValidationFailure`、`StorageFailure` 等
- **Dio 拦截器链**: `core/network/` — token 注入、验证码挑战、401 重定向、错误消息处理
- **国际化**: 自研 i18n，`AppI18n.t(config, 'key')` 访问，支持中/英双语

### 第三方本地覆盖

`third_party/` 下有两个本地覆盖依赖（pubspec `dependency_overrides`）：
- `flutter_lyric` — 歌词显示组件
- `audiotags` — 音频标签读取

修改这些依赖时需直接编辑 `third_party/` 下的源码，lint 已排除这些目录。

## 编码规范

- 2 空格缩进，文件名 `snake_case.dart`，类名 `UpperCamelCase`，方法/变量/provider `lowerCamelCase`
- 遵循 `analysis_options.yaml` 中的 `flutter_lints` 规则
- 保持现有 feature-first 结构，不引入额外抽象层
- 新增资产后同步更新 `pubspec.yaml` 的 assets 声明
- 涉及 Retrofit/JSON 代码生成的改动需执行 `make gen`

## 测试

- 使用 `flutter_test`，测试文件 `*_test.dart` 与源码路径对应
- 测试聚焦具体行为，如 `testWidgets('home shell renders with two tabs', ...)`
- 提交前至少运行 `make test`，同时运行 `make analyze`

## 提交规范

使用 Conventional Commits 风格：`feat:`、`fix:`、`refactor:`、`docs:` 等简短前缀。

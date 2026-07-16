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

## 编码风格与命名约定
遵循 `analysis_options.yaml` 中启用的 `flutter_lints` 规则。Dart 代码使用标准 2 空格缩进。文件名保持 `snake_case.dart`，类、枚举和类型别名使用 `UpperCamelCase`，方法、变量和 provider 使用 `lowerCamelCase`。保持现有的 feature-first 结构，优先沿用当前 Riverpod、GoRouter 和 repository 模式，不要额外引入平行抽象层。

## 测试指南
使用 `flutter_test` 编写单元测试和组件测试。测试文件命名为 `*_test.dart`，并尽量与被测源码路径对应。测试描述应聚焦具体行为，例如 `testWidgets('home shell renders with two tabs', ...)`。提交 PR 前至少运行 `make test`，代码变更同时运行 `make analyze`。

## 提交与 Pull Request 规范
当前历史中可见的提交格式是 Conventional Commits 风格，例如 `feat: init`；后续继续使用简短前缀，如 `feat:`、`fix:`、`refactor:`、`docs:`。PR 说明应写清改动范围、列出已执行命令，并关联相关 issue。涉及 UI 的改动应附截图或录屏；涉及配置或资源调整时，请明确说明如 `assets/app_config.json` 或 `env/` 的变化。

## 配置提示
不要在源码中硬编码环境相关值。执行 `flutter run` 时必须传入参数 `--dart-define-from-file=.env`。新增资源后要同步更新 `pubspec.yaml` 中的 assets 声明。涉及 Retrofit 或 JSON 模型生成代码的改动，通常都需要执行 `make gen`。生成图片时，使用 `openai-image-api` 这个 skill。

<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

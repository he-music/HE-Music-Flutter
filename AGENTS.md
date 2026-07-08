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
不要在源码中硬编码环境相关值。新增资源后要同步更新 `pubspec.yaml` 中的 assets 声明。涉及 Retrofit 或 JSON 模型生成代码的改动，通常都需要执行 `make gen`。

<!-- BEGIN BEADS INTEGRATION v:1 profile:full hash:f65d5d33 -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Quality
- Use `--acceptance` and `--design` fields when creating issues
- Use `--validate` to check description completeness

### Lifecycle
- `bd defer <id>` / `bd supersede <id>` for issue management
- `bd stale` / `bd orphans` / `bd lint` for hygiene
- `bd human <id>` to flag for human decisions
- `bd formula list` / `bd mol pour <name>` for structured workflows

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->
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

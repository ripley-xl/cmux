# cmux Fork 维护指南

## ⚠️ 重要：版本合入规则

本仓库是 `manaflow-ai/cmux` 的 Fork（`ripley-xl/cmux`）。日常维护流程为：**合入上游最新 tag → 编译 → 发布**。

### 禁止合入的版本

| 版本 | 原因 |
|------|------|
| **v0.64.10** | 有严重 Bug，会导致 Claude Code 无法全屏显示。绝对不可合入此版本。 |

### 发布流程

使用自动化脚本一键完成合入、编译、发布：

```bash
./scripts/fork-release.sh <上游tag>
```

示例：

```bash
./scripts/fork-release.sh v0.64.9        # 合入上游 v0.64.9，发布为 v1.64.9
./scripts/fork-release.sh v0.64.11       # 合入上游 v0.64.11，发布为 v1.64.11
./scripts/fork-release.sh v0.64.10       # ❌ 禁止！此版本有严重Bug
```

脚本会自动完成：
1. 切换到 `fork/main` 分支
2. 合入指定的上游 tag
3. 版本号 major +1（如 `v0.64.9` → `v1.64.9`）
4. 构建 Release 版本（含 cmuxd-remote）
5. 创建 DMG
6. 推送到 fork remote 并创建 GitHub Release
7. 安装到 `/Applications` 并启动

如果已手动合入，可跳过 merge 步骤：

```bash
./scripts/fork-release.sh v0.64.11 --no-merge
```

### Fork 版本号规则

- 上游 `v0.X.Y` → Fork 发布为 `v1.X.Y`（major 版本号 +1）
- 当前最新 Fork 发布：`v1.64.9`（基于上游 `v0.64.9`）

### 远程仓库

| 名称 | 地址 | 用途 |
|------|------|------|
| `origin` | `manaflow-ai/cmux` | 上游主仓库 |
| `fork` | `ripley-xl/cmux` | Fork 发布仓库 |
| `woa` | `git.woa.com:okarinhuang/cmux` | 内部镜像 |

---

## 初始设置

运行设置脚本以初始化子模块并构建 GhosttyKit：

```bash
./scripts/setup.sh
```

## 本地开发

代码修改后，始终使用带 tag 的 reload 脚本构建 Debug 应用：

```bash
./scripts/reload.sh --tag fix-zsh-autosuggestions
```

默认情况下 `reload.sh` 只构建不启动应用。脚本会打印 `.app` 路径供用户 cmd-click 打开。构建成功后会终止同 tag 的运行中应用。传入 `--launch` 可在构建后自动打开应用：

```bash
./scripts/reload.sh --tag fix-zsh-autosuggestions --launch
```

`reload.sh` 输出的 `App path:` 行包含构建的 `.app` 绝对路径。用该路径构建可点击的 `file://` URL：

1. 从 `reload.sh` 输出获取 `App path:` 路径
2. 前缀 `file://`，空格编码为 `%20`，不要硬编码任何路径部分
3. 用对应 agent 类型的模板格式化为 markdown 链接

示例。如果 `reload.sh` 输出：
```
App path:
  /Users/someone/Library/Developer/Xcode/DerivedData/cmux-my-tag/Build/Products/Debug/cmux DEV my-tag.app
```

**Claude Code** 输出：
```markdown
=======================================================
[cmux DEV my-tag.app](file:///Users/someone/Library/Developer/Xcode/DerivedData/cmux-my-tag/Build/Products/Debug/cmux%20DEV%20my-tag.app)
=======================================================
```

**Codex** 输出：
```
=======================================================
[my-tag: file:///Users/someone/Library/Developer/Xcode/DerivedData/cmux-my-tag/Build/Products/Debug/cmux%20DEV%20my-tag.app](file:///Users/someone/Library/Developer/Xcode/DerivedData/cmux-my-tag/Build/Products/Debug/cmux%20DEV%20my-tag.app)
=======================================================
```

禁止在聊天输出中使用 `/tmp/cmux-<tag>/...` 格式的应用链接。

CLI 或 socket 测试已标记的 Debug 应用时，使用 tag 绑定的辅助脚本并设置 `CMUX_TAG`。
不要使用 `/tmp/cmux-cli`，因为该符号链接指向最近重载的构建，可能指向用户的主应用 socket。

```bash
CMUX_TAG=<tag> scripts/cmux-debug-cli.sh list-workspaces
CMUX_TAG=<tag> scripts/cmux-debug-cli.sh send --workspace workspace:1 --surface surface:1 "echo ok"
```

辅助脚本拒绝在没有 `CMUX_TAG` 的情况下运行，目标为 `/tmp/cmux-debug-<tag>.sock`，并使用
`~/Library/Developer/Xcode/DerivedData/cmux-<tag>/...` 中匹配的 CLI。它还会清除环境中的 cmux 终端上下文
（`CMUX_SOCKET`、`CMUX_SOCKET_PASSWORD`、workspace/surface/tab/panel ID、cmuxd socket、debug log），
然后设置 `CMUX_SOCKET_PATH`、`CMUX_BUNDLE_ID` 和 `CMUX_BUNDLED_CLI_PATH`。

代码修改后始终使用 `reload.sh --tag` 构建。**绝不运行裸 `xcodebuild` 或打开未标记的 `cmux DEV.app`。**
未标记的构建共享默认 debug socket 和 bundle ID，会与其他 agent 冲突并抢夺焦点。

```bash
./scripts/reload.sh --tag <your-branch-slug>
```

如果只需验证编译通过（不启动），使用带 tag 的 derivedDataPath：

```bash
xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/cmux-<your-tag> build
```

重建 GhosttyKit.xcframework 时始终使用 Release 优化：

```bash
cd ghostty && zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast
```

重建 cmuxd 用于发布/打包时始终使用 ReleaseFast：

```bash
cd cmuxd && zig build -Doptimize=ReleaseFast
```

### 各种 reload 命令

| 命令 | 说明 |
|------|------|
| `reload.sh --tag <tag>` | 构建 Debug 应用（需要 tag），终止同 tag 运行中的应用 |
| `reload.sh --tag <tag> --launch` | 同上，并自动打开新构建的应用 |
| `reloadp.sh` | 终止并启动 Release 应用 |
| `reloads.sh` | 终止并启动 Release 应用（STAGING 模式，与生产隔离） |
| `reload2.sh --tag <tag>` | 同时 reload Debug 和 Release |

并行/隔离构建（如测试功能与主应用并行运行）使用 `--tag` 加简短描述名：

```bash
./scripts/reload.sh --tag fix-blur-effect
```

这会创建隔离的应用，拥有独立的名称、bundle ID、socket 和 derived data 路径，可与主应用并行运行。
注意：如需 xcframework 解析，请使用非 `/tmp` 的 derived data 路径（脚本自动处理）。

启动新 tag 前，清理本次会话中已启动的旧 tag（退出旧应用 + 删除 `/tmp` socket/derived data）。

## Cloud VM 密钥

Cloud VM 构建、测试和本地开发脚本使用 `~/.secrets/cmux.env` 中的密钥：

- `E2B_API_KEY`
- `FREESTYLE_API_KEY`
- `web/scripts/build-cloud-vm-images.ts` 创建 Freestyle 快照时使用的 R2 上传变量

加载方式：

```bash
set -a
source ~/.secrets/cmux.env
set +a
```

`~/.secrets/cmuxterm-dev.env` 用于本地 Stack/web 环境，不含提供商构建密钥。
`bun dev` 先加载 `~/.secrets/cmux.env`（如存在），再加载 `~/.secrets/cmuxterm-dev.env`，
cmuxterm 特定的 Stack 设置会覆盖更广泛的 cmux 密钥。Web dev 加载器仍接受
旧路径 `~/.secret/cmuxterm.env` 和 `~/.secrets/cmuxterm.env`。

## 后端 TypeScript

后端 TypeScript 默认使用 Effect。对于 `web/app/api/**`、`web/services/**` 下的代码，
以及涉及提供商、数据库、认证、限流、重试、超时或遥测的后端脚本，
将工作流建模为 `Effect.Effect` 值，使用类型化的领域错误和显式的服务依赖。
保持 Next 路由处理器精简：解析请求，在边界运行一个 Effect 程序，
将类型化错误映射为 HTTP 响应，并单独处理意外缺陷。

仅在以下场景使用纯 TypeScript：简单数据结构、常量、配置文件、前端 React 代码，
或 Effect 会增加不必要复杂度的小粘合代码。

Cloud VM 后端逻辑必须保留在 Vercel 路由处理器和基于 Postgres 的 Effect 服务中。
除非后续架构文档明确变更控制平面，否则不要重新引入 Rivet 或原始 actor 协议。

生产和预发环境的 Cloud VM Postgres 应使用 Vercel Marketplace AWS Aurora PostgreSQL OIDC/RDS IAM 路径。
运行时环境变量：`CMUX_DB_DRIVER=aws-rds-iam`、`AWS_ROLE_ARN`、`AWS_REGION`、`PGHOST`、`PGPORT`、`PGUSER`、`PGDATABASE`。
生产/预发迁移使用 `bun db:migrate:aws-rds-iam`；绝不在 Vercel 构建或路由启动时运行 Drizzle 迁移。
本地开发继续使用 `bun dev` 中基于 `CMUX_PORT` 的 Docker Postgres 路径。
Cloud VM 创建的定价门控应在启用时使用 Stack Auth team payment items。
Postgres 仍是 VM 生命周期、活跃 VM 限制、幂等性和使用事件的唯一真实来源。

## Debug 事件日志

添加 debug 事件埋点时，将事件（按键、鼠标、焦点、分屏、标签页）
放入统一的 DEBUG 构建日志：

本节描述 debug 日志的目标位置和格式要求。并非要求每个新代码路径都添加 debug 日志。
大多数临时探针应仅在 dogfood 调试循环中添加，合并前移除。

```bash
tail -f "$(cat /tmp/cmux-last-debug-log-path 2>/dev/null || echo /tmp/cmux-debug.log)"
```

- 未标记的 Debug 应用：`/tmp/cmux-debug.log`
- 标记的 Debug 应用（`./scripts/reload.sh --tag <tag>`）：`/tmp/cmux-debug-<tag>.log`
- `reload.sh` 将当前路径写入 `/tmp/cmux-last-debug-log-path`
- `reload.sh` 将选定的 dev CLI 路径写入 `/tmp/cmux-last-cli-path`
- `reload.sh` 更新 `/tmp/cmux-cli` 和 `$HOME/.local/bin/cmux-dev` 指向该 CLI

- 实现：`Packages/CMUXDebugLog/Sources/CMUXDebugLog/DebugEventLog.swift`
- App shim：`Sources/App/DebugLogging.swift`
- 自由函数 `cmuxDebugLog("message")` — 带时间戳记录并实时追加到文件
- 包实现和 app shim 使用 `#if DEBUG`；所有调用处必须包裹在 `#if DEBUG` / `#endif` 中
- 500 条目环形缓冲区；`CMUXDebugLog.DebugEventLog.shared.dump()` 将完整缓冲区写入文件
- 按键事件在 `AppDelegate.swift` 中记录（monitor、performKeyEquivalent）
- 鼠标/UI 事件在视图中内联记录（ContentView、BrowserPanelView 等）
- 焦点事件：`focus.panel`、`focus.bonsplit`、`focus.firstResponder`、`focus.moveFocus`
- Bonsplit 事件：`tab.select`、`tab.close`、`tab.dragStart`、`tab.drop`、`pane.focus`、`pane.drop`、`divider.dragStart`

## 回归测试提交策略

为 bug 修复添加回归测试时，使用两次提交结构以便 CI 证明测试能捕获 bug：

1. **提交 1：** 仅添加失败测试（无修复）。CI 应变红。
2. **提交 2：** 添加修复。CI 应变绿。

这使得在 GitHub PR UI（Commits 标签页、检查状态）中清晰可见测试确实在无修复时失败。

## 共享行为策略

- 当行为通过多个入口暴露（键盘快捷键、命令面板、上下文菜单、CLI、设置、debug 菜单）时，实现一个共享的 action/model 路径并验证每个应调用它的入口。不要只修补一个界面而让其他界面保留重复逻辑。
- 对于乐观 UI 或 CLI 更新，保持一条变更路径，用请求 ID 或前一个快照记录挂起状态，从权威结果协调，并用显式回滚或错误状态处理失败。不要让每个入口维护自己的乐观副本。
- 当用户说测试遗漏了 bug 时，在声称修复完成前先围绕精确重现路径添加或调整行为级覆盖。

## Debug 菜单

应用在 macOS 菜单栏有 **Debug** 菜单（仅 DEBUG 构建中）。用于可视化迭代：

- **Debug > Debug Windows** 包含调整布局、颜色和行为的面板。条目按字母顺序排列无分隔符。
- 添加 debug 开关或可视选项：创建 `NSWindowController` 子类并带 `shared` 单例，添加到 `Sources/cmuxApp.swift` 的 "Debug Windows" 菜单，并添加带 `@AppStorage` 绑定的 SwiftUI 视图以实时更改。
- 用户说"debug 菜单"或"debug 窗口"时，指的是此菜单，不是 `defaults write`。

## 注意事项

- **自定义 UTTypes** 用于拖放必须在 `Resources/Info.plist` 的 `UTExportedTypeDeclarations` 下声明（如 `com.splittabbar.tabtransfer`、`com.cmux.sidebar-tab-reorder`）。
- 不要添加应用级 display link 或手动 `ghostty_surface_draw` 循环；依赖 Ghostty 唤醒/渲染器以避免打字延迟。
- **打字延迟敏感路径**（修改这些区域前仔细阅读）：
  - `WindowTerminalHostView.hitTest()`（`TerminalWindowPortal.swift`）：每个事件（含键盘）都会调用。所有分隔线/侧栏/拖拽路由仅在指针事件中执行。不要在 `isPointerEvent` 守卫外添加工作。
  - `TabItemView`（`ContentView.swift`）：使用 `Equatable` 一致性 + `.equatable()` 在打字时跳过 body 重新评估。不要添加 `@EnvironmentObject`、`@ObservedObject`（除 `tab`）或 `@Binding` 属性而不更新 `==` 函数。不要从 ForEach 调用处移除 `.equatable()`。不要在 body 中读取 `tabManager` 或 `notificationStore`；使用预计算的 `let` 参数。
  - `TerminalSurface.forceRefresh()`（`GhosttyTerminalView.swift`）：每次击键调用。不要添加分配、文件 I/O 或格式化。
- **终端查找分层约定：** `SurfaceSearchOverlay` 必须从 `GhosttySurfaceScrollView`（`Sources/GhosttyTerminalView.swift` AppKit portal 层）挂载，不是从 SwiftUI 面板容器如 `Sources/Panels/TerminalPanelView.swift`。Portal 托管的终端视图在分屏/工作区切换时可位于 SwiftUI 之上。
- **子模块安全：** 修改子模块（ghostty、vendor/bonsplit 等）时，始终在提交父仓库中更新的指针之前将子模块提交推送到其远程 `main` 分支。绝不在 detached HEAD 或临时分支上提交 — 提交会被孤立并丢失。验证：`cd <submodule> && git merge-base --is-ancestor HEAD origin/main`。
- **所有面向用户的字符串必须本地化。** 使用 `String(localized: "key.name", defaultValue: "English text")` 处理 UI 中显示的每个字符串。键放在 `Resources/Localizable.xcstrings` 中，包含所有支持语言的翻译（当前为英语和日语）。绝不在 SwiftUI `Text()`、`Button()`、alert 标题等中使用裸字符串字面量。
- **快捷键策略：** 每个新的 cmux 自有键盘快捷键必须添加到 `KeyboardShortcutSettings`，在设置中可见/可编辑，在 `~/.config/cmux/cmux.json` 中支持，并在键盘快捷键和配置文档中记录。
- **列表子树的快照边界。** 在任何 `body` 包含 `LazyVStack` / `LazyHStack` / `List` / `ForEach` 行的 SwiftUI 面板中，该边界以下的视图不得持有 `ObservableObject` / `@Observable` store 的引用（无 `@ObservedObject`、`@EnvironmentObject`、`@StateObject`、`@Bindable`，甚至纯 `let store: SomeStore` 属性）。行和间隙仅接收不可变值快照加闭包动作包。违反此规则会重新引入"正交 @Published 变更使每行无效并拖慢 `LazyLayoutViewCache`"类型的 100% CPU 旋转循环。参考模式：`Sources/SessionIndexView.swift` 中的 `IndexSectionActions` / `SectionGapActions` / `SessionSearchFn`。
- **禁止在视图 body 计算中变更状态。** 从 `body` 调用的函数不得写入 `@Published` 状态、调度 `Task { @MainActor in store.x = … }` 或 `DispatchQueue.main.async` store 写入。这会创建重渲染反馈循环并卡死主线程。由"新数据出现"触发的状态变更工作属于 `reload()` 完成回调、`didSet` 或属性观察器 — 绝不在供 `ForEach` 使用的投影中。

## 测试质量策略

- 不要添加仅验证源代码文本、方法签名、AST 片段或 grep 模式的测试。
- 不要添加读取已签入的元数据或项目文件（如 `Resources/Info.plist`、`project.pbxproj`、`.xcconfig` 或源文件）仅断言键、字符串、plist 条目或片段存在的测试。
- 测试必须通过可执行路径（单元/集成/端到端/CLI）验证可观察的运行时行为，而非实现形状。
- 对于元数据变更，优先验证构建的 app bundle 或依赖该元数据的运行时行为，而非已签入的源文件。
- 如果行为尚无法端到端执行，先添加小型运行时接缝或测试工具，然后通过该接缝测试。
- 如果没有实际可行的行为或产物级测试，跳过虚假的回归测试并明确说明。

## Socket 命令线程策略

- 高频 socket 遥测命令（`report_*`、`ports_kick`、状态/进度/日志元数据更新）不要使用 `DispatchQueue.main.sync`。
- 遥测热路径：
  - 在非主线程解析和验证参数。
  - 先在非主线程去重/合并。
  - 仅在需要时用 `DispatchQueue.main.async` 调度最小的 UI/模型变更。
- 直接操作 AppKit/Ghostty UI 状态的命令（焦点/选择/打开/关闭/发送按键/输入、需要精确同步快照的列表/当前查询）允许在主线程运行。
- 添加新 socket 命令时，默认在非主线程处理；需要主线程执行时在代码注释中说明原因。

## Socket 焦点策略

- Socket/CLI 命令不得窃取 macOS 应用焦点（无应用激活/窗口提升副作用）。
- 只有显式焦点意图的命令可以变更应用内焦点/选择（`window.focus`、`workspace.select/next/previous/last`、`surface.focus`、`pane.focus/last`、浏览器焦点命令及 v1 焦点等价物）。
- 所有非焦点命令应在应用数据/模型变更的同时保持当前用户焦点上下文。

## 测试策略

**绝不在本地运行测试。** 所有测试（E2E、UI、Python socket 测试）通过 GitHub Actions 或 VM 运行。

- **E2E / UI 测试：** 通过 `gh workflow run test-e2e.yml` 触发
- **单元测试：** `xcodebuild -scheme cmux-unit` 安全（不启动应用），但优先使用 CI
- **Python socket 测试（tests_v2/）：** 连接运行中 cmux 实例的 socket。绝不启动未标记的 `cmux DEV.app` 来运行。如需本地测试，使用标记构建的 socket（`/tmp/cmux-debug-<tag>.sock`）配合 `CMUX_SOCKET_PATH=/tmp/cmux-debug-<tag>.sock`
- **绝不 `open` 未标记的 `cmux DEV.app`** — 会与用户运行中的 debug 实例冲突

## Ghostty 子模块工作流

Ghostty 变更必须在 `ghostty` 子模块中提交并推送到 `manaflow-ai/ghostty` fork。
保持 `docs/ghostty-fork.md` 与 fork 变更和冲突记录同步。

```bash
cd ghostty
git remote -v  # origin = 上游, manaflow = fork
git checkout -b <branch>
git add <files>
git commit -m "..."
git push manaflow <branch>
```

保持 fork 与上游同步：

```bash
cd ghostty
git fetch origin
git checkout main
git merge origin/main
git push manaflow main
```

然后在父仓库更新子模块 SHA：

```bash
cd ..
git add ghostty
git commit -m "Update ghostty submodule"
```

## 发布

使用 `/release` 命令准备新版本。它会：
1. 确定新版本号（默认 bump minor）
2. 收集上次 tag 以来的提交并更新 changelog
3. 更新 `CHANGELOG.md`（文档 changelog 页面 `web/app/docs/changelog/page.tsx` 从中读取）
4. 运行 `./scripts/bump-version.sh` 更新两个版本号
5. 提交、运行 `./scripts/release-pretag-guard.sh`、打 tag、推送

版本 bump：

```bash
./scripts/bump-version.sh          # bump minor (0.15.0 → 0.16.0)
./scripts/bump-version.sh patch    # bump patch (0.15.0 → 0.15.1)
./scripts/bump-version.sh major    # bump major (0.15.0 → 1.0.0)
./scripts/bump-version.sh 1.0.0    # 设置指定版本
```

同时更新 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`（构建号）。构建号自动递增，Sparkle 自动更新需要此项。

创建 release tag 前运行：

```bash
./scripts/release-pretag-guard.sh
```

如失败，运行 `./scripts/bump-version.sh`，提交构建号 bump，然后重试打 tag。

手动发布步骤（不使用命令时）：

```bash
./scripts/release-pretag-guard.sh
git tag vX.Y.Z
git push origin vX.Y.Z
gh run watch --repo manaflow-ai/cmux
```

注意事项：
- 需要 GitHub secrets：`APPLE_CERTIFICATE_BASE64`、`APPLE_CERTIFICATE_PASSWORD`、
  `APPLE_SIGNING_IDENTITY`、`APPLE_ID`、`APPLE_APP_SPECIFIC_PASSWORD`、`APPLE_TEAM_ID`
- Release 产物为附加在 tag 上的 `cmux-macos.dmg`
- README 下载按钮指向 `releases/latest/download/cmux-macos.dmg`
- 版本策略：更新默认 bump minor，除非另有指定
- Changelog：更新 `CHANGELOG.md`；文档 changelog 从中渲染

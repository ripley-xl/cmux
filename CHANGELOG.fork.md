# Fork Changelog (ripley-xl/cmux)

本文件记录 **Fork 自有的发布与维护要点**,独立于上游 `CHANGELOG.md`,以避免每次合入上游时产生冲突,也不会被渲染进公开文档页。

- 版本规则:上游 `v0.X.Y` → Fork 发布 `v1.X.Y`(major +1)。
- 上游完整 changelog 见 `CHANGELOG.md`;本文件只记 Fork 维护要点 + 本次合入亮点。
- 发布流程见 `CLAUDE.md` / `scripts/fork-release.sh`。

---

## [1.64.12] - 2026-06-03 (基于上游 v0.64.12)

### Fork 维护要点(下次合入的参照)

- **跨版本合入**:从 `v1.64.9`(上游 v0.64.9)一次性合入到上游 `v0.64.12`,跨越 v0.64.10 / v0.64.11 / v0.64.12 三个上游版本。
- **⚠️ 关于被禁止的 v0.64.10**:本次链路包含 v0.64.10。该版本曾因"终端 TextBox 富文本输入"(#4333)默认开启、顶掉 Claude Code 全屏而被禁止合入。**到 v0.64.12,该功能已收进 "TextBox (Beta)" 设置区,默认关闭**(`showTextBoxOnNewTerminals=false`、`focusTextBoxOnNewTerminals=false`,见 `Packages/CmuxSettings/.../TerminalCatalogSection.swift` 与 `Sources/App/WorkspaceRuntimeSettings.swift`)。新终端默认不显示 TextBox,全屏恢复正常 → **故 v0.64.12 安全合入**。下次若再遇"禁止版本",先确认其问题功能是否已被后续版本 gate/默认关闭。
- **Fork 自有改动完整保留**:`3616e0194 feat: improve SSH remote workspace experience` 在本次合并中全部存活,上游并未覆盖(仍为 Fork 独有):
  - `preferredRootPath` —— 文件浏览器跟随远程 shell CWD,而非死锁 `$HOME`(`Sources/FileExplorerStore.swift`、`Sources/ContentView.swift`)
  - 文件浏览器右键 "Set as Root" / "Go to Parent"(`Sources/FileExplorerView.swift`)
  - 修复 SSH 工作区 split 按钮开成本地 shell 而非远程 + 远程路径 `waitAfterCommand`(`Sources/Workspace.swift`、`Sources/RightSidebarToolPanel.swift`)
  - 上游 v0.64.10–12 在 SSH 区域做的是**相邻但不同**的改进(远程 PTY 分配上报、ssh-remote-pty-attach、Starship 提示符兼容),与 Fork 改动并存不冲突。
- **冲突解决记录**(合并 v0.64.12 时仅这两处冲突):
  - `CLAUDE.md` → 保留 Fork 维护指南(ours)。
  - `cmux.xcodeproj/project.pbxproj` → 取上游版本(theirs);版本号由 `fork-release.sh` 改写为 `MARKETING_VERSION=1.64.12` / `CURRENT_PROJECT_VERSION=93`。
- **合并后必做步骤**(脚本不自动处理,务必手动):
  1. `git submodule update --init --recursive` —— 本次:ghostty → `176bd550f`,vendor/bonsplit → `ddb46fe`。
  2. `./scripts/ensure-ghosttykit.sh` 重建 `GhosttyKit.xcframework`(ghostty 指针变了,Swift 通过 FFI 调用,不重建会链接失败)。
  3. 先跑一遍 Release 编译验证(`fork-release.sh` 把 build 输出截到 5 行,排错不便)。
- **本地安装注意**:`fork-release.sh` 最后一步会 `quit app "cmux"` 再装到 `/Applications`。若在 cmux 内执行会杀掉自身会话(发布步骤已在此前完成,不影响产物)。**改在非 cmux 终端执行安装那一步**。

### 合入的上游亮点 (v0.64.10 → v0.64.12)

> 完整列表见 `CHANGELOG.md` 的 [0.64.10] / [0.64.11] / [0.64.12] 三节。

#### Added
- 可断开重连的 SSH PTY 守护持久化,远程会话跨重连存活 ([#4807](https://github.com/manaflow-ai/cmux/pull/4807))
- 终端 TextBox 富文本输入 + Beta 默认设置(**默认关闭**)([#4333](https://github.com/manaflow-ai/cmux/pull/4333), [#4773](https://github.com/manaflow-ai/cmux/pull/4773))
- 可配置"打开 Diff 查看器"的键盘快捷键,设置中可编辑 ([#5178](https://github.com/manaflow-ai/cmux/pull/5178))
- Markdown 查看器字号 / 缩放控制 ([#5163](https://github.com/manaflow-ai/cmux/pull/5163))
- 侧边栏工作区字号 + tab bar 字号(上限 14pt)([#4798](https://github.com/manaflow-ai/cmux/pull/4798))

#### Changed
- Diff 查看器迁入 React 应用源码 ([#5074](https://github.com/manaflow-ai/cmux/pull/5074))
- Feed / 扩展 UI 收进 Beta Features 开关,默认关闭 ([#5174](https://github.com/manaflow-ai/cmux/pull/5174), [#5092](https://github.com/manaflow-ai/cmux/pull/5092))
- 改进终端文本右键菜单 ([#5135](https://github.com/manaflow-ai/cmux/pull/5135))
- 工作区切换器:可见标题匹配排序高于隐藏元数据 ([#5148](https://github.com/manaflow-ai/cmux/pull/5148))
- 用 macOS 26 SDK 构建 Release ([#5042](https://github.com/manaflow-ai/cmux/pull/5042))

#### Fixed
- bash 下 Starship 等自定义提示符变静止:bootstrap 与用户 `PROMPT_COMMAND` 组合 ([#5187](https://github.com/manaflow-ai/cmux/pull/5187))
- 远程 PTY 分配失败大声上报,`cmux ssh` 不再静默失败 ([#5186](https://github.com/manaflow-ai/cmux/pull/5186))
- 自定义快捷键触发 focus-surface 广播重入导致主线程卡死 ([#5108](https://github.com/manaflow-ai/cmux/pull/5108))
- 恢复右键侧边栏视图切换器及内置视图 ([#5182](https://github.com/manaflow-ai/cmux/pull/5182))
- 滚动回看剥离终端颜色 OSC 序列,旧会话不再残留上一个主题色(改主题后白底白字)([#5175](https://github.com/manaflow-ai/cmux/pull/5175))
- 浏览器 Web Inspector 手动关闭并导航后自行重开 ([#5180](https://github.com/manaflow-ai/cmux/pull/5180))
- 目录切换后 Claude fork / resume 失败 ([#5154](https://github.com/manaflow-ai/cmux/pull/5154))
- macOS 26.5 上标题栏 shortcut-hint 气泡底部被裁剪 ([#5145](https://github.com/manaflow-ai/cmux/pull/5145))
- 稳定 git 元数据 FSEvents 监听,消除事件风暴 ([#5131](https://github.com/manaflow-ai/cmux/pull/5131))
- SSH 启动脚本超长触发 E2BIG ([#5133](https://github.com/manaflow-ai/cmux/pull/5133))

### 子模块指针
- ghostty → `176bd550f6fedd29e85cd92470e5dfadf295ebf7`
- vendor/bonsplit → `ddb46fe94fbbd1efd062d80371ca2455c4296eb5`

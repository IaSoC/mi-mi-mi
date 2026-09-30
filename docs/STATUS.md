# 状态与证据 — Mi Mi Mi

> 研究状态文档，**不是**发布门禁清单。  
> English mirror: [STATUS.en.md](STATUS.en.md)  
> 构建/安装见 [BUILD.md](BUILD.md)；索引见 [README.md](../README.md)

## 当前一句话

> **「It works」——能启动、能对话、能写文件。**  
> **「How much of it is actually ARM64?」——仍须按四态逐项取证。**

## 四态定义

| 状态 | 含义 | 取证要求 |
|------|------|----------|
| **ARM64** | 已确认 ARM64 | PE 机器类型 `0xAA64`，或等价可靠证据；并说明应用是否加载该组件 |
| **x64** | 已确认 x64 | PE 机器类型 `0x8664`，或等价证据 |
| **Independent** | 无 CPU 架构相关二进制依赖 | 纯 JS/CSS/HTML/资源，或等价论证 |
| **Unknown** | 证据不足 | 缺审计、缺加载路径证明、或仅有文件存在 |

**铁律：** 文件在安装目录里出现，**不等于**应用加载它。成功启动 **不等于** 全 ARM64。

## 架构纯度（已交付结论）

来源：[compose/spec/electron-arm64-port.md](compose/spec/electron-arm64-port.md)（`status: delivered`）。

| 项 | 结论 |
|----|------|
| 纯度审计 | 架构纯度 **43/45 PE = ARM64（95.6%）**（以该 spec 报告为准） |
| 已知 x64/x86 残留 | 见下表「已知限制」；`elevate.exe` 为 x86（小体积，模拟层可接受）；Python embeddable 遗留 `vcruntime140_1.dll` 为 x64 |
| 功能回归（当时） | node-pty / parcel-watcher / Python+pydantic / qpdf / ripgrep / github-mcp-server 等 PASS（spec 报告） |
| 启动冒烟 | 窗口标题、API/插件/SSO/引擎栈加载（spec 报告） |

> 仓库 README 曾出现过「49/55 PE」等历史表述；**以 delivered spec 与 bench 证据目录为准**，不把旧数字与新证据混写。

## 已知限制（状态层面）

| 项目 | 状态 | 说明 |
|------|------|------|
| `elevate.exe` | x86 | 体积小，Prism 可接受 |
| `vcruntime140_1.dll` | x64 | Python embeddable 遗留 |
| 自动更新 | 不支持 ARM64 | 官方 CDN 无 `win-arm64`；drop-in 故意不带 `app-update.yml` |
| 代码签名 | 无 | 产物为未签名目录/skeleton |
| ARM64 生态持续维护 | 实验范围外 | 见 spec Out of Scope |

## 性能基准（证据指针，不在此重跑）

主交付 spec 中有一组基于 CDP / bench-run 的 ARM64 vs x64 对照（总运行、engineFetch、loadEngineSessions 等）。历史目录：

| 证据 | 路径 |
|------|------|
| 10-run startup 归档 | [scripts/bench-output/startup-10run-20260926.md](../scripts/bench-output/startup-10run-20260926.md) |
| functional 摘要（ARM64/x64） | `scripts/bench-output/functional-ARM64-20260926-225827/` · `.../functional-x64-20260926-225842/` |
| deep probe | `scripts/bench-output/deep-ARM64-20260926-232826/` · `.../deep-x64-20260926-232856/` |
| cpuprofile | `scripts/bench-output/cpuprof-ARM64-20260927-001929/` · `.../cpuprof-x64-20260927-001940/` |

测量口径（代理/脚本约定，见 [AGENTS.md](../AGENTS.md)）：

- 平台对比使用 **T1 `list-ready`**（进程启动到项目列表就绪）的绝对时间，不以 `mainToList` 作主指标。
- 里程碑经 **CDP**（`scripts/cdp-probe.mjs`），不以 stderr 文本正则作为主指标。
- 数字必须能追溯到 `scripts/bench-output/<kind>-<Side>-<timestamp>/`。

**研究清单未勾选项不表示当前已验证；重跑基准需用户确认，且禁止两侧并发。**

## 研究核对清单

来自原 README Verification Plan 的迁入版本。**状态列反映文档重组时的叙事状态**；完成项表示当时有操作记录，**不自动**等于今天再次复测通过。

### 1. 核心应用

| 项 | 叙事状态 |
|----|----------|
| 新对话 | 已记录 |
| 新项目 | 已记录 |
| 多轮对话 | 已记录 |
| 长时间 Agent 任务 | 已记录 |
| 文件创建 / 读取 / 修改 / 删除 | 已记录 |
| 目录操作 | 已记录 |
| 应用重启 | **未完成** |
| 状态持久化 | 已记录 |

### 2. Electron 功能

| 项 | 叙事状态 |
|----|----------|
| GPU 加速 | 已记录 |
| 剪贴板 | 已记录 |
| 拖放 | 已记录 |
| 通知 | 已记录 |
| 文件对话框 | 已记录 |
| 外部浏览器调用 | **未完成** |
| 多窗口 | **未完成** |
| 主/渲染进程 IPC | 已记录 |

### 3. 进程架构（审计项）

在输出目录检查完整进程树，记录：进程名、架构、可执行路径、父进程、用途。关注：ARM64/x64/x86、helper、更新器、crash reporter、GPU、utility 进程。

### 4. Native 组件（审计项）

安装环境中 `*.dll` `*.exe` `*.node` `*.asar` 按四态分类。文件存在 ≠ 应用使用。

## 证据索引

| 文档 | 用途 |
|------|------|
| [compose/spec/electron-arm64-port.md](compose/spec/electron-arm64-port.md) | 移植设计、任务完成记录、性能与 journey log |
| [BUILD.md](BUILD.md) | 操作正典（如何构建/安装） |
| [portkit/README.md](../portkit/README.md) | 作者路径细节与已知限制表 |
| [release/DROP-IN.md](release/DROP-IN.md) | drop-in 安装与第三方声明 |
| [compose/spec/](compose/spec/) | deck 与演示相关 spec |

## 更新约定

- 本文件与 [STATUS.en.md](STATUS.en.md) **成对**更新（`*.md` 中文，`*.en.md` 英文）。
- 只在有新证据时改状态表；禁止把「能跑」写成 fully ARM64。
- 性能数字变更必须指向新的 `scripts/bench-output/` 目录。

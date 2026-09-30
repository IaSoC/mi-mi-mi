# Build / Install — Mi Mi Mi

> **这是操作正典。** 使用者走 drop-in；维护者才走 portkit 作者路径。  
> English mirror: [BUILD.en.md](BUILD.en.md)

## 角色与路径

| 路径 | 给谁 | 入口 |
|------|------|------|
| **Drop-in（正典）** | 想在 Windows on ARM 上原生跑 MiMo Desktop 的使用者 | 本文 §1 · [release/DROP-IN.md](release/DROP-IN.md) |
| **Portkit 作者路径** | 从零重铸/更新 ARM64 骨架的维护者 | [portkit/README.md](../portkit/README.md) |

两层职责不同：drop-in **不**重新编译 Electron/natives；portkit **不**是消费者安装步骤。

```
使用者：官方 x64 安装中的 payload ──拷入──► ARM64 骨架 ──Patch-Asar──► 启动
作者：  Electron ARM64 壳 + natives 替换 ──构建──► output/Xiaomi MiMo ARM64 ──打 release 包──► drop-in zip
```

## §1 使用者：Drop-in（正典）

### 前置条件

| 项 | 要求 |
|----|------|
| 系统 | Windows 11 ARM64（Windows on ARM） |
| 官方安装 | 已合法安装 x64 Xiaomi MiMo Desktop，路径默认 `%LOCALAPPDATA%\Programs\Xiaomi MiMo\` |
| 骨架包 | payload-free ARM64 runtime skeleton zip（由作者发布；仓库内不附带专有 payload） |

骨架体积参考：约 875 MB（zip 约 327 MB）。适配过的 payload 版本示例：`26.923.232338`（以 DROP-IN 文档与补丁脚本输出为准）。

### 步骤

完整图文/校验说明见 **[release/DROP-IN.md](release/DROP-IN.md)**。摘要：

1. **解压骨架** 到长期路径，例如 `D:\MiMo-ARM64\`。
2. **从官方安装拷贝 payload**（**不要**覆盖 `resources\app.asar.unpacked`）：

   | 自官方安装 | 拷入骨架 |
   |------------|----------|
   | `resources\app.asar` | `resources\app.asar` |
   | `resources\evolve-seed\` | `resources\evolve-seed\` |
   | `resources\browser-extension\` | `resources\browser-extension\` |
   | `resources\computer-use-windows\` | `resources\computer-use-windows\` |
   | `resources\elevate.exe` | `resources\elevate.exe` |

3. **补丁 asar** — 双击 `Patch-Asar.bat`（普通 PowerShell，无需 Node）。
   - 期望：`RESULT : OK, patched` 或再次运行时 `OK, already patched`
   - 若 `RESULT : FAIL`（exit 2）：官方 payload 版本已变，补丁模式漂移。**不要启动**，记录官方版本号。
4. **启动** — 双击 `Launch ARM64.bat`。

### 行为说明

- **无自动更新**：官方更新通道没有 `win-arm64` 条目；骨架不含 `app-update.yml`。新版 payload 到来时重复步骤 2–3，并关注补丁漂移。
- **遥测**：你拷入的 payload 行为与官方应用一致；本项目不额外添加遥测。`MIMO_APM_DISABLE=1` 可关闭 APM reporter。

### 安全与法律

骨架可再分发的是 **不含专有 payload** 的 ARM64 运行时壳（Electron/Chromium/natives 等，许可证见 DROP-IN 第三方声明）。`app.asar` 及相关 payload 由你从自己的合法安装中提供，其许可由小米条款约束。本项目不提供代码签名。

## §2 维护者：Portkit 作者路径

### 前置条件

| 工具 | 用途 | 安装 |
|------|------|------|
| Visual Studio 2022 Build Tools | MSVC ARM64 交叉编译 | `portkit\msvc-arm64.vsconfig` |
| Git | 版本管理 | winget install Git.Git |
| PowerShell 5.1+ | 脚本执行 | 系统自带 |
| curl | 文件下载 | 系统自带 |
| 官方 x64 MiMo Desktop | 提取架构无关 payload | 合法安装 |

安装 Build Tools：

```powershell
winget install -e --id Microsoft.VisualStudio.BuildTools --override "--passive --config .\portkit\msvc-arm64.vsconfig --installPath C:\BuildTools"
```

### 脚本序列（以磁盘文件名为准）

| 步骤 | 脚本 | 作用 |
|------|------|------|
| 0 | `portkit\scripts\00-setup.ps1` | 检查 MSVC ARM64 / CMake / Git / curl |
| 1 | `portkit\scripts\01-download.ps1` | 下载 Electron ARM64 与 runtimes 到 `cache/downloads/` |
| 2 | `portkit\scripts\02-extract.ps1` | **从官方 x64 安装提取** 架构无关资源并嫁接到 ARM64 壳 |
| 3 | `portkit\scripts\03-verify.ps1` | 架构审计与启动验证 |

**不存在** `02-build.ps1`。脚本注释与文档一律以磁盘 `02-extract.ps1` 为准。

### 从仓库根运行（推荐）

```powershell
# 在仓库根目录
powershell -ExecutionPolicy Bypass -File portkit\scripts\00-setup.ps1
powershell -ExecutionPolicy Bypass -File portkit\scripts\01-download.ps1
powershell -ExecutionPolicy Bypass -File portkit\scripts\02-extract.ps1
powershell -ExecutionPolicy Bypass -File portkit\scripts\03-verify.ps1
```

若已 `cd portkit\`，则使用：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\00-setup.ps1
powershell -ExecutionPolicy Bypass -File scripts\01-download.ps1
powershell -ExecutionPolicy Bypass -File scripts\02-extract.ps1
powershell -ExecutionPolicy Bypass -File scripts\03-verify.ps1
```

详细提取清单、native 替换映射、asar 补丁说明见 [portkit/README.md](../portkit/README.md)。

### 仓库内相关脚本

| 脚本 | 用途 |
|------|------|
| `scripts\patch-asar.js` | 对官方 `app.asar` 做等长平台白名单补丁；`--check` 只检查 |
| `scripts\patch-asar.ps1` | PowerShell 侧补丁入口 |
| `scripts\release\Patch-Asar.bat` | drop-in 骨架内的一键补丁 |
| `scripts\release\Launch ARM64.bat` | drop-in 骨架内的一键启动 |
| `scripts\test-dropin.ps1` | drop-in 验收（拷 payload → 补丁 → CDP 里程碑 → 可选 functional） |

**进程管理**：`output\Xiaomi MiMo ARM64\` 下可能正是正在运行的 MiMo Desktop（含 AI 本身）。杀进程只能按已记录 PID，禁止按路径批量杀。

## §3 验证与证据

架构与功能证据 **不在本文件展开数字**，见 [STATUS.md](STATUS.md)。

与文档相关的既有设计结论：[compose/spec/electron-arm64-port.md](compose/spec/electron-arm64-port.md)。

## 相关文档

- [release/DROP-IN.md](release/DROP-IN.md) — 使用者安装细则与第三方声明  
- [STATUS.md](STATUS.md) — 四态证据与研究清单  
- [portkit/README.md](../portkit/README.md) — 作者路径细节  
- [README.md](../README.md) — 项目索引  
- [AGENTS.md](../AGENTS.md) — 代理约定  

*MIT © 2026 IaSoC — See `portkit/LICENSE` for build tooling licensing.*

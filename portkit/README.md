# MiMo Desktop x64 → ARM64 移植工具包（作者路径）

> **这是作者路径，不是消费者安装指南。**  
> 消费者请走 [docs/BUILD.md](../docs/BUILD.md) → drop-in / [docs/release/DROP-IN.md](../docs/release/DROP-IN.md)。  
> English mirror: [README.en.md](README.en.md)

Post-Market 约束下，从官方 x64 二进制提取并构建原生 ARM64 版本。

## 前置条件

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| **Visual Studio 2022 Build Tools** | MSVC ARM64 交叉编译 | `msvc-arm64.vsconfig` |
| **Git** | 版本管理 | winget install Git.Git |
| **PowerShell 5.1+** | 脚本执行 | 系统自带 |
| **curl** | 文件下载 | 系统自带 |
| **官方 x64 MiMo Desktop** | 提取架构无关 payload | 合法安装 |

VS Build Tools 组件清单（`msvc-arm64.vsconfig`）：

```json
{
  "version": "1.0",
  "components": [
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "Microsoft.VisualStudio.Component.Windows11SDK.26100"
  ]
}
```

安装命令（在**仓库根**执行）：

```powershell
winget install -e --id Microsoft.VisualStudio.BuildTools --override "--passive --config .\portkit\msvc-arm64.vsconfig --installPath C:\BuildTools"
```

## 快速开始（作者路径）

**磁盘脚本名以实际文件为准：**

| 步骤 | 脚本 |
|------|------|
| 0 | `portkit\scripts\00-setup.ps1` |
| 1 | `portkit\scripts\01-download.ps1` |
| 2 | `portkit\scripts\02-extract.ps1` |
| 3 | `portkit\scripts\03-verify.ps1` |

**不存在 `02-build.ps1`。** 脚本注释与文档一律以磁盘 `02-extract.ps1` 为准。

### 从仓库根运行（推荐）

```powershell
# 1. 设置环境
powershell -ExecutionPolicy Bypass -File portkit\scripts\00-setup.ps1

# 2. 下载 ARM64 组件
powershell -ExecutionPolicy Bypass -File portkit\scripts\01-download.ps1

# 3. 提取并嫁接到 ARM64 壳（不是「从零编译 Electron」）
powershell -ExecutionPolicy Bypass -File portkit\scripts\02-extract.ps1

# 4. 验证
powershell -ExecutionPolicy Bypass -File portkit\scripts\03-verify.ps1
```

### 从 `portkit\` 目录运行

```powershell
powershell -ExecutionPolicy Bypass -File scripts\00-setup.ps1
powershell -ExecutionPolicy Bypass -File scripts\01-download.ps1
powershell -ExecutionPolicy Bypass -File scripts\02-extract.ps1
powershell -ExecutionPolicy Bypass -File scripts\03-verify.ps1
```

## 从官方二进制提取（关键步骤）

### 目标

官方安装的 x64 MiMo Desktop 位于 `%LOCALAPPDATA%\Programs\Xiaomi MiMo\`（本文档作者机器上常为 `C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\`）。需要提取架构无关资源并嫁接到 ARM64 Electron 壳上。

### 提取清单

| 资源 | 路径 | 操作 |
|------|------|------|
| **app.asar** | `resources/app.asar` | 直接复制 + 补丁 |
| **app.asar.unpacked** | `resources/app.asar.unpacked/` | 复制后替换 native 二进制 |
| **browser-extension** | `resources/browser-extension/` | 直接复制 |
| **computer-use-windows** | `resources/computer-use-windows/` | 直接复制 |
| **evolve-seed** | `resources/evolve-seed/` | 直接复制 |
| **app-update.yml** | `resources/app-update.yml` | 直接复制（drop-in 发布物通常**不要**） |
| **elevate.exe** | `resources/elevate.exe` | 直接复制 (x86, 可接受) |
| **locales/** | `locales/*.pak` | 从 Electron ARM64 包取 |

### 不需要提取（从 Electron ARM64 包替换）

| 资源 | 说明 |
|------|------|
| `Xiaomi MiMo.exe` | Electron ARM64 主程序 |
| `*.dll` (Chromium) | ffmpeg/libEGL/libGLESv2/vulkan/d3dcompiler 等 |
| `*.pak`, `icudtl.dat` | Chromium 资源 |
| `snapshot_blob.bin`, `v8_context_snapshot.bin` | V8 快照 |
| `locales/` | 从 Electron ARM64 包取 |

提取实现细节以 `portkit\scripts\02-extract.ps1` 为准。

### Native 模块替换映射

| x64 原版 | ARM64 替换 | 来源 |
|----------|-----------|------|
| `@lydell/node-pty-win32-x64` | `@lydell/node-pty-win32-arm64` | npm 预编译 |
| `@napi-rs/canvas-win32-x64-msvc` | `@napi-rs/canvas-win32-arm64-msvc` | npm 预编译 |
| `@parcel/watcher-win32-x64` | `@parcel/watcher-win32-arm64` | npm 预编译 |
| `onnxruntime-node/bin/.../x64/` | `onnxruntime-node/bin/.../arm64/` | npm 自带 |
| `@img/sharp-win32-x64` | `@img/sharp-win32-arm64` | npm 预编译 |

**注意**：目录名保留 `*-x64`（匹配 asar 头），内容替换为 ARM64 二进制。JS 中 `process.arch` 拼接改为写死 `x64`。

### asar 补丁

| 补丁 | 文件 | 内容 |
|------|------|------|
| 平台白名单 | `app.asar` (binary) | 等长编辑，使 `win32-arm64` 被接受（见 `scripts\patch-asar.js` / `scripts\release\Patch-Asar.bat`） |
| canvas 绑定路径 | `js-binding.js` (unpacked) | 绝对路径绕过 asar |
| node-pty 包名 | `index.js` (unpacked) | `process.arch` → `x64` |
| parcel-watcher 包名 | `index.js` (unpacked) | `process.arch` → `x64` |
| onnxruntime 路径 | `binding.js` (unpacked) | 路径写死 `win32/x64` |

### Runtimes 替换映射

| 组件 | 来源 | 版本（示例） |
|------|------|----------------|
| Node.js | `node-v24.15.0-win-arm64.zip` | 24.15.0 |
| Python | `python-3.12.10-embed-arm64.zip` + pip wheel | 3.12.10 |
| ripgrep | `ripgrep-15.2.0-aarch64-pc-windows-msvc.zip` | 15.2.0 |
| qpdf | 源码编译 (zlib + libjpeg-turbo) | 12.4.1 |
| github-mcp-server | `github-mcp-server_Windows_arm64.zip` | 1.12.2 |
| sharp | npm `@img/sharp-win32-arm64` | 见 npm |

版本以下载缓存与实际构建为准；本表为历史对齐参考。

## 验证清单

```powershell
# 架构纯度审计（PE machine type）
Get-ChildItem "output\Xiaomi MiMo ARM64" -Recurse -Include "*.exe","*.dll","*.node" |
  ForEach-Object {
    $b = [IO.File]::ReadAllBytes($_.FullName)
    $pe = [BitConverter]::ToInt32($b, 0x3C)
    $m = [BitConverter]::ToUInt16($b, $pe+4)
    "$(@{0x8664='x64';0xAA64='ARM64';0x014C='x86'}[$m])  $($_.Name)"
  }

# 启动测试
& "output\Xiaomi MiMo ARM64\Launch ARM64.bat"

# 功能测试
# - 终端 (node-pty): 打开内置终端
# - 会话列表: 确认会话显示
# - 对话: 发送消息确认 API 连通

# drop-in 验收（完整流程）
powershell -ExecutionPolicy Bypass -File scripts\test-dropin.ps1
```

**进程管理铁律：** `output\Xiaomi MiMo ARM64\` 下的进程可能是正在运行的 MiMo Desktop（用户 + AI 自身）。只按已记录 PID 定点操作，禁止按路径批量杀。

状态与证据指针见 [docs/STATUS.md](../docs/STATUS.md)。

## 已知限制

| 项目 | 状态 | 说明 |
|------|------|------|
| `elevate.exe` | x86 | 体积小，模拟层运行可接受 |
| `vcruntime140_1.dll` | x64 | Python embeddable 遗留 |
| 自动更新 | 回退 x64 | 更新 CDN 提供 x64 包 |
| 代码签名 | 无 | 产物为未签名目录 |

## 性能参考

历史参考数字曾出现在旧版 portkit README；**不要当作当前唯一证据**。  
请以 [docs/STATUS.md](../docs/STATUS.md) 指向的 `scripts/bench-output/` 与 [docs/compose/spec/electron-arm64-port.md](../docs/compose/spec/electron-arm64-port.md) 为准。

## 相关文档

- [docs/BUILD.md](../docs/BUILD.md) — 操作正典  
- [docs/release/DROP-IN.md](../docs/release/DROP-IN.md) — 消费者 drop-in  
- [docs/STATUS.md](../docs/STATUS.md) — 状态与证据  
- [scripts/patch-asar.js](../scripts/patch-asar.js) · [scripts/test-dropin.ps1](../scripts/test-dropin.ps1)  
- [scripts/release/](../scripts/release/) — 骨架内 bat  

*MIT © 2026 IaSoC — 见 [LICENSE](LICENSE)。*

# MiMo Desktop x64 → ARM64 移植工具包

Post-Market 约束下，从官方 x64 二进制提取并构建原生 ARM64 版本。

## 前置条件

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| **Visual Studio 2022 Build Tools** | MSVC ARM64 交叉编译 | `msvc-arm64.vsconfig` |
| **Git** | 版本管理 | winget install Git.Git |
| **PowerShell 5.1+** | 脚本执行 | 系统自带 |
| **curl** | 文件下载 | 系统自带 |

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

安装命令：
```powershell
winget install -e --id Microsoft.VisualStudio.BuildTools --override "--passive --config .\msvc-arm64.vsconfig --installPath C:\BuildTools"
```

## 快速开始

```powershell
# 1. 设置环境
powershell -ExecutionPolicy Bypass -File scripts\00-setup.ps1

# 2. 下载 ARM64 组件
powershell -ExecutionPolicy Bypass -File scripts\01-download.ps1

# 3. 构建 ARM64 产物
powershell -ExecutionPolicy Bypass -File scripts\02-build.ps1

# 4. 验证
powershell -ExecutionPolicy Bypass -File scripts\03-verify.ps1
```

## 从官方二进制提取（关键步骤）

### 目标

官方安装的 x64 MiMo Desktop 位于 `C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\`，
需要提取以下架构无关资源并嫁接到 ARM64 Electron 壳上：

### 提取清单

| 资源 | 路径 | 操作 |
|------|------|------|
| **app.asar** | `resources/app.asar` | 直接复制 + 补丁 |
| **app.asar.unpacked** | `resources/app.asar.unpacked/` | 复制后替换 native 二进制 |
| **browser-extension** | `resources/browser-extension/` | 直接复制 |
| **computer-use-windows** | `resources/computer-use-windows/` | 直接复制 |
| **evolve-seed** | `resources/evolve-seed/` | 直接复制 |
| **app-update.yml** | `resources/app-update.yml` | 直接复制 |
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

### 提取脚本

```powershell
# scripts\extract-from-official.ps1
# 从官方 x64 安装提取架构无关资源

param(
    [string]$SourceDir = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo",
    [string]$TargetDir = ".\output\Xiaomi MiMo ARM64"
)

# 复制架构无关资源
$items = @(
    "resources\app.asar",
    "resources\app.asar.unpacked",
    "resources\app-update.yml",
    "resources\browser-extension",
    "resources\computer-use-windows",
    "resources\evolve-seed",
    "resources\elevate.exe",
    "LICENSE.electron.txt",
    "LICENSES.chromium.html"
)
foreach ($item in $items) {
    $src = Join-Path $SourceDir $item
    $dst = Join-Path $TargetDir $item
    if (Test-Path $src) {
        Copy-Item $src $dst -Recurse -Force
        Write-Output "OK   $item"
    }
}
```

### Native 模块替换映射

| x64 原版 | ARM64 替换 | 来源 |
|----------|-----------|------|
| `@lydell/node-pty-win32-x64` | `@lydell/node-pty-win32-arm64` | npm 预编译 |
| `@napi-rs/canvas-win32-x64-msvc` | `@napi-rs/canvas-win32-arm64-msvc` | npm 预编译 |
| `@parcel/watcher-win32-x64` | `@parcel/watcher-win32-arm64` | npm 预编译 |
| `onnxruntime-node/bin/.../x64/` | `onnxruntime-node/bin/.../arm64/` | npm 自带 |
| `@img/sharp-win32-x64` | `@img/sharp-win32-arm64` | npm 预编译 |

**注意**：目录名保留 `*-x64`（匹配 asar 头），内容替换为 ARM64 二进制。
JS 中 `process.arch` 拼接改为写死 `x64`。

### asar 补丁

| 补丁 | 文件 | 内容 |
|------|------|------|
| WNe 平台白名单 | `app.asar` (binary) | `darwin-arm64` → `win32-arm64` |
| canvas 绑定路径 | `js-binding.js` (unpacked) | 绝对路径绕过 asar |
| node-pty 包名 | `index.js` (unpacked) | `process.arch` → `x64` |
| parcel-watcher 包名 | `index.js` (unpacked) | `process.arch` → `x64` |
| onnxruntime 路径 | `binding.js` (unpacked) | 路径写死 `win32/x64` |

### Runtimes 替换映射

| 组件 | 来源 | 版本 |
|------|------|------|
| Node.js | `node-v24.15.0-win-arm64.zip` | 24.15.0 |
| Python | `python-3.12.10-embed-arm64.zip` + pip wheel | 3.12.10 |
| ripgrep | `ripgrep-15.2.0-aarch64-pc-windows-msvc.zip` | 15.2.0 |
| qpdf | 源码编译 (zlib + libjpeg-turbo) | 12.4.1 |
| github-mcp-server | `github-mcp-server_Windows_arm64.zip` | 1.12.2 |
| sharp | npm `@img/sharp-win32-arm64` | 0.35.4 |

## 验证清单

```powershell
# 架构纯度审计
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
# - 会话列表: 确认 18 个会话显示
# - 对话: 发送消息确认 API 连通
```

## 已知限制

| 项目 | 状态 | 说明 |
|------|------|------|
| `elevate.exe` | x86 | 体积小，模拟层运行可接受 |
| `vcruntime140_1.dll` | x64 | Python embeddable 遗留 |
| 自动更新 | 回退 x64 | 更新 CDN 提供 x64 包 |
| 代码签名 | 无 | 产物为未签名目录 |

## 性能基准参考

| 指标 | ARM64 | x64 模拟层 | 倍率 |
|------|-------|-----------|------|
| 窗体出现 | 4.5s | 6.2s | 1.37× |
| JS bundle + React | 4.5s | 18.1s | 4.0× |
| 任务数据就绪 | 210ms | 195ms | 1.1× |
| 总启动 | 9.5s | 24.7s | 2.6× |

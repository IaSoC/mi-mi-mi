---
feature: electron-arm64-port
status: delivered
updated: 2026-09-25
branch: master
commits: 
---

# MiMo Desktop Post-Market ARM64 Port

## Report

**What was built** — 在 Post-Market 约束下（无源码、无上游构建环境），将 Xiaomi MiMo Desktop (Electron 41.7.2) 从 x64 移植为原生 ARM64。产物位于 `output/Xiaomi MiMo ARM64/`，与原 x64 安装并存。核心手法：Electron 官方 ARM64 壳替换 + npm 预编译包移植 + 编译缺失组件 + asar 内模块解析补丁。

**Verification** — 架构纯度审计 43/45 PE 为 ARM64 (95.6%)，仅剩 `vcruntime140_1.dll` (x64, Python embeddable 遗留) 和 `elevate.exe` (x86) 两处已知瑕疵。启动冒烟测试通过：窗口标题 `Xiaomi MiMo`，6 个辅助进程全在 ARM64 路径，日志显示 API 连接 / 插件系统 / SSO 登录 / 更新检查 / 引擎服务 (端口 50003/50004/50007) 全部加载。node-pty / canvas / parcel-watcher / onnxruntime / sharp 全部 ARM64 加载。qpdf 12.4.1 从源码交叉编译为 ARM64。

**Journey log** —
1. asar 头仍登记 `*-x64` 包名，Node 模块解析经 asar 虚拟 fs 找不到 `*-arm64` 包 → 将磁盘目录改回 `*-x64` 名并补丁 JS 中 `process.arch` 拼接为写死 `x64`。
2. `@napi-rs/canvas` 的 `js-binding.js` 是 `unpacked:true`，可直接改；但 `require('./skia.win32-arm64-msvc.node')` 走 asar fs 仍找不到文件 → 改为 `require(path.join(process.resourcesPath, 'app.asar.unpacked', ...))` 绝对路径绕过 asar。
3. onnxruntime-node 1.27.0 npm 包自带 `win32/arm64` 预编译（此前未发现）——无需编译绑定层。
4. qpdf 无 ARM64 发行版 → 自建 zlib + libjpeg-turbo 后 MSVC ARM64 交叉编译；中文 Windows 代码页 936 导致编译错误，加 `/utf-8` 解决。
5. 单实例锁导致 ARM64 实例与原 x64 互踢 → 测试用 `--user-data-dir` 隔离；杀进程务必按 PID/完整路径，按进程名会误杀正在运行的 MiMo。

## [S1] Problem

MiMo Desktop (Electron 41.7.2) 以 x64 安装于 `C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo`，运行在 Xiaomi Book 12.4 (Snapdragon 8cx Gen 2, ARM64) 的 Windows x64 模拟层上。目标：Post-Market 约束下产出原生 ARM64 安装。

## [S2] Design

### 策略：二进制嫁接

| 层 | 来源 | 版本 |
|----|------|------|
| Electron 壳 + Chromium DLL | `electron-v41.7.2-win32-arm64.zip` | 精确 41.7.2 |
| node-pty / canvas / parcel-watcher / sharp | npm `*-win32-arm64` 预编译 | 匹配应用版本 |
| onnxruntime-node | npm 1.27.0 自带 `win32/arm64/` | N-API 兼容 |
| Node.js / Python / ripgrep / github-mcp-server | 官方 ARM64 便携包 | 对齐主版本 |
| qpdf | 源码 MSVC ARM64 交叉编译 | 12.4.1 |

### 关键补丁

1. **asar 模块解析**：`app.asar` 头登记 `*-x64` 包名，JS 内 `process.arch` 拼出 `*-arm64` 无法解析 → 磁盘目录用 `*-x64` 名（内容 ARM64），JS 中 arch 拼接写死 `x64`。
2. **canvas js-binding**：`unpacked:true`，直接补丁为绝对路径 `require(path.join(process.resourcesPath, 'app.asar.unpacked', ...))` 绕过 asar。
3. **WNe 平台白名单**：asar 内 `return r==="darwin-arm64"||r==="win32-x64"||r==="linux-x64"?r:null` → 同长替换为 `win32-arm64`（LibreOffice 路径）。
4. **onnxruntime binding.js**：路径写死 `win32/x64`（磁盘已放 ARM64 二进制）。

### 产物布局

```
output/Xiaomi MiMo ARM64/
├── Xiaomi MiMo.exe          (ARM64, from Electron 41.7.2)
├── *.dll, *.pak, locales/   (ARM64)
└── resources/
    ├── app.asar             (含 WNe 补丁)
    ├── app.asar.unpacked/   (native modules 全 ARM64 + JS 补丁)
    └── runtimes/win32-arm64/
        ├── node/ python/ ripgrep/ github-mcp-server/ qpdf/
        ├── node_modules/     (sharp ARM64)
        └── python-evolve-site/
```

## [S3] Out of Scope

- 代码签名 / 安装器
- 自动更新通道（会回退到 x64）
- 注册表 / 开始菜单快捷方式
- 性能基准对比

## Tasks

- [x] T1: Extract Electron ARM64 shell — acceptance: PE header 0xAA64 (covers: S2)
- [x] T2: Transplant app payload — acceptance: file tree matches original (covers: S2)
- [x] T3: Replace native node_modules ARM64 — acceptance: all .node/.dll ARM64 (covers: S2)
- [x] T4: onnxruntime-node ARM64 — acceptance: binding.node + dll ARM64 (covers: S2)
- [x] T5: Build runtimes tree win32-arm64 — acceptance: all PE ARM64 (covers: S2)
- [x] T6: qpdf ARM64 compile — acceptance: qpdf.exe ARM64 (covers: S2)
- [x] T7: Patch asar module resolution — acceptance: runtime finds ARM64 natives (covers: S2)
- [x] T8: Architecture audit + launch + terminal — acceptance: 95.6% purity, UI opens, helpers ARM64 (covers: S1, S2)

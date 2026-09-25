---
feature: electron-arm64-port
status: delivered
updated: 2026-09-26
branch: master
commits: 680ffe8..9535bca
---

# MiMo Desktop Post-Market ARM64 Port

## Report

**What was built** — 在 Post-Market 约束下（无源码、无上游构建环境），将 Xiaomi MiMo Desktop (Electron 41.7.2) 从 x64 移植为原生 ARM64。产物位于 `output/Xiaomi MiMo ARM64/`。核心手法：Electron 官方 ARM64 壳替换 + npm 预编译包移植 + 编译缺失组件 + asar 内模块解析补丁。Python C 扩展（pydantic_core / jiter）通过 ARM64 wheel 修复。

**Verification** — 架构纯度 43/45 PE 为 ARM64 (95.6%)。功能回归全 PASS：node-pty (spawn/IO)、parcel-watcher、Python 3.12 + pydantic + httpx、qpdf 12.4.1、ripgrep 15.2.0 (NEON SIMD)、github-mcp-server 1.12.2。启动冒烟：窗口 `Xiaomi MiMo`、API/插件/SSO/引擎栈全加载、用户配置正确识别。

性能基准（`bench-run.ps1` 单次运行 + 人手关闭，真实用户数据含 18 个会话）：

| 指标 | ARM64 | x64 模拟层 | 倍率 |
|------|-------|-----------|------|
| 总运行时间 | 17.1s | 36.4s | **2.1×** |
| engineFetch API | 2,805 ms | 11,561 ms | **4.1×** |
| loadEngineSessions | 2.9s | 11.8s | **4.1×** |
| 窗口标题出现 | 5,870 ms | 6,128 ms | 1.04× |
| 峰值 RSS | 1,213 MB | 1,712 MB | +41% |
| CPU 累计 | 19s | 47.5s | 2.5× |

「最近工作」列表延迟的根因是 **engineFetch API 在模拟层下慢 4 倍**（进程间 HTTP），不是渲染。用户观测到 x64 约 33s 才显示最近工作，与 loadEngineSessions 31s + 渲染收尾吻合。

**Journey log** —
1. asar 头登记 `*-x64` 包名，JS 中 `process.arch` 拼出 `*-arm64` 无法解析 → 目录改回 `*-x64` 名（内容 ARM64），JS 拼接写死 `x64`。
2. `js-binding.js` 是 `unpacked:true` 可直接改，但相对 `require('./skia.*.node')` 仍走 asar fs → 改绝对路径 `process.resourcesPath + app.asar.unpacked` 绕过。
3. onnxruntime-node 1.27.0 npm 包自带 `win32/arm64` 预编译，省了编译绑定层。
4. Python embeddable 的 `pydantic_core` / `jiter` 是 x64 `.pyd` → ARM64 pip 装 `win_arm64.whl` 修复。
5. **进程管理铁律**：`output\Xiaomi MiMo ARM64\` 下的进程就是正在运行的 MiMo Desktop（用户 + AI 自身），按路径批量杀会自杀。只按已记录 PID 定点操作。
6. **性能对比要对齐 UI 态**：空 user-data 进登录页 vs 已登录主界面，加载量不同不可比。早期 bench-startup.ps1 在灰屏时杀进程量出假数据（x64 "6s"实际 33s）。
7. **里程碑触发≠UI 可用**：窗口标题（~6s）和日志标记在渲染完成前就绪。正确做法：人手关闭 + 完整日志导出（bench-run.ps1）。
8. **x64 慢的根因是 IPC 不是渲染**：engineFetch 进程间 HTTP 调用在模拟层下 4 倍延迟（2.8s → 11.8s），这是「最近工作」列表晚出 20s 的主因。窗口标题两边几乎一样快。

## [S1] Problem

MiMo Desktop (Electron 41.7.2) 以 x64 安装于 ARM64 设备（Xiaomi Book 12.4, Snapdragon 8cx Gen 2）的 Windows x64 模拟层上。目标：Post-Market 约束下产出原生 ARM64 安装。

## [S2] Design

### 策略：二进制嫁接

| 层 | 来源 | 版本 |
|----|------|------|
| Electron 壳 + Chromium DLL | `electron-v41.7.2-win32-arm64.zip` | 精确 41.7.2 |
| node-pty / canvas / parcel-watcher / sharp | npm `*-win32-arm64` 预编译 | 匹配应用版本 |
| onnxruntime-node | npm 1.27.0 自带 `win32/arm64/` | N-API 兼容 |
| Node.js / Python / ripgrep / github-mcp-server | 官方 ARM64 便携包 | 对齐主版本 |
| qpdf | 源码 MSVC ARM64 交叉编译 | 12.4.1 |
| pydantic_core / jiter | pip `win_arm64` wheel | 2.46.5 / 0.16.0 |

### 关键补丁

1. **asar 模块解析**：目录用 `*-x64` 名（内容 ARM64），JS 中 arch 拼接写死 `x64`。
2. **canvas js-binding**：绝对路径绕过 asar fs。
3. **WNe 平台白名单**：同长替换加入 `win32-arm64`。
4. **onnxruntime binding.js**：路径写死 `win32/x64`（磁盘已放 ARM64 二进制）。

### 产物布局

```
output/Xiaomi MiMo ARM64/
├── Xiaomi MiMo.exe          (ARM64)
├── *.dll, *.pak, locales/   (ARM64)
└── resources/
    ├── app.asar             (含 WNe 补丁)
    ├── app.asar.unpacked/   (native modules 全 ARM64 + JS 补丁)
    └── runtimes/win32-arm64/
        ├── node/ python/ ripgrep/ github-mcp-server/ qpdf/
        ├── node_modules/     (sharp ARM64)
        └── python-evolve-site/ (pydantic_core/jiter ARM64)
```

## [S3] Out of Scope

- 代码签名 / 安装器
- 自动更新通道（会回退到 x64）
- 注册表 / 开始菜单快捷方式
- ARM64 生态持续维护

## Tasks

- [x] T1: Extract Electron ARM64 shell — acceptance: PE 0xAA64 (covers: S2)
- [x] T2: Transplant app payload — acceptance: file tree matches original (covers: S2)
- [x] T3: Replace native node_modules ARM64 — acceptance: .node/.dll ARM64 (covers: S2)
- [x] T4: onnxruntime-node ARM64 — acceptance: binding.node + dll ARM64 (covers: S2)
- [x] T5: Build runtimes tree win32-arm64 — acceptance: all PE ARM64 (covers: S2)
- [x] T6: qpdf ARM64 compile — acceptance: qpdf.exe ARM64 (covers: S2)
- [x] T7: Patch asar module resolution — acceptance: natives load (covers: S2)
- [x] T8: Architecture audit + launch + terminal — acceptance: 95.6% purity, UI opens (covers: S1, S2)
- [x] T9: Fix Python C extensions ARM64 — acceptance: pydantic/jiter import OK (covers: S2)
- [x] T10: Performance benchmark — acceptance: startup time comparison (covers: S1)

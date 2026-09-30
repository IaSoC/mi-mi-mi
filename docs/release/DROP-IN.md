# Drop-in 安装说明 — Mi Mi Mi ARM64 Runtime Skeleton

> 英文镜像：[DROP-IN.en.md](DROP-IN.en.md)  
> 操作总览：[docs/BUILD.md](../BUILD.md)

本发布物是 Xiaomi MiMo Desktop 的 **Windows on ARM 原生运行时骨架（runtime shell）**，在 post-market 约束下由官方 x64 安装环境构建。**不包含任何专有应用 payload**——请把你合法安装副本中的 payload 拷入后原生运行，无需 x64 模拟。

- 无 payload 骨架：约 875 MB（zip 约 327 MB）
- 适配过的 payload 版本示例：**26.923.232338**
- 主机要求：Windows on ARM（Windows 11 ARM64）

## zip 里没有的内容

| 排除项 | 原因 |
|--------|------|
| `resources\app.asar` | 专有 payload — 拷入你自己的 |
| `resources\evolve-seed` | 专有 payload — 拷入你自己的 |
| `resources\browser-extension` | 专有 payload — 拷入你自己的 |
| `resources\computer-use-windows` | 专有 payload — 拷入你自己的 |
| `resources\elevate.exe` | 随官方安装发布 — 拷入你自己的 |
| `resources\app-update.yml` | 更新源是死链；让更新保持关闭 |
| `resources\app.asar.unpacked` | **不要**用你的 x64 原版覆盖 — 骨架已带 ARM64 重建后的 natives（onnxruntime、canvas、node-pty、parcel-watcher） |

## 安装

1. **解压** 到长期目录，例如 `D:\MiMo-ARM64\`。
2. **拷贝 payload** 来自官方安装（`%LOCALAPPDATA%\Programs\Xiaomi MiMo\`）到解压目录：

   | 自官方安装 | 拷入骨架 |
   |------------|----------|
   | `resources\app.asar` | `resources\app.asar` |
   | `resources\evolve-seed\` | `resources\evolve-seed\` |
   | `resources\browser-extension\` | `resources\browser-extension\` |
   | `resources\computer-use-windows\` | `resources\computer-use-windows\` |
   | `resources\elevate.exe` | `resources\elevate.exe` |

3. **补丁 asar** — 双击 `Patch-Asar.bat`（普通 PowerShell，无需 Node）。它做一次等长字节编辑，使应用的平台白名单接受 `win32-arm64`。
   - 期望输出：`RESULT : OK, patched`
   - payload `26.923.232338` 补丁后期望 SHA256：  
     `5a9ba932a6b30aafccd4fc76ab6118e4a8564474ae3594bdc22729e3130ccf1d`
   - 若打印 `RESULT : FAIL`（exit 2）：payload 版本已变，补丁模式不再适用。**不要启动** — 记下你手头的官方版本号。
4. **启动** — 双击 `Launch ARM64.bat`。

随时可用 `Patch-Asar.bat` 再次校验（`OK, already patched`），或：

```powershell
node patch-asar.js <path-to-app.asar> --check
```

（仓库侧等价脚本：`scripts\patch-asar.js`。）

## 行为说明

- **无自动更新**：官方更新通道没有 `win-arm64` 条目，骨架也不带 `app-update.yml`。出现新官方版本时，重复步骤 2–3，并关注补丁漂移错误。
- **遥测**：你拷入的 payload 行为与官方应用完全一致（Elastic APM `apm-rum*.inf.miui.com`、OneTrack 等）。本项目不额外添加遥测。`MIMO_APM_DISABLE=1` 可禁用 APM reporter。

## 第三方声明

骨架再分发下列组件，均遵循各自许可证（全文随 zip 提供：`LICENSE.electron.txt`、`LICENSES.chromium.html` 及各包 `LICENSE`）：

| 组件 | 许可 | 说明 |
|------|------|------|
| Electron / Chromium | MIT + BSD-3-Clause | 见 `LICENSE.electron.txt`、`LICENSES.chromium.html` |
| FFmpeg（`ffmpeg.dll`） | **LGPL-2.1-or-later** | Chromium 的 FFmpeg 构建（未启用 GPL 部分）；DLL 为独立文件，可替换 |
| SwiftShader, Vulkan loader | Apache-2.0 | |
| `@img/sharp-win32-arm64`（libvips） | **Apache-2.0 AND LGPL-3.0-or-later** | native `.node` 可替换；libvips 源码：https://github.com/libvips/libvips |
| onnxruntime-node | MIT | |
| @napi-rs/canvas, @lydell/node-pty, @parcel/watcher | MIT | ARM64 构建 |
| Node.js runtime | MIT | `resources\runtimes\win32-arm64\node` |
| Python + site packages | PSF-2.0 / MIT / BSD | `resources\runtimes\win32-arm64\python*` |
| ripgrep | MIT | |
| qpdf | Apache-2.0 | |
| react, react-icons, mathjax-full, pptxgenjs, speech-rule-engine, jszip | MIT / Apache-2.0（jszip：从 MIT OR GPL-3.0 中选择 MIT） | |

本骨架 **不** 再分发任何 GPL-only 或 AGPL 组件。你拷入的 payload（`app.asar` 等）是小米专有材料，**由你**从自己的安装中提供；它不属于本发布物，其许可受小米条款约束。

## 本项目

MIT © 2026 IaSoC — 见 `portkit/LICENSE`。非小米官方项目。

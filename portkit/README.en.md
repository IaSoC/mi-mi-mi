# MiMo Desktop x64 → ARM64 port toolkit (author path)

> **This is the author path, not the consumer install guide.**  
> Consumers: [docs/BUILD.en.md](../docs/BUILD.en.md) → drop-in / [docs/release/DROP-IN.en.md](../docs/release/DROP-IN.en.md)  
> Chinese mirror: [README.md](README.md)

Extract architecture-independent resources from the official x64 binary and graft them onto an ARM64 Electron shell under post-market constraints.

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **Visual Studio 2022 Build Tools** | MSVC ARM64 cross-compile | `msvc-arm64.vsconfig` |
| **Git** | Version control | winget install Git.Git |
| **PowerShell 5.1+** | Script host | Built-in |
| **curl** | Downloads | Built-in |
| **Official x64 MiMo Desktop** | Extract architecture-independent payload | Legitimate install |

VS Build Tools component list (`msvc-arm64.vsconfig`):

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

Install (run from the **repo root**):

```powershell
winget install -e --id Microsoft.VisualStudio.BuildTools --override "--passive --config .\portkit\msvc-arm64.vsconfig --installPath C:\BuildTools"
```

## Quick start (author path)

**On-disk script names are authoritative:**

| Step | Script |
|------|--------|
| 0 | `portkit\scripts\00-setup.ps1` |
| 1 | `portkit\scripts\01-download.ps1` |
| 2 | `portkit\scripts\02-extract.ps1` |
| 3 | `portkit\scripts\03-verify.ps1` |

**There is no `02-build.ps1`.** If an old comment still says `02-build`, ignore it; the canonical name is `02-extract.ps1`.

### From the repository root (recommended)

```powershell
# 1. Check prerequisites
powershell -ExecutionPolicy Bypass -File portkit\scripts\00-setup.ps1

# 2. Download ARM64 components
powershell -ExecutionPolicy Bypass -File portkit\scripts\01-download.ps1

# 3. Extract + graft onto the ARM64 shell (not “compile Electron from scratch”)
powershell -ExecutionPolicy Bypass -File portkit\scripts\02-extract.ps1

# 4. Verify
powershell -ExecutionPolicy Bypass -File portkit\scripts\03-verify.ps1
```

### From the `portkit\` directory

```powershell
powershell -ExecutionPolicy Bypass -File scripts\00-setup.ps1
powershell -ExecutionPolicy Bypass -File scripts\01-download.ps1
powershell -ExecutionPolicy Bypass -File scripts\02-extract.ps1
powershell -ExecutionPolicy Bypass -File scripts\03-verify.ps1
```

## Extract from the official binary (critical step)

### Goal

Official x64 MiMo Desktop lives at `%LOCALAPPDATA%\Programs\Xiaomi MiMo\` (often `C:\Users\<you>\AppData\Local\Programs\Xiaomi MiMo\`). Extract architecture-independent resources and graft them onto the ARM64 Electron shell.

### Extract inventory

| Resource | Path | Action |
|----------|------|--------|
| **app.asar** | `resources/app.asar` | Copy + patch |
| **app.asar.unpacked** | `resources/app.asar.unpacked/` | Copy, then replace native binaries |
| **browser-extension** | `resources/browser-extension/` | Copy |
| **computer-use-windows** | `resources/computer-use-windows/` | Copy |
| **evolve-seed** | `resources/evolve-seed/` | Copy |
| **app-update.yml** | `resources/app-update.yml` | Copy (drop-in releases usually **omit** this) |
| **elevate.exe** | `resources/elevate.exe` | Copy (x86, acceptable) |
| **locales/** | `locales/*.pak` | Take from Electron ARM64 package |

### Do not extract (replace from Electron ARM64 package)

| Resource | Notes |
|----------|-------|
| `Xiaomi MiMo.exe` | Electron ARM64 main binary |
| `*.dll` (Chromium) | ffmpeg/libEGL/libGLESv2/vulkan/d3dcompiler, etc. |
| `*.pak`, `icudtl.dat` | Chromium resources |
| `snapshot_blob.bin`, `v8_context_snapshot.bin` | V8 snapshots |
| `locales/` | Take from Electron ARM64 package |

Implementation details: `portkit\scripts\02-extract.ps1`.

### Native module replacement map

| x64 original | ARM64 replacement | Source |
|--------------|-------------------|--------|
| `@lydell/node-pty-win32-x64` | `@lydell/node-pty-win32-arm64` | npm prebuild |
| `@napi-rs/canvas-win32-x64-msvc` | `@napi-rs/canvas-win32-arm64-msvc` | npm prebuild |
| `@parcel/watcher-win32-x64` | `@parcel/watcher-win32-arm64` | npm prebuild |
| `onnxruntime-node/bin/.../x64/` | `onnxruntime-node/bin/.../arm64/` | ships in npm |
| `@img/sharp-win32-x64` | `@img/sharp-win32-arm64` | npm prebuild |

**Note:** keep directory names as `*-x64` (they match the asar header) while the **contents** are ARM64. In JS, `process.arch` concatenation is forced to `x64`.

### asar patches

| Patch | File | Content |
|-------|------|---------|
| Platform whitelist | `app.asar` (binary) | Equal-length edit admitting `win32-arm64` (see `scripts\patch-asar.js` / `scripts\release\Patch-Asar.bat`) |
| canvas binding path | `js-binding.js` (unpacked) | Absolute path bypassing asar fs |
| node-pty package name | `index.js` (unpacked) | `process.arch` → `x64` |
| parcel-watcher package name | `index.js` (unpacked) | `process.arch` → `x64` |
| onnxruntime path | `binding.js` (unpacked) | Path forced to `win32/x64` |

### Runtimes replacement map

| Component | Source | Version (example) |
|-----------|--------|-------------------|
| Node.js | `node-v24.15.0-win-arm64.zip` | 24.15.0 |
| Python | `python-3.12.10-embed-arm64.zip` + pip wheels | 3.12.10 |
| ripgrep | `ripgrep-15.2.0-aarch64-pc-windows-msvc.zip` | 15.2.0 |
| qpdf | Source build (zlib + libjpeg-turbo) | 12.4.1 |
| github-mcp-server | `github-mcp-server_Windows_arm64.zip` | 1.12.2 |
| sharp | npm `@img/sharp-win32-arm64` | see npm |

Versions should match the download cache / actual build; this table is historical alignment reference.

## Verification checklist

```powershell
# Architecture purity audit (PE machine type)
Get-ChildItem "output\Xiaomi MiMo ARM64" -Recurse -Include "*.exe","*.dll","*.node" |
  ForEach-Object {
    $b = [IO.File]::ReadAllBytes($_.FullName)
    $pe = [BitConverter]::ToInt32($b, 0x3C)
    $m = [BitConverter]::ToUInt16($b, $pe+4)
    "$(@{0x8664='x64';0xAA64='ARM64';0x014C='x86'}[$m])  $($_.Name)"
  }

# Launch test
& "output\Xiaomi MiMo ARM64\Launch ARM64.bat"

# Feature tests
# - Terminal (node-pty): open the built-in terminal
# - Project/session list: confirm rows render
# - Conversation: send a message to confirm API connectivity

# Full drop-in acceptance
powershell -ExecutionPolicy Bypass -File scripts\test-dropin.ps1
```

**Process-safety rule:** processes under `output\Xiaomi MiMo ARM64\` may be a live MiMo Desktop (user + AI agent). Kill only by recorded PID — never by path wildcard.

Status/evidence pointers: [docs/STATUS.en.md](../docs/STATUS.en.md).

## Known limitations

| Item | Status | Notes |
|------|--------|-------|
| `elevate.exe` | x86 | Small; acceptable under Prism |
| `vcruntime140_1.dll` | x64 | Python embeddable leftover |
| Auto-update | Falls back to x64 | Update CDN ships x64 packages |
| Code signing | None | Unsigned directory output |

## Performance reference

Historical numbers once appeared in the old portkit README; **do not treat them as the sole current evidence**.  
Use [docs/STATUS.en.md](../docs/STATUS.en.md) (pointers into `scripts/bench-output/`) and [docs/compose/spec/electron-arm64-port.md](../docs/compose/spec/electron-arm64-port.md).

## Related documents

- [docs/BUILD.en.md](../docs/BUILD.en.md) — operational canonical  
- [docs/release/DROP-IN.en.md](../docs/release/DROP-IN.en.md) — consumer drop-in  
- [docs/STATUS.en.md](../docs/STATUS.en.md) — status and evidence  
- [scripts/patch-asar.js](../scripts/patch-asar.js) · [scripts/test-dropin.ps1](../scripts/test-dropin.ps1)  
- [scripts/release/](../scripts/release/) — bat files inside the skeleton  

*MIT © 2026 IaSoC — see [LICENSE](LICENSE).*

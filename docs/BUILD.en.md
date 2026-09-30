# Build / Install — Mi Mi Mi

> **This is the operational canonical.** Consumers use drop-in; maintainers use the portkit author path.  
> Chinese mirror: [BUILD.md](BUILD.md)

## Roles and paths

| Path | Audience | Entry |
|------|----------|-------|
| **Drop-in (canonical)** | People who want MiMo Desktop running natively on Windows on ARM | This §1 · [release/DROP-IN.en.md](release/DROP-IN.en.md) |
| **Portkit author path** | Maintainers rebuilding/updating the ARM64 skeleton | [portkit/README.en.md](../portkit/README.en.md) |

The two paths have different responsibilities. Drop-in does **not** rebuild Electron/natives. Portkit is **not** a consumer install guide.

```
Consumer: payload from official x64 install ──copy──► ARM64 skeleton ──Patch-Asar──► launch
Author:   Electron ARM64 shell + native rebuild ──build──► output/Xiaomi MiMo ARM64 ──package──► drop-in zip
```

## §1 Consumer: Drop-in (canonical)

### Prerequisites

| Item | Requirement |
|------|-------------|
| OS | Windows 11 ARM64 (Windows on ARM) |
| Official install | Legitimately installed x64 Xiaomi MiMo Desktop; default path `%LOCALAPPDATA%\Programs\Xiaomi MiMo\` |
| Skeleton package | Payload-free ARM64 runtime skeleton zip (published by authors; this repo does not ship proprietary payload) |

Skeleton size reference: ~875 MB (zip ~327 MB). Example adapted payload version: `26.923.232338` (confirm against DROP-IN and patch script output).

### Steps

Full detail and checksums: **[release/DROP-IN.en.md](release/DROP-IN.en.md)**. Summary:

1. **Unzip the skeleton** somewhere permanent, e.g. `D:\MiMo-ARM64\`.
2. **Copy the payload** from the official install (**do not** overwrite `resources\app.asar.unpacked`):

   | From official install | Into skeleton |
   |-----------------------|---------------|
   | `resources\app.asar` | `resources\app.asar` |
   | `resources\evolve-seed\` | `resources\evolve-seed\` |
   | `resources\browser-extension\` | `resources\browser-extension\` |
   | `resources\computer-use-windows\` | `resources\computer-use-windows\` |
   | `resources\elevate.exe` | `resources\elevate.exe` |

3. **Patch the asar** — double-click `Patch-Asar.bat` (plain PowerShell; Node not required).
   - Expected: `RESULT : OK, patched` or later `OK, already patched`
   - If `RESULT : FAIL` (exit 2): the official payload version changed and the patch pattern drifted. **Do not launch**; record the official version.
4. **Launch** — double-click `Launch ARM64.bat`.

### Behavior notes

- **No auto-updates**: the official update channel has no `win-arm64` entry; the skeleton ships without `app-update.yml`. When a new official payload appears, repeat steps 2–3 and watch for patch-drift errors.
- **Telemetry**: the payload you copy in behaves exactly as the official app; this project adds none of its own. `MIMO_APM_DISABLE=1` disables the APM reporter.

### Safety and licensing

What may be redistributed is the **payload-free** ARM64 runtime shell (Electron/Chromium/natives, etc.; see third-party notices in DROP-IN). `app.asar` and related payload are supplied by **you** from your legitimate install; their licensing is governed by Xiaomi terms. This project does not provide code signing.

## §2 Maintainer: Portkit author path

### Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Visual Studio 2022 Build Tools | MSVC ARM64 cross-compile | `portkit\msvc-arm64.vsconfig` |
| Git | Version control | winget install Git.Git |
| PowerShell 5.1+ | Script host | Built-in |
| curl | Downloads | Built-in |
| Official x64 MiMo Desktop | Extract architecture-independent payload | Legitimate install |

Install Build Tools:

```powershell
winget install -e --id Microsoft.VisualStudio.BuildTools --override "--passive --config .\portkit\msvc-arm64.vsconfig --installPath C:\BuildTools"
```

### Script sequence (match on-disk names)

| Step | Script | Purpose |
|------|--------|---------|
| 0 | `portkit\scripts\00-setup.ps1` | Check MSVC ARM64 / CMake / Git / curl |
| 1 | `portkit\scripts\01-download.ps1` | Download Electron ARM64 + runtimes into `cache/downloads/` |
| 2 | `portkit\scripts\02-extract.ps1` | **Extract** architecture-independent resources from the official x64 install onto the ARM64 shell |
| 3 | `portkit\scripts\03-verify.ps1` | Architecture audit + launch check |

**There is no** `02-build.ps1`. Script comments and docs use on-disk `02-extract.ps1`.

### From the repository root (recommended)

```powershell
# From the repo root
powershell -ExecutionPolicy Bypass -File portkit\scripts\00-setup.ps1
powershell -ExecutionPolicy Bypass -File portkit\scripts\01-download.ps1
powershell -ExecutionPolicy Bypass -File portkit\scripts\02-extract.ps1
powershell -ExecutionPolicy Bypass -File portkit\scripts\03-verify.ps1
```

If you have `cd portkit\`, use:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\00-setup.ps1
powershell -ExecutionPolicy Bypass -File scripts\01-download.ps1
powershell -ExecutionPolicy Bypass -File scripts\02-extract.ps1
powershell -ExecutionPolicy Bypass -File scripts\03-verify.ps1
```

Extract inventory, native replacement maps, and asar patch notes: [portkit/README.en.md](../portkit/README.en.md).

### Related repo scripts

| Script | Purpose |
|--------|---------|
| `scripts\patch-asar.js` | Equal-length platform-whitelist patch on official `app.asar`; `--check` is read-only |
| `scripts\patch-asar.ps1` | PowerShell entry for the patch |
| `scripts\release\Patch-Asar.bat` | One-click patch inside a drop-in skeleton |
| `scripts\release\Launch ARM64.bat` | One-click launch inside a drop-in skeleton |
| `scripts\test-dropin.ps1` | Drop-in acceptance (copy payload → patch → CDP milestones → optional functional) |

**Process safety**: `output\Xiaomi MiMo ARM64\` may be a live MiMo Desktop (including the AI agent itself). Kill processes only by recorded PID — never by path wildcard.

## §3 Verification and evidence

Architecture and feature numbers are **not** asserted here — see [STATUS.en.md](STATUS.en.md).

Delivered port design and conclusions: [compose/spec/electron-arm64-port.md](compose/spec/electron-arm64-port.md).

## Related documents

- [release/DROP-IN.en.md](release/DROP-IN.en.md) — consumer install detail and third-party notices  
- [STATUS.en.md](STATUS.en.md) — four-state evidence and research checklist  
- [portkit/README.en.md](../portkit/README.en.md) — author-path detail  
- [README.en.md](../README.en.md) — project index  
- [AGENTS.md](../AGENTS.md) — agent conventions  

*MIT © 2026 IaSoC — See `portkit/LICENSE` for build tooling licensing.*

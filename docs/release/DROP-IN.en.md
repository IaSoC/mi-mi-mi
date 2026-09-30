# Drop-in guide — Mi Mi Mi ARM64 Runtime Skeleton

> Chinese mirror: [DROP-IN.md](DROP-IN.md)  
> Operational overview: [docs/BUILD.en.md](../BUILD.en.md)

This release is the **native Windows-on-ARM runtime shell** for Xiaomi MiMo Desktop, built post-market from the official x64 installer. It contains **no proprietary application payload** — you drop in the payload from your own legitimately installed copy and it runs natively, without x64 emulation.

- Payload-free skeleton: ~875 MB (327 MB zipped)
- Adapted payload version: **26.923.232338**
- Host requirement: Windows on ARM (Windows 11 ARM64)

## What is NOT in the zip

| Excluded | Why |
|----------|-----|
| `resources\app.asar` | proprietary payload — copy yours in |
| `resources\evolve-seed` | proprietary payload — copy yours in |
| `resources\browser-extension` | proprietary payload — copy yours in |
| `resources\computer-use-windows` | proprietary payload — copy yours in |
| `resources\elevate.exe` | ships with the official install — copy yours in |
| `resources\app-update.yml` | update feed is a dead link; keep updates out |
| `resources\app.asar.unpacked` | **do NOT copy yours over this** — the skeleton already ships the ARM64-rebuilt natives (onnxruntime, canvas, node-pty, parcel-watcher) |

## Install

1. **Unzip** somewhere permanent, e.g. `D:\MiMo-ARM64\`.
2. **Copy the payload** from your official install
   (`%LOCALAPPDATA%\Programs\Xiaomi MiMo\`) into the unzipped folder:

   | From official install | Into skeleton |
   |-----------------------|---------------|
   | `resources\app.asar` | `resources\app.asar` |
   | `resources\evolve-seed\` | `resources\evolve-seed\` |
   | `resources\browser-extension\` | `resources\browser-extension\` |
   | `resources\computer-use-windows\` | `resources\computer-use-windows\` |
   | `resources\elevate.exe` | `resources\elevate.exe` |

3. **Patch the asar** — double-click `Patch-Asar.bat` (plain PowerShell, no
   Node needed). It makes one equal-length edit that lets the app's platform
   whitelist accept `win32-arm64`.
   - Expected output: `RESULT : OK, patched`
   - Expected SHA256 after patch (payload `26.923.232338`):
     `5a9ba932a6b30aafccd4fc76ab6118e4a8564474ae3594bdc22729e3130ccf1d`
   - If it prints `RESULT : FAIL` (exit 2): the payload version has changed
     and the patch pattern no longer applies. **Do not launch** — record the
     official version you have.
4. **Launch** — double-click `Launch ARM64.bat`.

You can verify a patched asar at any time with `Patch-Asar.bat` again
(`OK, already patched`) or:

```powershell
node patch-asar.js <path-to-app.asar> --check
```

(Repo equivalent: `scripts\patch-asar.js`.)

## Behavior notes

- **No auto-updates**: the official update channel has no `win-arm64`
  platform entry, and the skeleton ships without `app-update.yml`. When a new
  official version appears, repeat steps 2–3 with the new payload and watch
  for patch-drift errors.
- **Telemetry**: the payload you copy in behaves exactly as the official app
  (Elastic APM to `apm-rum*.inf.miui.com`, OneTrack analytics). This project
  adds none of its own. `MIMO_APM_DISABLE=1` disables the APM reporter.

## Third-party notices

The skeleton redistributes the following, all under their own licenses
(full texts ship in the zip: `LICENSE.electron.txt`,
`LICENSES.chromium.html`, package `LICENSE` files):

| Component | License | Notes |
|-----------|---------|-------|
| Electron / Chromium | MIT + BSD-3-Clause | see `LICENSE.electron.txt`, `LICENSES.chromium.html` |
| FFmpeg (`ffmpeg.dll`) | **LGPL-2.1-or-later** | Chromium's FFmpeg build (GPL parts not enabled); the DLL is a separate file and may be replaced |
| SwiftShader, Vulkan loader | Apache-2.0 | |
| `@img/sharp-win32-arm64` (libvips) | **Apache-2.0 AND LGPL-3.0-or-later** | native `.node` is replaceable; libvips source: https://github.com/libvips/libvips |
| onnxruntime-node | MIT | |
| @napi-rs/canvas, @lydell/node-pty, @parcel/watcher | MIT | ARM64 builds |
| Node.js runtime | MIT | `resources\runtimes\win32-arm64\node` |
| Python + site packages | PSF-2.0 / MIT / BSD | `resources\runtimes\win32-arm64\python*` |
| ripgrep | MIT | |
| qpdf | Apache-2.0 | |
| react, react-icons, mathjax-full, pptxgenjs, speech-rule-engine, jszip | MIT / Apache-2.0 (jszip: MIT chosen from MIT OR GPL-3.0) | |

No GPL-only or AGPL component is redistributed in this skeleton. The copied
payload (`app.asar` and friends) is Xiaomi proprietary material that **you**
supply from your own installation; it is not part of this release and its
licensing is governed by Xiaomi's terms.

## This project

MIT © 2026 IaSoC — see `portkit/LICENSE`. Not an official Xiaomi project.

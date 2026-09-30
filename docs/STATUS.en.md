# Status & Evidence — Mi Mi Mi

> Research status document — **not** a release gate checklist.  
> Chinese mirror: [STATUS.md](STATUS.md)  
> Build/install: [BUILD.en.md](BUILD.en.md) · Index: [README.en.md](../README.en.md)

## One-line status

> **“It works”** — launches, chats, writes files.  
> **“How much of it is actually ARM64?”** — still requires four-state evidence, component by component.

## Four-state taxonomy

| Status | Meaning | Evidence bar |
|--------|---------|--------------|
| **ARM64** | Confirmed ARM64 | PE machine type `0xAA64`, or equivalent reliable evidence; note whether the app *loads* the component |
| **x64** | Confirmed x64 | PE machine type `0x8664`, or equivalent |
| **Independent** | No CPU-specific binary dependency | Pure JS/CSS/HTML/assets, or equivalent argument |
| **Unknown** | Insufficient evidence | Missing audit, missing load-path proof, or presence-only |

**Hard rule:** A file in the install directory does **not** prove the app loads it. Successful startup does **not** mean fully ARM64.

## Architecture purity (delivered conclusion)

Source: [compose/spec/electron-arm64-port.md](compose/spec/electron-arm64-port.md) (`status: delivered`).

| Item | Conclusion |
|------|------------|
| Purity audit | **43/45 PE = ARM64 (95.6%)** per the delivered spec report |
| Known x64/x86 residue | See limitations table; `elevate.exe` is x86 (small, acceptable under Prism); Python embeddable leftover `vcruntime140_1.dll` is x64 |
| Feature regression (as recorded) | node-pty / parcel-watcher / Python+pydantic / qpdf / ripgrep / github-mcp-server, etc. PASS (spec report) |
| Launch smoke | Window title; API/plugin/SSO/engine stack load (spec report) |

> Older README notes (e.g. “49/55 PE”) are historical. Prefer the **delivered spec + bench evidence directories** — do not mix stale counts with newer evidence.

## Known limitations (status level)

| Item | Status | Notes |
|------|--------|-------|
| `elevate.exe` | x86 | Small; acceptable under Prism |
| `vcruntime140_1.dll` | x64 | Python embeddable leftover |
| Auto-update | No ARM64 channel | Official CDN has no `win-arm64`; drop-in intentionally omits `app-update.yml` |
| Code signing | None | Unsigned directory / skeleton |
| Ongoing ARM64 ecosystem maintenance | Out of experimental scope | See spec Out of Scope |

## Performance baselines (evidence pointers — not re-run here)

The delivered spec records a CDP/bench-run ARM64 vs x64 comparison (total run, engineFetch, loadEngineSessions, etc.). Historical directories:

| Evidence | Path |
|----------|------|
| 10-run startup archive | [scripts/bench-output/startup-10run-20260926.md](../scripts/bench-output/startup-10run-20260926.md) |
| functional summaries (ARM64/x64) | `scripts/bench-output/functional-ARM64-20260926-225827/` · `.../functional-x64-20260926-225842/` |
| deep probe | `scripts/bench-output/deep-ARM64-20260926-232826/` · `.../deep-x64-20260926-232856/` |
| cpuprofile | `scripts/bench-output/cpuprof-ARM64-20260927-001929/` · `.../cpuprof-x64-20260927-001940/` |

Measurement conventions (see [AGENTS.md](../AGENTS.md)):

- Platform comparison uses **T1 `list-ready`** absolute time from process start — not `mainToList` as the primary metric.
- Milestones come from **CDP** (`scripts/cdp-probe.mjs`), not stderr regex as primary metrics.
- Numbers must be traceable to `scripts/bench-output/<kind>-<Side>-<timestamp>/`.

**Unchecked research items are not current re-verifications. Re-running benchmarks requires user confirmation; never run both sides concurrently.**

## Research checklist

Ported from the original README Verification Plan. **Status = narrative state at docs-restructure time.** “Recorded” means there was an operational record then — it does **not** automatically re-pass today.

### 1. Core application

| Item | Narrative status |
|------|------------------|
| New conversation | Recorded |
| New project | Recorded |
| Multi-turn conversation | Recorded |
| Long-running Agent task | Recorded |
| File create / read / modify / delete | Recorded |
| Directory operations | Recorded |
| Application restart | **Not done** |
| State persistence | Recorded |

### 2. Electron features

| Item | Narrative status |
|------|------------------|
| GPU acceleration | Recorded |
| Clipboard | Recorded |
| Drag & drop | Recorded |
| Notifications | Recorded |
| File dialogs | Recorded |
| External browser invocation | **Not done** |
| Multiple windows | **Not done** |
| Main/renderer IPC | Recorded |

### 3. Process architecture (audit)

Inspect the full process tree under the output directory: process name, architecture, executable path, parent, purpose. Look for ARM64/x64/x86, helpers, updaters, crash reporters, GPU, utility processes.

### 4. Native components (audit)

Classify `*.dll` `*.exe` `*.node` `*.asar` in the install tree by the four states. Presence ≠ use.

## Evidence index

| Document | Role |
|----------|------|
| [compose/spec/electron-arm64-port.md](compose/spec/electron-arm64-port.md) | Port design, task completion, performance, journey log |
| [BUILD.en.md](BUILD.en.md) | Operational canonical (how to build/install) |
| [portkit/README.en.md](../portkit/README.en.md) | Author-path detail and limitations |
| [release/DROP-IN.en.md](release/DROP-IN.en.md) | Drop-in install and third-party notices |
| [compose/spec/](compose/spec/) | Deck-related specs |

## Update convention

- Keep this file in lockstep with [STATUS.md](STATUS.md) (`*.md` Chinese, `*.en.md` English).
- Change status tables only when new evidence exists; never claim fully ARM64 from “it works”.
- Any performance number change must point at a new `scripts/bench-output/` directory.

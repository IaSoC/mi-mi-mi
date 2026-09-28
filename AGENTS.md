# AGENTS.md

Guidance for AI agents working in this repository. Read this before editing anything.

## What this repo is

**Mi Mi Mi** — an experimental, post-market port of the closed-source Electron app
**Xiaomi MiMo Desktop** from x64 to native ARM64 on Windows on ARM. There is no upstream
source code: the starting point is the installed x64 application. See `README.md` for the
research framing and `portkit/README.md` for the build/extraction workflow.

The host machine is a Xiaomi Book S 12.4 (Snapdragon 8cx Gen 2, Windows on ARM). Work is
Windows-only; there is no CI, no test framework, and no package.json at the repo root.

## Repository layout

| Path | What it is | Tracked? |
|------|-----------|----------|
| `README.md` | Project narrative and verification plan | yes |
| `AGENTS.md` | This file | yes |
| `.gitignore` | Defines what must never be committed | yes |
| `portkit/` | Reproducible build tooling (`00-setup` → `03-verify`) | yes |
| `scripts/` | Benchmarks, CDP probes, analysis utilities | yes |
| `docs/compose/` | Presentation deck source and specs | yes |
| `output/` | Built ARM64 application (proprietary payload) | **never** |
| `cache/` | Downloads, extracted sources, test user profiles | **never** |
| `scripts/bench-output/` | Benchmark artifacts (logs, traces, screenshots) | mostly no |

When `git status` shows a flood of untracked files, check this table first. Most of them are
build artifacts under `output/`/`cache/` (already ignored) or run artifacts under
`scripts/bench-output/`. Source files live in `scripts/*.ps1|*.mjs|*.py|*.js`,
`portkit/`, and `docs/`.

## Hard rules

1. **Never commit proprietary Xiaomi material.** `output/`, `cache/`, credentials,
   cookies, local storage, session storage, and signing material are excluded by
   `.gitignore`. Do not weaken those rules, and do not `git add -f` around them.
2. **Never `git commit` or `git push` without explicit user request.** Show the diff and
   ask first.
3. **Keep user data intact.** Benchmarks operate on `%APPDATA%\Xiaomi MiMo`. Do not delete
   that directory; scripts clear only the V8 `Code Cache` subfolder, which is intentional.
4. **Do not claim "works" means "fully ARM64".** The project distinguishes four states —
   `ARM64`, `x64`, `Independent`, `Unknown`. Evidence required for each; a file being
   present does not prove the app loads it.

## PowerShell constraints (PS 5.1)

The scripts run under Windows PowerShell 5.1, which is older than PowerShell 7. Known
traps that have already bitten this repo:

- **No ternary expressions.** `return if/else` is invalid; use `if`/`else` statements.
- **`.ps1` files must be ASCII-only, no BOM.** PS 5.1 mis-decodes UTF-8 Chinese inside
  string literals and then breaks quote parsing. Chinese text belongs in `.mjs`/`.py`/
  `.md` files, not in `.ps1` string literals. There is a comment stating this at the top
  of `scripts/bench-startup.ps1` — keep it true.
- Use `$null -ne $x` rather than `$x -ne $null` (matches repo style and avoids
  PS-specific array pitfalls).
- Invoke as `powershell -ExecutionPolicy Bypass -File scripts\<name>.ps1`.

## Benchmarks and measurement

Two sides are compared:

- **ARM64**: `output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe` (this repo's build)
- **x64**: `%LOCALAPPDATA%\Programs\Xiaomi MiMo\Xiaomi MiMo.exe` (official install, runs
  under Prism)

### How startup is measured (current design)

Milestones are detected through the **Chrome DevTools Protocol**, not by matching stderr
text. The benchmark launches the app with `--remote-debugging-port=9333` and runs
`scripts/cdp-probe.mjs` against it.

| Point | Meaning |
|-------|---------|
| `window-title` | `Process.MainWindowTitle` — diagnostic only |
| `startup-loader` | logo splash element visible |
| `main-ui` (T0) | main slogan text visible |
| `list-ready` (T1) | project rows stable + recent section |
| `mainToList` | T1 − T0 — secondary window metric |
| `engine-sessions` | stderr `loadEngineSessions total=N` — diagnostic only |

**Platform comparison uses T1 (`list-ready`) absolute time from process start.** Do not
compare on `mainToList`: T0 can shift independently, while T1 is what a user actually
times from launch to seeing their project list. Do not reintroduce stderr-regex
milestones (`landing-page`, `shimmer-painted`, `projects-loaded`) as primary metrics —
they were replaced because they were unreliable.

Node for the probe is resolved by `Resolve-NodeExe` in order: `$env:MIMO_NODE` → the
ARM64 Node bundled inside the output app → system Node. If you add a script that needs
Node, reuse that resolution order instead of hardcoding a path.

### Running benchmarks

```powershell
# Multi-run ARM64 vs x64 comparison (close all MiMo instances first)
powershell -ExecutionPolicy Bypass -File scripts\bench-startup.ps1 -Runs 3

# Single run with manual close; collects stderr, stats, CDP milestones
powershell -ExecutionPolicy Bypass -File scripts\bench-run.ps1 -Side ARM64
```

Other scripts follow the same pattern: `bench-trace.ps1`, `bench-cpuprofile.ps1`,
`bench-deep.ps1`, `bench-functional.ps1`. Results are written to
`scripts/bench-output\<kind>-<Side>-<timestamp>\`. Python analyzers
(`analyze-*.py`, `aggregate-cpuprofiles.py`, `compare-cpuprofiles.py`) consume those
directories.

Benchmark runs are expensive and interactive (they launch real apps and may wait for
manual close). Confirm with the user before starting one, and never run both sides
concurrently.

`bench-startup.ps1` writes its full run to `scripts\bench-output\startup-<stamp>\`
(`summary.txt` + `results.csv` + `console.log`). Numbers that cannot be traced to a
directory there are not auditable — see `scripts/bench-output/startup-10run-20260926.md`
for the historical case that predates this behavior.

## Deck / documentation

`docs/compose/deck/` is a self-contained HTML deck (`index.html` + `styles.css` +
`deck.js` + `assets/`). Specs live in `docs/compose/spec/`. Helper Python scripts for
renumbering/reordering/restyle live in `scripts/` and `docs/compose/deck/`. Screenshots of
deck pages dumped into `scripts/bench-output/*.png` are artifacts, not sources.

## Git conventions

- Commit messages use a lowercase scope prefix, matching history:
  `scripts:`, `portkit:`, `fix:`, `readme:`, `repo:`, `license:`.
  Example: `scripts: rewrite bench-startup.ps1 with four precise milestones`.
- Stage deliberately. Prefer explicit paths over `git add -A`; the tree contains
  artifacts that must not land in a commit.
- Before committing, run `git status` and `git diff --stat`, and confirm every staged
  path is source (see layout table). If `scripts/bench-output/` or `__pycache__/` files
  appear, that is a `.gitignore` gap — fix the ignore file rather than staging around it.

## Definition of done

A change is complete when:

1. The modified script actually runs end-to-end on this machine (syntax-checked at
   minimum: `powershell -NoProfile -Command "Get-Content <file> -Raw | Invoke-Expression"`
   is *not* sufficient for scripts with `param()` — prefer running with a cheap flag or a
   dry path).
2. No proprietary bytes, credentials, or user-profile data are staged.
3. Output/artifacts from your verification run are not committed.
4. If the change affects reported metrics, state which numbers changed and why the new
   measurement is trustworthy.

## When uncertain

Ask the user rather than guessing about: deleting anything under `output/`, `cache/`, or
`%APPDATA%`; committing artifacts; changing `.gitignore` ignore rules for proprietary
paths; running long benchmarks; or modifying the extraction/porting logic in `portkit/`.

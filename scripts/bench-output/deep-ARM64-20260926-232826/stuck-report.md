# Stuck-call report - ARM64

- stamp: 20260926-232826
- exe: C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe

## Engine substeps (from app log)

| field | ms |
|------|---:|
| fetch | 3013 |
| repoRoots | 17 |
| build+reconcile | 8 |
| total | 3039 |

## Slowest network calls (CDP Network)

| rank | durationMs | status | url |
|-----:|----------:|-------:|-----|
## Verdict hints

- If engFetch is large and repoRoots/build are small -> ONE HTTP call is stuck (engine IPC).
- If one net row dominates (durationMs >> others) -> that URL is the stuck call.
- Longtasks > 500ms mean JS main-thread block (bundle eval / sync require).
- Engine log:- `[10332] [15524:0926/232836.702:INFO:CONSOLE:276] "[sess-diag] engineFetch GET /experimental/session?roots=true&limit=2000 -> HTTP 200 elapsed=2974ms responseBytes=187237 engineUrl= http://127.0.0.1:50790 engineId= (default)", source: app://-/renderer/assets/index-C2vAeNdg.js (276)`
- `[10567] [15524:0926/232836.702:INFO:CONSOLE:276] "[sess-diag] loadEngineSessions: 原始条数 = 23", source: app://-/renderer/assets/index-C2vAeNdg.js (276)`
- `[10578] [15524:0926/232836.722:INFO:CONSOLE:276] "[sess-diag] loadEngineSessions: reconcile 后 convos = 23 order = 23", source: app://-/renderer/assets/index-C2vAeNdg.js (276)`
- `[10588] [15524:0926/232836.742:INFO:CONSOLE:276] "[sess-diag] loadEngineSessions: 耗时(ms) fetch = 3013 repoRoots = 17 build+reconcile = 8 set = 1 total = 3039", source: app://-/renderer/assets/index-C2vAeNdg.js (276)`


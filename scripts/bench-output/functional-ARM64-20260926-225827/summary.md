# Functional startup - ARM64

- stamp: 20260926-225827
- exe: C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe

## Stage timeline (host ms from process start)

| Stage | Meaning | Host ms |
|------|---------|--------:|
| F1 window | window title | 6485 |
| F2 loader | startup logo | 9790 |
| F3 sidebar | sidebar chrome | 10612 |
| F4 main-ui | main UI slogan | 10693 |
| F5 interactive | interactive control | 10686 |
| F6 list-ready | project list stable | 13324 |
| F7 engine-sessions | session data | 13069 |

## Page Performance API (page clock)

| Mark | ms |
|------|---:|
| first-paint | 4680 |
| first-contentful-paint | 4680 |
| responseEnd | 2395 |
| DOMContentLoaded | 6432 |
| load | 6440 |

## Engine

- loadEngineSessions fetch = 3068 ms
- host timestamp = 13069 ms

## Derived

- Win->Loader = 3305 ms
- Loader->MainUI = 903 ms
- MainUI->List = 2631 ms
- List->Interactive = -2638 ms

Raw events: `events.ndjson`

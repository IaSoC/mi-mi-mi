# Functional startup - x64

- stamp: 20260926-225842
- exe: C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\Xiaomi MiMo.exe

## Stage timeline (host ms from process start)

| Stage | Meaning | Host ms |
|------|---------|--------:|
| F1 window | window title | 7943 |
| F2 loader | startup logo | 19163 |
| F3 sidebar | sidebar chrome | 25983 |
| F4 main-ui | main UI slogan | 26025 |
| F5 interactive | interactive control | 26001 |
| F6 list-ready | project list stable | 31162 |
| F7 engine-sessions | session data | 30692 |

## Page Performance API (page clock)

| Mark | ms |
|------|---:|
| first-paint | 15736 |
| first-contentful-paint | 15736 |
| responseEnd | 4720 |
| DOMContentLoaded | 15693 |
| load | 15723 |

## Engine

- loadEngineSessions fetch = 10951 ms
- host timestamp = 30692 ms

## Derived

- Win->Loader = 11220 ms
- Loader->MainUI = 6862 ms
- MainUI->List = 5137 ms
- List->Interactive = -5161 ms

Raw events: `events.ndjson`

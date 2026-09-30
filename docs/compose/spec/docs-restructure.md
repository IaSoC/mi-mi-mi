---
feature: docs-restructure
status: delivered
updated: 2026-09-30
branch: docs/restructure-mi-mi-mi
commits: effdedc..be2544f
---

# Mi Mi Mi 文档重组（README / BUILD / STATUS）

## Report

**What was built** — 将混杂的根 README 拆成可维护的成对双语文档体系：`README*.md` 仅保留定位、四态速查与索引；新增 `docs/BUILD*.md` 作为操作正典（使用者 drop-in 主线 + portkit 作者路径）；新增 `docs/STATUS*.md` 承载四态证据、已知限制与研究核对清单；致小米信迁至 `docs/letter-xiaomi*.md`。`portkit/README*` 标注为作者路径并纠正脚本名（`02-extract.ps1`，不存在 `02-build.ps1`）；`docs/release/DROP-IN*.md` 双语化并交叉链接。`AGENTS.md` layout 表同步读者入口；`.gitignore` 忽略 `/.worktrees/`。`portkit/scripts/01-download.ps1` 注释从 `02-build.ps1` 改为 `02-extract.ps1`。

**Verification** — 实现后（首次 review 发现编码问题后已修复）：
- 文件存在性：全部成对文档、portkit 四脚本、`scripts/patch-asar.js`、`scripts/test-dropin.ps1`、`scripts/release/*.bat` — PASS
- Markdown 相对链接审计（UTF-8 显式读取）：0 broken — PASS
- 中文文件 UTF-8 可读、无 mojibake（BUILD/STATUS/letter/README/portkit/DROP-IN）— PASS（复核）
- `02-build.ps1`：仅出现在「不存在该脚本」的否定说明；`01-download.ps1:2` 为 `02-extract.ps1` — PASS（复核）
- AGENTS 链：`00-setup → 01-download → 02-extract → 03-verify` — PASS（复核）
- 未跑 benchmark（超出范围且需用户确认）；无自动化测试框架（docs-only）— N/A
- 未 commit/push（遵守 AGENTS 硬规则）

**Journey log** —
1. **信息架构**：用户选定 README 索引 + BUILD/STATUS 拆分，而非只改 README 或全面重组。
2. **正典路径**：drop-in 为消费者正典，portkit 为作者路径；双语采用成对双文件（`*.md` 中文 / `*.en.md` 英文），不是单文件双语。
3. **PS 5.1 编码陷阱（再次踩中）**：`Get-Content -Raw` + `Set-Content -Encoding UTF8` 会按系统 ANSI 页损坏中文；链接修补导致 BUILD/STATUS mojibake。修复：用 Write 工具整文件重写，避免 PS 默认读码页。今后改 `.md` 中文优先 Write/Edit，不用无 `-Encoding UTF8` 的 PS 读写。
4. **Review 纪律**：首次 review 发现编码与 `01-download` 注释问题；修复后聚焦复核 5 项 critical 全 PASS。实现者自称「02-build 仅出现在否定说明」不准确——`01-download.ps1` 曾有正向旧名，必须扫脚本注释而不仅是 `*.md`。
5. **未自动提交**：worktree 含完整文档变更但保持 uncommitted，等用户明确要求后再 commit/merge。

## [S1] Problem

根 `README.md` 把研究叙事、半成品 Verification Plan、四态判别表、致小米信和免责声明挤在同一页，却没有可执行的构建入口。`portkit/README.md` 写着不存在的 `02-build.ps1`，且未说明必须从 `portkit\` 目录运行；现代安装路径在 `docs/release/DROP-IN.md`，读者无从判断「现在该怎么构建/安装」。语言也不统一：根 README / DROP-IN 为英文，portkit 与 AGENTS 为中文。

## [S2] Design

### 信息架构（已确认）

| 文件 | 职责 | 语言文件 |
|------|------|----------|
| `README.md` | 项目定位、四态速查、文档索引、免责声明摘要 | 中文正文 |
| `README.en.md` | 与 `README.md` 同构的英文镜像 | 英文 |
| `docs/BUILD.md` | **正典构建/安装指南** | 中文 |
| `docs/BUILD.en.md` | 英文镜像 | 英文 |
| `docs/STATUS.md` | 当前证据状态、四态明细、研究核对清单 | 中文 |
| `docs/STATUS.en.md` | 英文镜像 | 英文 |
| `portkit/README.md` | **作者路径**：从零重铸/维护 ARM64 骨架 | 中文 |
| `portkit/README.en.md` | 英文镜像 | 英文 |
| `docs/release/DROP-IN.md` | 使用者 drop-in 安装说明 | 中文 |
| `docs/release/DROP-IN.en.md` | 英文镜像（原英文内容迁入） | 英文 |
| `docs/letter-xiaomi.md` | 致小米信（从 README 迁出） | 中文 |
| `docs/letter-xiaomi.en.md` | 英文镜像 | 英文 |

**双语落盘约定（已确认）**：成对双文件；`*.md` 为中文，`*.en.md` 为英文。两份文件结构一一对应（同级标题、同序表格），更新时必须同步改另一份。

### 双路径（已确认）

1. **正典使用者路径（BUILD 主线）** — 与 `docs/release/DROP-IN.md` 同构：解压骨架 → 拷入官方 payload（不覆盖 `app.asar.unpacked`）→ `Patch-Asar.bat` → `Launch ARM64.bat`。
2. **作者路径（BUILD 子节 + portkit）**：`portkit\scripts\00-setup.ps1` → `01-download.ps1` → `02-extract.ps1` → `03-verify.ps1`（推荐从仓库根带 `portkit\` 前缀运行）。**不存在 `02-build.ps1`。**

### STATUS 内容边界

Verification Plan 迁入 STATUS；四态明细与证据指针在 STATUS；性能不在此重跑，指向 `scripts/bench-output/` 与 delivered spec。未完成项保持未勾选。禁止「能跑」= fully ARM64。

### README 内容边界

定位 + 实验问题 + 四态速查 + 文档索引 + 免责声明摘要。Verification 全文与致小米信不在 README。

### portkit 纠正

| 现状（重组前） | 目标（已交付） |
|----------------|----------------|
| `scripts\02-build.ps1` | `02-extract.ps1` |
| 未说明 cwd | 仓库根 / `portkit\` 两套命令均写明 |
| 无作者路径标注 | 文首标注作者路径，消费者指向 BUILD |

### 交付纪律

只改文档与 `.gitignore` / AGENTS layout；不改 portkit 提取逻辑本体（`01-download.ps1` 注释纠名除外）；不删除 `output/`/`cache/`/`%APPDATA%`；不自动 commit/push。

## [S3] Out of Scope

- 实际重铸 ARM64 骨架或跑完整 drop-in 验收
- 重跑 startup / functional benchmark
- deck 内容重做、master 主仓库脏 deck 文件清理
- 代码签名、安装器、自动更新通道
- 修改 portkit 提取/补丁脚本的业务逻辑（注释纠名除外）

## Tasks

- [x] T1: 更新 `AGENTS.md` layout 与读者入口 — acceptance: layout 表包含新文档路径；写明 BUILD 为操作正典（covers: S2）
- [x] T2: 重写 `README.md` + 新增 `README.en.md` — acceptance: README 为索引/定位/四态速查；Verification 全文与致小米信不在 README；两文件结构对应（covers: S1, S2）
- [x] T3: 新增 `docs/BUILD.md` + `docs/BUILD.en.md` — acceptance: 使用者 drop-in 为正典主线且命令可执行路径正确；portkit 作者路径脚本名改为 `02-extract.ps1` 并标明 cwd；链到 DROP-IN（covers: S2）
- [x] T4: 新增 `docs/STATUS.md` + `docs/STATUS.en.md` — acceptance: 四态明细 + Verification 清单迁入；证据指向现有 bench-output / spec；未完成项保持未勾选（covers: S1, S2）
- [x] T5: 修正并双语化 `portkit/README.md` + `portkit/README.en.md` — acceptance: 无 `02-build.ps1`；作者路径标注清楚；消费者入口指向 `docs/BUILD.md`（covers: S2）
- [x] T6: 重写 `docs/release/DROP-IN.md` + `docs/release/DROP-IN.en.md` — acceptance: 原英文内容迁入 `.en.md`；中文正文与 BUILD 正典一致；链接互通（covers: S2）
- [x] T7: 迁出致小米信 → `docs/letter-xiaomi.md` + `docs/letter-xiaomi.en.md` — acceptance: 全文离开 README，双语成对存在（covers: S1, S2）
- [x] T8: 跨文档链接审计 — acceptance: 新增/改写文档中相对链接全部可解析；索引与 BUILD/STATUS/portkit/letter/DROP-IN 互指一致（covers: S2）
- [x] T9: 可执行性抽检 — acceptance: 文档中的路径/脚本名与磁盘一致（`00-setup`/`01-download`/`02-extract`/`03-verify`、`scripts/patch-asar.js`、`scripts/release/*.bat`）；不声称未验证的 benchmark（covers: S2）

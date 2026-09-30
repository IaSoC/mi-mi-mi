# Mi Mi Mi

*An experiment on the portability of a “platform-independent” development framework, where everything goes wrong with Windows on ARM.*

**«MiMo-on-MiMo-on-Timi.»**

Mi Mi Mi is an experimental project investigating how portable a closed-source Electron application really is when moved from x86-64 to native ARM64 on Windows on ARM — using only its post-market installation environment.

The experiment runs on a **Xiaomi Book S 12.4** (Snapdragon 8cx Gen 2, Windows on ARM), using **Xiaomi MiMo** to assist the migration of **Xiaomi MiMo Desktop** — the very application hosting the agent doing the migration.

## The question

> **How much of a real Electron application is actually architecture-dependent?**

More specifically:

> **Can a closed-source Electron application be migrated from x86-64 to ARM64 using only the post-market installation artifact?**

The important distinction is not merely *“Does the application run on ARM64?”* — it already does, through Prism. It is:

> ***“Can the application run without requiring x64 compatibility for its core execution path?”***

Original path: `ARM64 CPU → Windows on ARM → Prism → x64 Electron → MiMo Desktop`  
Target path: `ARM64 CPU → Windows on ARM → ARM64 Electron → MiMo Desktop`

## Four-state taxonomy (quick reference)

| Status | Meaning |
|--------|---------|
| **ARM64** | Confirmed ARM64 |
| **x64** | Confirmed x64 |
| **Independent** | No CPU-specific binary dependency |
| **Unknown** | Insufficient evidence |

**“It works” ≠ “everything is ARM64-native.”** A file being present does not prove the app loads it. Details: [docs/STATUS.en.md](docs/STATUS.en.md).

## Where to start

| I want to… | Read |
|------------|------|
| Build / install the ARM64 build (consumers) | [docs/BUILD.en.md](docs/BUILD.en.md) · [docs/release/DROP-IN.en.md](docs/release/DROP-IN.en.md) |
| Rebuild the skeleton from scratch (maintainers) | [portkit/README.en.md](portkit/README.en.md) (author path) |
| Evidence status and research checklist | [docs/STATUS.en.md](docs/STATUS.en.md) |
| Full port design and conclusions | [docs/compose/spec/electron-arm64-port.md](docs/compose/spec/electron-arm64-port.md) |
| Presentation deck | [docs/compose/deck/](docs/compose/deck/) |
| Letter to Xiaomi | [docs/letter-xiaomi.en.md](docs/letter-xiaomi.en.md) |
| AI agent conventions | [AGENTS.md](AGENTS.md) |

**The operational canonical is `docs/BUILD.en.md` (see also `docs/BUILD.md` in Chinese).** Consumer path = drop-in (official payload + skeleton + asar patch); `portkit/` is author-path only.

## Experimental constraints

This experiment deliberately starts from the installed application rather than an official source repository. We do **not** assume access to:

- official source code
- official build system
- internal CI
- original ARM64 build configuration
- vendor development environment

It therefore resembles a **post-market portability investigation** rather than a conventional source-level port.

## How to read the result

The most interesting outcome may not be whether the migration succeeds.

If the application works with **surprisingly few changes**, the architecture-dependent boundary is relatively small. If it **fails**, the failure itself identifies where the abstraction breaks. Both success and failure are useful results.

## Disclaimer

**Mi Mi Mi is an independent research project.**

This repository does not contain Xiaomi MiMo Desktop, Xiaomi proprietary source code, signing certificates, private keys, service credentials, or other proprietary resources belonging to Xiaomi Corporation. Users are responsible for obtaining any required proprietary software or resources through legitimate channels and for complying with the applicable software licenses and terms of service.

The project author does not have the ability to sign executables on behalf of Xiaomi Corporation.

This project is provided **AS IS**, without warranty of any kind. It is not an official Xiaomi project, and it does not imply endorsement, support, or participation by Xiaomi, Timi Personal Computing Co., Ltd., Microsoft, Qualcomm, or Electron.

*MIT © 2026 IaSoC — See `portkit/LICENSE` for build tooling licensing.*

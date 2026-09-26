# Mi Mi Mi

*An experiment on the portability of a "platform-independent" development framework, where everything goes wrong with Windows on ARM.*

**«MiMo-on-MiMo-on-Timi.»**

Mi Mi Mi is an experimental project investigating how portable a closed-source Electron application really is when moved from x86-64 to ARM64 — using only its post-market installation environment.

The experiment uses **Xiaomi MiMo v2.6 Series** to assist with the migration of **Xiaomi MiMo Desktop**, running on a **Xiaomi Book S 12.4** powered by a **Qualcomm Snapdragon 8cx Gen 2** under **Windows on ARM**.

And yes, the application being migrated is the application hosting the agent doing the migration.

---

## The Setup

```
┌──────────────────────────────┐
│       MiMo v2.6 Series       │
│          AI Agent            │
└──────────────┬───────────────┘
               │
               │ modifies
               ▼
┌──────────────────────────────┐
│       MiMo Desktop           │
│       Electron application   │
└──────────────┬───────────────┘
               │
               │ originally
               ▼
┌──────────────────────────────┐
│       x64 Electron           │
│       Windows on ARM         │
│          Prism               │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│     Snapdragon 8cx Gen 2     │
│       Xiaomi Book S 12.4     │
└──────────────────────────────┘
```

The goal is to investigate whether the middle layer can instead become:

```
MiMo v2.6 Series
       │
       ▼
MiMo Desktop
       │
       ▼
ARM64 Electron
       │
       ▼
Windows ARM64
       │
       ▼
Snapdragon 8cx Gen 2
```

---

## Why?

Electron is *kinda* platform-independent.

A large portion of an Electron application's logic consists of:

- JavaScript
- HTML
- CSS
- Chromium APIs
- Electron APIs

These are largely independent of CPU architecture.

The architecture-dependent boundary tends to appear around:

- Electron itself
- Node.js native modules
- `.node` addons
- DLLs
- bundled executables
- helper processes
- installers
- updaters
- operating-system integration

So the experiment asks:

> **How much of a real Electron application is actually architecture-dependent?**

More specifically:

> **Can a closed-source Electron application be migrated from x86-64 to ARM64 using only the post-market installation artifact?**

---

## Why Windows on ARM?

The original application runs as an x64 application through Microsoft's x64 compatibility layer, **Prism**.

The original execution path is approximately:

```
ARM64 CPU → Windows on ARM → Prism → x64 Electron → MiMo Desktop
```

The experiment attempts to replace this with:

```
ARM64 CPU → Windows on ARM → ARM64 Electron → MiMo Desktop
```

The important distinction is therefore not merely:

> *"Does the application run on ARM64?"*

It already does.

The question is:

> ***"Can the application run without requiring x64 compatibility for its core execution path?"***

---

## Experimental Constraints

This experiment deliberately starts from the installed application rather than an official source repository.

We do **not** assume access to:

- official source code
- official build system
- internal CI
- original ARM64 build configuration
- vendor development environment

The experiment therefore resembles a **post-market portability investigation** rather than a conventional source-level port.

---

## Current Results

### Initial ARM64 Electron test

The modified application has currently demonstrated:

- [x] Application launches
- [x] MiMo conversation works
- [x] Agent functionality works
- [x] File writing works

Further testing is required before claiming that the application is completely ARM64-native.

In particular, successful startup does not prove that all components are ARM64.

---

## Verification Plan

### 1. Core application

- [ ] New conversation
- [ ] Multi-turn conversation
- [ ] Long-running Agent task
- [ ] File creation
- [ ] File reading
- [ ] File modification
- [ ] File deletion
- [ ] Directory operations
- [ ] Application restart
- [ ] State persistence

### 2. Electron functionality

- [ ] GPU acceleration
- [ ] Clipboard
- [ ] Drag & Drop
- [ ] Notifications
- [ ] File dialogs
- [ ] External browser invocation
- [ ] Multiple windows
- [ ] Main/renderer IPC

### 3. Process architecture

Inspect the complete process tree and record:

| Field | Example |
|-------|---------|
| Process | `Xiaomi MiMo.exe` |
| Architecture | ARM64 |
| Executable path | `output\Xiaomi MiMo ARM64\` |
| Parent process | — |
| Purpose | Main Electron process |

Look specifically for:

- ARM64 processes
- x64 processes
- x86 processes
- helper executables
- updater processes
- crash reporters
- GPU processes
- utility processes

### 4. Native components

Inspect the installation environment for:

```
*.dll   *.exe   *.node   *.asar
```

Architecture-specific components should be classified as:

| Classification | Meaning |
|---------------|---------|
| ARM64 | Confirmed ARM64 |
| x64 | Confirmed x64 |
| x86 | Confirmed x86 |
| Independent | No CPU-specific binary dependency |
| Unknown | Insufficient evidence |

A file being present does not by itself prove that the application uses it.

---

## Architecture Status

The experiment uses **four states** rather than a binary "ARM64/x64" classification.

| Status | Meaning |
|--------|---------|
| **ARM64** | Confirmed ARM64 |
| **x64** | Confirmed x64 |
| **Independent** | No CPU-specific binary dependency |
| **Unknown** | Insufficient evidence |

This prevents the experiment from confusing:

> *"It works"*

with:

> *"Everything is ARM64-native."*

---

## The Interesting Part

The most interesting outcome may not be whether the migration succeeds.

If the application works with **surprisingly few changes**, that suggests the architecture-dependent boundary of the application is relatively small.

If it **fails**, the failure itself identifies where the abstraction breaks.

For example:

| Layer | Portability |
|-------|-------------|
| JavaScript | portable |
| Chromium | portable through Electron |
| Electron runtime | architecture-specific |
| Native addon | architecture-specific |
| `helper.exe` | architecture-specific |
| Updater | architecture-specific |

The experiment therefore treats both success and failure as useful results.

---

## Mi Mi Mi

### Why "Mi Mi Mi"?

Because the experiment forms an unusually recursive stack:

```
MiMo model
    │
    ▼
MiMo Agent
    │
    ▼
MiMo Desktop
    │
    ▼
Xiaomi Book S
    │
    ▼
Timi / Xiaomi hardware ecosystem
```

In other words:

> ***A Xiaomi model, using a Xiaomi agent, modifying Xiaomi software, running on a Xiaomi ARM64 computer.***

Or, less formally:

> ***MiMo migrated MiMo on Timi.***

---

## Disclaimer

**Mi Mi Mi is an independent research project.**

This repository does not contain Xiaomi MiMo Desktop, Xiaomi proprietary source code, signing certificates, private keys, service credentials, or other proprietary resources belonging to Xiaomi Corporation.

Users are responsible for obtaining any required proprietary software or resources through legitimate channels and for complying with the applicable software licenses and terms of service.

The project author does not have the ability to sign executables on behalf of Xiaomi Corporation.

This project is provided **AS IS**, without warranty of any kind.

It is not an official Xiaomi project, and it does not imply endorsement, support, or participation by Xiaomi, Timi Personal Computing Co., Ltd., Microsoft, Qualcomm, or Electron.

If something breaks, crashes, refuses to start, or somehow summons a Prism translation layer from another dimension:

*that's probably part of the research.*

---

## Status

**Experimental.**

Current result:

> ***"It works."***

Current question:

> ***"How much of it is actually ARM64?"***

---

## To Dear Xiaomi Corporation

Dear Xiaomi Corporation,

Let's skip the void of *"What will people do?"* imagination.

Let's talk about your own advertisement for MiMo Desktop:

> *"The all-in-one AI desktop app for professionals—high-quality office work, design, coding, and multimodal creation."*

Yeah.

Office work.

So which laptops do people doing professional office work use?

**ThinkPad!** 🤓👆

Increasingly, those ThinkPads—and other professional Windows laptops—are shipping with ARM64 processors.

I'm not going to pretend I know exactly how Copilot+ PCs will change our lives.

But one thing is becoming increasingly difficult to ignore:

**Windows on ARM is entering professional computing.**

There are already machines such as the **ThinkPad T14s Gen 6**, alongside an expanding range of Windows on ARM devices.

If MiMo Desktop is meant to be an all-in-one AI desktop application for professionals, supporting Windows on ARM should eventually be part of that story.

And, well...

I happened to have a Xiaomi Book S.

So I tried it myself.

I took the ARM64 Electron runtime, reconstructed the necessary development environment, dealt with the architecture-dependent parts, and got MiMo Desktop running natively on Windows on ARM.

Not because Xiaomi asked me to.

Not because I had the source code.

Just because I wondered:

> ***"How difficult could it actually be?"***

Apparently, at least some of it was possible.

So, Xiaomi—

**I did it.**

**Now it's your turn.** 🤓👍

---

*MIT © 2026 IaSoC — See `portkit/LICENSE` for build tooling licensing.*

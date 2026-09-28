# One-shot functional startup observation (CDP + stderr).
# Measures feature-stage times for ARM64 migration evidence.
#
# NOTE: Keep this .ps1 ASCII-only (no BOM). PS 5.1 mis-reads UTF-8 Chinese
# in string literals and breaks quotes. Chinese labels live in the deck HTML.
#
# Usage (close ALL MiMo first):
#   powershell -ExecutionPolicy Bypass -File bench-functional.ps1
#   powershell -ExecutionPolicy Bypass -File bench-functional.ps1 -Side x64
#   powershell -ExecutionPolicy Bypass -File bench-functional.ps1 -Side Both
#
# Output:
#   scripts/bench-output/functional-<Side>-<stamp>/timeline.json
#   scripts/bench-output/functional-<Side>-<stamp>/summary.md
#   scripts/bench-output/functional-<Side>-<stamp>/events.ndjson

param(
    [ValidateSet("ARM64", "x64", "Both")]
    [string]$Side = "Both",

    [int]$MaxWaitMs = 90000,
    [int]$DebugPort = 9333
)

$ErrorActionPreference = "Stop"

$arm64Exe = "C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe"
$x64Exe   = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\Xiaomi MiMo.exe"
$realUd   = Join-Path $env:APPDATA "Xiaomi MiMo"
$probeJs  = Join-Path $PSScriptRoot "cdp-probe.mjs"
$outRoot  = Join-Path $PSScriptRoot "bench-output"

function Resolve-NodeExe {
    $candidates = @(
        $env:MIMO_NODE
        (Join-Path $PSScriptRoot "..\output\Xiaomi MiMo ARM64\resources\runtimes\win32-arm64\node\node.exe")
        "C:\Program Files\nodejs\node.exe"
        "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
        "node"
    )
    foreach ($c in $candidates) {
        if (-not $c) { continue }
        if ($c -eq 'node') {
            $cmd = Get-Command node -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            continue
        }
        $full = if ([System.IO.Path]::IsPathRooted($c)) { $c } else { Join-Path $PSScriptRoot $c }
        try { $full = [System.IO.Path]::GetFullPath($full) } catch { }
        if (Test-Path $full) { return $full }
    }
    return $null
}

$nodeExe = Resolve-NodeExe
if (-not $nodeExe) { Write-Host "ERROR: node.exe not found" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $probeJs)) { Write-Host "ERROR: missing $probeJs" -ForegroundColor Red; exit 1 }

function Measure-Functional {
    param([string]$Label, [string]$ExePath)

    Write-Host ""
    Write-Host "=== FUNCTIONAL $Label ===" -ForegroundColor Cyan

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outDir = Join-Path $outRoot "functional-$Label-$stamp"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $codeCache = Join-Path $realUd "Code Cache"
    if (Test-Path $codeCache) {
        Remove-Item $codeCache -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $codeCache | Out-Null
    }

    $exeDir = Split-Path $ExePath -Parent
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.WorkingDirectory = $exeDir
    $psi.Arguments = "--enable-logging=stderr --remote-debugging-port=$DebugPort"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    if ($Label -eq "ARM64") {
        $nativeLib = Join-Path $exeDir "resources\native\skia.win32-arm64-msvc.node"
        if (Test-Path $nativeLib) {
            $psi.EnvironmentVariables["NAPI_RS_NATIVE_LIBRARY_PATH"] = $nativeLib
        }
    }

    $eventsPath = Join-Path $outDir "events.ndjson"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)

    $milestones = @{
        windowTitle    = $null
        startupLoader  = $null
        sidebarChrome  = $null
        mainUi         = $null
        interactive    = $null
        listReady      = $null
        engineSessions = $null
        engineFetchMs  = $null
        engineReady    = $null
    }
    $perf = @{ fp = $null; fcp = $null; dcl = $null; load = $null; responseEnd = $null }

    $probePsi = New-Object System.Diagnostics.ProcessStartInfo
    $probePsi.FileName = $nodeExe
    $probePsi.Arguments = "`"$probeJs`" --port $DebugPort --timeout $MaxWaitMs"
    $probePsi.UseShellExecute = $false
    $probePsi.RedirectStandardOutput = $true
    $probePsi.RedirectStandardError = $true
    $probePsi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $probe = [System.Diagnostics.Process]::Start($probePsi)
    $probeOutTask = $probe.StandardOutput.ReadLineAsync()
    $probeErrTask = $probe.StandardError.ReadLineAsync()
    $stderrTask = $proc.StandardError.ReadLineAsync()

    function Add-Event([string]$Name, $Ts, $Detail = "") {
        $obj = [ordered]@{ event = $Name; hostMs = $Ts; detail = "$Detail" }
        $line = ($obj | ConvertTo-Json -Compress)
        Add-Content -Path $eventsPath -Value $line -Encoding UTF8
        Write-Host ("  [+] {0,-18} {1} ms  {2}" -f $Name, $Ts, $Detail)
    }

    while (-not $proc.HasExited -and $sw.ElapsedMilliseconds -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds 60

        while ($stderrTask.IsCompleted -and $null -ne $stderrTask.Result) {
            $line = $stderrTask.Result
            $ts = $sw.ElapsedMilliseconds
            if ($line -match 'loadEngineSessions.*total\s*=\s*(\d+)' -and -not $milestones.engineSessions) {
                $milestones.engineSessions = $ts
                $milestones.engineFetchMs = [int]$matches[1]
                Add-Event "engine-sessions" $ts "fetch=$($matches[1])ms"
            }
            if ($line -match 'engine in-process server ready' -and -not $milestones.engineReady) {
                $milestones.engineReady = $ts
                Add-Event "engine-ready" $ts "in-process server ready"
            }
            $stderrTask = $proc.StandardError.ReadLineAsync()
        }

        while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
            $raw = $probeOutTask.Result
            try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
            if ($evt) {
                $ts = $sw.ElapsedMilliseconds
                $ename = "$($evt.event)"
                switch ($ename) {
                    'connected' { Add-Event "cdp-connected" $ts "$($evt.ws)" }
                    'perf' {
                        $d = "$($evt.detail)"
                        if ($d -match '(\w+)=(\d+)') {
                            $k = $matches[1]
                            $v = [int]$matches[2]
                            if ($perf.ContainsKey($k) -and $null -eq $perf[$k]) {
                                $perf[$k] = $v
                                Add-Event "perf-$k" $ts $d
                            }
                        }
                    }
                    'startup-loader' {
                        if (-not $milestones.startupLoader) {
                            $milestones.startupLoader = $ts
                            Add-Event "startup-loader" $ts "$($evt.detail)"
                        }
                    }
                    'sidebar-chrome' {
                        if (-not $milestones.sidebarChrome) {
                            $milestones.sidebarChrome = $ts
                            Add-Event "sidebar-chrome" $ts "$($evt.detail)"
                        }
                    }
                    'interactive' {
                        if (-not $milestones.interactive) {
                            $milestones.interactive = $ts
                            Add-Event "interactive" $ts "$($evt.detail)"
                        }
                    }
                    'main-ui' {
                        if (-not $milestones.mainUi) {
                            $milestones.mainUi = $ts
                            Add-Event "main-ui" $ts "$($evt.detail)"
                        }
                    }
                    'list-ready' {
                        if (-not $milestones.listReady) {
                            $milestones.listReady = $ts
                            Add-Event "list-ready" $ts "$($evt.detail)"
                        }
                    }
                    'done' {
                        Add-Event "probe-done" $ts "T0=$($evt.mainUiMs) T1=$($evt.listMs) interactive=$($evt.interactiveMs)"
                        if ($evt.perf) {
                            foreach ($k in @('fp','fcp','dcl','load','responseEnd')) {
                                $pv = $evt.perf.$k
                                if ($null -ne $pv -and $null -eq $perf[$k]) { $perf[$k] = $pv }
                            }
                        }
                    }
                    'error' { Write-Host "  [!] probe error $($evt.message)" -ForegroundColor Yellow }
                }
            }
            $probeOutTask = $probe.StandardOutput.ReadLineAsync()
        }

        while ($probeErrTask.IsCompleted -and $null -ne $probeErrTask.Result) {
            $probeErrTask = $probe.StandardError.ReadLineAsync()
        }

        try {
            $proc.Refresh()
            if (-not $milestones.windowTitle -and $proc.MainWindowTitle -eq "Xiaomi MiMo") {
                $milestones.windowTitle = $sw.ElapsedMilliseconds
                Add-Event "window-title" $milestones.windowTitle "MainWindowTitle"
            }
        } catch {}

        if ($milestones.mainUi -and $milestones.listReady -and $milestones.interactive) {
            Start-Sleep -Milliseconds 600
            break
        }
    }

    try { if (-not $probe.HasExited) { $probe.Kill() } } catch {}

    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1

    function Gap($a, $b) {
        if ($null -eq $a -or $null -eq $b) { return $null }
        return [int]($b - $a)
    }

    $timeline = [ordered]@{
        label = $Label
        exe = $ExePath
        stamp = $stamp
        hostMs = [ordered]@{
            windowTitle    = $milestones.windowTitle
            startupLoader  = $milestones.startupLoader
            sidebarChrome  = $milestones.sidebarChrome
            mainUi         = $milestones.mainUi
            interactive    = $milestones.interactive
            listReady      = $milestones.listReady
            engineSessions = $milestones.engineSessions
            engineReady    = $milestones.engineReady
        }
        engineFetchMs = $milestones.engineFetchMs
        pagePerfMs = $perf
        stages = @(
            [ordered]@{ id = "F1-window";      name = "window";        hostMs = $milestones.windowTitle }
            [ordered]@{ id = "F2-loader";      name = "startup-logo";  hostMs = $milestones.startupLoader }
            [ordered]@{ id = "F3-sidebar";     name = "sidebar-chrome"; hostMs = $milestones.sidebarChrome }
            [ordered]@{ id = "F4-mainui";      name = "main-ui";       hostMs = $milestones.mainUi }
            [ordered]@{ id = "F5-interactive"; name = "interactive";   hostMs = $milestones.interactive }
            [ordered]@{ id = "F6-list";        name = "list-ready";    hostMs = $milestones.listReady }
            [ordered]@{ id = "F7-engine";      name = "engine-sessions"; hostMs = $milestones.engineSessions }
        )
        derivedMs = [ordered]@{
            winToLoader   = Gap $milestones.windowTitle $milestones.startupLoader
            loaderToMainUi = Gap $milestones.startupLoader $milestones.mainUi
            mainUiToList  = Gap $milestones.mainUi $milestones.listReady
            listToInteractive = Gap $milestones.listReady $milestones.interactive
        }
    }

    $jsonPath = Join-Path $outDir "timeline.json"
    $timeline | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

    $md = @"
# Functional startup - $Label

- stamp: $stamp
- exe: $ExePath

## Stage timeline (host ms from process start)

| Stage | Meaning | Host ms |
|------|---------|--------:|
| F1 window | window title | $($milestones.windowTitle) |
| F2 loader | startup logo | $($milestones.startupLoader) |
| F3 sidebar | sidebar chrome | $($milestones.sidebarChrome) |
| F4 main-ui | main UI slogan | $($milestones.mainUi) |
| F5 interactive | interactive control | $($milestones.interactive) |
| F6 list-ready | project list stable | $($milestones.listReady) |
| F7 engine-sessions | session data | $($milestones.engineSessions) |

## Page Performance API (page clock)

| Mark | ms |
|------|---:|
| first-paint | $($perf.fp) |
| first-contentful-paint | $($perf.fcp) |
| responseEnd | $($perf.responseEnd) |
| DOMContentLoaded | $($perf.dcl) |
| load | $($perf.load) |

## Engine

- loadEngineSessions fetch = $($milestones.engineFetchMs) ms
- host timestamp = $($milestones.engineSessions) ms

## Derived

- Win->Loader = $(Gap $milestones.windowTitle $milestones.startupLoader) ms
- Loader->MainUI = $(Gap $milestones.startupLoader $milestones.mainUi) ms
- MainUI->List = $(Gap $milestones.mainUi $milestones.listReady) ms
- List->Interactive = $(Gap $milestones.listReady $milestones.interactive) ms

Raw events: ``events.ndjson``
"@
    $mdPath = Join-Path $outDir "summary.md"
    Set-Content -Path $mdPath -Value $md -Encoding UTF8

    Write-Host ""
    Write-Host "  saved -> $outDir" -ForegroundColor Yellow
    return $timeline
}

$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "ERROR: Xiaomi MiMo is still running ($($running.Count) procs)." -ForegroundColor Red
    Write-Host "Close ALL MiMo instances first, then re-run."
    Write-Host "Command:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor Cyan
    exit 1
}

Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue

Write-Host "MiMo Functional Startup Observation (CDP)" -ForegroundColor Yellow
Write-Host "  Side: $Side   Probe: $probeJs"

$sides = @()
if ($Side -eq "Both") { $sides = @("ARM64", "x64") } else { $sides = @($Side) }

$results = @()
foreach ($s in $sides) {
    $exe = if ($s -eq "ARM64") { $arm64Exe } else { $x64Exe }
    if (-not (Test-Path $exe)) {
        Write-Host "SKIP $s - exe not found: $exe" -ForegroundColor Yellow
        continue
    }
    $r = Measure-Functional -Label $s -ExePath $exe
    $results += ,$r
}

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo." -ForegroundColor Green
if ($results.Count -gt 0) {
    Write-Host ""
    Write-Host "Functional stages (host ms):" -ForegroundColor Yellow
    foreach ($r in $results) {
        $h = $r.hostMs
        Write-Host ("  {0}: window={1} loader={2} sidebar={3} mainUi={4} interactive={5} list={6} eng={7} fetch={8}ms" -f `
            $r.label, $h.windowTitle, $h.startupLoader, $h.sidebarChrome, $h.mainUi, $h.interactive, $h.listReady, $h.engineSessions, $r.engineFetchMs)
    }
}

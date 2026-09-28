# MiMo Desktop ARM64 vs x64 Startup Benchmark (CDP-based)
#
# Usage:
#   1. Close ALL Xiaomi MiMo instances
#   2. powershell -ExecutionPolicy Bypass -File bench-startup.ps1 -Runs 3
#
# Detection map:
#   1 window-title     : Process.MainWindowTitle
#   2 startup-loader   : CDP .startup-loader (logo splash in static HTML)
#   3 main-ui (T0)     : CDP slogan text visible (he yi qi tan suo wu xian ke neng)
#   4 list-ready (T1)  : CDP sidebar project rows stable + recent section
#   Compare ARM64 vs x64 on T1 (list-ready from process start).
#   mainToList (T1-T0) is a secondary window metric.
#
# NOTE: Keep this .ps1 ASCII-only (no BOM). PS 5.1 mis-reads UTF-8 Chinese
# in string literals and breaks quotes. Chinese lives in cdp-probe.mjs only.

param(
    [int]$Runs = 2,
    [int]$MaxWaitMs = 90000,
    [int]$DebugPort = 9333
)

$ErrorActionPreference = "Stop"

$arm64Exe = "C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe"
$x64Exe   = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\Xiaomi MiMo.exe"
$realUd   = Join-Path $env:APPDATA "Xiaomi MiMo"
$probeJs  = Join-Path $PSScriptRoot "cdp-probe.mjs"

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

if (-not (Test-Path $probeJs)) {
    Write-Host "ERROR: missing $probeJs" -ForegroundColor Red
    exit 1
}
if (-not $nodeExe) {
    Write-Host "ERROR: node.exe not found. Install Node or set MIMO_NODE." -ForegroundColor Red
    exit 1
}
Write-Host "  node : $nodeExe"
Write-Host "  probe: $probeJs"

function Get-NativeLibPath {
    param([string]$ExePath)
    $exeDir = Split-Path $ExePath -Parent
    $lib = Join-Path $exeDir "resources\native\skia.win32-arm64-msvc.node"
    if (Test-Path $lib) { return $lib } else { return $null }
}

function Measure-Startup {
    param(
        [string]$Label,
        [string]$ExePath
    )

    Write-Host ""
    Write-Host "=== $Label ===" -ForegroundColor Cyan

    $exeDir = Split-Path $ExePath -Parent

    $codeCache = Join-Path $realUd "Code Cache"
    if (Test-Path $codeCache) {
        Remove-Item $codeCache -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $codeCache | Out-Null
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.WorkingDirectory = $exeDir
    $psi.Arguments = "--enable-logging=stderr --remote-debugging-port=$DebugPort"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $isArm64 = $ExePath -like "*ARM64*"
    $nativeLib = Get-NativeLibPath -ExePath $ExePath
    if ($isArm64 -and $nativeLib) {
        $psi.EnvironmentVariables["NAPI_RS_NATIVE_LIBRARY_PATH"] = $nativeLib
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)

    $milestones = @{
        windowTitle    = $null
        startupLoader  = $null
        mainUi         = $null
        listReady      = $null
        engineSessions = $null
        engineTotalMs  = $null
    }

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

    Write-Host "  CDP probe on port $DebugPort ..."

    $stderrTask = $proc.StandardError.ReadLineAsync()
    $lastHeartbeat = 0
    $probeDone = $null

    while (-not $proc.HasExited -and $sw.ElapsedMilliseconds -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds 80

        if (($sw.ElapsedMilliseconds - $lastHeartbeat) -ge 5000) {
            $lastHeartbeat = $sw.ElapsedMilliseconds
            Write-Host "  [.] still running @ $($sw.ElapsedMilliseconds) ms (T0=$($milestones.mainUi) T1=$($milestones.listReady))"
        }

        while ($stderrTask.IsCompleted -and $null -ne $stderrTask.Result) {
            $line = $stderrTask.Result
            $ts = $sw.ElapsedMilliseconds
            if ($line -match 'loadEngineSessions.*total\s*=\s*(\d+)' -and -not $milestones.engineSessions) {
                $milestones.engineSessions = $ts
                $milestones.engineTotalMs = [int]$matches[1]
                Write-Host "  [.] engine-sessions : $ts ms (fetch=$($matches[1])ms) [diagnostic]"
            }
            $stderrTask = $proc.StandardError.ReadLineAsync()
        }

        while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
            $raw = $probeOutTask.Result
            try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
            if ($evt) {
                $hostTs = $sw.ElapsedMilliseconds
                switch ($evt.event) {
                    'connected' {
                        Write-Host "  [.] CDP connected   : ${hostTs} ms"
                    }
                    'startup-loader' {
                        if (-not $milestones.startupLoader) {
                            $milestones.startupLoader = $hostTs
                            Write-Host "  [+] startup-loader  : $hostTs ms  $($evt.detail)"
                        }
                    }
                    'main-ui' {
                        if (-not $milestones.mainUi) {
                            $milestones.mainUi = $hostTs
                            Write-Host "  [+] main-ui (T0)    : $hostTs ms  $($evt.detail)"
                        }
                    }
                    'list-ready' {
                        if (-not $milestones.listReady) {
                            $milestones.listReady = $hostTs
                            Write-Host "  [+] list-ready (T1) : $hostTs ms  $($evt.detail)"
                            if ($milestones.mainUi) {
                                Write-Host "  [+] mainToList      : $($hostTs - $milestones.mainUi) ms"
                            }
                        }
                    }
                    'done' {
                        $probeDone = $evt
                        Write-Host "  [.] probe done      : loader=$($evt.loaderMs) T0=$($evt.mainUiMs) T1=$($evt.listMs) gap=$($evt.mainToListMs) ms"
                    }
                    'probe-debug' {
                        Write-Host "  [.] probe-debug     : $($evt.detail)"
                    }
                    'error' {
                        Write-Host "  [!] probe error     : $($evt.message)" -ForegroundColor Yellow
                    }
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
                Write-Host "  [.] window-title    : $($milestones.windowTitle) ms [diagnostic]"
            }
        } catch {}

        if ($milestones.mainUi -and $milestones.listReady) {
            Start-Sleep -Milliseconds 400
            break
        }
    }

    try {
        while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
            $raw = $probeOutTask.Result
            try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
            if ($evt) {
                $hostTs = $sw.ElapsedMilliseconds
                if ($evt.event -eq 'startup-loader' -and -not $milestones.startupLoader) {
                    $milestones.startupLoader = $hostTs
                    Write-Host "  [+] startup-loader  : $hostTs ms (late drain)"
                }
                if ($evt.event -eq 'main-ui' -and -not $milestones.mainUi) {
                    $milestones.mainUi = $hostTs
                    Write-Host "  [+] main-ui (T0)    : $hostTs ms (late drain)"
                }
                if ($evt.event -eq 'list-ready' -and -not $milestones.listReady) {
                    $milestones.listReady = $hostTs
                    Write-Host "  [+] list-ready (T1) : $hostTs ms (late drain)"
                }
            }
            $probeOutTask = $probe.StandardOutput.ReadLineAsync()
        }
    } catch {}

    try { if (-not $probe.HasExited) { $probe.Kill() } } catch {}

    $sw.Stop()

    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    $rss = if ($procs) {
        [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1)
    } else { 0 }
    $procCount = if ($procs) { $procs.Count } else { 0 }

    foreach ($p in $procs) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1

    $wt = $milestones.windowTitle
    $tl = $milestones.startupLoader
    $t0 = $milestones.mainUi
    $t1 = $milestones.listReady
    $es = $milestones.engineSessions
    $engTotal = $milestones.engineTotalMs
    $mainToList = if ($t0 -and $t1) { $t1 - $t0 } else { $null }
    $winToLoader = if ($wt -and $tl) { $tl - $wt } else { $null }
    $loaderToMain = if ($tl -and $t0) { $t0 - $tl } else { $null }

    function FmtMs($v) {
        if ($null -eq $v -or "$v" -eq '') { return 'n/a' }
        return "$v ms"
    }
    function FmtGap($v) {
        if ($null -eq $v -or "$v" -eq '') { return 'n/a' }
        return "${v}ms"
    }

    Write-Host "  --- results ---"
    Write-Host "    window-title      : $(FmtMs $wt)   (1 window)"
    Write-Host "    startup-loader    : $(FmtMs $tl)   (2 logo splash)  winToLoader=$(FmtGap $winToLoader)"
    Write-Host "    T0 main-ui        : $(FmtMs $t0)   (3 main UI)  loaderToMain=$(FmtGap $loaderToMain)"
    Write-Host "    T1 list-ready     : $(FmtMs $t1)   (4 project list)"
    Write-Host "    mainToList        : $(FmtGap $mainToList)   <- PRIMARY (3->4)"
    Write-Host "    engine-sessions   : $(FmtMs $es)  fetch=$(FmtMs $engTotal) [diag]"
    Write-Host "    RSS               : ${rss} MB ($procCount procs)"

    return [PSCustomObject]@{
        Label           = $Label
        WindowTitleMs   = $wt
        StartupLoaderMs = $tl
        MainUiMs        = $t0
        ListReadyMs     = $t1
        MainToListMs    = $mainToList
        WinToLoaderMs   = $winToLoader
        LoaderToMainMs  = $loaderToMain
        EngineSessionsMs = $es
        EngineTotalMs   = $engTotal
        RssMB           = $rss
        ProcCount       = $procCount
    }
}

# --- Preflight ---
$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "ERROR: Xiaomi MiMo is still running ($($running.Count) processes)." -ForegroundColor Red
    Write-Host "Close ALL MiMo instances first, then re-run."
    exit 1
}

Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue

Write-Host "MiMo ARM64 vs x64 Startup Benchmark (CDP)" -ForegroundColor Yellow
Write-Host "Runs per side: $Runs   User profile: $realUd"
Write-Host "Four points:"
Write-Host "  1 window-title     : Process.MainWindowTitle"
Write-Host "  2 startup-loader   : CDP .startup-loader (logo splash)"
Write-Host "  3 main-ui (T0)     : CDP slogan visible"
Write-Host "  4 list-ready (T1)  : CDP project rows stable + recent"
Write-Host "Compare on T1 (list-ready). mainToList = T1-T0 is secondary."

# Persist everything: console transcript + summary.txt + results.csv.
# (This script used to print only to the console, which made published
# numbers impossible to audit after the session closed.)
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $PSScriptRoot "bench-output\startup-$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$transcriptPath = Join-Path $outDir "console.log"
$transcriptOn = $false
try {
    Start-Transcript -Path $transcriptPath -Force | Out-Null
    $transcriptOn = $true
} catch {
    Write-Host "WARNING: transcript unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host "  output: $outDir"

$summaryBuf = New-Object System.Collections.ArrayList
function Say {
    param([string]$m = "")
    Write-Host $m
    [void]$summaryBuf.Add($m)
}

$results = @{
    "ARM64" = New-Object System.Collections.ArrayList
    "x64"   = New-Object System.Collections.ArrayList
}

for ($i = 1; $i -le $Runs; $i++) {
    Write-Host ""
    Write-Host "--- Run $i / $Runs ---" -ForegroundColor Yellow

    $order = if ($i % 2 -eq 1) { @("ARM64","x64") } else { @("x64","ARM64") }

    foreach ($side in $order) {
        $exe = if ($side -eq "ARM64") { $arm64Exe } else { $x64Exe }
        $r = Measure-Startup -Label "$side run $i" -ExePath $exe
        [void]$results[$side].Add($r)
    }
}

Say ""
Say "================================================================"
Say "                    SUMMARY (averages)"
Say "================================================================"

$keys = @('WindowTitleMs','StartupLoaderMs','MainUiMs','ListReadyMs','MainToListMs','LoaderToMainMs','EngineSessionsMs','EngineTotalMs','RssMB')
$header = "{0,-8}" -f "Side"
foreach ($k in $keys) {
    $header += "  {0,12}" -f ($k -replace 'Ms$','' -replace 'WindowTitle','Win' -replace 'StartupLoader','Loader' -replace 'MainUi','T0' -replace 'ListReady','T1' -replace 'MainToList','MainToList' -replace 'LoaderToMain','LdrToMain' -replace 'EngineSessions','EngEnd' -replace 'EngineTotal','EngFetch')
}
Say $header
Say ("-" * [Math]::Min(140, $header.Length))

foreach ($side in @("ARM64","x64")) {
    $list = $results[$side]
    if ($list.Count -eq 0) { continue }
    $line = "{0,-8}" -f $side
    foreach ($k in $keys) {
        $vals = @($list | Where-Object { $null -ne $_.$k -and "$($_.$k)" -ne '' } | ForEach-Object { $_.$k })
        if ($vals.Count -gt 0) {
            $avg = [math]::Round(($vals | Measure-Object -Average).Average, 1)
            $line += "  {0,12}" -f $avg
        } else {
            $line += "  {0,12}" -f "n/a"
        }
    }
    Say $line
}

# Compare platforms on T1 (list-ready absolute time from process start),
# NOT on mainToList (T1-T0). T0 can shift independently; T1 is what the
# user times from launch until the project list is up.
$armList = @($results['ARM64'] | Where-Object { $null -ne $_.ListReadyMs })
$x64List = @($results['x64']   | Where-Object { $null -ne $_.ListReadyMs })
if ($armList.Count -gt 0 -and $x64List.Count -gt 0) {
    $armAvg = ($armList | ForEach-Object { $_.ListReadyMs } | Measure-Object -Average).Average
    $x64Avg = ($x64List | ForEach-Object { $_.ListReadyMs } | Measure-Object -Average).Average
    if ($armAvg -gt 0) {
        $speedup = [math]::Round($x64Avg / $armAvg, 2)
        Say ""
        Say "Speedup (T1 list-ready): ARM64 is ${speedup}x faster than x64 emulation"
        Say ("  T1 avg  ARM64={0} ms  x64={1} ms" -f $armAvg, $x64Avg)
        $armM2 = @($results['ARM64'] | Where-Object { $null -ne $_.MainToListMs })
        $x64M2 = @($results['x64']   | Where-Object { $null -ne $_.MainToListMs })
        if ($armM2.Count -gt 0 -and $x64M2.Count -gt 0) {
            $a2 = ($armM2 | ForEach-Object { $_.MainToListMs } | Measure-Object -Average).Average
            $x2 = ($x64M2 | ForEach-Object { $_.MainToListMs } | Measure-Object -Average).Average
            Say ("  ref only mainToList (T1-T0)  ARM64={0} ms  x64={1} ms" -f [math]::Round($a2,1), [math]::Round($x2,1))
        }
    }
}

Say ""
Say "--- Per-run detail ---"
foreach ($side in @("ARM64","x64")) {
    foreach ($r in $results[$side]) {
        function N($v) { if ($null -eq $v -or "$v" -eq '') { return '-' } else { return "$v" } }
        Say ("  {0,-16}  win={1}  loader={2}  T0={3}  T1={4}  mainToList={5}  engFetch={6}  rss={7}MB" -f `
            $r.Label, (N $r.WindowTitleMs), (N $r.StartupLoaderMs), (N $r.MainUiMs), (N $r.ListReadyMs), (N $r.MainToListMs), (N $r.EngineTotalMs), $r.RssMB)
    }
}

# --- Persist ---
$summaryFile = Join-Path $outDir "summary.txt"
$summaryHeader = @(
    "MiMo Startup Benchmark (CDP) - $Runs runs per side",
    "Stamp     : $stamp",
    "Script    : bench-startup.ps1 -Runs $Runs -DebugPort $DebugPort",
    "Cold start: Code Cache cleared before every run; order alternates ARM64/x64",
    "Compare   : T1 (list-ready) absolute time. mainToList is reference only.",
    ""
)
Set-Content -Path $summaryFile -Value ($summaryHeader + $summaryBuf) -Encoding UTF8

$allRuns = @($results['ARM64']) + @($results['x64'])
if ($allRuns.Count -gt 0) {
    $csvFile = Join-Path $outDir "results.csv"
    $allRuns | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
}

if ($transcriptOn) { try { Stop-Transcript | Out-Null } catch {} }

Write-Host ""
Write-Host "Saved: $outDir" -ForegroundColor Green
Write-Host "  summary.txt  results.csv  console.log"

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo."

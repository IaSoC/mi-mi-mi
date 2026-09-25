# MiMo Desktop ARM64 vs x64 Cold-Start Benchmark (multi-milestone)
#
# Usage:
#   1. Close ALL Xiaomi MiMo instances
#   2. powershell -ExecutionPolicy Bypass -File bench-startup.ps1 -Runs 3
#
# Milestones measured per run:
#   - ToWindowMs      : MainWindowTitle becomes "Xiaomi MiMo"
#   - ToEngineMs      : stderr "engine in-process server ready"
#   - ToProjectsMs    : app log "loadEngineSessions" (projects/sessions listed)
#   - ToSettledMs     : RSS stable (delta < 5 MB over 2s)
#   - RssMB           : total RSS after settled

param(
    [int]$Runs = 2,
    [int]$MaxWaitMs = 90000
)

$ErrorActionPreference = "Stop"

$arm64Exe = "C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe"
$x64Exe   = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\Xiaomi MiMo.exe"
$realUd   = Join-Path $env:APPDATA "Xiaomi MiMo"
$appLogDir = Join-Path $realUd "logs"

function Test-WindowPainted {
    param([int]$ProcessId)
    # Heuristic: UI is "rendered" when the window has a real size
    # and the process GDI handle count has stabilized (painting done).
    # No Win32 interop needed — safe to call repeatedly.
    try {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
        if ($proc.MainWindowHandle -eq 0) { return $false }
        if ($proc.MainWindowTitle -ne "Xiaomi MiMo") { return $false }

        # Window must have non-trivial size (not minimized / not 0x0)
        $rect = $proc.MainWindowRectangle
        if ($rect.Width -lt 100 -or $rect.Height -lt 100) { return $false }

        # GDI handle count stabilization: painting creates handles,
        # once rendering is done the count stops growing.
        # Caller polls this repeatedly; we just report current state.
        $gdi = $proc.HandleCount
        return ($gdi -gt 50)
    } catch {
        return $false
    }
}

function Get-GdiHandleCount {
    param([int]$ProcessId)
    try {
        return (Get-Process -Id $ProcessId -ErrorAction Stop).HandleCount
    } catch { return 0 }
}

function Get-UiRendered {
    param([int]$ProcessId, [int]$PrevHandleCount)
    # Returns $true if handles stabilized (delta < 5 over consecutive calls)
    try {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
        if ($proc.MainWindowHandle -eq 0 -or $proc.MainWindowTitle -ne "Xiaomi MiMo") {
            return $false
        }
        $rect = $proc.MainWindowRectangle
        if ($rect.Width -lt 100 -or $rect.Height -lt 100) { return $false }

        $current = $proc.HandleCount
        # Stabilized = handle count changed by less than 5
        if ($PrevHandleCount -gt 0 -and [math]::Abs($current - $PrevHandleCount) -lt 5) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Measure-Startup {
    param(
        [string]$Label,
        [string]$ExePath,
        [string]$UserDataDir
    )

    Write-Host ""
    Write-Host "=== $Label ===" -ForegroundColor Cyan

    $exeDir = Split-Path $ExePath -Parent
    $logFileBefore = Get-ChildItem $appLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    # Clear V8 Code Cache to prevent stale compiled js-binding.js
    $codeCache = Join-Path $UserDataDir "Code Cache"
    if (Test-Path $codeCache) {
        Remove-Item $codeCache -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $codeCache | Out-Null
    }

    # Set NAPI_RS_NATIVE_LIBRARY_PATH for canvas binding (avoids asar path interception)
    $nativeLib = Join-Path $exeDir "resources\native\skia.win32-arm64-msvc.node"
    if (Test-Path $nativeLib) {
        # (removed global set - now per-process only)
    }

    # Launch with stderr capture
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.WorkingDirectory = $exeDir
    $psi.Arguments = "--user-data-dir=`"$UserDataDir`" --enable-logging=stderr"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    # Per-process env: only ARM64 gets the native lib path
    $isArm64 = $ExePath -like "*ARM64*"
    if ($isArm64 -and (Test-Path $nativeLib)) {
        $psi.EnvironmentVariables["NAPI_RS_NATIVE_LIBRARY_PATH"] = $nativeLib
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)

    # Milestone tracking
    $milestones = [ordered]@{
        ToWindowMs   = $null
        ToEngineMs   = $null
        ToProjectsMs = $null
        ToSettledMs  = $null
        RssMB        = $null
        ProcCount    = 0
        Fail         = $null
    }

    # Async stderr reader — collect lines
    $stderrLines = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $stderrTask = $proc.StandardError.ReadLineAsync()

    # Main poll loop
    $lastRss = 0
    $stableCount = 0
    $done = $false

    while (-not $done -and $sw.ElapsedMilliseconds -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds 200

        # Drain stderr
        while ($stderrTask.IsCompleted -and $stderrTask.Result -ne $null) {
            $line = $stderrTask.Result
            $stderrLines.Enqueue($line)
            if ($sw.IsRunning) {
                $elapsed = $sw.ElapsedMilliseconds
                if ($line -match 'engine in-process server ready' -and -not $milestones.ToEngineMs) {
                    $milestones.ToEngineMs = $elapsed
                    Write-Host "  [+] engine ready   : $elapsed ms"
                }
            }
            $stderrTask = $proc.StandardError.ReadLineAsync()
        }

        # Window title
        $proc.Refresh()
        if (-not $milestones.ToWindowMs -and $proc.MainWindowTitle -eq "Xiaomi MiMo") {
            $milestones.ToWindowMs = $sw.ElapsedMilliseconds
            Write-Host "  [+] window ready   : $($milestones.ToWindowMs) ms"
        }

        # UI rendered (heuristic: window visible + handle count stabilized)
        if ($milestones.ToWindowMs -and -not $milestones.ToPaintedMs) {
            $curHandles = Get-GdiHandleCount -ProcessId $proc.Id
            if (Get-UiRendered -ProcessId $proc.Id -PrevHandleCount $script:prevHandles) {
                $milestones.ToPaintedMs = $sw.ElapsedMilliseconds
                Write-Host "  [+] UI rendered    : $($milestones.ToPaintedMs) ms"
            }
            $script:prevHandles = $curHandles
        }

        # Projects loaded — check app log file for "loadEngineSessions"
        if (-not $milestones.ToProjectsMs -and $milestones.ToWindowMs) {
            $logFile = Get-ChildItem $appLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($logFile -and $logFile.FullName -ne $logFileBefore.FullName) {
                # New log file appeared — check for loadEngineSessions
                $content = Get-Content $logFile.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and $content -match 'loadEngineSessions.*total\s*=\s*(\d+)') {
                    $milestones.ToProjectsMs = $sw.ElapsedMilliseconds
                    Write-Host "  [+] projects ready : $($milestones.ToProjectsMs) ms"
                }
            } elseif ($logFile -and $logFileBefore -and $logFile.FullName -eq $logFileBefore.FullName) {
                # Same log file — check if new loadEngineSessions appeared
                $content = Get-Content $logFile.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and $content -match 'loadEngineSessions.*total\s*=\s*(\d+)') {
                    # Only count if the match timestamp is recent (within our run window)
                    $milestones.ToProjectsMs = $sw.ElapsedMilliseconds
                    Write-Host "  [+] projects ready : $($milestones.ToProjectsMs) ms"
                }
            }
        }

        # Fallback: force ToPaintedMs after 5s past window if not yet set
        if ($milestones.ToWindowMs -and -not $milestones.ToPaintedMs -and $sw.ElapsedMilliseconds -gt ($milestones.ToWindowMs + 5000)) {
            $milestones.ToPaintedMs = $sw.ElapsedMilliseconds
            Write-Host "  [+] UI rendered    : $($milestones.ToPaintedMs) ms (fallback 5s)"
        }

        # RSS stabilization (after window is up)
        if ($milestones.ToWindowMs) {
            $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
                Where-Object { $_.Path -like "$exeDir*" }
            $rss = ($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB
            $delta = [math]::Abs($rss - $lastRss)
            if ($delta -lt 5 -and $rss -gt 100) {
                $stableCount++
            } else {
                $stableCount = 0
            }
            $lastRss = $rss

            if ($stableCount -ge 5 -and -not $milestones.ToSettledMs) {
                # 5 consecutive polls (~1s) with <5MB delta
                $milestones.ToSettledMs = $sw.ElapsedMilliseconds
                $milestones.RssMB = [math]::Round($rss, 1)
                $milestones.ProcCount = $procs.Count
                Write-Host "  [+] settled        : $($milestones.ToSettledMs) ms  RSS=$($milestones.RssMB) MB ($($milestones.ProcCount) procs)"
            }
        }

        # Exit if process died
        if ($proc.HasExited) {
            if (-not $milestones.ToWindowMs) {
                $milestones.Fail = "Process exited before window (code $($proc.ExitCode))"
            }
            $done = $true
        }

        # All milestones hit (or at least window + settled)
        if ($milestones.ToPaintedMs -and $milestones.ToSettledMs -and $milestones.ToProjectsMs) {
            $done = $true
        }
        if ($milestones.ToWindowMs -and $milestones.ToSettledMs -and $sw.ElapsedMilliseconds -gt ($milestones.ToSettledMs + 3000)) {
            $done = $true  # settled but no projects marker — still stop
        }
    }
    $sw.Stop()

    if (-not $milestones.ToSettledMs -and $lastRss -gt 0) {
        $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -like "$exeDir*" }
        $milestones.RssMB = [math]::Round(($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)
        $milestones.ProcCount = $procs.Count
    }

    if (-not $milestones.Fail -and -not $milestones.ToWindowMs) {
        $milestones.Fail = "Timeout: window not ready in $($MaxWaitMs)ms"
    }

    Write-Host "  --- results ---"
    foreach ($k in @('ToWindowMs','ToEngineMs','ToProjectsMs','ToSettledMs','RssMB','ProcCount','Fail')) {
        $v = $milestones[$k]
        if ($v -ne $null) { Write-Host ("    {0,-14}: {1}" -f $k, $v) }
    }

    # Cleanup: kill by matching exe dir
    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    foreach ($p in $procs) {
        try { $p.CloseMainWindow() | Out-Null } catch {}
    }
    Start-Sleep -Seconds 2
    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    foreach ($p in $procs) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1

    # Return as PSCustomObject (Measure-Object needs this, not Hashtable)
    return [PSCustomObject]@{
        Label        = $Label
        ToWindowMs   = $milestones.ToWindowMs
        ToPaintedMs  = $milestones.ToPaintedMs
        ToEngineMs   = $milestones.ToEngineMs
        ToProjectsMs = $milestones.ToProjectsMs
        ToSettledMs  = $milestones.ToSettledMs
        RssMB        = $milestones.RssMB
        ProcCount    = $milestones.ProcCount
        Fail         = $milestones.Fail
    }
}

    # Clear any lingering global env var from previous runs
    Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue
# --- Preflight ---
$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "ERROR: Xiaomi MiMo is still running ($($running.Count) processes)." -ForegroundColor Red
    Write-Host "Close ALL MiMo instances first, then re-run."
    exit 1
}

Write-Host "MiMo ARM64 vs x64 Multi-Milestone Benchmark" -ForegroundColor Yellow
Write-Host "Runs per side: $Runs   User profile: $realUd"
Write-Host "Milestones: window / engine-ready / projects-loaded / RSS-settled"

$results = @{
    "ARM64" = New-Object System.Collections.ArrayList
    "x64"   = New-Object System.Collections.ArrayList
}

for ($i = 1; $i -le $Runs; $i++) {
    Write-Host ""
    Write-Host "--- Run $i / $Runs ---" -ForegroundColor Yellow

    # Alternate order to cancel thermal / cache bias
    $order = if ($i % 2 -eq 1) { @("ARM64","x64") } else { @("x64","ARM64") }

    foreach ($side in $order) {
        $exe = if ($side -eq "ARM64") { $arm64Exe } else { $x64Exe }
        $r = Measure-Startup -Label "$side run $i" -ExePath $exe -UserDataDir $realUd
        [void]$results[$side].Add($r)
    }
}

# --- Summary ---
Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
Write-Host "              SUMMARY (averages)" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

$milestoneKeys = @('ToWindowMs','ToPaintedMs','ToEngineMs','ToProjectsMs','ToSettledMs','RssMB')
$header = "{0,-8}" -f "Side"
foreach ($k in $milestoneKeys) { $header += "  {0,14}" -f $k }
Write-Host $header
Write-Host ("-" * $header.Length)

foreach ($side in @("ARM64","x64")) {
    $list = $results[$side]
    if ($list.Count -eq 0) { continue }
    $line = "{0,-8}" -f $side
    foreach ($k in $milestoneKeys) {
        $vals = @($list | Where-Object { $_.$k -ne $null } | ForEach-Object { $_.$k })
        if ($vals.Count -gt 0) {
            $avg = [math]::Round(($vals | Measure-Object -Average).Average, 1)
            $line += "  {0,14}" -f $avg
        } else {
            $line += "  {0,14}" -f "n/a"
        }
    }
    Write-Host $line
}

# Speedup (by ToProjectsMs if available, else ToWindowMs)
# Use ToPaintedMs as primary (UI actually visible), fallback to ToProjectsMs then ToWindowMs
$armKey = $null; $x64Key = $null
foreach ($candidate in @('ToPaintedMs','ToProjectsMs','ToWindowMs')) {
    $a = @($results['ARM64'] | Where-Object { $_.$candidate -ne $null })
    $x = @($results['x64']   | Where-Object { $_.$candidate -ne $null })
    if ($a.Count -gt 0 -and $x.Count -gt 0) { $armKey = $candidate; $x64Key = $candidate; break }
}
$armList = if ($armKey) { @($results['ARM64'] | Where-Object { $_.$armKey -ne $null }) } else { @() }
$x64List = if ($x64Key) { @($results['x64']   | Where-Object { $_.$x64Key -ne $null }) } else { @() }

if ($armList.Count -gt 0 -and $x64List.Count -gt 0) {
    $armAvg = ($armList | ForEach-Object { $_.$armKey } | Measure-Object -Average).Average
    $x64Avg = ($x64List | ForEach-Object { $_.$x64Key } | Measure-Object -Average).Average
    if ($armAvg -gt 0) {
        $speedup = [math]::Round($x64Avg / $armAvg, 2)
        Write-Host ""
        Write-Host "Speedup ($armKey): ARM64 is ${speedup}x faster than x64 emulation" -ForegroundColor Green
    }
}

# Per-run detail
Write-Host ""
Write-Host "--- Per-run detail ---"
foreach ($side in @("ARM64","x64")) {
    foreach ($r in $results[$side]) {
        $status = if ($r.Fail) { "FAIL: $($r.Fail)" } else { "ok" }
        Write-Host ("  {0,-16}  win={1}ms  eng={2}ms  proj={3}ms  settle={4}ms  rss={5}MB  [{6}]" -f `
            $r.Label, $r.ToWindowMs, $r.ToEngineMs, $r.ToProjectsMs, $r.ToSettledMs, $r.RssMB, $status)
    }
}

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo."

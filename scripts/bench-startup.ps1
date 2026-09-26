# MiMo Desktop ARM64 vs x64 Automated Startup Benchmark (multi-round)
#
# Usage:
#   1. Close ALL Xiaomi MiMo instances
#   2. powershell -ExecutionPolicy Bypass -File bench-startup.ps1 -Runs 3
#
# Four milestones per run:
#   1. window-title    : MainWindowTitle becomes "Xiaomi MiMo"
#   2. shimmer-painted : window has valid size (startup-loader first paint)
#   3. landing-page    : first INFO:CONSOLE (React bundle executed)
#   4. projects-loaded : loadEngineSessions total=Nms from stderr

param(
    [int]$Runs = 2,
    [int]$MaxWaitMs = 90000
)

$ErrorActionPreference = "Stop"

$arm64Exe = "C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe"
$x64Exe   = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\Xiaomi MiMo.exe"
$realUd   = Join-Path $env:APPDATA "Xiaomi MiMo"

# Per-process env: ARM64 gets the native lib path for canvas binding
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

    # Clear V8 Code Cache to prevent stale compiled js-binding.js
    $codeCache = Join-Path $realUd "Code Cache"
    if (Test-Path $codeCache) {
        Remove-Item $codeCache -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $codeCache | Out-Null
    }

    # Launch with stderr capture
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.WorkingDirectory = $exeDir
    $psi.Arguments = "--enable-logging=stderr"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    # Per-process env: only ARM64 gets the native lib path
    $isArm64 = $ExePath -like "*ARM64*"
    $nativeLib = Get-NativeLibPath -ExePath $ExePath
    if ($isArm64 -and $nativeLib) {
        $psi.EnvironmentVariables["NAPI_RS_NATIVE_LIBRARY_PATH"] = $nativeLib
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)

    # Milestone tracking
    $milestones = @{
        windowTitle    = $null
        shimmerPainted = $null
        landingPage    = $null
        projectsLoaded = $null
    }

    $stderrTask = $proc.StandardError.ReadLineAsync()

    # Main poll loop
    while (-not $proc.HasExited -and $sw.ElapsedMilliseconds -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds 100

        # Drain stderr for milestone detection
        while ($stderrTask.IsCompleted -and $stderrTask.Result -ne $null) {
            $line = $stderrTask.Result
            $ts = $sw.ElapsedMilliseconds

            # Milestone 3: landing-page (first INFO:CONSOLE = React bundle executed)
            if ($line -match 'INFO:CONSOLE' -and -not $milestones.landingPage) {
                $milestones.landingPage = $ts
                Write-Host "  [+] landing-page   : $ts ms"
            }

            # Milestone 4: projects-loaded (loadEngineSessions total=Nms)
            if ($line -match 'loadEngineSessions.*total\s*=\s*(\d+)' -and -not $milestones.projectsLoaded) {
                $milestones.projectsLoaded = $ts
                Write-Host "  [+] projects-loaded: $ts ms (engine total=$($matches[1])ms)"
            }

            $stderrTask = $proc.StandardError.ReadLineAsync()
        }

        # Milestone 1: window-title
        try {
            $proc.Refresh()
            if (-not $milestones.windowTitle -and $proc.MainWindowTitle -eq "Xiaomi MiMo") {
                $milestones.windowTitle = $sw.ElapsedMilliseconds
                Write-Host "  [+] window-title   : $($milestones.windowTitle) ms"
            }
        } catch {}

        # Milestone 2: shimmer-painted (startup-loader first paint)
        if ($milestones.windowTitle -and -not $milestones.shimmerPainted) {
            try {
                $proc.Refresh()
                $rect = $proc.MainWindowRectangle
                if ($rect.Width -gt 0 -and $rect.Height -gt 0) {
                    $milestones.shimmerPainted = $sw.ElapsedMilliseconds
                    Write-Host "  [+] shimmer-painted: $($milestones.shimmerPainted) ms (window $($rect.Width)x$($rect.Height))"
                }
            } catch {}
            # Fallback: force after 200ms past window-title
            if (-not $milestones.shimmerPainted -and ($sw.ElapsedMilliseconds - $milestones.windowTitle) -gt 200) {
                $milestones.shimmerPainted = $sw.ElapsedMilliseconds
                Write-Host "  [+] shimmer-painted: $($milestones.shimmerPainted) ms (fallback +200ms)"
            }
        }

        # Exit early if all four milestones are captured
        if ($milestones.windowTitle -and $milestones.shimmerPainted -and $milestones.landingPage -and $milestones.projectsLoaded) {
            Start-Sleep -Seconds 2
            break
        }
    }
    $sw.Stop()

    # Capture final RSS
    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    $rss = if ($procs) {
        [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1)
    } else { 0 }
    $procCount = if ($procs) { $procs.Count } else { 0 }

    # Kill by exe dir match (not by name globally)
    foreach ($p in $procs) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1

    # Summary line
    $wt = $milestones.windowTitle
    $sp = $milestones.shimmerPainted
    $lp = $milestones.landingPage
    $pl = $milestones.projectsLoaded
    $gap1 = if ($wt -and $sp) { $sp - $wt } else { $null }
    $gap2 = if ($sp -and $lp) { $lp - $sp } else { $null }
    $gap3 = if ($lp -and $pl) { $pl - $lp } else { $null }

    Write-Host "  --- results ---"
    Write-Host "    window-title    : $wt ms"
    Write-Host "    shimmer-painted : $sp ms (gap: ${gap1}ms)"
    Write-Host "    landing-page    : $lp ms (gap: ${gap2}ms)"
    Write-Host "    projects-loaded : $pl ms (gap: ${gap3}ms)"
    Write-Host "    RSS             : ${rss} MB ($procCount procs)"

    # Return as PSCustomObject (Measure-Object needs this)
    return [PSCustomObject]@{
        Label           = $Label
        WindowTitleMs   = $wt
        ShimmerPaintedMs = $sp
        LandingPageMs   = $lp
        ProjectsLoadedMs = $pl
        GapWindowShimmer = $gap1
        GapShimmerLanding = $gap2
        GapLandingProjects = $gap3
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

# Clear any lingering global env var
Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue

Write-Host "MiMo ARM64 vs x64 Four-Milestone Benchmark" -ForegroundColor Yellow
Write-Host "Runs per side: $Runs   User profile: $realUd"
Write-Host "Milestones: window-title / shimmer-painted / landing-page / projects-loaded"

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
        $r = Measure-Startup -Label "$side run $i" -ExePath $exe
        [void]$results[$side].Add($r)
    }
}

# --- Summary ---
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "                    SUMMARY (averages)" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow

$keys = @('WindowTitleMs','ShimmerPaintedMs','GapWindowShimmer','LandingPageMs','GapShimmerLanding','ProjectsLoadedMs','GapLandingProjects','RssMB')
$header = "{0,-8}" -f "Side"
foreach ($k in $keys) { $header += "  {0,14}" -f ($k -replace 'Ms$','' -replace 'Gap','+') }
Write-Host $header
Write-Host ("-" * $header.Length)

foreach ($side in @("ARM64","x64")) {
    $list = $results[$side]
    if ($list.Count -eq 0) { continue }
    $line = "{0,-8}" -f $side
    foreach ($k in $keys) {
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

# Speedup (by projects-loaded)
$armList = @($results['ARM64'] | Where-Object { $_.ProjectsLoadedMs -ne $null })
$x64List = @($results['x64']   | Where-Object { $_.ProjectsLoadedMs -ne $null })
if ($armList.Count -gt 0 -and $x64List.Count -gt 0) {
    $armAvg = ($armList | ForEach-Object { $_.ProjectsLoadedMs } | Measure-Object -Average).Average
    $x64Avg = ($x64List | ForEach-Object { $_.ProjectsLoadedMs } | Measure-Object -Average).Average
    if ($armAvg -gt 0) {
        $speedup = [math]::Round($x64Avg / $armAvg, 2)
        Write-Host ""
        Write-Host "Speedup (projects-loaded): ARM64 is ${speedup}x faster than x64 emulation" -ForegroundColor Green
    }
}

# Per-run detail
Write-Host ""
Write-Host "--- Per-run detail ---"
foreach ($side in @("ARM64","x64")) {
    foreach ($r in $results[$side]) {
        Write-Host ("  {0,-16}  win={1}  shimmer={2}  land={3}  proj={4}  gaps=+{5}/+{6}/+{7}  rss={8}MB" -f `
            $r.Label, $r.WindowTitleMs, $r.ShimmerPaintedMs, $r.LandingPageMs, $r.ProjectsLoadedMs,
            $r.GapWindowShimmer, $r.GapShimmerLanding, $r.GapLandingProjects, $r.RssMB)
    }
}

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo."

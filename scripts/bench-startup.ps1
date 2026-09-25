# MiMo Desktop ARM64 vs x64 Cold-Start Benchmark
# Usage:
#   1. Close ALL Xiaomi MiMo instances
#   2. powershell -ExecutionPolicy Bypass -File bench-startup.ps1
#   3. Optionally: powershell -ExecutionPolicy Bypass -File bench-startup.ps1 -Runs 3
#
# Measures: time-to-window, total RSS after idle, process count
# Uses the real user profile for both sides.

param(
    [int]$Runs = 2,
    [int]$IdleSeconds = 5
)

$ErrorActionPreference = "Stop"

# Paths
$arm64Exe = "C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe"
$x64Exe   = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\Xiaomi MiMo.exe"
$realUd   = Join-Path $env:APPDATA "Xiaomi MiMo"

function Measure-Startup {
    param(
        [string]$Label,
        [string]$ExePath,
        [string]$WorkDir,
        [string]$UserDataDir
    )

    Write-Host ""
    Write-Host "=== $Label ===" -ForegroundColor Cyan

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.WorkingDirectory = $WorkDir
    if ($UserDataDir) {
        $psi.Arguments = "--user-data-dir=`"$UserDataDir`""
    }
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    $rootPid = $proc.Id

    # Wait for window title "Xiaomi MiMo"
    $ready = $false
    while (-not $ready -and $sw.ElapsedMilliseconds -lt 60000) {
        Start-Sleep -Milliseconds 200
        $proc.Refresh()
        if ($proc.MainWindowTitle -eq "Xiaomi MiMo") {
            $ready = $true
        }
    }
    $sw.Stop()
    $toWindowMs = $sw.ElapsedMilliseconds

    if (-not $ready) {
        Write-Host "  FAIL: window not ready in 60s" -ForegroundColor Red
        Stop-Process -Id $rootPid -Force -ErrorAction SilentlyContinue
        return $null
    }

    # Wait for startup to settle, then measure RSS
    Start-Sleep -Seconds $IdleSeconds

    # Collect process tree (match by path prefix of exe)
    $exeDir = Split-Path $ExePath -Parent
    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    $totalRss = [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1)
    $count = $procs.Count

    Write-Host "  Time to window : $toWindowMs ms"
    Write-Host "  Total RSS      : $totalRss MB ($count processes)"

    # Kill cleanly (wait up to 5s for graceful, then force)
    foreach ($p in $procs) {
        $p.CloseMainWindow() | Out-Null
    }
    Start-Sleep -Seconds 2
    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    foreach ($p in $procs) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1

    return @{
        Label     = $Label
        ToWindowMs = $toWindowMs
        RssMB     = $totalRss
        ProcCount = $count
    }
}

# Preflight: ensure no MiMo is running
$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "ERROR: Xiaomi MiMo is still running ($($running.Count) processes)." -ForegroundColor Red
    Write-Host "Please close ALL MiMo instances first, then re-run this script."
    exit 1
}

Write-Host "MiMo ARM64 vs x64 Cold-Start Benchmark" -ForegroundColor Yellow
Write-Host "Runs per side: $Runs   Idle: ${IdleSeconds}s"
Write-Host "User profile : $realUd"

$results = @{ "ARM64" = @(); "x64" = @() }

for ($i = 1; $i -le $Runs; $i++) {
    Write-Host ""
    Write-Host "--- Run $i / $Runs ---" -ForegroundColor Yellow

    # Alternate order to cancel thermal / cache bias
    if ($i % 2 -eq 1) {
        $r = Measure-Startup -Label "ARM64 run $i" -ExePath $arm64Exe -WorkDir (Split-Path $arm64Exe -Parent) -UserDataDir $realUd
        if ($r) { $results["ARM64"] += $r }

        $r = Measure-Startup -Label "x64 run $i" -ExePath $x64Exe -WorkDir (Split-Path $x64Exe -Parent) -UserDataDir $realUd
        if ($r) { $results["x64"] += $r }
    } else {
        $r = Measure-Startup -Label "x64 run $i" -ExePath $x64Exe -WorkDir (Split-Path $x64Exe -Parent) -UserDataDir $realUd
        if ($r) { $results["x64"] += $r }

        $r = Measure-Startup -Label "ARM64 run $i" -ExePath $arm64Exe -WorkDir (Split-Path $arm64Exe -Parent) -UserDataDir $realUd
        if ($r) { $results["ARM64"] += $r }
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "           SUMMARY (averages)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

foreach ($side in @("ARM64", "x64")) {
    $list = $results[$side]
    if ($list.Count -eq 0) { continue }
    $avgMs  = [math]::Round(($list | Measure-Object ToWindowMs -Average).Average)
    $avgRss = [math]::Round(($list | Measure-Object RssMB -Average).Average, 1)
    Write-Host ("{0,-8}  {1,6} ms   {2,8} MB   ({3} runs)" -f $side, $avgMs, $avgRss, $list.Count)
}

$armAvg = ($results["ARM64"] | Measure-Object ToWindowMs -Average).Average
$x64Avg = ($results["x64"]   | Measure-Object ToWindowMs -Average).Average
if ($armAvg -and $x64Avg) {
    $speedup = [math]::Round($x64Avg / $armAvg, 2)
    Write-Host ""
    Write-Host "Speedup: ARM64 is ${speedup}x faster than x64 emulation" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo."

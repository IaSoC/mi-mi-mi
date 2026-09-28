# Capture Chromium startup trace from t=0 (covers the CDP blind window).
# Uses --trace-startup so V8/timeline events exist before DevTools attaches.
#
# NOTE: ASCII-only (no BOM).
#
# Usage (close ALL MiMo first):
#   powershell -ExecutionPolicy Bypass -File bench-trace.ps1
#   powershell -ExecutionPolicy Bypass -File bench-trace.ps1 -Side ARM64
#   powershell -ExecutionPolicy Bypass -File bench-trace.ps1 -Side Both
#
# Output:
#   scripts/bench-output/trace-<Side>-<stamp>/startup-trace.json
#   scripts/bench-output/trace-<Side>-<stamp>/stages.txt
#   scripts/bench-output/trace-<Side>-<stamp>/trace-summary.txt
#
# Then: analyze with scripts/analyze-startup-trace.py

param(
    [ValidateSet("ARM64", "x64", "Both")]
    [string]$Side = "Both",

    [int]$MaxWaitMs = 60000,
    [int]$DebugPort = 9334,
    [int]$TraceSeconds = 25
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

function Measure-Trace {
    param([string]$Label, [string]$ExePath)

    Write-Host ""
    Write-Host "=== TRACE $Label ===" -ForegroundColor Cyan

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outDir = Join-Path $outRoot "trace-$Label-$stamp"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $codeCache = Join-Path $realUd "Code Cache"
    if (Test-Path $codeCache) {
        Remove-Item $codeCache -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $codeCache | Out-Null
    }

    $exeDir = Split-Path $ExePath -Parent
    $tracePath = Join-Path $outDir "startup-trace.json"
    $stagesPath = Join-Path $outDir "stages.txt"
    $stderrPath = Join-Path $outDir "stderr.log"

    # Chromium --trace-startup. NO nested quotes: categories have no spaces.
    # Use a simple absolute path for the output file.
    $traceFile = [System.IO.Path]::GetFullPath($tracePath)
    $cats = "devtools.timeline,v8,disabled-by-default-v8.cpu_profiler,blink.user_timing,loading"
    $traceArgs = "--enable-logging=stderr"
    $traceArgs += " --remote-debugging-port=$DebugPort"
    $traceArgs += " --trace-startup=$cats"
    $traceArgs += " --trace-startup-file=$traceFile"
    $traceArgs += " --trace-startup-duration=$TraceSeconds"

    Write-Host "  trace file: $traceFile"
    Write-Host "  args: $traceArgs"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.WorkingDirectory = $outDir
    $psi.Arguments = $traceArgs
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

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host "  launching with --trace-startup ($TraceSeconds s) ..."
    $proc = [System.Diagnostics.Process]::Start($psi)

    # Stage markers via CDP probe (optional; may miss early)
    $probePsi = New-Object System.Diagnostics.ProcessStartInfo
    $probePsi.FileName = $nodeExe
    $probePsi.Arguments = "`"$probeJs`" --port $DebugPort --timeout $MaxWaitMs"
    $probePsi.UseShellExecute = $false
    $probePsi.RedirectStandardOutput = $true
    $probePsi.RedirectStandardError = $true
    $probePsi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $probe = [System.Diagnostics.Process]::Start($probePsi)
    $probeOutTask = $probe.StandardOutput.ReadLineAsync()
    $stderrTask = $proc.StandardError.ReadLineAsync()

    # DO NOT kill before trace-startup-duration elapses, or the file never flushes.
    $deadlineMs = ($TraceSeconds + 8) * 1000
    if ($deadlineMs -gt $MaxWaitMs) { $deadlineMs = $MaxWaitMs }

    while (-not $proc.HasExited -and $sw.ElapsedMilliseconds -lt $deadlineMs) {
        Start-Sleep -Milliseconds 100

        while ($stderrTask.IsCompleted -and $null -ne $stderrTask.Result) {
            $line = $stderrTask.Result
            $ts = $sw.ElapsedMilliseconds
            Add-Content -Path $stderrPath -Value "[$ts] $line" -Encoding UTF8
            $stderrTask = $proc.StandardError.ReadLineAsync()
        }

        while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
            $raw = $probeOutTask.Result
            try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
            if ($evt) {
                $ename = "$($evt.event)"
                if ($ename -in @('connected','startup-loader','sidebar-chrome','main-ui','interactive','list-ready','done')) {
                    $rec = "{0}  {1}  {2}" -f $sw.ElapsedMilliseconds, $ename, "$($evt.detail)"
                    Add-Content -Path $stagesPath -Value $rec -Encoding UTF8
                    Write-Host "  [+] $rec"
                }
            }
            $probeOutTask = $probe.StandardOutput.ReadLineAsync()
        }

        # status
        if (($sw.ElapsedMilliseconds % 5000) -lt 120) {
            Write-Host "  [.] waiting for trace flush @ $($sw.ElapsedMilliseconds) ms"
        }
    }

    try { if (-not $probe.HasExited) { $probe.Kill() } } catch {}

    # Wait for natural exit so Chromium can write the trace
    $wait = [Diagnostics.Stopwatch]::StartNew()
    while (-not $proc.HasExited -and $wait.ElapsedMilliseconds -lt 15000) {
        Start-Sleep -Milliseconds 250
    }

    # Poll for the trace file even after the process exits (flush can be late)
    $fileWait = [Diagnostics.Stopwatch]::StartNew()
    while ($fileWait.ElapsedMilliseconds -lt 15000 -and -not (Test-Path $tracePath)) {
        Start-Sleep -Milliseconds 400
    }

    if (-not $proc.HasExited) {
        Write-Host "  killing app after wait (trace may be incomplete)" -ForegroundColor Yellow
        try { $proc.Kill() } catch {}
        Start-Sleep -Milliseconds 1500
        $fileWait2 = [Diagnostics.Stopwatch]::StartNew()
        while ($fileWait2.ElapsedMilliseconds -lt 8000 -and -not (Test-Path $tracePath)) {
            Start-Sleep -Milliseconds 400
        }
    }

    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }

    # Discover whatever Chromium wrote
    Write-Host "  scanning for trace artifacts..."
    $searchDirs = @($outDir, $exeDir, $env:TEMP, $realUd)
    foreach ($sd in $searchDirs) {
        if (-not (Test-Path $sd)) { continue }
        Get-ChildItem $sd -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) -and ($_.Name -match 'trace' -or $_.Extension -eq '.json' -or $_.Extension -eq '.json.gz') -and $_.Length -gt 500 } |
            Select-Object -First 12 |
            ForEach-Object { Write-Host "  found: $($_.FullName) ($($_.Length))" }
    }

    if (Test-Path $tracePath) {
        $kb = [math]::Round((Get-Item $tracePath).Length / 1KB, 1)
        Write-Host "  TRACE OK -> $tracePath ($kb KB)" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: $tracePath not written. Dump outDir:" -ForegroundColor Yellow
        Get-ChildItem $outDir -Force | Select-Object Name, Length
    }

    Write-Host "  saved -> $outDir" -ForegroundColor Yellow
    return $outDir
}

$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "ERROR: Xiaomi MiMo is still running ($($running.Count) procs)." -ForegroundColor Red
    Write-Host "Close ALL MiMo first:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor Cyan
    exit 1
}

Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue

Write-Host "MiMo Chromium startup trace (covers 0-6s blind window)" -ForegroundColor Yellow
Write-Host "  Side: $Side   TraceSeconds: $TraceSeconds"

$sides = @()
if ($Side -eq "Both") { $sides = @("ARM64", "x64") } else { $sides = @($Side) }

foreach ($s in $sides) {
    $exe = if ($s -eq "ARM64") { $arm64Exe } else { $x64Exe }
    if (-not (Test-Path $exe)) {
        Write-Host "SKIP $s - exe not found" -ForegroundColor Yellow
        continue
    }
    [void](Measure-Trace -Label $s -ExePath $exe)

    # Cooldown so the next side does not hit single-instance / file locks
    Write-Host "  cooldown 5s before next side..."
    Start-Sleep -Seconds 5
    $leftover = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
    if ($leftover) {
        Write-Host "  waiting for $($leftover.Count) leftover procs to die..."
        $leftover | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
}

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo." -ForegroundColor Green
Write-Host "Analyze:  & `$env:MIMO_PYTHON scripts\analyze-startup-trace.py"

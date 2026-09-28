# CPU profile during startup - drill into B (Logo -> sidebar / main bundle).
# Electron V8 rejects --cpu-prof, so use CDP Profiler domain via cdp-cpuprofile.mjs.
#
# NOTE: ASCII-only (no BOM). PS 5.1 breaks on UTF-8 Chinese in strings.
#
# Usage (close ALL MiMo first):
#   powershell -ExecutionPolicy Bypass -File bench-cpuprofile.ps1
#   powershell -ExecutionPolicy Bypass -File bench-cpuprofile.ps1 -Side x64
#   powershell -ExecutionPolicy Bypass -File bench-cpuprofile.ps1 -Side Both
#
# Output per side:
#   scripts/bench-output/cpuprof-<Side>-<stamp>/startup.cpuprofile
#   scripts/bench-output/cpuprof-<Side>-<stamp>/stages.txt
#   scripts/bench-output/cpuprof-<Side>-<stamp>/stderr.log
#
# How to read:
#   Chrome DevTools -> Performance -> Load profile -> startup.cpuprofile
#   Or https://www.speedscope.app (offline-capable)
#   Focus the Logo -> sidebar window (see stages.txt).

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
$profJs   = Join-Path $PSScriptRoot "cdp-cpuprofile.mjs"
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
if (-not (Test-Path $profJs)) { Write-Host "ERROR: missing $profJs" -ForegroundColor Red; exit 1 }

function Measure-Profile {
    param([string]$Label, [string]$ExePath)

    Write-Host ""
    Write-Host "=== CDP CPU PROF $Label ===" -ForegroundColor Cyan

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outDir = Join-Path $outRoot "cpuprof-$Label-$stamp"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $codeCache = Join-Path $realUd "Code Cache"
    if (Test-Path $codeCache) {
        Remove-Item $codeCache -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $codeCache | Out-Null
    }

    $exeDir = Split-Path $ExePath -Parent
    $profPath = Join-Path $outDir "startup.cpuprofile"
    $stagesPath = Join-Path $outDir "stages.txt"
    $stderrPath = Join-Path $outDir "stderr.log"

    # No --js-flags: Electron V8 rejects --cpu-prof.
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

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)
    Write-Host "  launched, CDP Profiler will attach..."

    # Stage marker probe (lightweight milestones)
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

    # CPU profiler (stops itself at list-ready)
    $profLog = Join-Path $outDir "profiler-console.log"
    $profPsi = New-Object System.Diagnostics.ProcessStartInfo
    $profPsi.FileName = $nodeExe
    $profPsi.Arguments = "`"$profJs`" --port $DebugPort --out `"$profPath`" --timeout $MaxWaitMs"
    $profPsi.UseShellExecute = $false
    $profPsi.RedirectStandardOutput = $true
    $profPsi.RedirectStandardError = $true
    $profPsi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $profiler = [System.Diagnostics.Process]::Start($profPsi)
    $profOutTask = $profiler.StandardOutput.ReadLineAsync()
    $profErrTask = $profiler.StandardError.ReadLineAsync()

    while (-not $proc.HasExited -and $sw.ElapsedMilliseconds -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds 80

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
                if ($ename -in @('startup-loader','sidebar-chrome','main-ui','interactive','list-ready','done')) {
                    $rec = "{0}  {1}  {2}" -f $sw.ElapsedMilliseconds, $ename, "$($evt.detail)"
                    Add-Content -Path $stagesPath -Value $rec -Encoding UTF8
                    Write-Host "  [+] $rec"
                }
            }
            $probeOutTask = $probe.StandardOutput.ReadLineAsync()
        }

        while ($profOutTask.IsCompleted -and $null -ne $profOutTask.Result) {
            $praw = $profOutTask.Result
            if ($praw) {
                Add-Content -Path $profLog -Value $praw -Encoding UTF8
                Write-Host "  [prof] $praw"
            }
            $profOutTask = $profiler.StandardOutput.ReadLineAsync()
        }

        while ($profErrTask.IsCompleted -and $null -ne $profErrTask.Result) {
            $eline = $profErrTask.Result
            if ($eline) {
                Add-Content -Path $profLog -Value "ERR $eline" -Encoding UTF8
                Write-Host "  [prof-err] $eline" -ForegroundColor Yellow
            }
            $profErrTask = $profiler.StandardError.ReadLineAsync()
        }

        # exit when profiler finished (it writes the file before exit)
        if ($profiler.HasExited) {
            Start-Sleep -Milliseconds 300
            break
        }
        if ($proc.HasExited -and $sw.ElapsedMilliseconds -gt 15000) {
            # app closed; give profiler a moment to flush
            Start-Sleep -Milliseconds 2000
            break
        }
    }

    # drain profiler output, wait up to 3s for natural exit
    $waitUntil = [Diagnostics.Stopwatch]::StartNew()
    while (-not $profiler.HasExited -and $waitUntil.ElapsedMilliseconds -lt 3000) {
        Start-Sleep -Milliseconds 100
        while ($profOutTask.IsCompleted -and $null -ne $profOutTask.Result) {
            $praw = $profOutTask.Result
            if ($praw) {
                Add-Content -Path $profLog -Value $praw -Encoding UTF8
                Write-Host "  [prof] $praw"
            }
            $profOutTask = $profiler.StandardOutput.ReadLineAsync()
        }
    }

    try { if (-not $probe.HasExited) { $probe.Kill() } } catch {}
    try { if (-not $profiler.HasExited) { $profiler.Kill() } } catch {}

    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1

    if (Test-Path $profPath) {
        $kb = [math]::Round((Get-Item $profPath).Length / 1KB, 1)
        Write-Host "  PROFILE OK -> $profPath ($kb KB)" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: $profPath not written" -ForegroundColor Yellow
        Get-ChildItem $outDir -ErrorAction SilentlyContinue | Select-Object Name, Length
        if (Test-Path $profLog) {
            Write-Host "  --- profiler-console.log ---"
            Get-Content $profLog | Select-Object -Last 30
        }
    }

    Write-Host "  saved -> $outDir" -ForegroundColor Yellow
    return $outDir
}

$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "ERROR: Xiaomi MiMo is still running ($($running.Count) procs)." -ForegroundColor Red
    Write-Host "Close ALL MiMo first, then:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor Cyan
    exit 1
}

Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue

Write-Host "MiMo CDP CPU Profile (Logo->sidebar / main bundle)" -ForegroundColor Yellow
Write-Host "  Side: $Side   Profiler: $profJs"

$sides = @()
if ($Side -eq "Both") { $sides = @("ARM64", "x64") } else { $sides = @($Side) }

foreach ($s in $sides) {
    $exe = if ($s -eq "ARM64") { $arm64Exe } else { $x64Exe }
    if (-not (Test-Path $exe)) {
        Write-Host "SKIP $s - exe not found" -ForegroundColor Yellow
        continue
    }
    [void](Measure-Profile -Label $s -ExePath $exe)
}

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo." -ForegroundColor Green
Write-Host "Load startup.cpuprofile in Chrome DevTools -> Performance -> Load profile"
Write-Host "Or open https://www.speedscope.app and drop the file."

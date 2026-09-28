# Fine-grained call-level startup observation.
# Finds whether ONE single call is stuck (Network / Resource / engine substeps).
#
# NOTE: Keep this .ps1 ASCII-only (no BOM). PS 5.1 mis-reads UTF-8 Chinese.
#
# Usage (close ALL MiMo first):
#   powershell -ExecutionPolicy Bypass -File bench-deep.ps1
#   powershell -ExecutionPolicy Bypass -File bench-deep.ps1 -Side x64
#   powershell -ExecutionPolicy Bypass -File bench-deep.ps1 -Side Both
#
# Output per side:
#   scripts/bench-output/deep-<Side>-<stamp>/network.ndjson
#   scripts/bench-output/deep-<Side>-<stamp>/engine.log
#   scripts/bench-output/deep-<Side>-<stamp>/stuck-report.md

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
$appLogDir = Join-Path $realUd "logs"
$probeJs  = Join-Path $PSScriptRoot "cdp-deep-probe.mjs"
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

function Measure-Deep {
    param([string]$Label, [string]$ExePath)

    Write-Host ""
    Write-Host "=== DEEP $Label ===" -ForegroundColor Cyan

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outDir = Join-Path $outRoot "deep-$Label-$stamp"
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

    $netPath = Join-Path $outDir "network.ndjson"
    $enginePath = Join-Path $outDir "engine.log"
    $stderrPath = Join-Path $outDir "stderr.log"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)

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

    $engineLines = New-Object System.Collections.ArrayList
    $netDone = $null
    $lastNetLog = 0

    while (-not $proc.HasExited -and $sw.ElapsedMilliseconds -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds 80

        while ($stderrTask.IsCompleted -and $null -ne $stderrTask.Result) {
            $line = $stderrTask.Result
            $ts = $sw.ElapsedMilliseconds
            Add-Content -Path $stderrPath -Value "[$ts] $line" -Encoding UTF8

            if ($line -match 'loadEngineSessions|engine in-process|repoRoots|sess-diag') {
                $rec = "[{0}] {1}" -f $ts, $line
                [void]$engineLines.Add($rec)
                Add-Content -Path $enginePath -Value $rec -Encoding UTF8
                Write-Host "  [eng $ts] $line"
            }
            $stderrTask = $proc.StandardError.ReadLineAsync()
        }

        while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
            $raw = $probeOutTask.Result
            try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
            if ($evt) {
                $ename = "$($evt.event)"
                if ($ename -eq 'done') {
                    $netDone = $evt
                    Write-Host "  [+] probe done  netCount=$($evt.netCount)"
                }
                elseif ($ename -eq 'error') {
                    Write-Host "  [!] probe error $($evt.message)" -ForegroundColor Yellow
                }
                else {
                    Add-Content -Path $netPath -Value $raw -Encoding UTF8
                    if ($ename -eq 'net') {
                        $d = $evt.durationMs
                        if ($d -ge 200) {
                            Write-Host ("  [net {0}ms] {1} {2}" -f $d, $evt.status, $evt.url)
                        }
                    }
                    if ($ename -eq 'longtask') {
                        Write-Host ("  [longtask {0}ms] pageStart={1}" -f $evt.durationMs, $evt.pageStartMs)
                    }
                }
            }
            $probeOutTask = $probe.StandardOutput.ReadLineAsync()
        }

        while ($probeErrTask.IsCompleted -and $null -ne $probeErrTask.Result) {
            $probeErrTask = $probe.StandardError.ReadLineAsync()
        }

        if ($netDone -and $engineLines.Count -gt 0) {
            Start-Sleep -Milliseconds 500
            break
        }
        if ($netDone -and $sw.ElapsedMilliseconds -gt 35000) {
            break
        }
    }

    try { if (-not $probe.HasExited) { $probe.Kill() } } catch {}

    # drain probe
    try {
        while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
            $raw = $probeOutTask.Result
            if ($raw) { Add-Content -Path $netPath -Value $raw -Encoding UTF8 }
            $probeOutTask = $probe.StandardOutput.ReadLineAsync()
        }
    } catch {}

    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$exeDir*" }
    foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1

    # Parse engine substeps
    $engFetch = $null; $engRepo = $null; $engBuild = $null; $engTotal = $null
    foreach ($ln in $engineLines) {
        if ($ln -match 'fetch\s*=\s*(\d+).*repoRoots\s*=\s*(\d+).*build\+reconcile\s*=\s*(\d+).*total\s*=\s*(\d+)') {
            $engFetch = [int]$matches[1]
            $engRepo = [int]$matches[2]
            $engBuild = [int]$matches[3]
            $engTotal = [int]$matches[4]
        }
    }

    # Top network from netDone
    $top = @()
    if ($netDone -and $netDone.topN) {
        $top = @($netDone.topN)
    }

    $slowest = $null
    if ($top.Count -gt 0) { $slowest = $top[0] }

    $md = @"
# Stuck-call report - $Label

- stamp: $stamp
- exe: $ExePath

## Engine substeps (from app log)

| field | ms |
|------|---:|
| fetch | $engFetch |
| repoRoots | $engRepo |
| build+reconcile | $engBuild |
| total | $engTotal |

## Slowest network calls (CDP Network)

| rank | durationMs | status | url |
|-----:|----------:|-------:|-----|
"@

    $rank = 1
    foreach ($t in $top) {
        $md += "| $rank | $($t.durationMs) | $($t.status) | $($t.url) |`n"
        $rank++
    }

    $md += @"

## Verdict hints

- If engFetch is large and repoRoots/build are small -> ONE HTTP call is stuck (engine IPC).
- If one net row dominates (durationMs >> others) -> that URL is the stuck call.
- Longtasks > 500ms mean JS main-thread block (bundle eval / sync require).
- Engine log:
"@

    foreach ($ln in $engineLines) {
        $md += "- ``$ln```n"
    }

    $mdPath = Join-Path $outDir "stuck-report.md"
    Set-Content -Path $mdPath -Value $md -Encoding UTF8

    Write-Host ""
    Write-Host "  saved -> $outDir" -ForegroundColor Yellow
    if ($slowest) {
        Write-Host "  slowest net: $($slowest.durationMs)ms  $($slowest.url)" -ForegroundColor Yellow
    }
    Write-Host "  engine fetch=$engFetch repo=$engRepo build=$engBuild total=$engTotal"

    return [PSCustomObject]@{
        Label = $Label
        OutDir = $outDir
        EngFetch = $engFetch
        EngRepo = $engRepo
        EngBuild = $engBuild
        EngTotal = $engTotal
        Slowest = $slowest
    }
}

$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "ERROR: Xiaomi MiMo is still running ($($running.Count) procs)." -ForegroundColor Red
    Write-Host "Close ALL MiMo instances first, then re-run:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor Cyan
    exit 1
}

Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue

Write-Host "MiMo Deep Call-level Startup Observation" -ForegroundColor Yellow
Write-Host "  Side: $Side   Probe: $probeJs"

$sides = @()
if ($Side -eq "Both") { $sides = @("ARM64", "x64") } else { $sides = @($Side) }

$all = @()
foreach ($s in $sides) {
    $exe = if ($s -eq "ARM64") { $arm64Exe } else { $x64Exe }
    if (-not (Test-Path $exe)) {
        Write-Host "SKIP $s - exe not found: $exe" -ForegroundColor Yellow
        continue
    }
    $r = Measure-Deep -Label $s -ExePath $exe
    $all += ,$r
}

Write-Host ""
Write-Host "Done. Safe to relaunch MiMo." -ForegroundColor Green
if ($all.Count -eq 2) {
    Write-Host ""
    Write-Host "Compare engine fetch (the suspect single call):" -ForegroundColor Yellow
    Write-Host ("  ARM64 fetch={0}ms  x64 fetch={1}ms  ratio={2}" -f `
        $all[0].EngFetch, $all[1].EngFetch,
        $(if ($all[0].EngFetch -gt 0) { [math]::Round($all[1].EngFetch / $all[0].EngFetch, 2) } else { 'n/a' }))
}

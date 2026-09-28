# MiMo Startup Diagnostic Runner (CDP milestones)
# Launches ONE MiMo version, collects telemetry,
# and waits for the user to manually close it. No auto-kill.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File bench-run.ps1 -Side ARM64
#   powershell -ExecutionPolicy Bypass -File bench-run.ps1 -Side x64
#
# Detection map:
#   T0 main-ui     : CDP slogan visible
#   T1 list-ready  : CDP project rows stable + recent section
#   mainToList     : T1 - T0  (PRIMARY)
#   window-title / engine-sessions / RSS : diagnostic

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("ARM64", "x64")]
    [string]$Side,

    [int]$SampleIntervalMs = 2000,
    [int]$DebugPort = 9333
)

$ErrorActionPreference = "Stop"

$arm64Exe = "C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\output\Xiaomi MiMo ARM64\Xiaomi MiMo.exe"
$x64Exe   = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo\Xiaomi MiMo.exe"
$realUd   = Join-Path $env:APPDATA "Xiaomi MiMo"
$appLogDir = Join-Path $realUd "logs"
$outRoot  = "C:\Users\xiaomi\XiaomiMiMoProjects\electron-arm64-port\scripts\bench-output"
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
if (-not $nodeExe) {
    Write-Host "ERROR: node.exe not found. Install Node or set MIMO_NODE." -ForegroundColor Red
    exit 1
}

$exePath = if ($Side -eq "ARM64") { $arm64Exe } else { $x64Exe }
$exeDir  = Split-Path $exePath -Parent
$stamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir  = Join-Path $outRoot "$Side-$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "MiMo Startup Diagnostic Runner (CDP)" -ForegroundColor Yellow
Write-Host "  Side     : $Side"
Write-Host "  Exe      : $exePath"
Write-Host "  Output   : $outDir"
Write-Host "  Probe    : $probeJs"
Write-Host ""

$running = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "WARNING: Xiaomi MiMo is already running ($($running.Count) processes)." -ForegroundColor Red
    Write-Host "Close ALL instances first, or the new instance may hit single-instance lock."
    Write-Host "Press Enter to continue anyway, or Ctrl+C to abort..."
    Read-Host | Out-Null
}

$logFilesBefore = @()
if (Test-Path $appLogDir) {
    $logFilesBefore = @(Get-ChildItem $appLogDir -Filter "*.log" -ErrorAction SilentlyContinue)
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.WorkingDirectory = $exeDir
$psi.Arguments = "--enable-logging=stderr --remote-debugging-port=$DebugPort"
$psi.UseShellExecute = $false
$psi.RedirectStandardError = $true
$psi.RedirectStandardOutput = $true
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

if ($Side -eq "ARM64") {
    $nativeLib = Join-Path $exeDir "resources\native\skia.win32-arm64-msvc.node"
    if (Test-Path $nativeLib) {
        $psi.EnvironmentVariables["NAPI_RS_NATIVE_LIBRARY_PATH"] = $nativeLib
        Write-Host "  NAPI_RS_NATIVE_LIBRARY_PATH = $nativeLib"
    }
}

$stderrFile = Join-Path $outDir "stderr.log"
$stdoutFile = Join-Path $outDir "stdout.log"
$milestoneFile = Join-Path $outDir "milestones.txt"
$statsFile = Join-Path $outDir "process-stats.csv"
$probeLog = Join-Path $outDir "cdp-probe.log"

$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Launching... (close MiMo manually when done)" -ForegroundColor Cyan
$proc = [System.Diagnostics.Process]::Start($psi)

$stderrWriter = [System.IO.StreamWriter]::new($stderrFile, $false, [System.Text.Encoding]::UTF8)
$stdoutWriter = [System.IO.StreamWriter]::new($stdoutFile, $false, [System.Text.Encoding]::UTF8)
$mileWriter   = [System.IO.StreamWriter]::new($milestoneFile, $false, [System.Text.Encoding]::UTF8)
$statsWriter  = [System.IO.StreamWriter]::new($statsFile, $false, [System.Text.Encoding]::UTF8)
$probeWriter  = [System.IO.StreamWriter]::new($probeLog, $false, [System.Text.Encoding]::UTF8)
$statsWriter.WriteLine("TimestampMs,RSS_MB,HandleCount,CPU_s,ProcCount")

$milestones = [ordered]@{}
$stderrTask = $proc.StandardError.ReadLineAsync()
$stdoutTask = $proc.StandardOutput.ReadLineAsync()

# CDP probe
$probePsi = New-Object System.Diagnostics.ProcessStartInfo
$probePsi.FileName = $nodeExe
$probePsi.Arguments = "`"$probeJs`" --port $DebugPort --timeout 120000"
$probePsi.UseShellExecute = $false
$probePsi.RedirectStandardOutput = $true
$probePsi.RedirectStandardError = $true
$probePsi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$probe = [System.Diagnostics.Process]::Start($probePsi)
$probeOutTask = $probe.StandardOutput.ReadLineAsync()
$probeErrTask = $probe.StandardError.ReadLineAsync()

function Write-Milestone {
    param([string]$Name, [string]$Detail = "")
    $ts = $sw.ElapsedMilliseconds
    $line = "[${ts}ms] $Name $(if($Detail){"$Detail"})"
    $script:mileWriter.WriteLine($line)
    $script:mileWriter.Flush()
    Write-Host "  [+] $line" -ForegroundColor Green
    $script:milestones[$Name] = $ts
}

function Write-Stats {
    $procs = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$script:exeDir*" }
    if (-not $procs) { return }
    $rss = [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1)
    $handles = ($procs | Measure-Object HandleCount -Sum).Sum
    $cpu = [math]::Round((($procs | Measure-Object CPU -Sum).Sum), 1)
    $ts = $sw.ElapsedMilliseconds
    $script:statsWriter.WriteLine("$ts,$rss,$handles,$cpu,$($procs.Count)")
    $script:statsWriter.Flush()
}

Write-Host ""
Write-Host "Collecting... (process will run until you close it)" -ForegroundColor Yellow
Write-Host "  stderr -> $stderrFile"
Write-Host "  probe  -> $probeLog"
Write-Host "  stats  -> $statsFile"
Write-Host ""

$lastStatMs = 0

while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 200

    # App stderr (diagnostic)
    while ($stderrTask.IsCompleted -and $null -ne $stderrTask.Result) {
        $line = $stderrTask.Result
        $ts = $sw.ElapsedMilliseconds
        $stderrWriter.WriteLine("[$ts] $line")
        $stderrWriter.Flush()

        if ($line -match 'loadEngineSessions.*total\s*=\s*(\d+)' -and -not $milestones['engine-sessions']) {
            Write-Milestone "engine-sessions" "loadEngineSessions total=$($matches[1])ms [diagnostic]"
        }
        if ($line -match 'engine in-process server ready' -and -not $milestones['engine-ready']) {
            Write-Milestone "engine-ready" $line.Trim()
        }
        $stderrTask = $proc.StandardError.ReadLineAsync()
    }

    while ($stdoutTask.IsCompleted -and $null -ne $stdoutTask.Result) {
        $line = $stdoutTask.Result
        $ts = $sw.ElapsedMilliseconds
        $stdoutWriter.WriteLine("[$ts] $line")
        $stdoutWriter.Flush()
        $stdoutTask = $proc.StandardOutput.ReadLineAsync()
    }

    # CDP probe
    while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
        $raw = $probeOutTask.Result
        $probeWriter.WriteLine($raw)
        $probeWriter.Flush()
        try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
        if ($evt) {
            switch ($evt.event) {
                'connected' { Write-Milestone "cdp-connected" $evt.ws }
                'startup-loader' { Write-Milestone "startup-loader" "logo splash $($evt.detail)" }
                'main-ui'   { Write-Milestone "main-ui" "T0 slogan visible $($evt.detail)" }
                'list-ready'{ Write-Milestone "list-ready" "T1 project rows stable $($evt.detail)" }
                'done' {
                    Write-Milestone "probe-done" "T0=$($evt.mainUiMs) T1=$($evt.listMs) mainToList=$($evt.mainToListMs)ms"
                }
                'probe-debug' {
                    Write-Host "  [.] probe-debug: $($evt.detail)"
                }
                'error' {
                    $line = "[ms] probe error $($evt.message)"
                    $mileWriter.WriteLine($line); $mileWriter.Flush()
                    Write-Host "  [!] probe error: $($evt.message)" -ForegroundColor Yellow
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
        if (-not $milestones['window-title'] -and $proc.MainWindowTitle -eq "Xiaomi MiMo") {
            Write-Milestone "window-title" "MainWindowTitle = 'Xiaomi MiMo' [diagnostic]"
        }
    } catch {}

    $now = $sw.ElapsedMilliseconds
    if ($now - $lastStatMs -ge $SampleIntervalMs) {
        Write-Stats
        $lastStatMs = $now
    }
}

Write-Host ""
Write-Host "Process exited (code $($proc.ExitCode))" -ForegroundColor Yellow

# final probe drain
try {
    while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
        $raw = $probeOutTask.Result
        $probeWriter.WriteLine($raw)
        $probeWriter.Flush()
        try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
        if ($evt) {
            if ($evt.event -eq 'startup-loader' -and -not $milestones['startup-loader']) {
                Write-Milestone "startup-loader" "logo splash late $($evt.detail)"
            }
            if ($evt.event -eq 'main-ui' -and -not $milestones['main-ui']) {
                Write-Milestone "main-ui" "T0 late $($evt.detail)"
            }
            if ($evt.event -eq 'list-ready' -and -not $milestones['list-ready']) {
                Write-Milestone "list-ready" "T1 late $($evt.detail)"
            }
            if ($evt.event -eq 'done') {
                Write-Milestone "probe-done" "T0=$($evt.mainUiMs) T1=$($evt.listMs) mainToList=$($evt.mainToListMs)ms"
            }
        }
        $probeOutTask = $probe.StandardOutput.ReadLineAsync()
    }
} catch {}

try { if (-not $probe.HasExited) { $probe.Kill() } } catch {}

Write-Stats

$stderrWriter.Close()
$stdoutWriter.Close()
$statsWriter.Close()
$mileWriter.Close()
$probeWriter.Close()

Start-Sleep -Seconds 2

$appLogSnap = Join-Path $outDir "app-log-snapshot"
New-Item -ItemType Directory -Force -Path $appLogSnap | Out-Null
if (Test-Path $appLogDir) {
    $logFilesAfter = @(Get-ChildItem $appLogDir -Filter "*.log" -ErrorAction SilentlyContinue)
    foreach ($f in $logFilesAfter) { Copy-Item $f.FullName $appLogSnap -Force }
}

$codeCache = Join-Path $realUd "Code Cache"
$ccSize = if (Test-Path $codeCache) {
    [math]::Round(((Get-ChildItem $codeCache -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 1)
} else { 0 }

$mainToList = $null
if ($milestones['main-ui'] -and $milestones['list-ready']) {
    $mainToList = $milestones['list-ready'] - $milestones['main-ui']
}

$summaryFile = Join-Path $outDir "summary.txt"
$summary = @"
MiMo Startup Diagnostic - $Side (CDP)
=====================================
Timestamp   : $stamp
Exe         : $exePath
Exit code   : $($proc.ExitCode)
Total time  : $($sw.ElapsedMilliseconds) ms
Code Cache  : $ccSize MB at exit

PRIMARY mainToList : $mainToList ms
  1 window-title   = $($milestones['window-title']) ms
  2 startup-loader = $($milestones['startup-loader']) ms   (logo splash)
  3 T0 main-ui     = $($milestones['main-ui']) ms   (slogan visible)
  4 T1 list-ready  = $($milestones['list-ready']) ms   (project rows stable)

Milestones (host clock):
"@
foreach ($k in $milestones.Keys) {
    if ($k -like '_*') { continue }
    $summary += "  $($k) : $($milestones[$k]) ms`n"
}
$summary += "`nOutput files:`n  stderr.log`n  stdout.log`n  cdp-probe.log`n  process-stats.csv`n  milestones.txt`n  app-log-snapshot\`n"

Set-Content -Path $summaryFile -Value $summary -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  RESULTS saved to: $outDir" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host $summary

$remaining = Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$exeDir*" }
if ($remaining) {
    Write-Host "Cleaning up $($remaining.Count) remaining processes..." -ForegroundColor Yellow
    foreach ($p in $remaining) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}

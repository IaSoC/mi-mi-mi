# Drop-in acceptance test (T2 + T3).
#
# Simulates what a downloader does: take the skeleton, copy in the OFFICIAL
# payload, patch the asar, boot it, and prove the app reaches a usable state.
#
# IMPORTANT: close ALL Xiaomi MiMo instances before running this script.
#   powershell -ExecutionPolicy Bypass -File scripts\test-dropin.ps1
#
# T2 steps:
#   1  materialize runtime (skeleton zip -> extract, or stage from output\)
#   2  copy payload from the official install (NOT app.asar.unpacked, NOT
#      app-update.yml - the update feed is a dead link and must stay out)
#   3  patch asar (scripts\patch-asar.js) - hard-fail on pattern drift
#   4  boot with CDP, require milestones: startup-loader / main-ui / list-ready
#   5  scan stderr for native module load errors
# T3 steps:
#   6  re-run bench-functional.ps1 -Side ARM64 against the normal build and
#      require F1..F7 stage rows in its summary
#
# Output: scripts/bench-output/dropin-test-<stamp>/report.md  (+ exit 0/1)
#
# NOTE: Keep this .ps1 ASCII-only (no BOM). PS 5.1 mis-reads UTF-8 Chinese
# in string literals and breaks quotes.

param(
    [string]$Zip = "",
    [string]$OfficialDir = "",
    [int]$DebugPort = 9333,
    [int]$ProbeTimeoutMs = 120000,
    [switch]$SkipFunctional
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$official = if ($OfficialDir) { $OfficialDir } else { Join-Path $env:LOCALAPPDATA "Programs\Xiaomi MiMo" }
$defaultZip = Join-Path $env:TEMP "mi-mi-mi-runtime-win32-arm64.zip"
if (-not $Zip) { $Zip = $defaultZip }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$workRoot = Join-Path $env:TEMP "mi-mi-mi-dropin-$stamp"
$runtimeDir = Join-Path $workRoot "Xiaomi MiMo ARM64"
$outDir = Join-Path $PSScriptRoot "bench-output\dropin-test-$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$report = New-Object System.Collections.ArrayList
$failed = $false
function Step([string]$m) { Write-Host "==> $m" -ForegroundColor Cyan; [void]$report.Add("## $m") }
function Pass([string]$m) { Write-Host "  PASS  $m" -ForegroundColor Green; [void]$report.Add("- PASS  $m") }
function Fail([string]$m) { Write-Host "  FAIL  $m" -ForegroundColor Red; [void]$report.Add("- FAIL  $m"); $script:failed = $true }
function Info([string]$m) { Write-Host "  ....  $m"; [void]$report.Add("  - $m") }

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

[void]$report.Add("# Drop-in acceptance test - $stamp")
[void]$report.Add("")
[void]$report.Add("Runtime workdir: $workRoot")
[void]$report.Add("")

# --- preflight ---
$running = @(Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    Write-Host "ERROR: Xiaomi MiMo is running ($($running.Count) processes)." -ForegroundColor Red
    Write-Host "Close ALL MiMo instances first (this test owns the profile and CDP port)."
    exit 1
}

$nodeExe = Resolve-NodeExe
if (-not $nodeExe) {
    Write-Host "ERROR: node.exe not found. Install Node or set MIMO_NODE." -ForegroundColor Red
    exit 1
}
$probeJs = Join-Path $PSScriptRoot "cdp-probe.mjs"
$patchJs = Join-Path $PSScriptRoot "patch-asar.js"
if (-not (Test-Path $probeJs)) { Write-Host "ERROR: missing $probeJs" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $patchJs)) { Write-Host "ERROR: missing $patchJs" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $official)) { Write-Host "ERROR: official install not found: $official" -ForegroundColor Red; exit 1 }
Write-Host "  node : $nodeExe"
Write-Host "  zip  : $(if (Test-Path $Zip) { $Zip } else { '(none - will stage from output\)' })"
Write-Host "  official: $official"

# --- 1 materialize runtime ---
Step "T2.1 materialize runtime"
try {
    if (Test-Path $Zip) {
        New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
        tar -x -f $Zip -C $workRoot
        if ($LASTEXITCODE -ne 0) { throw "tar extract exit $LASTEXITCODE" }
        Info "extracted zip -> $workRoot"
    } else {
        $src = Join-Path $repoRoot "output\Xiaomi MiMo ARM64"
        New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
        robocopy $src $runtimeDir /E /XD evolve-seed browser-extension computer-use-windows `
            /XF app.asar app.asar.bak app-update.yml elevate.exe canvas-binding-error.log `
            /NFL /NDL /NJH /NJS | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy exit $LASTEXITCODE" }
        Copy-Item $patchJs (Join-Path $runtimeDir "patch-asar.js") -Force
        Info "staged from output\ -> $runtimeDir"
    }
    if (-not (Test-Path (Join-Path $runtimeDir "Xiaomi MiMo.exe"))) { throw "runtime exe missing" }
    if (Test-Path (Join-Path $runtimeDir "resources\app.asar")) { throw "runtime already contains app.asar (must start payload-free)" }
    $n = @(Get-ChildItem $runtimeDir -Recurse -File).Count
    Pass "runtime ready, $n files, payload-free"
} catch {
    Fail "materialize: $($_.Exception.Message)"
    throw
}

# --- 2 copy payload ---
Step "T2.2 copy official payload"
$payload = @("resources\app.asar", "resources\evolve-seed", "resources\browser-extension", "resources\computer-use-windows", "resources\elevate.exe")
foreach ($rel in $payload) {
    $s = Join-Path $official $rel
    $d = Join-Path $runtimeDir $rel
    if (-not (Test-Path $s)) { Fail "payload missing in official install: $rel"; continue }
    try {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force }
        $parent = Split-Path $d -Parent
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        Copy-Item $s $d -Recurse -Force
        Pass "copied $rel"
    } catch { Fail "copy ${rel}: $($_.Exception.Message)" }
}
Info "deliberately NOT copied: resources\app.asar.unpacked (skeleton ships ARM64 natives)"
Info "deliberately NOT copied: resources\app-update.yml (update feed is a dead link)"

# --- 3 patch asar ---
Step "T2.3 patch asar"
$asar = Join-Path $runtimeDir "resources\app.asar"
if (-not (Test-Path $asar)) {
    Fail "app.asar not present - cannot patch"
} else {
    $hashBefore = (Get-FileHash $asar -Algorithm SHA256).Hash.ToLower()
    & $nodeExe $patchJs $asar
    $patchExit = $LASTEXITCODE
    if ($patchExit -eq 0) {
        $hashAfter = (Get-FileHash $asar -Algorithm SHA256).Hash.ToLower()
        Pass "patch ok (exit 0)"
        Info "sha256 before: $hashBefore"
        Info "sha256 after : $hashAfter"
        if ($hashAfter -eq "5a9ba932a6b30aafccd4fc76ab6118e4a8564474ae3594bdc22729e3130ccf1d") {
            Info "matches the known-good ARM64 asar byte-for-byte"
        } else {
            Info "NOTE: differs from the 26.923 reference hash (payload updated?)"
        }
    } else {
        Fail "patch-asar exit $patchExit (pattern drift on a new payload version)"
    }
}

# --- 4 boot + CDP probe ---
Step "T2.4 boot drop-in runtime and probe milestones"
$exe = Join-Path $runtimeDir "Xiaomi MiMo.exe"
$stderrFile = Join-Path $outDir "dropin-stderr.log"
$milestones = @{}
try {
    $env:NAPI_RS_NATIVE_LIBRARY_PATH = Join-Path $runtimeDir "resources\native\skia.win32-arm64-msvc.node"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.WorkingDirectory = $runtimeDir
    $psi.Arguments = "--enable-logging=stderr --remote-debugging-port=$DebugPort"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $proc = [System.Diagnostics.Process]::Start($psi)
    Info "launched PID $($proc.Id)"

    $stderrWriter = [System.IO.StreamWriter]::new($stderrFile, $false, [System.Text.Encoding]::UTF8)
    $stderrTask = $proc.StandardError.ReadLineAsync()

    $probePsi = New-Object System.Diagnostics.ProcessStartInfo
    $probePsi.FileName = $nodeExe
    $probePsi.Arguments = "`"$probeJs`" --port $DebugPort --timeout $ProbeTimeoutMs"
    $probePsi.UseShellExecute = $false
    $probePsi.RedirectStandardOutput = $true
    $probePsi.RedirectStandardError = $true
    $probePsi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $probe = [System.Diagnostics.Process]::Start($probePsi)
    $probeOutTask = $probe.StandardOutput.ReadLineAsync()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $probeDone = $false
    while ((-not $proc.HasExited) -and (-not $probeDone) -and ($sw.ElapsedMilliseconds -lt ($ProbeTimeoutMs + 30000))) {
        Start-Sleep -Milliseconds 150
        while ($stderrTask.IsCompleted -and $null -ne $stderrTask.Result) {
            $stderrWriter.WriteLine($stderrTask.Result)
            $stderrTask = $proc.StandardError.ReadLineAsync()
        }
        while ($probeOutTask.IsCompleted -and $null -ne $probeOutTask.Result) {
            $raw = $probeOutTask.Result
            try { $evt = $raw | ConvertFrom-Json } catch { $evt = $null }
            if ($evt) {
                switch ($evt.event) {
                    'startup-loader' { if (-not $milestones['startup-loader']) { $milestones['startup-loader'] = $sw.ElapsedMilliseconds } }
                    'main-ui'        { if (-not $milestones['main-ui']) { $milestones['main-ui'] = $sw.ElapsedMilliseconds } }
                    'list-ready'     { if (-not $milestones['list-ready']) { $milestones['list-ready'] = $sw.ElapsedMilliseconds } }
                    'done'           { $probeDone = $true }
                    'error'          { Info "probe error: $($evt.message)" }
                }
            }
            $probeOutTask = $probe.StandardOutput.ReadLineAsync()
        }
    }
    try { if (-not $probe.HasExited) { $probe.Kill() } } catch { }
    while ($stderrTask.IsCompleted -and $null -ne $stderrTask.Result) {
        $stderrWriter.WriteLine($stderrTask.Result)
        $stderrTask = $proc.StandardError.ReadLineAsync()
    }
    $stderrWriter.Close()

    foreach ($k in @('startup-loader', 'main-ui', 'list-ready')) {
        if ($milestones.ContainsKey($k) -and $null -ne $milestones[$k]) {
            Pass "milestone $k = $($milestones[$k]) ms"
        } else {
            Fail "milestone $k not reached within $ProbeTimeoutMs ms"
        }
    }

    if ($proc.HasExited) {
        Fail "drop-in process exited early (code $($proc.ExitCode))"
    } else {
        Pass "process still alive after probe"
        try { $proc.Kill() } catch { }
    }
} catch {
    Fail "boot/probe: $($_.Exception.Message)"
}

# --- 5 stderr native-module scan ---
Step "T2.5 stderr scan for native module errors"
$errPatterns = @(
    'The specified module could not be found',
    'is not a valid Win32 application',
    'compiled against a different Node.js version',
    'ERR_DLOPEN',
    'Cannot find module',
    'A duplicate name',
    'win32-arm64-msvc.node'
)
if (Test-Path $stderrFile) {
    $lines = @(Get-Content $stderrFile)
    Info "stderr lines: $($lines.Count) -> $stderrFile"
    $bad = @()
    foreach ($pat in $errPatterns) {
        $hits = @($lines | Where-Object { $_ -like "*$pat*" })
        foreach ($h in $hits) {
            if ($pat -eq 'win32-arm64-msvc.node' -and $h -notmatch 'error|Error|ERROR|fail|Fail') { continue }
            $bad += $h
        }
    }
    if ($bad.Count -eq 0) { Pass "no native module load errors" }
    else { foreach ($b in ($bad | Select-Object -First 8)) { Fail "stderr: $b" } }
} else {
    Fail "stderr log missing"
}

# cleanup any leftover test processes (path-scoped, never by bare name)
$leftover = @(Get-Process -Name "Xiaomi MiMo" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$workRoot*" })
foreach ($p in $leftover) { try { $p.Kill() } catch { } }
if ($leftover.Count -gt 0) { Info "killed $($leftover.Count) leftover test process(es)" }
Remove-Item Env:\NAPI_RS_NATIVE_LIBRARY_PATH -ErrorAction SilentlyContinue

# --- 6 T3 functional regression on the normal build ---
if (-not $SkipFunctional) {
    Step "T3 bench-functional regression (normal build, -Side ARM64)"
    try {
        $fn = Join-Path $PSScriptRoot "bench-functional.ps1"
        & powershell -ExecutionPolicy Bypass -File $fn -Side ARM64
        $fnExit = $LASTEXITCODE
        $newest = Get-ChildItem (Join-Path $PSScriptRoot "bench-output") -Directory -Filter "functional-ARM64-*" |
            Sort-Object Name | Select-Object -Last 1
        if ($newest) {
            $summaryPath = Join-Path $newest.FullName "summary.md"
            if (Test-Path $summaryPath) {
                $sum = Get-Content $summaryPath -Raw
                $stages = @('F1 window', 'F2 loader', 'F3 sidebar', 'F4 main-ui', 'F5 interactive', 'F6 list-ready', 'F7 engine-sessions')
                $missing = @($stages | Where-Object { $sum -notlike "*$_*" })
                if ($missing.Count -eq 0) { Pass "all F1..F7 stages present in $($newest.Name)" }
                else { Fail "stages missing: $($missing -join ', ')" }
            } else { Fail "summary.md missing in $($newest.Name)" }
        } else { Fail "no functional-ARM64-* output produced" }
        if ($fnExit -ne 0) { Info "bench-functional exit code $fnExit" }
    } catch {
        Fail "T3: $($_.Exception.Message)"
    }
}

# --- report ---
[void]$report.Add("")
if ($failed) { [void]$report.Add("**RESULT: FAIL**") } else { [void]$report.Add("**RESULT: PASS**") }
$reportPath = Join-Path $outDir "report.md"
Set-Content -Path $reportPath -Value $report -Encoding UTF8

Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
if ($failed) { Write-Host "RESULT: FAIL  - see $reportPath" -ForegroundColor Red }
else { Write-Host "RESULT: PASS  - see $reportPath" -ForegroundColor Green }
Write-Host "================================================" -ForegroundColor Yellow
if ($failed) { exit 1 }
exit 0

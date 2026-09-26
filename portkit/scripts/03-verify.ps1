# 03-verify.ps1 — Architecture purity audit + smoke test

param(
    [string]$TargetDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $TargetDir) {
    $TargetDir = Join-Path $PSScriptRoot "..\output\Xiaomi MiMo ARM64"
}

Write-Host "=== Architecture Purity Audit ===" -ForegroundColor Yellow

$results = Get-ChildItem $TargetDir -Recurse -Include "*.exe","*.dll","*.node" -ErrorAction SilentlyContinue |
    ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $peOff = [BitConverter]::ToInt32($bytes, 0x3C)
        $machine = [BitConverter]::ToUInt16($bytes, $peOff + 4)
        $arch = switch ($machine) { 0x8664 {"x64"} 0xAA64 {"ARM64"} 0x014C {"x86"} default {"0x{0:X4}" -f $machine} }
        [PSCustomObject]@{
            Arch = $arch
            File = $_.FullName.Replace($TargetDir, '')
            Size = [math]::Round($_.Length/1MB, 1)
        }
    }

$arm64 = ($results | Where-Object { $_.Arch -eq 'ARM64' }).Count
$other = ($results | Where-Object { $_.Arch -ne 'ARM64' }).Count
$total = $results.Count

Write-Host "`nARM64: $arm64 / $total ($([math]::Round($arm64/$total*100,1))%)" -ForegroundColor $(if ($other -le 2) { "Green" } else { "Yellow" })

if ($other -gt 0) {
    Write-Host "`nNon-ARM64 (expected: elevate.exe x86, vcruntime140_1.dll x64):" -ForegroundColor Yellow
    $results | Where-Object { $_.Arch -ne 'ARM64' } | Format-Table -AutoSize
}

# Smoke test
Write-Host "=== Smoke Test ===" -ForegroundColor Yellow
$exe = Join-Path $TargetDir "Xiaomi MiMo.exe"
if (-not (Test-Path $exe)) {
    Write-Host "FAIL: Xiaomi MiMo.exe not found" -ForegroundColor Red
    exit 1
}

Write-Host "Launching $exe ..." -ForegroundColor Cyan
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.WorkingDirectory = $TargetDir
$psi.Arguments = "--user-data-dir=`"$env:TEMP\mimo-arm64-test`" --enable-logging=stderr"
$psi.UseShellExecute = $false
$psi.RedirectStandardError = $true

$proc = [System.Diagnostics.Process]::Start($psi)
Start-Sleep -Seconds 15

if ($proc.HasExited) {
    Write-Host "FAIL: Process exited with code $($proc.ExitCode)" -ForegroundColor Red
    Write-Host "STDERR:"
    Write-Host $proc.StandardError.ReadToEnd()
    exit 1
}

$proc.Refresh()
if ($proc.MainWindowTitle -eq "Xiaomi MiMo") {
    Write-Host "PASS: Window title = 'Xiaomi MiMo'" -ForegroundColor Green
} else {
    Write-Host "WARN: Window title = '$($proc.MainWindowTitle)'" -ForegroundColor Yellow
}

# Check native modules loaded (no canvas error in stderr)
$stderrAsync = $proc.StandardError.ReadToEndAsync()
Start-Sleep -Seconds 3
if ($stderrAsync.IsCompleted) {
    $err = $stderrAsync.Result
    if ($err -match 'Cannot find native binding') {
        Write-Host "FAIL: Canvas native binding error detected" -ForegroundColor Red
    } else {
        Write-Host "PASS: No native binding errors" -ForegroundColor Green
    }
}

# Kill test instance (ONLY by PID)
$testPid = $proc.Id
$proc.Kill()
Write-Host "Killed test PID $testPid"

Write-Host "`n=== Verify Complete ===" -ForegroundColor Yellow

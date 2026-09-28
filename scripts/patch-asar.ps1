# Patch an OFFICIAL MiMo app.asar for the ARM64 runtime (no Node required).
#
# The port needs exactly one equal-length byte edit in out/main/index.mjs:
# the platform whitelist must admit win32-arm64. Everything else in the
# official asar is already architecture-independent.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Patch-Asar.ps1
#       (defaults to <script dir>\resources\app.asar - double-click friendly)
#   powershell -ExecutionPolicy Bypass -File Patch-Asar.ps1 -Asar C:\path\app.asar
#   powershell -ExecutionPolicy Bypass -File Patch-Asar.ps1 -Asar ... -Check
#
# Exit codes: 0 patched/already patched, 2 pattern not found (version drift),
#             3 usage error.
#
# NOTE: Keep this .ps1 ASCII-only (no BOM).

param(
    [string]$Asar = "",
    [switch]$Check
)

$ErrorActionPreference = "Stop"

$OFFICIAL = 'return r==="darwin-arm64"||r==="win32-x64"||r==="linux-x64"?r:null'
$PATCHED  = 'return r==="win32-arm64"||r==="win32-x64"||r==="linux-x64"?r: null'
if ($OFFICIAL.Length -ne $PATCHED.Length) {
    Write-Host "FATAL: patch is not length-preserving" -ForegroundColor Red
    exit 3
}

if (-not $Asar) {
    $Asar = Join-Path $PSScriptRoot "resources\app.asar"
}
if (-not (Test-Path $Asar)) {
    Write-Host "ERROR: asar not found: $Asar" -ForegroundColor Red
    exit 3
}

$latin1 = [System.Text.Encoding]::GetEncoding(28591)
$bytes = [System.IO.File]::ReadAllBytes($Asar)
$text = $latin1.GetString($bytes)

function Count-Occ([string]$haystack, [string]$needle) {
    $c = 0
    $i = 0
    while ($true) {
        $i = $haystack.IndexOf($needle, $i, [StringComparison]::Ordinal)
        if ($i -lt 0) { break }
        $c++
        $i += $needle.Length
    }
    return $c
}

$nOfficial = Count-Occ $text $OFFICIAL
$nPatched  = Count-Occ $text $PATCHED
$sha = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
).Replace("-", "").ToLower()

Write-Host "file   : $Asar"
Write-Host "size   : $($bytes.Length)"
Write-Host "sha256 : $sha"
Write-Host "official-pattern: $nOfficial  patched-pattern: $nPatched"

if ($nOfficial -eq 1 -and $nPatched -eq 0) {
    if ($Check) {
        Write-Host "RESULT : OK, patchable (not applied, -Check)"
        exit 0
    }
    $idx = $text.IndexOf($OFFICIAL, [StringComparison]::Ordinal)
    $newText = $text.Substring(0, $idx) + $PATCHED + $text.Substring($idx + $OFFICIAL.Length)
    $newBytes = $latin1.GetBytes($newText)
    if ($newBytes.Length -ne $bytes.Length) {
        Write-Host "FATAL: patch changed length ($($bytes.Length) -> $($newBytes.Length))" -ForegroundColor Red
        exit 3
    }
    [System.IO.File]::WriteAllBytes($Asar, $newBytes)
    $sha2 = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash($newBytes)
    ).Replace("-", "").ToLower()
    Write-Host "applied at byte offset $idx"
    Write-Host "sha256 after: $sha2"
    Write-Host "RESULT : OK, patched"
    exit 0
}

if ($nOfficial -eq 0 -and $nPatched -eq 1) {
    Write-Host "RESULT : OK, already patched"
    exit 0
}

Write-Host "RESULT : FAIL - expected exactly one platform-whitelist match." -ForegroundColor Red
Write-Host "  This asar is neither stock nor known-patched; the payload"
Write-Host "  version has changed and the pattern no longer applies."
Write-Host "  Refusing to guess. Do NOT launch with a half-patched asar."
exit 2

# 00-setup.ps1 — Verify prerequisites

Write-Host "=== Checking prerequisites ===" -ForegroundColor Yellow

# Check VS Build Tools
$clPaths = @(
    "C:\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\arm64\cl.exe",
    "C:\BuildTools\VC\Tools\MSVC\*\bin\Hostarm64\arm64\cl.exe"
)
$found = $false
foreach ($p in $clPaths) {
    if (Get-Item $p -ErrorAction SilentlyContinue) { $found = $true; break }
}
if ($found) {
    Write-Host "  OK   MSVC ARM64 compiler" -ForegroundColor Green
} else {
    Write-Host "  MISS MSVC ARM64 compiler" -ForegroundColor Red
    Write-Host "       Install: winget install -e --id Microsoft.VisualStudio.BuildTools --override `"--passive --config .\msvc-arm64.vsconfig --installPath C:\BuildTools`""
}

# Check CMake
$cmake = "C:\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
if (Test-Path $cmake) {
    Write-Host "  OK   CMake" -ForegroundColor Green
} else {
    Write-Host "  MISS CMake (included in VS Build Tools C++ workload)" -ForegroundColor Yellow
}

# Check Git
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "  OK   Git $(git --version)" -ForegroundColor Green
} else {
    Write-Host "  MISS Git" -ForegroundColor Red
}

# Check curl
if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    Write-Host "  OK   curl" -ForegroundColor Green
} else {
    Write-Host "  MISS curl" -ForegroundColor Red
}

Write-Host "`n=== Setup check complete ===" -ForegroundColor Yellow

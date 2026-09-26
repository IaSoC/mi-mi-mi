# 02-extract.ps1 — Extract architecture-independent resources from official x64 install
# Then replace native binaries with ARM64 equivalents

param(
    [string]$SourceDir = "C:\Users\xiaomi\AppData\Local\Programs\Xiaomi MiMo",
    [string]$TargetDir = "",
    [string]$CacheDir  = "..\cache\downloads"
)

$ErrorActionPreference = "Stop"

if (-not $TargetDir) {
    $TargetDir = Join-Path $PSScriptRoot "..\output\Xiaomi MiMo ARM64"
}
$cache = Join-Path $PSScriptRoot $CacheDir

Write-Host "=== Extract from official x64 ===" -ForegroundColor Yellow
Write-Host "  Source: $SourceDir"
Write-Host "  Target: $TargetDir"

# Step 1: Extract Electron ARM64 shell
Write-Host "`n--- Step 1: Electron ARM64 shell ---" -ForegroundColor Cyan
$electronZip = Join-Path $cache "electron-v41.7.2-win32-arm64.zip"
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
Expand-Archive -Path $electronZip -DestinationPath $TargetDir -Force
if (Test-Path "$TargetDir\electron.exe") {
    Rename-Item "$TargetDir\electron.exe" "Xiaomi MiMo.exe"
    Write-Output "  Renamed electron.exe -> Xiaomi MiMo.exe"
}

# Step 2: Copy architecture-independent resources
Write-Host "`n--- Step 2: App payload ---" -ForegroundColor Cyan
$items = @(
    "resources\app.asar",
    "resources\app.asar.unpacked",
    "resources\app-update.yml",
    "resources\browser-extension",
    "resources\computer-use-windows",
    "resources\evolve-seed",
    "resources\elevate.exe",
    "LICENSE.electron.txt",
    "LICENSES.chromium.html"
)
foreach ($item in $items) {
    $src = Join-Path $SourceDir $item
    $dst = Join-Path $TargetDir $item
    if (Test-Path $src) {
        Copy-Item $src $dst -Recurse -Force
        Write-Output "  OK   $item"
    } else {
        Write-Output "  MISS $item"
    }
}

# Step 3: Replace native modules with ARM64
Write-Host "`n--- Step 3: Native modules ---" -ForegroundColor Cyan
$unpacked = Join-Path $TargetDir "resources\app.asar.unpacked\node_modules"
$extractDir = Join-Path $cache "extracted"
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

# node-pty
$ptyTgz = Join-Path $cache "node-pty-win32-arm64-1.2.0-beta.15.tgz"
if (Test-Path $ptyTgz) {
    $dest = Join-Path $extractDir "node-pty-arm64"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    tar -xzf $ptyTgz -C $dest
    $oldDir = Join-Path $unpacked "@lydell\node-pty-win32-x64"
    if (Test-Path $oldDir) { Remove-Item $oldDir -Recurse -Force }
    $newDir = Join-Path $unpacked "@lydell\node-pty-win32-x64"
    New-Item -ItemType Directory -Force -Path $newDir | Out-Null
    Copy-Item "$dest\package\*" $newDir -Recurse -Force
    Write-Output "  OK   node-pty-win32-x64 <- ARM64"
}

# canvas
$canvasTgz = Join-Path $cache "canvas-win32-arm64-msvc-1.0.9.tgz"
if (Test-Path $canvasTgz) {
    $dest = Join-Path $extractDir "canvas-arm64"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    tar -xzf $canvasTgz -C $dest
    $oldDir = Join-Path $unpacked "@napi-rs\canvas-win32-x64-msvc"
    if (Test-Path $oldDir) { Remove-Item $oldDir -Recurse -Force }
    $newDir = Join-Path $unpacked "@napi-rs\canvas-win32-x64-msvc"
    New-Item -ItemType Directory -Force -Path $newDir | Out-Null
    Copy-Item "$dest\package\*" $newDir -Recurse -Force
    # Also copy .node for relative require fallback
    Copy-Item "$dest\package\skia.win32-arm64-msvc.node" (Join-Path $unpacked "@napi-rs\canvas\") -Force
    Write-Output "  OK   canvas-win32-x64-msvc <- ARM64"
}

# parcel-watcher
$watcherTgz = Join-Path $cache "watcher-win32-arm64-2.6.0.tgz"
if (Test-Path $watcherTgz) {
    $dest = Join-Path $extractDir "watcher-arm64"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    tar -xzf $watcherTgz -C $dest
    $oldDir = Join-Path $unpacked "@parcel\watcher-win32-x64"
    if (Test-Path $oldDir) { Remove-Item $oldDir -Recurse -Force }
    $newDir = Join-Path $unpacked "@parcel\watcher-win32-x64"
    New-Item -ItemType Directory -Force -Path $newDir | Out-Null
    Copy-Item "$dest\package\*" $newDir -Recurse -Force
    Write-Output "  OK   watcher-win32-x64 <- ARM64"
}

# onnxruntime (from npm tarball which includes win32/arm64)
$ortTgz = Join-Path $cache "onnxruntime-node-1.27.0.tgz"
if (Test-Path $ortTgz) {
    $dest = Join-Path $extractDir "onnxruntime"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    tar -xzf $ortTgz -C $dest
    $ortDst = Join-Path $unpacked "onnxruntime-node\bin\napi-v6\win32\arm64"
    New-Item -ItemType Directory -Force -Path $ortDst | Out-Null
    Copy-Item "$dest\package\bin\napi-v6\win32\arm64\*" $ortDst -Force
    # Also place at x64 path (asar header expects this name)
    $x64Dst = Join-Path $unpacked "onnxruntime-node\bin\napi-v6\win32\x64"
    New-Item -ItemType Directory -Force -Path $x64Dst | Out-Null
    Copy-Item "$dest\package\bin\napi-v6\win32\arm64\*" $x64Dst -Force
    Write-Output "  OK   onnxruntime-node <- ARM64"
}

# sharp (runtimes)
$sharpTgz = Join-Path $cache "sharp-win32-arm64-0.35.4.tgz"
$runtimesNm = Join-Path $TargetDir "resources\runtimes\win32-arm64\node_modules"
if (Test-Path $sharpTgz) {
    $dest = Join-Path $extractDir "sharp-arm64"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    tar -xzf $sharpTgz -C $dest
    $oldSharp = Join-Path $runtimesNm "@img\sharp-win32-x64"
    if (Test-Path $oldSharp) { Remove-Item $oldSharp -Recurse -Force }
    $newSharp = Join-Path $runtimesNm "@img\sharp-win32-arm64"
    New-Item -ItemType Directory -Force -Path $newSharp | Out-Null
    Copy-Item "$dest\package\*" $newSharp -Recurse -Force
    Write-Output "  OK   sharp-win32-arm64"
}

Write-Host "`n=== Extract complete ===" -ForegroundColor Yellow
Write-Host "Next: run 03-build.ps1 to compile qpdf and assemble runtimes"

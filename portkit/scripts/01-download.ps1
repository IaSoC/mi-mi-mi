# 01-download.ps1 — Download all ARM64 components
# Downloads to cache/downloads/ for use by 02-build.ps1

param(
    [string]$CacheDir = "..\cache\downloads"
)

$ErrorActionPreference = "Stop"
$cache = Join-Path $PSScriptRoot $CacheDir
New-Item -ItemType Directory -Force -Path $cache | Out-Null

Write-Host "=== Downloading ARM64 components ===" -ForegroundColor Yellow

# Component list: name, url, filename
$components = @(
    @{
        name = "Electron 41.7.2 win32-arm64"
        url  = "https://github.com/electron/electron/releases/download/v41.7.2/electron-v41.7.2-win32-arm64.zip"
        file = "electron-v41.7.2-win32-arm64.zip"
    },
    @{
        name = "Node.js v24.15.0 win-arm64"
        url  = "https://nodejs.org/dist/v24.15.0/node-v24.15.0-win-arm64.zip"
        file = "node-v24.15.0-win-arm64.zip"
    },
    @{
        name = "Python 3.12.10 embed-arm64"
        url  = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-arm64.zip"
        file = "python-3.12.10-embed-arm64.zip"
    },
    @{
        name = "ripgrep 15.2.0 aarch64-pc-windows-msvc"
        url  = "https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-aarch64-pc-windows-msvc.zip"
        file = "ripgrep-15.2.0-aarch64-pc-windows-msvc.zip"
    },
    @{
        name = "github-mcp-server Windows_arm64"
        url  = "https://github.com/github/github-mcp-server/releases/download/v1.12.2/github-mcp-server_Windows_arm64.zip"
        file = "github-mcp-server_Windows_arm64.zip"
    },
    @{
        name = "ONNX Runtime win-arm64"
        url  = "https://github.com/microsoft/onnxruntime/releases/download/v1.30.0/onnxruntime-win-arm64-1.30.0.zip"
        file = "onnxruntime-win-arm64-1.30.0.zip"
    },
    @{
        name = "onnxruntime-node 1.27.0 (source with ARM64 binaries)"
        url  = "https://registry.npmjs.org/onnxruntime-node/-/onnxruntime-node-1.27.0.tgz"
        file = "onnxruntime-node-1.27.0.tgz"
    },
    @{
        name = "@lydell/node-pty-win32-arm64"
        url  = "https://registry.npmjs.org/@lydell/node-pty-win32-arm64/-/node-pty-win32-arm64-1.2.0-beta.15.tgz"
        file = "node-pty-win32-arm64-1.2.0-beta.15.tgz"
    },
    @{
        name = "@napi-rs/canvas-win32-arm64-msvc"
        url  = "https://registry.npmjs.org/@napi-rs/canvas-win32-arm64-msvc/-/canvas-win32-arm64-msvc-1.0.9.tgz"
        file = "canvas-win32-arm64-msvc-1.0.9.tgz"
    },
    @{
        name = "@parcel/watcher-win32-arm64"
        url  = "https://registry.npmjs.org/@parcel/watcher-win32-arm64/-/watcher-win32-arm64-2.6.0.tgz"
        file = "watcher-win32-arm64-2.6.0.tgz"
    },
    @{
        name = "@img/sharp-win32-arm64"
        url  = "https://registry.npmjs.org/@img/sharp-win32-arm64/-/sharp-win32-arm64-0.35.4.tgz"
        file = "sharp-win32-arm64-0.35.4.tgz"
    }
)

# qpdf source (for ARM64 compilation)
$qpdfDeps = @(
    @{
        name = "qpdf 12.4.1 source"
        url  = "https://github.com/qpdf/qpdf/releases/download/v12.4.1/qpdf-12.4.1.tar.gz"
        file = "qpdf-12.4.1.tar.gz"
    },
    @{
        name = "zlib 1.3.1 source"
        url  = "https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz"
        file = "zlib-1.3.1.tar.gz"
    },
    @{
        name = "libjpeg-turbo 3.1.0 source"
        url  = "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/3.1.0.tar.gz"
        file = "libjpeg-turbo-3.1.0.tar.gz"
    }
)

function Download-Component {
    param($comp)
    $dest = Join-Path $cache $comp.file
    if (Test-Path $dest) {
        $size = (Get-Item $dest).Length
        if ($size -gt 1000) {
            Write-Host "  SKIP $($comp.name) ($([math]::Round($size/1MB,1))MB)" -ForegroundColor DarkGray
            return
        }
    }
    Write-Host "  GET  $($comp.name)..." -ForegroundColor Cyan
    curl.exe -sL -o $dest $comp.url --connect-timeout 30 --max-time 600 --retry 2
    $size = (Get-Item $dest -ErrorAction SilentlyContinue).Length
    if ($size -gt 1000) {
        Write-Host "  OK   $([math]::Round($size/1MB,1))MB" -ForegroundColor Green
    } else {
        Write-Host "  FAIL $comp.name" -ForegroundColor Red
    }
}

Write-Host "`n--- Runtime components ---" -ForegroundColor Yellow
foreach ($c in $components) { Download-Component $c }

Write-Host "`n--- qpdf build dependencies ---" -ForegroundColor Yellow
foreach ($c in $qpdfDeps) { Download-Component $c }

Write-Host "`n=== Download complete ===" -ForegroundColor Yellow
Get-ChildItem $cache -File | Select-Object Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}} | Format-Table -AutoSize

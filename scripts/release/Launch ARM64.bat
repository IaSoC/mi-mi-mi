@echo off
set "NAPI_RS_NATIVE_LIBRARY_PATH=%~dp0resources\native\skia.win32-arm64-msvc.node"
start "" "%~dp0Xiaomi MiMo.exe" %*

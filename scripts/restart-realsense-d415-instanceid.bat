@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restart-realsense-d415-instanceid.ps1" %*

endlocal

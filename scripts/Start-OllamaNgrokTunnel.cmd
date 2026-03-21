@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-OllamaNgrokTunnel.ps1" %*
exit /b %errorlevel%

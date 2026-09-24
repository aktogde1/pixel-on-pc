@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0pixel-on-pc.ps1" %*
if errorlevel 1 pause

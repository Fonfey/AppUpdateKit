@echo off
rem Starts the AppUpdateKit Builder. Double-clicking is enough.
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0AppUpdateKit-Builder.ps1"

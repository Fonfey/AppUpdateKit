@echo off
rem Start de AppUpdateKit Builder (invulscherm). Dubbelklikken is genoeg.
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0AppUpdateKit-Builder.ps1"

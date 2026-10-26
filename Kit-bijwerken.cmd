@echo off
rem Werkt de AppUpdateKit bij naar de nieuwste versie op GitHub. Je apps, pakketten en instellingen blijven staan.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Kit-bijwerken.ps1"

@echo off
rem Checks the Builder (language, settings, version). Changes nothing; the result opens in Notepad.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Diagnose-Builder.ps1"

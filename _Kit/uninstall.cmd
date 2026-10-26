@echo off
setlocal
cd /d "%~dp0"
rem Verwijdert {{APPNAME}} (stappen in uninstall-app.cmd) en de update-gegevens. NIET aanpassen.

rem Meldingen alleen als UninstallNotify = $true in app.psd1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Uninstalling

call uninstall-app.cmd
set UNINSTALL_EXITCODE=%ERRORLEVEL%
cd /d "%~dp0"

if "%UNINSTALL_EXITCODE%"=="0" goto ok
if "%UNINSTALL_EXITCODE%"=="3010" goto ok
if "%UNINSTALL_EXITCODE%"=="1641" goto ok
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type UninstallError
goto cleanup
:ok
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Uninstalled

:cleanup
rem Update-gegevens opruimen; update.log blijft staan
schtasks.exe /delete /tn "AppUpdateKit Herstart {{APPID}}" /f >nul 2>&1
set "KIT_DATA=C:\ProgramData\AppUpdates\{{APPID}}"
if exist "%KIT_DATA%\PostponeState.json" del /f /q "%KIT_DATA%\PostponeState.json"
if exist "%KIT_DATA%\app.json" del /f /q "%KIT_DATA%\app.json"
for %%d in (UI Herstart Stappen) do if exist "%KIT_DATA%\%%d" rmdir /s /q "%KIT_DATA%\%%d"
>>"%KIT_DATA%\update.log" echo %DATE% %TIME:~0,8% - [uninstall] Klaar (exitcode %UNINSTALL_EXITCODE%)

exit /b %UNINSTALL_EXITCODE%

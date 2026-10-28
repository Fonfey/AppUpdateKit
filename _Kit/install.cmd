@echo off
setlocal
cd /d "%~dp0"
rem ====================================================================
rem  Update package for {{APPNAME}}  -  do NOT change.
rem  Your own installation steps are in install-app.cmd,
rem  texts and settings in app.psd1.
rem ====================================================================

rem ---- 0. Parameters from Intune, for example: install.cmd /noprocesscheck /noshortcuts ----
rem  /noprocesscheck : don't check whether the app is open
rem  /noconsent      : no popup, install right away (notifications bottom right stay)
rem  /silent         : no popup and no notifications
rem  Every parameter /name is available in install-app.cmd as APP_NAME=1,
rem  for example /noshortcuts -> APP_NOSHORTCUTS (if defined APP_NOSHORTCUTS ...).
set "KIT_LOG=C:\ProgramData\AppUpdates\{{APPID}}"
if not exist "%KIT_LOG%" md "%KIT_LOG%"
set "KIT_LOG=%KIT_LOG%\update.log"
set "KIT_ARGS=%*"
:args
if "%~1"=="" goto argsdone
set "ARG=%~1"
if "%ARG:~0,1%"=="/" set "ARG=%ARG:~1%"
if "%ARG:~0,1%"=="-" set "ARG=%ARG:~1%"
if not "%ARG%"=="" set "APP_%ARG%=1"
shift
goto args
:argsdone
if defined APP_SILENT set APP_NOCONSENT=1
if defined KIT_ARGS >>"%KIT_LOG%" echo %DATE% %TIME:~0,8% - [install] Parameters: %KIT_ARGS%

rem ---- New installation or update? (determines the texts in the windows) ----
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppInstalled.ps1"
if errorlevel 1 (set APPKIT_NEWINSTALL=1) else (set APPKIT_NEWINSTALL=0)

rem ---- 1. The app must not be open (Intune tries again later) ----
if defined APP_NOPROCESSCHECK goto consent
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppRunning.ps1"
if errorlevel 1 exit /b 1618

:consent
rem ---- 2. Ask for consent (Later = postpone: stop without installing) ----
if defined APP_NOCONSENT goto install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Ask-InstallConsent.ps1"
if errorlevel 1 (
    echo User postponed the update.
    exit /b 0
)

rem ---- 3. Again: the app may have been opened while the window or the countdown was running ----
if defined APP_NOPROCESSCHECK goto install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppRunning.ps1"
if errorlevel 1 exit /b 1618

:install
if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Installing

rem ---- 4. Installation steps of this app ----
call install-app.cmd
set INSTALL_EXITCODE=%ERRORLEVEL%
cd /d "%~dp0"

rem ---- 5. Result (0, 3010, 1641 = success) ----
if "%INSTALL_EXITCODE%"=="0" goto success
if "%INSTALL_EXITCODE%"=="3010" goto success
if "%INSTALL_EXITCODE%"=="1641" goto success

if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Error
goto end

:success
rem Only reset the postpone counter when the installation really succeeded
if exist "C:\ProgramData\AppUpdates\{{APPID}}\PostponeState.json" del /f /q "C:\ProgramData\AppUpdates\{{APPID}}\PostponeState.json"
if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Success
rem Restart prompt (RestartMode in app.psd1); returns 0 if the kit handles the restart
if defined APP_SILENT goto end
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Set-RestartPrompt.ps1" -ExitCode %INSTALL_EXITCODE%
set INSTALL_EXITCODE=%ERRORLEVEL%

:end
exit /b %INSTALL_EXITCODE%

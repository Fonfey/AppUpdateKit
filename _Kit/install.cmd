@echo off
setlocal
cd /d "%~dp0"
rem ====================================================================
rem  {{T:Update-pakket voor|Update package for}} {{APPNAME}}  -  {{T:NIET aanpassen.|do NOT edit.}}
rem  {{T:Je eigen installatiestappen staan in install-app.cmd,|Your own installation steps are in install-app.cmd,}}
rem  {{T:teksten en instellingen in app.psd1.|texts and settings in app.psd1.}}
rem ====================================================================

rem ---- 0. {{T:Parameters uit Intune, bijvoorbeeld|Parameters from Intune, for example}}: install.cmd /noprocesscheck /noshortcuts ----
rem  /noprocesscheck : {{T:niet controleren of de app open staat|do not check whether the app is running}}
rem  /noconsent      : {{T:geen popup, direct installeren (meldingen rechtsonder blijven)|no popup, install right away (notifications remain)}}
rem  /silent         : {{T:geen popup en geen meldingen|no popup and no notifications}}
rem  {{T:Elke parameter /naam is in install-app.cmd beschikbaar als APP_NAAM=1,|Every parameter /name is available in install-app.cmd as APP_NAME=1,}}
rem  {{T:bijvoorbeeld|for example}} /noshortcuts -> APP_NOSHORTCUTS (if defined APP_NOSHORTCUTS ...).
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

rem ---- {{T:Nieuwe installatie of update? (bepaalt de teksten in de vensters)|New installation or update? (decides the texts in the popups)}} ----
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppInstalled.ps1"
if errorlevel 1 (set APPKIT_NEWINSTALL=1) else (set APPKIT_NEWINSTALL=0)

rem ---- 1. {{T:App mag niet open staan (Intune probeert het later opnieuw)|App must not be running (Intune retries later)}} ----
if defined APP_NOPROCESSCHECK goto consent
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppRunning.ps1"
if errorlevel 1 exit /b 1618

:consent
rem ---- 2. {{T:Toestemming vragen (Later = uitstellen: stoppen zonder installatie)|Ask for consent (Later = postpone: stop without installing)}} ----
if defined APP_NOCONSENT goto install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Ask-InstallConsent.ps1"
if errorlevel 1 (
    echo {{T:Installatie voor nu overgeslagen.|Installation skipped for now.}}
    exit /b 0
)

rem ---- 3. {{T:Nogmaals: de app kan geopend zijn terwijl het venster of de aftelklok liep|Again: the app may have been opened while the popup or countdown was showing}} ----
if defined APP_NOPROCESSCHECK goto install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppRunning.ps1"
if errorlevel 1 exit /b 1618

:install
if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Installing

rem ---- 4. {{T:Installatiestappen van deze app|Installation steps of this app}} ----
call install-app.cmd
set INSTALL_EXITCODE=%ERRORLEVEL%
cd /d "%~dp0"

rem ---- 5. {{T:Resultaat (0, 3010, 1641 = gelukt)|Result (0, 3010, 1641 = success)}} ----
if "%INSTALL_EXITCODE%"=="0" goto success
if "%INSTALL_EXITCODE%"=="3010" goto success
if "%INSTALL_EXITCODE%"=="1641" goto success

if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Error
goto end

:success
rem {{T:Uitstelteller pas resetten als de installatie echt gelukt is|Reset the postpone counter only when the installation really succeeded}}
if exist "C:\ProgramData\AppUpdates\{{APPID}}\PostponeState.json" del /f /q "C:\ProgramData\AppUpdates\{{APPID}}\PostponeState.json"
if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Success
rem {{T:Herstartmelding (RestartMode in app.psd1); geeft 0 terug als de kit de herstart regelt|Restart prompt (RestartMode in app.psd1); returns 0 when the kit handles the restart}}
if defined APP_SILENT goto end
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Set-RestartPrompt.ps1" -ExitCode %INSTALL_EXITCODE%
set INSTALL_EXITCODE=%ERRORLEVEL%

:end
exit /b %INSTALL_EXITCODE%

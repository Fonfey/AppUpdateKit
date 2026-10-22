@echo off
setlocal
cd /d "%~dp0"
rem ====================================================================
rem  Update-pakket voor {{APPNAME}}  -  NIET aanpassen.
rem  Je eigen installatiestappen staan in install-app.cmd,
rem  teksten en instellingen in app.psd1.
rem ====================================================================

rem ---- 0. Parameters uit Intune, bijvoorbeeld: install.cmd /noprocesscheck /noshortcuts ----
rem  /noprocesscheck : niet controleren of de app open staat
rem  /noconsent      : geen popup, direct installeren (meldingen rechtsonder blijven)
rem  /silent         : geen popup en geen meldingen
rem  Elke parameter /naam is in install-app.cmd beschikbaar als APP_NAAM=1,
rem  bijvoorbeeld /noshortcuts -> APP_NOSHORTCUTS (if defined APP_NOSHORTCUTS ...).
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

rem ---- Nieuwe installatie of update? (bepaalt de teksten in de vensters) ----
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppInstalled.ps1"
if errorlevel 1 (set APPKIT_NEWINSTALL=1) else (set APPKIT_NEWINSTALL=0)

rem ---- 1. App mag niet open staan (Intune probeert het later opnieuw) ----
if defined APP_NOPROCESSCHECK goto consent
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppRunning.ps1"
if errorlevel 1 exit /b 1618

:consent
rem ---- 2. Toestemming vragen (Later = uitstellen: stoppen zonder installatie) ----
if defined APP_NOCONSENT goto install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Ask-InstallConsent.ps1"
if errorlevel 1 (
    echo Gebruiker heeft de update uitgesteld.
    exit /b 0
)

rem ---- 3. Nogmaals: de app kan geopend zijn terwijl het venster of de aftelklok liep ----
if defined APP_NOPROCESSCHECK goto install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Test-AppRunning.ps1"
if errorlevel 1 exit /b 1618

:install
if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Installing

rem ---- 4. Installatiestappen van deze app ----
call install-app.cmd
set INSTALL_EXITCODE=%ERRORLEVEL%
cd /d "%~dp0"

rem ---- 5. Resultaat (0, 3010, 1641 = gelukt) ----
if "%INSTALL_EXITCODE%"=="0" goto success
if "%INSTALL_EXITCODE%"=="3010" goto success
if "%INSTALL_EXITCODE%"=="1641" goto success

if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Error
goto end

:success
rem Uitstelteller pas resetten als de installatie echt gelukt is
if exist "C:\ProgramData\AppUpdates\{{APPID}}\PostponeState.json" del /f /q "C:\ProgramData\AppUpdates\{{APPID}}\PostponeState.json"
if not defined APP_SILENT powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Show-Toast.ps1" -Type Success
rem Herstartmelding (RestartMode in app.psd1); geeft 0 terug als de kit de herstart regelt
if defined APP_SILENT goto end
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Set-RestartPrompt.ps1" -ExitCode %INSTALL_EXITCODE%
set INSTALL_EXITCODE=%ERRORLEVEL%

:end
exit /b %INSTALL_EXITCODE%

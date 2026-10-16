rem ===========================================================================
rem  INSTALLATIESTAPPEN - Omnissa Horizon
rem  Automatisch gemaakt door de Builder uit de onderdelen in tabblad 2.
rem  Wijzig de onderdelen in de Builder (of zet "automatisch maken" uit).
rem ===========================================================================

set APP_EXITCODE=0

rem ---- Onderdeel 1: windowsdesktop-runtime-8.0.22-win-x64.exe (WiX) ----
"windowsdesktop-runtime-8.0.22-win-x64.exe" /install /quiet /norestart
set STEP=%ERRORLEVEL%
set OK=
for %%c in (0 3010 1641 1638) do if "%STEP%"=="%%c" set OK=1
if not defined OK (
    echo Onderdeel 1 - windowsdesktop-runtime-8.0.22-win-x64.exe - is mislukt met exitcode %STEP%
    exit /b %STEP%
)
if "%STEP%"=="3010" set APP_EXITCODE=3010
if "%STEP%"=="1641" set APP_EXITCODE=1641

rem ---- Onderdeel 2: Omnissa-Horizon-Client.exe (EXE) - hoofdonderdeel ----
"Omnissa-Horizon-Client.exe" /silent /norestart SKIP_DOTNET_RUNTIME_INSTALL=0 AUTO_UPDATE_ENABLED=0 DESKTOP_SHORTCUT=0 STARTMENU_SHORTCUT=1
set STEP=%ERRORLEVEL%
set OK=
for %%c in (0 3010 1641) do if "%STEP%"=="%%c" set OK=1
if not defined OK (
    echo Onderdeel 2 - Omnissa-Horizon-Client.exe - is mislukt met exitcode %STEP%
    exit /b %STEP%
)
if "%STEP%"=="3010" set APP_EXITCODE=3010
if "%STEP%"=="1641" set APP_EXITCODE=1641

rem ---- Na de installatie ----
rem Eigen snelkoppelingen "Inloggen VDI werkplek" (overslaan: install.cmd /noshortcuts, of NOSHORTCUTS = $true in Install.ps1)
if defined APP_NOSHORTCUTS goto na_snelkoppelingen
set SC=C:\Program Files\cctg\Omnissa Client Snelkoppeling\v2.0
if not exist "%SC%" md "%SC%"
xcopy "create_shortcuts.ps1" "%SC%\" /Y
xcopy "starthorizon.ps1" "%SC%\" /Y
xcopy "starthorizon-test.ps1" "%SC%\" /Y
copy /Y "app.ico" "%SC%\horizon-client.ico"
powershell.exe -ExecutionPolicy Bypass -File "%SC%\create_shortcuts.ps1"
:na_snelkoppelingen

exit /b %APP_EXITCODE%

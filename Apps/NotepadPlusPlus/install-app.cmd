rem ===========================================================================
rem  INSTALLATIESTAPPEN - Notepad++
rem  Automatisch gemaakt door de Builder uit de onderdelen in tabblad 2.
rem  Wijzig de onderdelen in de Builder (of zet "automatisch maken" uit).
rem ===========================================================================

set APP_EXITCODE=0

rem ---- Onderdeel 1: npp.8.9.8.1.Installer.x64.exe (NSIS) - hoofdonderdeel ----
"npp.8.9.8.1.Installer.x64.exe" /S
set STEP=%ERRORLEVEL%
set OK=
for %%c in (0 3010 1641) do if "%STEP%"=="%%c" set OK=1
if not defined OK (
    echo Onderdeel 1 - npp.8.9.8.1.Installer.x64.exe - is mislukt met exitcode %STEP%
    exit /b %STEP%
)
if "%STEP%"=="3010" set APP_EXITCODE=3010
if "%STEP%"=="1641" set APP_EXITCODE=1641

rem ---- Na de installatie ----
rem Ingebouwde updater uitschakelen: Intune regelt de updates
if exist "%ProgramFiles%\Notepad++\updater" rmdir /s /q "%ProgramFiles%\Notepad++\updater"

exit /b %APP_EXITCODE%

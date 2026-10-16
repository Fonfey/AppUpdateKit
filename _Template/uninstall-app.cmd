rem ===========================================================================
rem  VERWIJDERSTAPPEN VAN DEZE APP
rem ===========================================================================
rem  - Draait als SYSTEM vanuit de pakketmap.
rem  - De update-gegevens (teller, log) ruimt uninstall.cmd zelf op.
rem
rem  Voorbeelden:
rem    MSI          msiexec /x "MijnApp.msi" /qn /norestart
rem    MSI (code)   msiexec /x {PRODUCT-CODE-GUID} /qn /norestart
rem    EXE          "%ProgramFiles%\MijnApp\uninstall.exe" /S
rem    Op naam      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "Mijn App"
rem ===========================================================================

"%ProgramFiles%\MijnApp\uninstall.exe" /S
set APP_EXITCODE=%ERRORLEVEL%

rem ---- Eigen bestanden of snelkoppelingen opruimen ----
rem if exist "C:\Users\Public\Desktop\Mijn App.lnk" del /f /q "C:\Users\Public\Desktop\Mijn App.lnk"

exit /b %APP_EXITCODE%

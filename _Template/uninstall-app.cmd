rem ===========================================================================
rem  UNINSTALL STEPS OF THIS APP
rem ===========================================================================
rem  - Runs as SYSTEM from the package folder.
rem  - The update data (counter, log) is cleaned up by uninstall.cmd itself.
rem
rem  Examples:
rem    MSI          msiexec /x "MyApp.msi" /qn /norestart
rem    MSI (code)   msiexec /x {PRODUCT-CODE-GUID} /qn /norestart
rem    EXE          "%ProgramFiles%\MyApp\uninstall.exe" /S
rem    By name      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "My App"
rem ===========================================================================

"%ProgramFiles%\MyApp\uninstall.exe" /S
set APP_EXITCODE=%ERRORLEVEL%

rem ---- Clean up own files or shortcuts ----
rem if exist "C:\Users\Public\Desktop\My App.lnk" del /f /q "C:\Users\Public\Desktop\My App.lnk"

exit /b %APP_EXITCODE%

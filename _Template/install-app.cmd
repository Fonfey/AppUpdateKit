rem ===========================================================================
rem  INSTALLATION STEPS OF THIS APP  -  put everything that needs to be installed here
rem ===========================================================================
rem  - Runs as SYSTEM, from the package folder: all files from this folder are next to it.
rem  - The popup, the process check and the notifications are handled by install.cmd; you don't
rem    need to do them here.
rem  - Set APP_EXITCODE to the exit code of the MOST IMPORTANT installer. The package uses it
rem    to decide whether it reports "Update installed" or "Update failed".
rem    (0, 3010 and 1641 = success)
rem
rem  Examples (silent switches differ per vendor):
rem    MSI          msiexec /i "MyApp.msi" /qn /norestart ALLUSERS=1
rem    EXE (NSIS)   "MyApp-Setup.exe" /S
rem    EXE (Inno)   "MyApp-Setup.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
rem    EXE (other)  "MyApp-Setup.exe" /quiet /norestart
rem    File         xcopy "config.ini" "C:\Program Files\MyApp\" /Y
rem    Script       powershell.exe -ExecutionPolicy Bypass -File "create-shortcuts.ps1"
rem ===========================================================================

rem ---- Optional preparation (e.g. a runtime that is needed first) ----
rem "vc_redist.x64.exe" /install /quiet /norestart

rem ---- The app itself ----
"MyApp-Setup.exe" /S
set APP_EXITCODE=%ERRORLEVEL%

rem ---- Aftercare (extra files, shortcuts, turning off the built-in updater, ...) ----
rem xcopy "config.ini" "C:\Program Files\MyApp\" /Y

exit /b %APP_EXITCODE%

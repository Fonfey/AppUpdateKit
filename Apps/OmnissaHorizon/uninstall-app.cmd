rem ===========================================================================
rem  VERWIJDERSTAPPEN - Omnissa Horizon Client
rem ===========================================================================

rem Via de MSI-productcode; "Omnissa-Horizon-Client.exe /uninstall" geeft 1605
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "Omnissa Horizon Client"
set APP_EXITCODE=%ERRORLEVEL%

rem ---- Eigen snelkoppelingen en bestanden ----
set SC=C:\Program Files\cctg\Omnissa Client Snelkoppeling
if exist "%SC%" rmdir /s /q "%SC%"
if exist "C:\Program Files\cctg" rmdir /q "C:\Program Files\cctg"
if exist "C:\Users\Public\Desktop\Inloggen VDI werkplek.lnk" del /f /q "C:\Users\Public\Desktop\Inloggen VDI werkplek.lnk"
if exist "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Inloggen VDI werkplek.lnk" del /f /q "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Inloggen VDI werkplek.lnk"
if exist "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Inloggen VDI testwerkplek.lnk" del /f /q "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Inloggen VDI testwerkplek.lnk"

rem ---- Gegevens van de oude Omnissa-update opruimen ----
if exist "C:\ProgramData\OmnissaHorizonUpdate" rmdir /s /q "C:\ProgramData\OmnissaHorizonUpdate"

exit /b %APP_EXITCODE%

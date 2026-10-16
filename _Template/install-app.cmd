rem ===========================================================================
rem  INSTALLATIESTAPPEN VAN DEZE APP  -  hier zet je alles wat geinstalleerd moet worden
rem ===========================================================================
rem  - Draait als SYSTEM, vanuit de pakketmap: alle bestanden uit deze map staan ernaast.
rem  - De popup, de procescheck en de meldingen regelt install.cmd al; die hoef je hier
rem    niet te doen.
rem  - Zet APP_EXITCODE op de exitcode van de BELANGRIJKSTE installer. Daarop bepaalt
rem    het pakket of het "Update geinstalleerd" of "Update niet gelukt" meldt.
rem    (0, 3010 en 1641 = gelukt)
rem
rem  Voorbeelden (stille parameters verschillen per leverancier):
rem    MSI          msiexec /i "MijnApp.msi" /qn /norestart ALLUSERS=1
rem    EXE (NSIS)   "MijnApp-Setup.exe" /S
rem    EXE (Inno)   "MijnApp-Setup.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
rem    EXE (overig) "MijnApp-Setup.exe" /quiet /norestart
rem    Bestand      xcopy "config.ini" "C:\Program Files\MijnApp\" /Y
rem    Script       powershell.exe -ExecutionPolicy Bypass -File "maak-snelkoppelingen.ps1"
rem ===========================================================================

rem ---- Eventuele voorbereiding (bijv. een runtime die eerst nodig is) ----
rem "vc_redist.x64.exe" /install /quiet /norestart

rem ---- De app zelf ----
"MijnApp-Setup.exe" /S
set APP_EXITCODE=%ERRORLEVEL%

rem ---- Nazorg (extra bestanden, snelkoppelingen, ingebouwde updater uitzetten, ...) ----
rem xcopy "config.ini" "C:\Program Files\MijnApp\" /Y

exit /b %APP_EXITCODE%

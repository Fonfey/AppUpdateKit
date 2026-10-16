#  Gemaakt met de AppUpdateKit Builder. Je kunt dit bestand ook met de hand aanpassen.
#  Texts = Nederlands, TextsEn = Engels. In teksten: {AppName}, {Versie}, {Minuten}, {MaxUitstel}. Leeg = standaardtekst.
@{
    # ---------- 1. Basis ----------
    AppId      = 'OmnissaHorizon'
    AppName    = 'Omnissa Horizon'
    Version    = '8.18.0.51429'
    DetectName = 'Omnissa Horizon Client'
    Processes  = @('vmware-view', 'horizon-client')

    # ---------- 2. Uiterlijk ----------
    Icon          = 'app.ico'
    AccentColor   = '#185FA5'
    PopupLanguage = 'Auto'   # Auto (Windows-taal van de gebruiker) | nl | en

    # ---------- 3. Wie krijgt de update ----------
    OnlyUpdateExisting = $false
    InstallDuringSetup = $true   # $true = nieuwe laptops (Autopilot) direct installeren, zonder popup

    # ---------- 4. Uitstellen ----------
    MaxPostpones          = 5
    PostponeHours         = 24
    ConsentTimeoutMinutes = 15
    ForcedDelayMinutes    = 5

    # ---------- 4b. Wanneer ----------
    InstallWindow = 'Altijd'   # Altijd | Werktijd | BuitenWerktijd
    WorkHours     = '08:00-17:00'
    WorkDays      = 'ma,di,wo,do,vr'
    IdleMinutes   = 0   # > 0 = na zoveel minuten inactief of vergrendeld direct installeren
    NoUserAction  = 'Installeren'   # Installeren | Wachten

    # ---------- 4c. Herstart na de installatie ----------
    RestartMode            = 'Nooit'   # Nooit | AlsNodig (3010/1641) | Altijd
    RestartReminderMinutes = 60   # Later: opnieuw vragen na (minuten)
    RestartDeadlineHours   = 24   # verplicht herstarten na (uren, 0 = nooit)
    RestartWarningMinutes  = 15   # waarschuwing voor de verplichte herstart (minuten)

    # ---------- 4d. Verwijderen ----------
    UninstallNotify = $false   # $true = meldingen rechtsonder bij het verwijderen

    # ---------- 5. Installatie (onderdelen worden in deze volgorde geïnstalleerd) ----------
    AutoInstallSteps = $true   # $true = install-app.cmd wordt hieruit gemaakt
    Components = @(
        @{ File = 'windowsdesktop-runtime-8.0.22-win-x64.exe'; Kind = 'WiX'; Args = '/install /quiet /norestart'; Codes = '0 3010 1641 1638'; Main = $false; ProductCode = '' }
        @{ File = 'Omnissa-Horizon-Client.exe'; Kind = 'EXE'; Args = '/silent /norestart SKIP_DOTNET_RUNTIME_INSTALL=0 AUTO_UPDATE_ENABLED=0 DESKTOP_SHORTCUT=0 STARTMENU_SHORTCUT=1'; Codes = '0 3010 1641'; Main = $true; ProductCode = '' }
    )
    PreInstall  = ''    # cmd-regels vóór de onderdelen
    PostInstall = 'rem Eigen snelkoppelingen "Inloggen VDI werkplek" (overslaan: install.cmd /noshortcuts, of NOSHORTCUTS = $true in Install.ps1)
if defined APP_NOSHORTCUTS goto na_snelkoppelingen
set SC=C:\Program Files\cctg\Omnissa Client Snelkoppeling\v2.0
if not exist "%SC%" md "%SC%"
xcopy "create_shortcuts.ps1" "%SC%\" /Y
xcopy "starthorizon.ps1" "%SC%\" /Y
xcopy "starthorizon-test.ps1" "%SC%\" /Y
copy /Y "app.ico" "%SC%\horizon-client.ico"
powershell.exe -ExecutionPolicy Bypass -File "%SC%\create_shortcuts.ps1"
:na_snelkoppelingen'    # cmd-regels na de onderdelen

    # ---------- 6. Teksten voor deze app/versie (leeg = _Kit\Standaardteksten.psd1) ----------
    Texts = @{
        ConsentSubHeading      = 'VMware Horizon wordt Omnissa Horizon'
        ConsentMessage         = 'VMware Horizon heet voortaan Omnissa Horizon. De nieuwe versie staat voor je klaar. Je logt daarna op dezelfde manier in op je VDI-werkplek, via ''Inloggen VDI werkplek''. Tijdens de update (een paar minuten) kun je VDI even niet gebruiken. Sla je werk in VDI op voordat je op Nu bijwerken klikt.'
        ForcedSubHeading       = ''
        ForcedMessage          = 'Je hebt de overstap van VMware Horizon naar Omnissa Horizon {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt de nieuwe Omnissa Horizon automatisch geïnstalleerd. Sla je werk in VDI op en sluit VDI af. Daarna log je in via ''Inloggen VDI werkplek'', net als je gewend bent.'
        ForcedInfo             = 'Wil je niet wachten? Sla je werk op, sluit VDI af en klik op Nu installeren.'
        InstallingHeading      = 'Omnissa Horizon wordt geïnstalleerd'
        InstallingMessage      = 'VMware Horizon wordt vervangen door Omnissa Horizon. Je kunt VDI even niet gebruiken. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
        SuccessHeading         = 'Omnissa Horizon is geïnstalleerd'
        SuccessMessage         = 'Omnissa Horizon vervangt voortaan VMware Horizon. Je logt weer in op je VDI-werkplek via ''Inloggen VDI werkplek'', net als je gewend bent.'
        ErrorHeading           = ''
        ErrorMessage           = 'Er ging iets mis bij het installeren van Omnissa Horizon. Werkt VDI niet? Neem dan contact op met de servicedesk.'
        RestartSubHeading      = ''
        RestartMessage         = ''
        RestartForcedSubHeading= ''
        RestartForcedMessage   = ''
        UninstallingHeading    = ''
        UninstallingMessage    = ''
        UninstalledHeading     = ''
        UninstalledMessage     = ''
        UninstallErrorHeading  = ''
        UninstallErrorMessage  = ''
        NewConsentSubHeading   = ''
        NewConsentMessage      = ''
        NewForcedSubHeading    = ''
        NewForcedMessage       = ''
        NewForcedInfo          = ''
        NewInstallingHeading   = ''
        NewInstallingMessage   = ''
        NewSuccessHeading      = ''
        NewSuccessMessage      = ''
        NewErrorHeading        = ''
        NewErrorMessage        = ''
        NewRestartMessage      = ''
        NewRestartForcedMessage= ''
    }
    TextsEn = @{
        ConsentSubHeading      = 'VMware Horizon becomes Omnissa Horizon'
        ConsentMessage         = 'VMware Horizon is now called Omnissa Horizon. The new version is ready for you. Afterwards you sign in to your VDI workspace the same way, through ''Inloggen VDI werkplek''. During the update (a few minutes) you cannot use VDI. Save your work in VDI before you click Update now.'
        ForcedSubHeading       = ''
        ForcedMessage          = 'You have postponed the switch from VMware Horizon to Omnissa Horizon {MaxPostpones} times. In {Minutes} minutes the new Omnissa Horizon will be installed automatically. Save your work in VDI and close VDI. Afterwards you sign in through ''Inloggen VDI werkplek'', as usual.'
        ForcedInfo             = 'Do not want to wait? Save your work, close VDI and click Install now.'
        InstallingHeading      = 'Installing Omnissa Horizon'
        InstallingMessage      = 'VMware Horizon is being replaced by Omnissa Horizon. You cannot use VDI for a moment. You do not need to do anything; we will let you know when it is done.'
        SuccessHeading         = 'Omnissa Horizon has been installed'
        SuccessMessage         = 'Omnissa Horizon now replaces VMware Horizon. You sign in to your VDI workspace through ''Inloggen VDI werkplek'', as usual.'
        ErrorHeading           = ''
        ErrorMessage           = 'Something went wrong while installing Omnissa Horizon. Is VDI not working? Please contact the service desk.'
        RestartSubHeading      = ''
        RestartMessage         = ''
        RestartForcedSubHeading= ''
        RestartForcedMessage   = ''
        UninstallingHeading    = ''
        UninstallingMessage    = ''
        UninstalledHeading     = ''
        UninstalledMessage     = ''
        UninstallErrorHeading  = ''
        UninstallErrorMessage  = ''
        NewConsentSubHeading   = ''
        NewConsentMessage      = ''
        NewForcedSubHeading    = ''
        NewForcedMessage       = ''
        NewForcedInfo          = ''
        NewInstallingHeading   = ''
        NewInstallingMessage   = ''
        NewSuccessHeading      = ''
        NewSuccessMessage      = ''
        NewErrorHeading        = ''
        NewErrorMessage        = ''
        NewRestartMessage      = ''
        NewRestartForcedMessage= ''
    }
}

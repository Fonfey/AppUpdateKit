#  Gemaakt met de AppUpdateKit Builder. Je kunt dit bestand ook met de hand aanpassen.
#  Texts = Nederlands, TextsEn = Engels. In teksten: {AppName}, {Versie}, {Minuten}, {MaxUitstel}. Leeg = standaardtekst.
@{
    # ---------- 1. Basis ----------
    AppId      = 'NotepadPlusPlus'
    AppName    = 'Notepad++'
    Version    = '8.9.8.1'
    DetectName = 'Notepad++'
    Processes  = @('notepad++')

    # ---------- 2. Uiterlijk ----------
    Icon          = 'app.ico'
    AccentColor   = '#3B7A1E'
    PopupLanguage = 'Auto'   # Auto (Windows-taal van de gebruiker) | nl | en

    # ---------- 3. Wie krijgt de update ----------
    OnlyUpdateExisting = $true
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
        @{ File = 'npp.8.9.8.1.Installer.x64.exe'; Kind = 'NSIS'; Args = '/S'; Codes = '0 3010 1641'; Main = $true; ProductCode = '' }
    )
    PreInstall  = ''    # cmd-regels vóór de onderdelen
    PostInstall = 'rem Ingebouwde updater uitschakelen: Intune regelt de updates
if exist "%ProgramFiles%\Notepad++\updater" rmdir /s /q "%ProgramFiles%\Notepad++\updater"'    # cmd-regels na de onderdelen

    # ---------- 6. Teksten voor deze app/versie (leeg = _Kit\Standaardteksten.psd1) ----------
    Texts = @{
        ConsentSubHeading      = ''
        ConsentMessage         = 'Er staat een nieuwe versie van {AppName} voor je klaar. Je openstaande bestanden blijven bewaard. Tijdens de update (minder dan een minuut) kun je {AppName} even niet gebruiken.'
        ForcedSubHeading       = ''
        ForcedMessage          = ''
        ForcedInfo             = ''
        InstallingHeading      = ''
        InstallingMessage      = ''
        SuccessHeading         = ''
        SuccessMessage         = ''
        ErrorHeading           = ''
        ErrorMessage           = ''
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
        ConsentSubHeading      = ''
        ConsentMessage         = 'A new version of {AppName} is ready for you. Your open files are kept. During the update (less than a minute) you cannot use {AppName}.'
        ForcedSubHeading       = ''
        ForcedMessage          = ''
        ForcedInfo             = ''
        InstallingHeading      = ''
        InstallingMessage      = ''
        SuccessHeading         = ''
        SuccessMessage         = ''
        ErrorHeading           = ''
        ErrorMessage           = ''
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

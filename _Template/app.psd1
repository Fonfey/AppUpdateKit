#  ===========================================================================
#   APP-GEGEVENS  -  vul de waarden tussen de aanhalingstekens in
#  ===========================================================================
#   Teksten die je leeg laat ('') komen uit _Kit\Standaardteksten.psd1.
#   In alle teksten kun je gebruiken:
#     {AppName}     -> de naam hieronder
#     {Versie}      -> de versie hieronder
#     {Minuten}     -> ForcedDelayMinutes
#     {MaxUitstel}  -> MaxPostpones
#  ===========================================================================
@{
    # ---------- 1. Basis (verplicht) ----------
    AppId      = 'MijnApp'          # interne naam, zonder spaties (map, log, teller)
    AppName    = 'Mijn App'         # naam zoals de gebruiker hem in de vensters ziet
    Version    = '1.0.0'            # versie die dit pakket installeert (detectie in Intune)
    DetectName = 'Mijn App'         # naam in "Apps en onderdelen" (begint met ...)
    Processes  = @('mijnapp')       # processen die dicht moeten zijn, zonder .exe
    OutputFolder = ''                # map voor het pakket, bijv. I:\...\versies\1.2.3\intune-package; leeg = Output in de kit

    # Detectie: hoe Intune ziet dat de app er staat (ook in te stellen in de Builder, tabblad 1)
    DetectionMethod = 'AppsEnOnderdelen'   # AppsEnOnderdelen | Bestand | Register | Script
    DetectVersion   = ''   # leeg = Version hierboven; '-' = alleen kijken of het bestaat
    DetectFile      = ''   # bij Bestand, bijv. '%ProgramFiles%\Remote help\RemoteHelp.exe'
    DetectRegKey    = ''   # bij Register, bijv. 'HKLM\SOFTWARE\Leverancier\App'
    DetectRegValue  = ''   # bij Register, bijv. 'Version' (leeg = alleen de sleutel)
    DetectScript    = ''   # bij Script: eigen PowerShell-detectiescript
                                    #   meerdere: @('proces1', 'proces2')

    # ---------- 2. Uiterlijk ----------
    Icon        = 'app.ico'         # logo (.ico) in deze map; liefst met 256x256 erin
    AccentColor = '#185FA5'         # kleur van de kop en de knop "Nu bijwerken"

    # ---------- 3. Wie krijgt de update ----------
    OnlyUpdateExisting = $true      # $true  = alleen apparaten waar de app al staat
                                    # $false = iedereen in de toegewezen groep
    InstallDuringSetup = $true      # $true  = nieuwe laptops (Autopilot): direct installeren, zonder popup,
                                    #          ook als OnlyUpdateExisting aan staat
                                    # $false = tijdens Autopilot overslaan, daarna gewoon met popup

    # ---------- 4. Uitstellen ----------
    MaxPostpones          = 5       # hoe vaak "Later" mag
    PostponeHours         = 24      # hoe lang een keer uitstellen duurt
    ConsentTimeoutMinutes = 15      # na zoveel minuten zonder keuze: venster sluiten en later opnieuw vragen
    ForcedDelayMinutes    = 5       # na de laatste keer uitstellen: zoveel minuten waarschuwing
                                    #   0 = zonder waarschuwing installeren

    # ---------- 4b. Wanneer ----------
    InstallWindow = 'Altijd'        # 'Altijd'         = op elk moment
                                    # 'Werktijd'       = alleen op werkdagen binnen de werktijd
                                    # 'BuitenWerktijd' = alleen 's avonds, 's nachts en in het weekend
    WorkHours     = '08:00-17:00'   # tijden (van-tot); meerdere blokken mag: '09:00-10:00,13:00-14:00'
    WorkDays      = 'ma,di,wo,do,vr'
    IdleMinutes   = 0               # > 0: zo lang niets gedaan of scherm vergrendeld -> direct installeren, zonder popup
    NoUserAction  = 'Installeren'   # niemand ingelogd: 'Installeren' (direct, ook buiten het tijdvenster) of 'Wachten'

    # ---------- 4c. Herstart na de installatie ----------
    RestartMode            = 'Nooit'   # 'Nooit' | 'AlsNodig' (installer geeft 3010/1641) | 'Altijd'
    RestartReminderMinutes = 60        # Later bij de herstartmelding: opnieuw vragen na (minuten)
    RestartDeadlineHours   = 24        # na zoveel uur verplicht herstarten (0 = nooit verplicht)
    RestartWarningMinutes  = 15        # waarschuwing met aftelklok voor de verplichte herstart

    # ---------- 4d. Verwijderen ----------
    UninstallNotify = $false        # $true = meldingen rechtsonder bij het verwijderen van de app

    # ---------- 5. Installatie (voor de Builder) ----------
    # Werk je zonder Builder? Dan schrijf je de stappen zelf in install-app.cmd en mag dit leeg blijven.
    AutoInstallSteps = $false       # $true = de Builder maakt install-app.cmd uit de onderdelen hieronder
    Components = @(
        # @{ File = 'runtime.exe'; Kind = 'EXE'; Args = '/install /quiet /norestart'; Codes = '0 3010 1641 1638'; Main = $false; ProductCode = '' }
        # @{ File = 'MijnApp.msi'; Kind = 'MSI'; Args = 'ALLUSERS=1';                 Codes = '0 3010 1641';      Main = $true;  ProductCode = '' }
    )
    PreInstall  = ''                # cmd-regels vóór de onderdelen
    PostInstall = ''                # cmd-regels na de onderdelen

    # ---------- 6. Teksten voor deze app/versie (leeg = standaardtekst) ----------
    Texts = @{
        # Venster "Update beschikbaar" (Later / Nu bijwerken)
        ConsentSubHeading = ''
        ConsentMessage    = ''

        # Waarschuwing na de laatste keer uitstellen (alleen "Nu installeren")
        ForcedSubHeading  = ''
        ForcedMessage     = ''
        ForcedInfo        = ''

        # Meldingen rechtsonder
        InstallingHeading = ''
        InstallingMessage = ''
        SuccessHeading    = ''
        SuccessMessage    = ''
        ErrorHeading      = ''
        ErrorMessage      = ''

        # Herstartmelding ({Minuten} = waarschuwingstijd voor de herstart)
        RestartSubHeading       = ''
        RestartMessage          = ''
        RestartForcedSubHeading = ''
        RestartForcedMessage    = ''

        # Meldingen bij het verwijderen
        UninstallingHeading     = ''
        UninstallingMessage     = ''
        UninstalledHeading      = ''
        UninstalledMessage      = ''
        UninstallErrorHeading   = ''
        UninstallErrorMessage   = ''

        # Nieuwe installatie: de app stond nog niet op de laptop (leeg = standaardtekst voor een installatie)
        NewConsentSubHeading    = ''
        NewConsentMessage       = ''
        NewForcedSubHeading     = ''
        NewForcedMessage        = ''
        NewForcedInfo           = ''
        NewInstallingHeading    = ''
        NewInstallingMessage    = ''
        NewSuccessHeading       = ''
        NewSuccessMessage       = ''
        NewErrorHeading         = ''
        NewErrorMessage         = ''
        NewRestartMessage       = ''
        NewRestartForcedMessage = ''
    }
}

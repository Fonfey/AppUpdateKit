#  ===========================================================================
#   APP DETAILS  -  fill in the values between the quotes
#  ===========================================================================
#   Texts you leave empty ('') come from _Kit\Standaardteksten.psd1.
#   You can use these tokens in all texts:
#     {AppName}       -> the name below
#     {Version}       -> the version below
#     {Minutes}       -> ForcedDelayMinutes
#     {MaxPostpones}  -> MaxPostpones
#   Some values stay in Dutch because the scripts use them (e.g. 'Altijd', 'Werktijd', 'Nooit').
#  ===========================================================================
@{
    # ---------- 1. Basics (required) ----------
    AppId      = 'MijnApp'          # internal name without spaces (folder, log, counter)
    AppName    = 'Mijn App'         # name as the user sees it in the popups
    Version    = '1.0.0'            # version this package installs (detection in Intune)
    DetectName = 'Mijn App'         # name in "Apps & features" (starts with ...)
    Processes  = @('mijnapp')       # processes that must be closed, without .exe
                                    #   several: @('process1', 'process2')

    # ---------- 2. Appearance ----------
    Icon        = 'app.ico'         # logo (.ico) in this folder; preferably containing 256x256
    AccentColor = '#185FA5'         # colour of the header and the "Update now" button
    PopupLanguage = 'Auto'          # popup language: 'Auto' (user's Windows language), 'nl' or 'en'

    # ---------- 3. Who gets the update ----------
    OnlyUpdateExisting = $true      # $true  = only devices where the app is already installed
                                    # $false = everyone in the assigned group
    InstallDuringSetup = $true      # $true  = new laptops (Autopilot): install right away, no popup,
                                    #          also when OnlyUpdateExisting is on
                                    # $false = skip during Autopilot, afterwards normally with popup

    # ---------- 4. Postponing ----------
    MaxPostpones          = 5       # how often "Later" is allowed
    PostponeHours         = 24      # how long one postpone lasts
    ConsentTimeoutMinutes = 15      # after this many minutes without a choice: close the popup and ask again later
    ForcedDelayMinutes    = 5       # after the last postpone: this many minutes warning
                                    #   0 = install without warning

    # ---------- 4b. When ----------
    InstallWindow = 'Altijd'        # 'Altijd'         = any time
                                    # 'Werktijd'       = only on working days during working hours
                                    # 'BuitenWerktijd' = only in the evening, at night and at the weekend
    WorkHours     = '08:00-17:00'   # working hours (from-to)
    WorkDays      = 'ma,di,wo,do,vr' # working days: ma=Mon di=Tue wo=Wed do=Thu vr=Fri za=Sat zo=Sun
    IdleMinutes   = 0               # > 0: idle this long or screen locked -> install right away, no popup
    NoUserAction  = 'Installeren'   # nobody signed in: 'Installeren' (right away, also outside the time window) or 'Wachten' (wait)

    # ---------- 4c. Restart after installation ----------
    RestartMode            = 'Nooit'   # 'Nooit' (never) | 'AlsNodig' (installer returns 3010/1641) | 'Altijd' (always)
    RestartReminderMinutes = 60        # Later on the restart prompt: ask again after (minutes)
    RestartDeadlineHours   = 24        # mandatory restart after this many hours (0 = never mandatory)
    RestartWarningMinutes  = 15        # warning with countdown before the mandatory restart

    # ---------- 4d. Uninstall ----------
    UninstallNotify = $false        # $true = notifications bottom right when the app is removed

    # ---------- 5. Installation (for the Builder) ----------
    # Working without the Builder? Then write the steps yourself in install-app.cmd; this may stay empty.
    AutoInstallSteps = $false       # $true = the Builder creates install-app.cmd from the components below
    Components = @(
        # @{ File = 'runtime.exe'; Kind = 'EXE'; Args = '/install /quiet /norestart'; Codes = '0 3010 1641 1638'; Main = $false; ProductCode = '' }
        # @{ File = 'MyApp.msi';   Kind = 'MSI'; Args = 'ALLUSERS=1';                 Codes = '0 3010 1641';      Main = $true;  ProductCode = '' }
    )
    PreInstall  = ''                # cmd lines before the components
    PostInstall = ''                # cmd lines after the components

    # ---------- 6. Texts for this app/version (empty = standard text) ----------
    # Texts   = Dutch
    # TextsEn = English, for users with English Windows
    Texts = @{
        # "Update available" window (Later / Update now)
        ConsentSubHeading       = ''
        ConsentMessage          = ''

        # Warning after the last postpone (only "Install now")
        ForcedSubHeading        = ''
        ForcedMessage           = ''
        ForcedInfo              = ''

        # Notifications bottom right
        InstallingHeading       = ''
        InstallingMessage       = ''
        SuccessHeading          = ''
        SuccessMessage          = ''
        ErrorHeading            = ''
        ErrorMessage            = ''

        # Restart prompt ({Minutes} = warning time before the restart)
        RestartSubHeading       = ''
        RestartMessage          = ''
        RestartForcedSubHeading = ''
        RestartForcedMessage    = ''

        # Notifications when removing
        UninstallingHeading     = ''
        UninstallingMessage     = ''
        UninstalledHeading      = ''
        UninstalledMessage      = ''
        UninstallErrorHeading   = ''
        UninstallErrorMessage   = ''

        # New installation: the app was not on the device yet (empty = standard text for an installation)
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

    TextsEn = @{
        # "Update available" window (Later / Update now)
        ConsentSubHeading       = ''
        ConsentMessage          = ''

        # Warning after the last postpone (only "Install now")
        ForcedSubHeading        = ''
        ForcedMessage           = ''
        ForcedInfo              = ''

        # Notifications bottom right
        InstallingHeading       = ''
        InstallingMessage       = ''
        SuccessHeading          = ''
        SuccessMessage          = ''
        ErrorHeading            = ''
        ErrorMessage            = ''

        # Restart prompt ({Minutes} = warning time before the restart)
        RestartSubHeading       = ''
        RestartMessage          = ''
        RestartForcedSubHeading = ''
        RestartForcedMessage    = ''

        # Notifications when removing
        UninstallingHeading     = ''
        UninstallingMessage     = ''
        UninstalledHeading      = ''
        UninstalledMessage      = ''
        UninstallErrorHeading   = ''
        UninstallErrorMessage   = ''

        # New installation: the app was not on the device yet (empty = standard text for an installation)
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

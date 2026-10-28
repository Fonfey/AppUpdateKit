#  ===========================================================================
#   APP DETAILS  -  fill in the values between the quotes
#  ===========================================================================
#   Texts you leave empty ('') come from _Kit\DefaultTexts.psd1.
#   In all texts you can use:
#     {AppName}     -> the name below
#     {Version}      -> the version below
#     {Minutes}      -> ForcedDelayMinutes
#     {MaxPostpones} -> MaxPostpones
#  ===========================================================================
@{
    # ---------- 1. Basics (required) ----------
    AppId      = 'MyApp'          # internal name, without spaces (folder, log, counter)
    AppName    = 'My App'         # name as the user sees it in the windows
    Version    = '1.0.0'            # version this package installs (detection in Intune)
    DetectName = 'My App'         # name in "Apps & features" (starts with ...)
    Processes  = @('mijnapp')       # processes that must be closed, without .exe
    OutputFolder = ''                # folder for the package, e.g. I:\...\versions\1.2.3\intune-package; empty = Output in the kit

    # Detection: how Intune sees that the app is present (can also be set in the Builder, tab 1)
    DetectionMethod = 'AppsAndFeatures'   # AppsAndFeatures | File | Registry | Script
    DetectVersion   = ''   # empty = Version above; '-' = only check whether it exists
    DetectFile      = ''   # with File, e.g. '%ProgramFiles%\Remote help\RemoteHelp.exe'
    DetectRegKey    = ''   # with Registry, e.g. 'HKLM\SOFTWARE\Vendor\App'
    DetectRegValue  = ''   # with Registry, e.g. 'Version' (empty = only the key)
    DetectScript    = ''   # with Script: own PowerShell detection script
                                    #   several: @('process1', 'process2')

    # ---------- 2. Appearance ----------
    Icon        = 'app.ico'         # logo (.ico) in this folder; preferably containing 256x256
    AccentColor = '#185FA5'         # colour of the header and the "Update now" button
    Language    = 'en'              # language of the popups and the scripts on the laptop: 'nl' or 'en'

    # ---------- 3. Who gets the update ----------
    OnlyUpdateExisting = $true      # $true  = only devices that already have the app
                                    # $false = everyone in the assigned group
    InstallDuringSetup = $true      # $true  = new laptops (Autopilot): install right away, without popup,
                                    #          also if OnlyUpdateExisting is on
                                    # $false = skip during Autopilot, then normally with popup

    # ---------- 4. Postpone ----------
    MaxPostpones          = 5       # how often "Later" is allowed
    PostponeHours         = 24      # how long one postpone lasts
    ConsentTimeoutMinutes = 15      # after this many minutes without a choice: close the window and ask again later
    ForcedDelayMinutes    = 5       # after the last postpone: this many minutes of warning
                                    #   0 = install without warning

    # ---------- 4b. When ----------
    InstallWindow = 'Always'        # 'Always'         = at any time
                                    # 'DuringWorkHours'       = only on working days within working hours
                                    # 'OutsideWorkHours' = only in the evening, at night and at the weekend
    WorkHours     = '08:00-17:00'   # times (from-to); multiple blocks allowed: '09:00-10:00,13:00-14:00'
    WorkDays      = 'mon,tue,wed,thu,fri'
    IdleMinutes   = 0               # > 0: this long without activity or screen locked -> install right away, without popup
    NoUserAction  = 'Install'   # nobody signed in: 'Install' (right away, also outside the time window) or 'Wait'

    # ---------- 4c. Restart after the installation ----------
    RestartMode            = 'Never'   # 'Never' | 'IfNeeded' (installer returns 3010/1641) | 'Always'
    RestartReminderMinutes = 60        # Later on the restart prompt: ask again after (minutes)
    RestartDeadlineHours   = 24        # forced restart after this many hours (0 = never forced)
    RestartWarningMinutes  = 15        # warning with countdown before the forced restart

    # ---------- 4d. Uninstall ----------
    UninstallNotify = $false        # $true = notifications bottom right when the app is removed

    # ---------- 5. Installation (for the Builder) ----------
    # Working without the Builder? Then you write the steps yourself in install-app.cmd and this may stay empty.
    AutoInstallSteps = $false       # $true = the Builder creates install-app.cmd from the components below
    Components = @(
        # @{ File = 'runtime.exe'; Kind = 'EXE'; Args = '/install /quiet /norestart'; Codes = '0 3010 1641 1638'; Main = $false; ProductCode = '' }
        # @{ File = 'MyApp.msi'; Kind = 'MSI'; Args = 'ALLUSERS=1';                 Codes = '0 3010 1641';      Main = $true;  ProductCode = '' }
    )
    PreInstall  = ''                # cmd lines before the components
    PostInstall = ''                # cmd lines after the components

    # ---------- 6. Texts for this app/version (empty = default text) ----------
    Texts = @{
        # Window "Update available" (Later / Update now)
        ConsentSubHeading = ''
        ConsentMessage    = ''

        # Warning after the last postpone (only "Install now")
        ForcedSubHeading  = ''
        ForcedMessage     = ''
        ForcedInfo        = ''

        # Notifications bottom right
        InstallingHeading = ''
        InstallingMessage = ''
        SuccessHeading    = ''
        SuccessMessage    = ''
        ErrorHeading      = ''
        ErrorMessage      = ''

        # Restart prompt ({Minutes} = warning time before the restart)
        RestartSubHeading       = ''
        RestartMessage          = ''
        RestartForcedSubHeading = ''
        RestartForcedMessage    = ''

        # Notifications on uninstall
        UninstallingHeading     = ''
        UninstallingMessage     = ''
        UninstalledHeading      = ''
        UninstalledMessage      = ''
        UninstallErrorHeading   = ''
        UninstallErrorMessage   = ''

        # New installation: the app was not on the laptop yet (empty = default text for an installation)
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

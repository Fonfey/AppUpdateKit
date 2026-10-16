<#
.SYNOPSIS
    Intune-installatiescript voor Notepad++ 8.9.8.1  (AppUpdateKit)

.DESCRIPTION
    Upload dit script in Intune bij de Win32-app:
      Program > Installer type: PowerShell script > Install script
    Het hoort NIET in het .intunewin-pakket. Daardoor kun je het later in Intune aanpassen
    (teksten, uitstellen, tijden, parameters, extra stappen) zonder opnieuw te verpakken.

    Opnieuw verpakken is alleen nodig bij een nieuwe installer, een ander logo of een nieuwe kit-versie.
    Neem een wijziging die je hier in Intune doet ook over in de Builder, anders is hij bij de volgende build weg.

    Gemaakt door de AppUpdateKit Builder op 2026-10-16 12:51.
#>

# =============================================================================
#  1. SCHAKELAARS  ($true = aan)
# =============================================================================
# Niet controleren of de app open staat (gebruik dan ook Requirement-zonder-procescheck.ps1)
$NoProcessCheck = $false
# Geen popup, direct installeren (meldingen rechtsonder blijven)
$NoPopup        = $false
# Geen popup en geen meldingen
$Silent         = $false

# Eigen schakelaars voor de stappen hieronder (in de cmd-regels beschikbaar als APP_<NAAM>)
$Switches = @{
    # bijvoorbeeld: NOSHORTCUTS = $true
}

# =============================================================================
#  2. INSTELLINGEN EN TEKSTEN  (zelfde betekenis als in app.psd1)
#     Texts = Nederlands, TextsEn = Engels (voor gebruikers met Engelse Windows). Leeg ('') = standaardtekst.
# =============================================================================
$App = @{
    AppId                  = 'NotepadPlusPlus'   # niet wijzigen: map, teller en log
    AppName                = 'Notepad++'   # naam in de vensters
    DetectName             = 'Notepad++'   # naam in Apps en onderdelen: bepaalt nieuwe installatie of update
    Version                = '8.9.8.1'   # versie in dit pakket (nieuwe versie = nieuw pakket)
    Processes              = @('notepad++')   # staan ook in Requirement.ps1
    Icon                   = 'app.ico'   # logo in het pakket
    AccentColor            = '#3B7A1E'   # kleur van de kop en de knop
    PopupLanguage          = 'Auto'   # taal van de popups: Auto (Windows-taal van de gebruiker) | nl | en
    KitLanguage            = 'nl'   # taal van de logbestanden: nl | en
    MaxPostpones           = 5   # hoe vaak Later mag
    PostponeHours          = 24   # hoe lang een keer uitstellen duurt (uren)
    ConsentTimeoutMinutes  = 15   # geen keuze: venster sluiten na (minuten)
    ForcedDelayMinutes     = 5   # waarschuwing na de laatste keer uitstellen (minuten)
    InstallWindow          = 'Altijd'   # Altijd | Werktijd | BuitenWerktijd  (staat ook in Requirement.ps1)
    WorkHours              = '08:00-17:00'   # werktijd (van-tot)
    WorkDays               = 'ma,di,wo,do,vr'   # werkdagen
    IdleMinutes            = 0   # > 0 = na zoveel minuten inactief of vergrendeld direct installeren
    NoUserAction           = 'Installeren'   # niemand ingelogd: Installeren | Wachten
    InstallDuringSetup     = $true   # nieuwe laptops (Autopilot) direct installeren (staat ook in Requirement.ps1)
    RestartMode            = 'Nooit'   # herstartmelding na de installatie: Nooit | AlsNodig (exitcode 3010/1641) | Altijd
    RestartReminderMinutes = 60   # Later bij de herstartmelding: opnieuw vragen na (minuten)
    RestartDeadlineHours   = 24   # na zoveel uur verplicht herstarten (0 = nooit verplicht)
    RestartWarningMinutes  = 15   # waarschuwing voor de verplichte herstart (minuten)
    Texts = @{
        ConsentSubHeading       = ''
        ConsentMessage          = 'Er staat een nieuwe versie van {AppName} voor je klaar. Je openstaande bestanden blijven bewaard. Tijdens de update (minder dan een minuut) kun je {AppName} even niet gebruiken.'
        ForcedSubHeading        = ''
        ForcedMessage           = ''
        ForcedInfo              = ''
        InstallingHeading       = ''
        InstallingMessage       = ''
        SuccessHeading          = ''
        SuccessMessage          = ''
        ErrorHeading            = ''
        ErrorMessage            = ''
        RestartSubHeading       = ''
        RestartMessage          = ''
        RestartForcedSubHeading = ''
        RestartForcedMessage    = ''
        UninstallingHeading     = ''
        UninstallingMessage     = ''
        UninstalledHeading      = ''
        UninstalledMessage      = ''
        UninstallErrorHeading   = ''
        UninstallErrorMessage   = ''
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
        ConsentSubHeading       = ''
        ConsentMessage          = 'A new version of {AppName} is ready for you. Your open files are kept. During the update (less than a minute) you cannot use {AppName}.'
        ForcedSubHeading        = ''
        ForcedMessage           = ''
        ForcedInfo              = ''
        InstallingHeading       = ''
        InstallingMessage       = ''
        SuccessHeading          = ''
        SuccessMessage          = ''
        ErrorHeading            = ''
        ErrorMessage            = ''
        RestartSubHeading       = ''
        RestartMessage          = ''
        RestartForcedSubHeading = ''
        RestartForcedMessage    = ''
        UninstallingHeading     = ''
        UninstallingMessage     = ''
        UninstalledHeading      = ''
        UninstalledMessage      = ''
        UninstallErrorHeading   = ''
        UninstallErrorMessage   = ''
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

# =============================================================================
#  3. INSTALLATIESTAPPEN
#     Onderdelen worden in volgorde uitgevoerd vanuit de pakketmap.
#     Command = de opdrachtregel (met parameters); SuccessCodes = exitcodes die als gelukt tellen.
# =============================================================================
$Components = @(
    @{ Name = 'npp.8.9.8.1.Installer.x64'; Command = '"npp.8.9.8.1.Installer.x64.exe" /S'; SuccessCodes = 0, 3010, 1641 }
)

# cmd-regels voor en na de onderdelen (mogen leeg blijven)
$PreInstall = @'

'@

$PostInstall = @'
rem Ingebouwde updater uitschakelen: Intune regelt de updates
if exist "%ProgramFiles%\Notepad++\updater" rmdir /s /q "%ProgramFiles%\Notepad++\updater"
'@

# Eigen installatiescript (alleen gebruikt als er hierboven geen onderdelen staan)
$CustomScript = @'

'@


# =============================================================================
#  VANAF HIER NIET AANPASSEN
# =============================================================================
$ErrorActionPreference = 'Stop'

# Package folder: Intune starts this script from the extracted content of the .intunewin package
$PackageDir = (Get-Location).Path
foreach ($candidate in @($PackageDir, $PSScriptRoot)) {
    if ($candidate -and (Test-Path (Join-Path $candidate 'AppUI-Launcher.ps1'))) { $PackageDir = $candidate; break }
}
$AppDir = Join-Path 'C:\ProgramData\AppUpdates' $App.AppId
if (-not (Test-Path $AppDir)) { New-Item -Path $AppDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $AppDir 'update.log'

function Write-InstallLog([string]$Text) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [install] $Text"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host $line   # Write-Host: does not end up in the output of functions
}

if (-not (Test-Path (Join-Path $PackageDir 'AppUI-Launcher.ps1'))) {
    Write-InstallLog "FOUT: de pakketinhoud is niet gevonden ($PackageDir). Hoort install.intunewin van $($App.AppName) bij dit script?"
    exit 1
}
Set-Location $PackageDir
Write-InstallLog "Start $($App.AppName) $($App.Version) (PowerShell-installer, pakket: $PackageDir)"

# Settings for the popups (they read this file instead of app.psd1)
$configFile = Join-Path $AppDir 'app.json'
[System.IO.File]::WriteAllText($configFile, ($App | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
$env:APPKIT_CONFIG = $configFile

# Pass the switches to the cmd lines
foreach ($name in @($Switches.Keys)) {
    if ($Switches[$name]) { Set-Item -Path "env:APP_$($name.ToUpper())" -Value '1' }
}

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Invoke-KitScript([string]$Name, [string[]]$Arguments = @()) {
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackageDir $Name) @Arguments | Out-Null
    return $LASTEXITCODE
}

# New installation or update? (decides the texts in the popups)
$env:APPKIT_NEWINSTALL = if ((Invoke-KitScript 'Test-AppInstalled.ps1') -ne 0) { '1' } else { '0' }

$on = @(@{ NoProcessCheck = $NoProcessCheck; NoPopup = $NoPopup; Silent = $Silent }.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key }) +
      @($Switches.Keys | Where-Object { $Switches[$_] })
if ($on) { Write-InstallLog "Schakelaars aan: $($on -join ', ')" }

function Invoke-CmdBlock([string]$Text, [string]$Name) {
    # Run cmd lines in the package folder; returns the exit code
    $stepDir = Join-Path $AppDir 'Stappen'
    if (-not (Test-Path $stepDir)) { New-Item -Path $stepDir -ItemType Directory -Force | Out-Null }
    $file = Join-Path $stepDir "$Name.cmd"
    $content = "@echo off`r`ncd /d `"$PackageDir`"`r`n" + ($Text -replace "`r?`n", "`r`n") + "`r`nexit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::Default)
    & $env:ComSpec /c $file | ForEach-Object { Add-Content -Path $LogFile -Value "    $_" -ErrorAction SilentlyContinue }
    $rc = $LASTEXITCODE
    Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
    return $rc
}

function Invoke-Installation {
    $result = 0
    if ($PreInstall.Trim()) {
        $rc = Invoke-CmdBlock $PreInstall 'pre'
        Write-InstallLog "Stappen voor de installatie klaar (exitcode $rc)"
    }

    $list = @($Components | Where-Object { $_ })
    if (-not $list.Count -and $CustomScript.Trim()) {
        Write-InstallLog 'Eigen installatiescript wordt uitgevoerd'
        return (Invoke-CmdBlock ("set APP_EXITCODE=0`r`n" + $CustomScript) 'custom-script')
    }

    $n = 0
    foreach ($c in $list) {
        $n++
        Write-InstallLog "Onderdeel $n ($($c.Name)): $($c.Command)"
        $rc = Invoke-CmdBlock $c.Command "component$n"
        $ok = @($c.SuccessCodes | ForEach-Object { [int]$_ })
        if (-not $ok.Count) { $ok = 0, 3010, 1641 }
        if ($ok -notcontains $rc) {
            Write-InstallLog "Onderdeel $n ($($c.Name)) is mislukt met exitcode $rc"
            return $rc
        }
        Write-InstallLog "Onderdeel $n ($($c.Name)) gelukt (exitcode $rc)"
        if ($rc -eq 3010 -or $rc -eq 1641) { $result = $rc }
    }

    if ($PostInstall.Trim()) {
        $rc = Invoke-CmdBlock $PostInstall 'post'
        Write-InstallLog "Stappen na de installatie klaar (exitcode $rc)"
    }
    return $result
}

try {
    if ($Silent) { $NoPopup = $true }

    # 1. App must not be running (Intune retries later)
    if (-not $NoProcessCheck -and (Invoke-KitScript 'Test-AppRunning.ps1') -ne 0) { exit 1618 }

    # 2. Ask for consent (Later = postpone: stop without installing)
    if (-not $NoPopup) {
        if ((Invoke-KitScript 'Ask-InstallConsent.ps1') -ne 0) {
            Write-InstallLog 'Installatie voor nu overgeslagen (uitgesteld, buiten tijdvenster of geen reactie).'
            exit 0
        }
        # 3. Again: the app may have been opened while the popup or countdown was showing
        if (-not $NoProcessCheck -and (Invoke-KitScript 'Test-AppRunning.ps1') -ne 0) { exit 1618 }
    }

    if (-not $Silent) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Installing') | Out-Null }

    # 4. Installation steps
    $exitCode = [int](Invoke-Installation)

    # 5. Result (0, 3010, 1641 = success)
    if (@(0, 3010, 1641) -contains $exitCode) {
        Remove-Item -Path (Join-Path $AppDir 'PostponeState.json') -Force -ErrorAction SilentlyContinue
        if (-not $Silent) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Success') | Out-Null }
        Write-InstallLog "Installatie gelukt (exitcode $exitCode)"
        # Restart prompt (RestartMode); returns 0 when the kit handles the restart
        if (-not $Silent) { $exitCode = Invoke-KitScript 'Set-RestartPrompt.ps1' @('-ExitCode', "$exitCode") }
    }
    else {
        if (-not $Silent) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Error') | Out-Null }
        Write-InstallLog "Installatie mislukt (exitcode $exitCode)"
    }
    exit $exitCode
}
catch {
    Write-InstallLog "FOUT: $($_.Exception.Message)"
    exit 1
}

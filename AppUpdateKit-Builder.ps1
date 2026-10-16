<#
.SYNOPSIS
    AppUpdateKit Builder - form to create update packages with popups.
    Start with Start-Builder.cmd (double-click).

.DESCRIPTION
    - Pick an app or create a new one (folder Apps\<AppId>)
    - Pick the installer: name, version, type and silent parameters are detected
    - Logo (.svg/.ico/.png/.jpg), colour, postpone rules and texts (Dutch and English)
    - Preview of every popup on your own screen
    - Save and build the .intunewin package (through 2-Bouw-pakket.ps1)
    - Interface language Dutch / English (stored in _Kit\Settings.psd1)
#>

$ErrorActionPreference = 'Stop'
# Kit folder (also when $PSScriptRoot is empty, e.g. when started from PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Kan de AppUpdateKit-map niet vinden / Cannot find the AppUpdateKit folder. cd <AppUpdateKit> ; .\AppUpdateKit-Builder.ps1"
}
$AppsRoot = Join-Path $KitRoot 'Apps'
$KitDir   = Join-Path $KitRoot '_Kit'

# ---------- Interface language (Builder, messages, generated files) ----------
$SettingsPath = Join-Path $KitDir 'Settings.psd1'
$script:Lang = 'nl'
if (Test-Path $SettingsPath) { try { if ((Import-PowerShellDataFile $SettingsPath).Language -eq 'en') { $script:Lang = 'en' } } catch { } }
if ($env:APPKIT_LANG -in 'nl', 'en') { $script:Lang = $env:APPKIT_LANG }
function T([string]$Nl, [string]$En) { if ($script:Lang -eq 'en') { return $En } else { return $Nl } }

function Save-KitLanguage([string]$Language)
{
    $text = "# AppUpdateKit - instellingen van de kit / kit settings (de Builder past dit aan / the Builder updates this)`r`n@{`r`n    Language = '$Language'   # nl | en`r`n}`r`n"
    [System.IO.File]::WriteAllText($SettingsPath, $text, (New-Object System.Text.UTF8Encoding $true))
}

$TextKeys = @('ConsentSubHeading', 'ConsentMessage', 'ForcedSubHeading', 'ForcedMessage', 'ForcedInfo',
              'InstallingHeading', 'InstallingMessage', 'SuccessHeading', 'SuccessMessage', 'ErrorHeading', 'ErrorMessage',
              'RestartSubHeading', 'RestartMessage', 'RestartForcedSubHeading', 'RestartForcedMessage',
              'UninstallingHeading', 'UninstallingMessage', 'UninstalledHeading', 'UninstalledMessage', 'UninstallErrorHeading', 'UninstallErrorMessage',
              'NewConsentSubHeading', 'NewConsentMessage', 'NewForcedSubHeading', 'NewForcedMessage', 'NewForcedInfo', 'NewInstallingHeading', 'NewInstallingMessage', 'NewSuccessHeading', 'NewSuccessMessage', 'NewErrorHeading', 'NewErrorMessage', 'NewRestartMessage', 'NewRestartForcedMessage')

# Ingebouwde teksten; worden overschreven door _Kit\Standaardteksten.psd1 (zie Get-StandardTexts)
$BuiltinTexts = [ordered]@{
    ConsentSubHeading = 'Er is een update beschikbaar'
    ConsentMessage    = 'Er staat een nieuwe versie van {AppName} voor je klaar. Tijdens de update (een paar minuten) kun je {AppName} even niet gebruiken.'
    ForcedSubHeading  = 'De update start over {Minuten} minuten'
    ForcedMessage     = 'Je hebt de update van {AppName} {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt de nieuwe versie automatisch geïnstalleerd. Sla je werk op en sluit {AppName} af.'
    ForcedInfo        = 'Wil je niet wachten? Sla je werk op, sluit {AppName} af en klik op Nu installeren.'
    InstallingHeading = 'Update wordt geïnstalleerd'
    InstallingMessage = '{AppName} wordt bijgewerkt en is even niet beschikbaar. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    SuccessHeading    = 'Update geïnstalleerd'
    SuccessMessage    = 'De nieuwe versie van {AppName} staat klaar. Je kunt de app weer gebruiken.'
    ErrorHeading      = 'Update niet gelukt'
    ErrorMessage      = 'Er ging iets mis bij het bijwerken van {AppName}. Werkt de app niet? Neem dan contact op met de servicedesk.'
    RestartSubHeading       = 'Herstart nodig'
    RestartMessage          = '{AppName} is bijgewerkt. Herstart je laptop om de update af te ronden. Sla eerst je werk op.'
    RestartForcedSubHeading = 'Je laptop wordt over {Minuten} minuten herstart'
    RestartForcedMessage    = '{AppName} is bijgewerkt en je laptop moet herstarten om de update af te ronden. Sla je werk op en sluit je programma''s af.'
    UninstallingHeading     = '{AppName} wordt verwijderd'
    UninstallingMessage     = '{AppName} wordt van je laptop verwijderd en is even niet beschikbaar. Je hoeft niets te doen.'
    UninstalledHeading      = '{AppName} is verwijderd'
    UninstalledMessage      = '{AppName} staat niet meer op je laptop.'
    UninstallErrorHeading   = 'Verwijderen niet gelukt'
    UninstallErrorMessage   = 'Er ging iets mis bij het verwijderen van {AppName}. Geeft dit problemen? Neem dan contact op met de servicedesk.'
    NewConsentSubHeading    = 'Er staat een nieuwe app voor je klaar'
    NewConsentMessage       = '{AppName} wordt op je laptop geïnstalleerd. Dat duurt een paar minuten.'
    NewForcedSubHeading     = 'De installatie start over {Minuten} minuten'
    NewForcedMessage        = 'Je hebt de installatie van {AppName} {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt {AppName} automatisch geïnstalleerd. Sla je werk op.'
    NewForcedInfo           = 'Wil je niet wachten? Sla je werk op en klik op Nu installeren.'
    NewInstallingHeading    = '{AppName} wordt geïnstalleerd'
    NewInstallingMessage    = '{AppName} wordt op je laptop geïnstalleerd. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    NewSuccessHeading       = '{AppName} is geïnstalleerd'
    NewSuccessMessage       = '{AppName} staat klaar. Je vindt de app in het startmenu.'
    NewErrorHeading         = 'Installatie niet gelukt'
    NewErrorMessage         = 'Er ging iets mis bij het installeren van {AppName}. Heb je de app nodig? Neem dan contact op met de servicedesk.'
    NewRestartMessage       = '{AppName} is geïnstalleerd. Herstart je laptop om de installatie af te ronden. Sla eerst je werk op.'
    NewRestartForcedMessage = '{AppName} is geïnstalleerd en je laptop moet herstarten om de installatie af te ronden. Sla je werk op en sluit je programma''s af.'
}
# Built-in English texts (users with English Windows)
$BuiltinTextsEn = [ordered]@{
    ConsentSubHeading       = 'An update is available'
    ConsentMessage          = 'A new version of {AppName} is ready for you. During the update (a few minutes) you cannot use {AppName}.'
    ForcedSubHeading        = 'The update starts in {Minutes} minutes'
    ForcedMessage           = 'You have postponed the update of {AppName} {MaxPostpones} times. In {Minutes} minutes the new version will be installed automatically. Save your work and close {AppName}.'
    ForcedInfo              = 'Do not want to wait? Save your work, close {AppName} and click Install now.'
    InstallingHeading       = 'Installing update'
    InstallingMessage       = '{AppName} is being updated and is briefly unavailable. You do not need to do anything; we will let you know when it is done.'
    SuccessHeading          = 'Update installed'
    SuccessMessage          = 'The new version of {AppName} is ready. You can use the app again.'
    ErrorHeading            = 'Update failed'
    ErrorMessage            = 'Something went wrong while updating {AppName}. Is the app not working? Please contact the service desk.'
    RestartSubHeading       = 'Restart required'
    RestartMessage          = '{AppName} has been updated. Restart your laptop to finish the update. Save your work first.'
    RestartForcedSubHeading = 'Your laptop will restart in {Minutes} minutes'
    RestartForcedMessage    = '{AppName} has been updated and your laptop needs to restart to finish the update. Save your work and close your programs.'
    UninstallingHeading     = 'Removing {AppName}'
    UninstallingMessage     = '{AppName} is being removed from your laptop and is briefly unavailable. You do not need to do anything.'
    UninstalledHeading      = '{AppName} has been removed'
    UninstalledMessage      = '{AppName} is no longer on your laptop.'
    UninstallErrorHeading   = 'Removal failed'
    UninstallErrorMessage   = 'Something went wrong while removing {AppName}. Does this cause problems? Please contact the service desk.'
    NewConsentSubHeading    = 'A new app is ready for you'
    NewConsentMessage       = '{AppName} will be installed on your laptop. This takes a few minutes.'
    NewForcedSubHeading     = 'The installation starts in {Minutes} minutes'
    NewForcedMessage        = 'You have postponed the installation of {AppName} {MaxPostpones} times. In {Minutes} minutes {AppName} will be installed automatically. Save your work.'
    NewForcedInfo           = 'Do not want to wait? Save your work and click Install now.'
    NewInstallingHeading    = 'Installing {AppName}'
    NewInstallingMessage    = '{AppName} is being installed on your laptop. You do not need to do anything; we will let you know when it is done.'
    NewSuccessHeading       = '{AppName} has been installed'
    NewSuccessMessage       = '{AppName} is ready. You can find the app in the Start menu.'
    NewErrorHeading         = 'Installation failed'
    NewErrorMessage         = 'Something went wrong while installing {AppName}. Do you need the app? Please contact the service desk.'
    NewRestartMessage       = '{AppName} has been installed. Restart your laptop to finish the installation. Save your work first.'
    NewRestartForcedMessage = '{AppName} has been installed and your laptop needs to restart to finish the installation. Save your work and close your programs.'
}
$StandardTextsPath = Join-Path $KitDir 'Standaardteksten.psd1'
$TextLabels = [ordered]@{
    ConsentSubHeading = 'Venster "Update beschikbaar" - ondertitel'
    ConsentMessage    = 'Venster "Update beschikbaar" - tekst'
    ForcedSubHeading  = 'Waarschuwing na laatste keer uitstellen - ondertitel'
    ForcedMessage     = 'Waarschuwing na laatste keer uitstellen - tekst'
    ForcedInfo        = 'Waarschuwing - oranje regel'
    InstallingHeading = 'Melding tijdens installatie - kop'
    InstallingMessage = 'Melding tijdens installatie - tekst'
    SuccessHeading    = 'Melding geslaagd - kop'
    SuccessMessage    = 'Melding geslaagd - tekst'
    ErrorHeading      = 'Melding mislukt - kop'
    ErrorMessage      = 'Melding mislukt - tekst'
    RestartSubHeading       = 'Herstartmelding - ondertitel'
    RestartMessage          = 'Herstartmelding - tekst'
    RestartForcedSubHeading = 'Verplichte herstart - ondertitel ({Minuten} = waarschuwingstijd)'
    RestartForcedMessage    = 'Verplichte herstart - tekst'
    UninstallingHeading     = 'Verwijderen - melding tijdens verwijderen, kop'
    UninstallingMessage     = 'Verwijderen - melding tijdens verwijderen, tekst'
    UninstalledHeading      = 'Verwijderen - melding verwijderd, kop'
    UninstalledMessage      = 'Verwijderen - melding verwijderd, tekst'
    UninstallErrorHeading   = 'Verwijderen - melding mislukt, kop'
    UninstallErrorMessage   = 'Verwijderen - melding mislukt, tekst'
    NewConsentSubHeading    = 'Nieuwe installatie - venster, ondertitel'
    NewConsentMessage       = 'Nieuwe installatie - venster, tekst'
    NewForcedSubHeading     = 'Nieuwe installatie - waarschuwing, ondertitel'
    NewForcedMessage        = 'Nieuwe installatie - waarschuwing, tekst'
    NewForcedInfo           = 'Nieuwe installatie - waarschuwing, oranje regel'
    NewInstallingHeading    = 'Nieuwe installatie - melding tijdens installatie, kop'
    NewInstallingMessage    = 'Nieuwe installatie - melding tijdens installatie, tekst'
    NewSuccessHeading       = 'Nieuwe installatie - melding geslaagd, kop'
    NewSuccessMessage       = 'Nieuwe installatie - melding geslaagd, tekst'
    NewErrorHeading         = 'Nieuwe installatie - melding mislukt, kop'
    NewErrorMessage         = 'Nieuwe installatie - melding mislukt, tekst'
    NewRestartMessage       = 'Nieuwe installatie - herstartmelding, tekst'
    NewRestartForcedMessage = 'Nieuwe installatie - verplichte herstart, tekst'
}
if ($script:Lang -eq 'en')
{
    $TextLabels = [ordered]@{
        ConsentSubHeading       = '"Update available" window - subtitle'
        ConsentMessage          = '"Update available" window - text'
        ForcedSubHeading        = 'Warning after the last postpone - subtitle'
        ForcedMessage           = 'Warning after the last postpone - text'
        ForcedInfo              = 'Warning - orange line'
        InstallingHeading       = 'Notification during installation - heading'
        InstallingMessage       = 'Notification during installation - text'
        SuccessHeading          = 'Success notification - heading'
        SuccessMessage          = 'Success notification - text'
        ErrorHeading            = 'Failure notification - heading'
        ErrorMessage            = 'Failure notification - text'
        RestartSubHeading       = 'Restart prompt - subtitle'
        RestartMessage          = 'Restart prompt - text'
        RestartForcedSubHeading = 'Mandatory restart - subtitle ({Minutes} = warning time)'
        RestartForcedMessage    = 'Mandatory restart - text'
        UninstallingHeading     = 'Uninstall - notification while removing, heading'
        UninstallingMessage     = 'Uninstall - notification while removing, text'
        UninstalledHeading      = 'Uninstall - removed notification, heading'
        UninstalledMessage      = 'Uninstall - removed notification, text'
        UninstallErrorHeading   = 'Uninstall - failure notification, heading'
        UninstallErrorMessage   = 'Uninstall - failure notification, text'
        NewConsentSubHeading    = 'New installation - window, subtitle'
        NewConsentMessage       = 'New installation - window, text'
        NewForcedSubHeading     = 'New installation - warning, subtitle'
        NewForcedMessage        = 'New installation - warning, text'
        NewForcedInfo           = 'New installation - warning, orange line'
        NewInstallingHeading    = 'New installation - notification during installation, heading'
        NewInstallingMessage    = 'New installation - notification during installation, text'
        NewSuccessHeading       = 'New installation - success notification, heading'
        NewSuccessMessage       = 'New installation - success notification, text'
        NewErrorHeading         = 'New installation - failure notification, heading'
        NewErrorMessage         = 'New installation - failure notification, text'
        NewRestartMessage       = 'New installation - restart prompt, text'
        NewRestartForcedMessage = 'New installation - mandatory restart, text'
    }
}

#region ===================== Logic (also usable without the window) =====================

function Read-AppPsd1
{
    # Read through a copy with BOM (Notepad saves UTF-8 without BOM)
    param ([string]$Path)
    $tmp = [System.IO.Path]::GetTempFileName() + '.psd1'
    try
    {
        [System.IO.File]::WriteAllText($tmp, [System.IO.File]::ReadAllText($Path), (New-Object System.Text.UTF8Encoding $true))
        return Import-PowerShellDataFile -Path $tmp
    }
    finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-StandardTexts
{
    # Standard texts for all apps: _Kit\Standaardteksten.psd1 (English in the 'En' section), completed with the built-in texts
    param ([string]$Language = 'nl', [string]$Path = $StandardTextsPath)
    $base = if ($Language -eq 'en') { $BuiltinTextsEn } else { $BuiltinTexts }
    $r = [ordered]@{}
    foreach ($k in $TextKeys) { $r[$k] = $base[$k] }
    if ($Path -and (Test-Path $Path))
    {
        try
        {
            $f = Read-AppPsd1 $Path
            if ($Language -eq 'en') { $f = $f['En'] }
            if ($f -is [hashtable]) { foreach ($k in $TextKeys) { if ($f[$k]) { $r[$k] = $f[$k] } } }
        }
        catch { }
    }
    return $r
}

function ConvertTo-StandardTextsPsd1
{
    param ($Texts, $TextsEn)
    $q = { param($s) "'" + ([string]$s).Replace("'", "''") + "'" }
    $lines = @(
        '#  STANDAARDTEKSTEN / STANDARD TEXTS - voor alle apps / for all apps (AppUpdateKit Builder).'
        '#  NL: Een app gebruikt deze tekst, tenzij er in app.psd1 een eigen tekst staat. Engels staat onder "En".'
        '#  EN: An app uses these texts unless app.psd1 has its own text. English is under "En".'
        '#  NL: {AppName}, {Versie}, {Minuten}, {MaxUitstel}   EN: {AppName}, {Version}, {Minutes}, {MaxPostpones}'
        '@{'
    )
    foreach ($k in $TextKeys) { $lines += "    $($k.PadRight(23))= $(& $q $Texts[$k])" }
    $lines += ''
    $lines += '    En = @{'
    foreach ($k in $TextKeys) { $lines += "        $($k.PadRight(23))= $(& $q $TextsEn[$k])" }
    $lines += '    }'
    $lines += '}'
    return ($lines -join "`r`n") + "`r`n"
}

function Get-AppVersions
{
    # All builds of an app: Output\<AppId>\<version>\ and earlier builds in Output\<AppId>\_archief\<version>_<date>\
    param ([string]$AppId)
    $dir = Join-Path (Join-Path $KitRoot 'Output') $AppId
    if (-not (Test-Path $dir)) { return @() }

    $make = {
        param ($folder, [string]$ver, [bool]$isArchive)
        $v = $null; try { $v = [version]$ver } catch { }
        $pkgFile = Join-Path $folder.FullName 'install.intunewin'
        $bi = Join-Path $folder.FullName 'Bouwinfo.txt'
        $built = if (Test-Path $bi) { (Get-Item $bi).LastWriteTime } else { $folder.LastWriteTime }
        $bron = Join-Path $folder.FullName 'Bron'
        [pscustomobject]@{
            Version       = $ver
            Label         = if ($isArchive) { "$ver  $(T '(vervangen)' '(replaced)')" } else { $ver }
            IsArchive     = $isArchive
            SortKey       = $v
            Path          = $folder.FullName
            Built         = $built
            HasPkg        = Test-Path $pkgFile
            SizeMB        = if (Test-Path $pkgFile) { [math]::Round((Get-Item $pkgFile).Length / 1MB) } else { 0 }
            HasBron       = Test-Path (Join-Path $bron 'app.psd1')
            HasInstallers = [bool](Get-ChildItem $bron -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.exe', '.msi', '.msp' })
        }
    }

    $items = @()
    foreach ($d in (Get-ChildItem $dir -Directory | Where-Object { $_.Name -ne '_archief' })) { $items += & $make $d $d.Name $false }
    $arch = Join-Path $dir '_archief'
    if (Test-Path $arch)
    {
        foreach ($d in (Get-ChildItem $arch -Directory)) { $items += & $make $d (($d.Name -split '_')[0]) $true }
    }
    return $items | Sort-Object @{ Expression = { $_.SortKey }; Descending = $true },
                                @{ Expression = { $_.IsArchive }; Descending = $false },
                                @{ Expression = { $_.Built }; Descending = $true }
}

function ConvertTo-Psd1Text
{
    param ([hashtable]$d)
    $q = { param($s) "'" + ([string]$s).Replace("'", "''") + "'" }
    $procs = (@($d.Processes) | Where-Object { $_ } | ForEach-Object { & $q $_ }) -join ', '
    $bool = if ($d.OnlyUpdateExisting) { '$true' } else { '$false' }
    $popup = if ("$($d.PopupLanguage)" -in 'nl', 'en') { "$($d.PopupLanguage)" } else { 'Auto' }

    $lines = @(
        (T '#  Gemaakt met de AppUpdateKit Builder. Je kunt dit bestand ook met de hand aanpassen.' '#  Created with the AppUpdateKit Builder. You can also edit this file by hand.')
        (T '#  Texts = Nederlands, TextsEn = Engels. In teksten: {AppName}, {Versie}, {Minuten}, {MaxUitstel}. Leeg = standaardtekst.' '#  Texts = Dutch, TextsEn = English. In texts: {AppName}, {Version}, {Minutes}, {MaxPostpones}. Empty = standard text.')
        '@{'
        (T '    # ---------- 1. Basis ----------' '    # ---------- 1. Basics ----------')
        "    AppId      = $(& $q $d.AppId)"
        "    AppName    = $(& $q $d.AppName)"
        "    Version    = $(& $q $d.Version)"
        "    DetectName = $(& $q $d.DetectName)"
        "    Processes  = @($procs)"
        ''
        (T '    # ---------- 2. Uiterlijk ----------' '    # ---------- 2. Appearance ----------')
        "    Icon          = $(& $q $d.Icon)"
        "    AccentColor   = $(& $q $d.AccentColor)"
        "    PopupLanguage = $(& $q $popup)   # $(T 'Auto (Windows-taal van de gebruiker) | nl | en' 'Auto (user''s Windows language) | nl | en')"
        ''
        (T '    # ---------- 3. Wie krijgt de update ----------' '    # ---------- 3. Who gets the update ----------')
        "    OnlyUpdateExisting = $bool"
        "    InstallDuringSetup = $(if ($d.InstallDuringSetup -eq $false) { '$false' } else { '$true' })   # $(T '$true = nieuwe laptops (Autopilot) direct installeren, zonder popup' '$true = new laptops (Autopilot): install right away, no popup')"
        ''
        (T '    # ---------- 4. Uitstellen ----------' '    # ---------- 4. Postponing ----------')
        "    MaxPostpones          = $([int]$d.MaxPostpones)"
        "    PostponeHours         = $([int]$d.PostponeHours)"
        "    ConsentTimeoutMinutes = $([int]$d.ConsentTimeoutMinutes)"
        "    ForcedDelayMinutes    = $([int]$d.ForcedDelayMinutes)"
        ''
        (T '    # ---------- 4b. Wanneer ----------' '    # ---------- 4b. When ----------')
        "    InstallWindow = $(& $q $(if ($d.InstallWindow) { $d.InstallWindow } else { 'Altijd' }))   # $(T 'Altijd | Werktijd | BuitenWerktijd' 'Altijd (always) | Werktijd (working hours) | BuitenWerktijd (outside working hours)')"
        "    WorkHours     = $(& $q $(if ($d.WorkHours) { $d.WorkHours } else { '08:00-17:00' }))"
        "    WorkDays      = $(& $q $(if ($d.WorkDays) { $d.WorkDays } else { 'ma,di,wo,do,vr' }))$(T '' '   # ma=Mon di=Tue wo=Wed do=Thu vr=Fri za=Sat zo=Sun')"
        "    IdleMinutes   = $([int]("0$($d.IdleMinutes)"))   # $(T '> 0 = na zoveel minuten inactief of vergrendeld direct installeren' '> 0 = install right away after this many minutes idle or locked')"
        "    NoUserAction  = $(& $q $(if ($d.NoUserAction) { $d.NoUserAction } else { 'Installeren' }))   # $(T 'Installeren | Wachten' 'Installeren (install) | Wachten (wait)')"
        ''
        (T '    # ---------- 4c. Herstart na de installatie ----------' '    # ---------- 4c. Restart after installation ----------')
        "    RestartMode            = $(& $q $(if ($d.RestartMode) { $d.RestartMode } else { 'Nooit' }))   # $(T 'Nooit | AlsNodig (3010/1641) | Altijd' 'Nooit (never) | AlsNodig (3010/1641) | Altijd (always)')"
        "    RestartReminderMinutes = $([int]$(if ($null -ne $d.RestartReminderMinutes -and "$($d.RestartReminderMinutes)" -ne '') { $d.RestartReminderMinutes } else { 60 }))   # $(T 'Later: opnieuw vragen na (minuten)' 'Later: ask again after (minutes)')"
        "    RestartDeadlineHours   = $([int]$(if ($null -ne $d.RestartDeadlineHours -and "$($d.RestartDeadlineHours)" -ne '') { $d.RestartDeadlineHours } else { 24 }))   # $(T 'verplicht herstarten na (uren, 0 = nooit)' 'mandatory restart after (hours, 0 = never)')"
        "    RestartWarningMinutes  = $([int]$(if ($null -ne $d.RestartWarningMinutes -and "$($d.RestartWarningMinutes)" -ne '') { $d.RestartWarningMinutes } else { 15 }))   # $(T 'waarschuwing voor de verplichte herstart (minuten)' 'warning before the mandatory restart (minutes)')"
        ''
        (T '    # ---------- 4d. Verwijderen ----------' '    # ---------- 4d. Uninstall ----------')
        "    UninstallNotify = $(if ($d.UninstallNotify -eq $true) { '$true' } else { '$false' })   # $(T '$true = meldingen rechtsonder bij het verwijderen' '$true = notifications bottom right when removing')"
        ''
        (T '    # ---------- 5. Installatie (onderdelen worden in deze volgorde geïnstalleerd) ----------' '    # ---------- 5. Installation (components are installed in this order) ----------')
        "    AutoInstallSteps = $(if ($d.AutoInstallSteps) { '$true' } else { '$false' })   # $(T '$true = install-app.cmd wordt hieruit gemaakt' '$true = install-app.cmd is created from this')"
        '    Components = @('
    )
    foreach ($c in @($d.Components))
    {
        if (-not $c) { continue }
        $main = if ($c.Main) { '$true' } else { '$false' }
        $lines += "        @{ File = $(& $q $c.File); Kind = $(& $q $c.Kind); Args = $(& $q $c.Args); Codes = $(& $q $c.Codes); Main = $main; ProductCode = $(& $q $c.ProductCode) }"
    }
    $lines += @(
        '    )'
        "    PreInstall  = $(& $q $d.PreInstall)    # $(T 'cmd-regels vóór de onderdelen' 'cmd lines before the components')"
        "    PostInstall = $(& $q $d.PostInstall)    # $(T 'cmd-regels na de onderdelen' 'cmd lines after the components')"
        ''
        (T '    # ---------- 6. Teksten voor deze app/versie (leeg = _Kit\Standaardteksten.psd1) ----------' '    # ---------- 6. Texts for this app/version (empty = _Kit\Standaardteksten.psd1) ----------')
    )
    foreach ($section in 'Texts', 'TextsEn')
    {
        $lines += "    $section = @{"
        foreach ($k in $TextKeys)
        {
            $v = ''
            if ($d[$section] -and $d[$section][$k]) { $v = $d[$section][$k] }
            $lines += "        $($k.PadRight(23))= $(& $q $v)"
        }
        $lines += '    }'
    }
    $lines += '}'
    return ($lines -join "`r`n") + "`r`n"
}

function Get-MsiProperty
{
    param ([string]$Path, [string]$Property)
    try
    {
        $wi   = New-Object -ComObject WindowsInstaller.Installer
        $db   = $wi.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $wi, @($Path, 0))
        $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @("SELECT Value FROM Property WHERE Property='$Property'"))
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null) | Out-Null
        $rec  = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
        $val  = if ($rec) { $rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, 1) } else { $null }
        $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null) | Out-Null
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($db)
        return $val
    }
    catch { return $null }
}

function Get-InstallerInfo
{
    # Detects the installer type and suggests silent parameters
    param ([string]$Path)

    $info = @{ Kind = 'EXE'; ProductName = ''; Version = ''; ProductCode = ''; Args = '/quiet /norestart'; Note = '' }
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()

    if ($ext -eq '.msi')
    {
        $info.Kind        = 'MSI'
        $info.ProductName = Get-MsiProperty $Path 'ProductName'
        $info.Version     = Get-MsiProperty $Path 'ProductVersion'
        $info.ProductCode = Get-MsiProperty $Path 'ProductCode'
        $info.Args        = ''
        $info.Note        = T 'MSI: wordt stil geïnstalleerd met msiexec /qn.' 'MSI: installed silently with msiexec /qn.'
        return $info
    }

    try
    {
        $vi = (Get-Item -LiteralPath $Path).VersionInfo
        $info.ProductName = ("$($vi.ProductName)").Trim()
        $ver = ("$($vi.ProductVersion)").Trim()
        if (-not $ver -or $ver -notmatch '\d') { $ver = ("$($vi.FileVersion)").Trim() }
        if ($ver -match '(\d+(?:[\.,]\d+){0,3})') { $info.Version = $Matches[1].Replace(',', '.') }
    }
    catch { }

    # Search the first 4 MB for signs of the installer framework
    $text = ''
    try
    {
        $fs = [System.IO.File]::OpenRead($Path)
        $buf = New-Object byte[] ([math]::Min(4MB, $fs.Length))
        [void]$fs.Read($buf, 0, $buf.Length); $fs.Close()
        $text = [System.Text.Encoding]::ASCII.GetString($buf)
    }
    catch { }

    if ($text -match 'Nullsoft|NSIS')
    {
        $info.Kind = 'NSIS'; $info.Args = '/S'; $info.Note = T 'NSIS-installer: /S = stil.' 'NSIS installer: /S = silent.'
    }
    elseif ($text -match 'Inno Setup')
    {
        $info.Kind = 'Inno'; $info.Args = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'; $info.Note = T 'Inno Setup-installer.' 'Inno Setup installer.'
    }
    elseif ($text -match 'InstallShield')
    {
        $info.Kind = 'InstallShield'; $info.Args = '/s /v"/qn /norestart"'; $info.Note = T 'InstallShield: controleer de parameters bij de leverancier.' 'InstallShield: check the parameters with the vendor.'
    }
    elseif ($text -match 'WixBundle|WiX Toolset|\.wixburn')
    {
        $info.Kind = 'WiX'; $info.Args = '/quiet /norestart'; $info.Note = T 'WiX-bundle.' 'WiX bundle.'
    }
    else
    {
        $info.Note = T 'Type niet herkend: controleer de stille parameters bij de leverancier.' 'Type not recognised: check the silent parameters with the vendor.'
    }
    return $info
}

function Find-UninstallString
{
    # Searches "Apps & features" on THIS pc for an uninstall command
    param ([string]$DisplayName)
    if (-not $DisplayName -or -not (Test-Path 'HKLM:\SOFTWARE')) { return $null }
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $e = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "$DisplayName*" } | Select-Object -First 1
    if (-not $e) { return $null }
    if ($e.QuietUninstallString) { return $e.QuietUninstallString }
    if ($e.UninstallString -match 'msiexec') { return ($e.UninstallString -replace '/I', '/X') + ' /qn /norestart' }
    return $e.UninstallString
}

function New-InstallCmdText
{
    param ([string]$AppName, [string]$InstallerName, [hashtable]$Info, [string]$InstallArgs)

    $line = if ($Info.Kind -eq 'MSI') { "msiexec.exe /i `"$InstallerName`" /qn /norestart $InstallArgs".Trim() }
            else { "`"$InstallerName`" $InstallArgs".Trim() }
@"
rem ===========================================================================
rem  $(T 'INSTALLATIESTAPPEN' 'INSTALLATION STEPS') - $AppName
rem  $(T 'Gemaakt met de Builder; je mag dit aanpassen (extra stappen, bestanden, ...).' 'Created with the Builder; you may change this (extra steps, files, ...).')
rem  $(T 'De popup, de procescheck en de meldingen regelt install.cmd al.' 'install.cmd already handles the popup, the process check and the notifications.')
rem ===========================================================================

rem ---- $(T 'Voorbereiding (bijv. een runtime die eerst nodig is)' 'Preparation (e.g. a runtime that is needed first)') ----

rem ---- $(T 'De app zelf' 'The app itself') ($($Info.Kind)) ----
$line
set APP_EXITCODE=%ERRORLEVEL%

rem ---- $(T 'Nazorg (extra bestanden, snelkoppelingen, ingebouwde updater uitzetten, ...)' 'Aftercare (extra files, shortcuts, disable the built-in updater, ...)') ----

exit /b %APP_EXITCODE%
"@
}

function Get-ComponentInfo
{
    # Type, suggested parameters and (for MSI) product code of a file to install
    param ([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $r = @{ File = [System.IO.Path]::GetFileName($Path); Kind = 'EXE'; Args = ''; Codes = '0 3010 1641'; Main = $false
            ProductCode = ''; ProductName = ''; Version = ''; Note = '' }
    switch ($ext)
    {
        '.msi' { $i = Get-InstallerInfo $Path; $r.Kind = 'MSI'; $r.ProductCode = "$($i.ProductCode)"; $r.ProductName = "$($i.ProductName)"; $r.Version = "$($i.Version)"; $r.Note = $i.Note }
        '.exe' { $i = Get-InstallerInfo $Path; $r.Kind = $i.Kind; $r.Args = $i.Args; $r.ProductName = "$($i.ProductName)"; $r.Version = "$($i.Version)"; $r.Note = $i.Note }
        '.msp' { $r.Kind = 'MSP'; $r.Note = T 'MSI-patch (msiexec /p).' 'MSI patch (msiexec /p).' }
        '.ps1' { $r.Kind = 'PS1'; $r.Codes = '0'; $r.Note = T 'PowerShell-script.' 'PowerShell script.' }
        '.cmd' { $r.Kind = 'CMD'; $r.Codes = '0'; $r.Note = T 'Batchbestand.' 'Batch file.' }
        '.bat' { $r.Kind = 'CMD'; $r.Codes = '0'; $r.Note = T 'Batchbestand.' 'Batch file.' }
        '.reg' { $r.Kind = 'REG'; $r.Codes = '0'; $r.Note = T 'Registerbestand (reg import).' 'Registry file (reg import).' }
    }
    # Typical prerequisites: also accept "already installed" (1638)
    if ($r.File -match '(?i)runtime|redist|vcredist|dotnet|webview') { $r.Codes = '0 3010 1641 1638' }
    return $r
}

function Get-ComponentCommand
{
    param ($c)
    $a = "$($c.Args)".Trim()
    $line = switch ("$($c.Kind)".ToUpper())
    {
        'MSI'   { "msiexec.exe /i `"$($c.File)`" /qn /norestart $a" }
        'MSP'   { "msiexec.exe /p `"$($c.File)`" /qn /norestart $a" }
        'PS1'   { "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$($c.File)`" $a" }
        'CMD'   { "call `"$($c.File)`" $a" }
        'REG'   { "reg.exe import `"$($c.File)`"" }
        default { "`"$($c.File)`" $a" }
    }
    return $line.Trim()
}

function New-InstallCmdFromComponents
{
    # Creates install-app.cmd: components in order, with their own parameters and accepted exit codes.
    # When a component fails, the installation stops with that component's exit code.
    param ([string]$AppName, $Components, [string]$PreInstall, [string]$PostInstall)

    $L = @(
        'rem ==========================================================================='
        "rem  $(T 'INSTALLATIESTAPPEN' 'INSTALLATION STEPS') - $AppName"
        (T 'rem  Automatisch gemaakt door de Builder uit de onderdelen in tabblad 2.' 'rem  Created automatically by the Builder from the components in tab 2.')
        (T 'rem  Wijzig de onderdelen in de Builder (of zet "automatisch maken" uit).' 'rem  Change the components in the Builder (or switch off "create automatically").')
        'rem ==========================================================================='
        ''
        'set APP_EXITCODE=0'
    )
    if ("$PreInstall".Trim())
    {
        $L += ''; $L += (T 'rem ---- Voor de installatie ----' 'rem ---- Before the installation ----'); $L += ("$PreInstall".TrimEnd() -split "`r?`n")
    }
    $i = 0
    foreach ($c in @($Components))
    {
        if (-not $c) { continue }
        $i++
        $codes = @("$($c.Codes)" -split '[\s,;]+' | Where-Object { $_ -match '^-?\d+$' })
        if (-not $codes.Count) { $codes = @('0', '3010', '1641') }
        $safe = "$($c.File)" -replace '[()&|<>^%!]', ''
        $L += ''
        $L += "rem ---- $(T 'Onderdeel' 'Component') ${i}: $($c.File) ($($c.Kind))$(if ($c.Main) { T ' - hoofdonderdeel' ' - main component' }) ----"
        $L += Get-ComponentCommand $c
        $L += 'set STEP=%ERRORLEVEL%'
        $L += 'set OK='
        $L += "for %%c in ($($codes -join ' ')) do if `"%STEP%`"==`"%%c`" set OK=1"
        $L += 'if not defined OK ('
        $L += "    echo $(T 'Onderdeel' 'Component') $i - $safe - $(T 'is mislukt met exitcode' 'failed with exit code') %STEP%"
        $L += '    exit /b %STEP%'
        $L += ')'
        $L += 'if "%STEP%"=="3010" set APP_EXITCODE=3010'
        $L += 'if "%STEP%"=="1641" set APP_EXITCODE=1641'
    }
    if ("$PostInstall".Trim())
    {
        $L += ''; $L += (T 'rem ---- Na de installatie ----' 'rem ---- After the installation ----'); $L += ("$PostInstall".TrimEnd() -split "`r?`n")
    }
    $L += ''
    $L += 'exit /b %APP_EXITCODE%'
    return ($L -join "`r`n") + "`r`n"
}

function New-UninstallCmdText
{
    param ([string]$AppName, [hashtable]$Info, [string]$DetectName)

    $line = $null
    if ($Info.Kind -eq 'MSI' -and $Info.ProductCode) { $line = "msiexec.exe /x $($Info.ProductCode) /qn /norestart" }
    if (-not $line -and $DetectName)
    {
        # Remove by name (MSI product code or the app's own uninstaller); works on every laptop
        $line = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"Remove-App.ps1`" -Name `"$DetectName`""
        if ($Info.Kind -in 'NSIS', 'Inno', 'EXE') { $line += " -ExeArgs `"$(if ($Info.Kind -eq 'Inno') { '/VERYSILENT /NORESTART' } else { '/S' })`"" }
    }
    if (-not $line)
    {
        $line = "rem $(T 'VUL IN: het verwijdercommando, bijvoorbeeld' 'FILL IN: the uninstall command, for example'):`r`nrem `"%ProgramFiles%\$AppName\uninstall.exe`" /S`r`nver > nul"
    }
@"
rem ===========================================================================
rem  $(T 'VERWIJDERSTAPPEN' 'UNINSTALL STEPS') - $AppName
rem ===========================================================================

$line
set APP_EXITCODE=%ERRORLEVEL%

exit /b %APP_EXITCODE%
"@
}

function Find-HeadlessBrowser
{
    # Edge is on every Windows 10/11 laptop; Chrome as a fallback
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($key in 'msedge.exe', 'chrome.exe')
    {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$key" -ErrorAction SilentlyContinue
        if ($reg -and $reg.'(default)') { $candidates += $reg.'(default)' }
    }
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}

function Save-PngCrop([string]$Source, [string]$Target, [int]$Size)
{
    Add-Type -AssemblyName System.Drawing
    $full = [System.Drawing.Bitmap]::FromFile($Source)
    try
    {
        $crop = $full.Clone((New-Object System.Drawing.Rectangle 0, 0, $Size, $Size), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $crop.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png); $crop.Dispose()
    }
    finally { $full.Dispose() }
}

function ConvertFrom-SvgToPng
{
    <#
        Converts an .svg to a Size x Size PNG with a transparent background.
        Windows cannot draw SVG itself; that is why Edge (headless) does it.
    #>
    param ([string]$Svg, [string]$Png, [int]$Size = 256, [string]$Browser = (Find-HeadlessBrowser), [string[]]$ExtraArgs = @(), [switch]$NoCrop)
    if (-not $Browser) { throw (T 'Microsoft Edge of Google Chrome is nodig om een SVG om te zetten, maar is niet gevonden. Sla het logo op als .png en kies dat.' 'Microsoft Edge or Google Chrome is needed to convert an SVG, but was not found. Save the logo as .png and pick that.') }

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("AppKitSvg_" + [guid]::NewGuid().ToString('N'))
    New-Item -Path $work -ItemType Directory -Force | Out-Null
    try
    {
        $b64  = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Svg))
        $html = Join-Path $work 'logo.html'
        $page = "<!doctype html><html><head><meta charset='utf-8'><style>html,body{margin:0;padding:0;background:transparent;width:${Size}px;height:${Size}px;overflow:hidden}" +
                "img{width:${Size}px;height:${Size}px;object-fit:contain;display:block}</style></head>" +
                "<body><img src='data:image/svg+xml;base64,$b64'></body></html>"
        [System.IO.File]::WriteAllText($html, $page, (New-Object System.Text.UTF8Encoding $false))
        $out = Join-Path $work 'logo.png'

        # Own profile folder: otherwise Edge hands the job to an already open Edge window
        $argList = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
                     '--disable-extensions', '--force-device-scale-factor=1', '--default-background-color=00000000',
                     "--window-size=$($Size * 2 + 200),$($Size * 2 + 200)", "--user-data-dir=`"$(Join-Path $work 'profiel')`"",
                     "--screenshot=`"$out`"") + $ExtraArgs + @("`"file:///$($html.Replace('\', '/').TrimStart('/'))`"")
        $hide = @{}; if ($IsWindows -ne $false) { $hide.WindowStyle = 'Hidden' }   # PS 5.1: $IsWindows does not exist
        $proc = Start-Process -FilePath $Browser -ArgumentList $argList -PassThru @hide
        $null = $proc.Handle
        if (-not $proc.WaitForExit(30000)) { try { $proc.Kill() } catch { }; throw (T 'Het omzetten van de SVG duurde te lang.' 'Converting the SVG took too long.') }
        if (-not (Test-Path $out) -or (Get-Item $out).Length -lt 100) { throw (T 'De SVG kon niet worden omgezet. Klopt het bestand? Probeer anders een .png.' 'The SVG could not be converted. Is the file valid? Otherwise try a .png.') }
        if ($NoCrop) { Copy-Item -LiteralPath $out -Destination $Png -Force; return }

        # The window was rendered larger (small headless windows are cut off at the bottom): crop the logo top left
        Save-PngCrop -Source $out -Target $Png -Size $Size
    }
    finally
    {
        Start-Sleep -Milliseconds 300
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-IcoFromImage
{
    # Creates an .ico (256x256, PNG inside) from an .svg/.png/.jpg/.bmp, or extracts the icon from an .exe
    param ([string]$Source, [string]$Target)
    Add-Type -AssemblyName System.Drawing
    $ext = [System.IO.Path]::GetExtension($Source).ToLower()
    if ($ext -eq '.ico') { Copy-Item -LiteralPath $Source -Destination $Target -Force; return }

    if ($ext -eq '.svg')
    {
        $tmpPng = Join-Path ([System.IO.Path]::GetTempPath()) ("AppKitLogo_" + [guid]::NewGuid().ToString('N') + '.png')
        try
        {
            ConvertFrom-SvgToPng -Svg $Source -Png $tmpPng
            New-IcoFromImage -Source $tmpPng -Target $Target
        }
        finally { Remove-Item -LiteralPath $tmpPng -Force -ErrorAction SilentlyContinue }
        return
    }

    if ($ext -eq '.exe')
    {
        $img = ([System.Drawing.Icon]::ExtractAssociatedIcon($Source)).ToBitmap()
    }
    else
    {
        $img = [System.Drawing.Image]::FromFile($Source)
    }
    $bmp = New-Object System.Drawing.Bitmap 256, 256
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $scale = [math]::Min(256 / $img.Width, 256 / $img.Height)
    $w = [int]($img.Width * $scale); $h = [int]($img.Height * $scale)
    $g.DrawImage($img, [int]((256 - $w) / 2), [int]((256 - $h) / 2), $w, $h)
    $g.Dispose(); $img.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    $png = $ms.ToArray()

    $out = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $out
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)          # header: 1 image
    $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)  # 256x256
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$png.Length); $bw.Write([uint32]22)
    $bw.Write($png); $bw.Flush()
    [System.IO.File]::WriteAllBytes($Target, $out.ToArray())
}

function Expand-AppText
{
    param ([string]$Text, [hashtable]$d)
    return $Text.Replace('{AppName}', $d.AppName).
                 Replace('{Versie}', [string]$d.Version).Replace('{Version}', [string]$d.Version).
                 Replace('{Minuten}', [string]$d.ForcedDelayMinutes).Replace('{Minutes}', [string]$d.ForcedDelayMinutes).
                 Replace('{MaxUitstel}', [string]$d.MaxPostpones).Replace('{MaxPostpones}', [string]$d.MaxPostpones)
}

function Get-EffectiveText
{
    # Text as the user will see it: own text (Texts / TextsEn) -> standard text, for a new installation first the New... variant
    param ([string]$Key, [hashtable]$d, $Std = $null, [switch]$New, [string]$Language = 'nl')
    if (-not $Std) { $Std = Get-StandardTexts $Language }
    $own = if ($Language -eq 'en') { $d.TextsEn } else { $d.Texts }
    $t = $null
    if ($New -and $Key -notlike 'New*')
    {
        $nk = "New$Key"
        if ($own -and $own[$nk]) { $t = $own[$nk] } elseif ($Std[$nk]) { $t = $Std[$nk] }
    }
    if (-not $t) { $t = if ($own -and $own[$Key]) { $own[$Key] } else { $Std[$Key] } }
    return Expand-AppText $t $d
}

function Get-VersionDetails
{
    # Everything about a built version, from Output\<AppId>\<version>\Bron and Bouwinfo.txt
    param ([string]$Path)
    $bron = Join-Path $Path 'Bron'
    $r = @{ Data = $null; Std = $null; StdEn = $null; Icon = $null; Summary = ''; Install = ''; Texts = ''; BuildInfo = '' }

    $psd = Join-Path $bron 'app.psd1'
    if (-not (Test-Path $psd))
    {
        $r.Summary = T 'Van deze versie zijn geen instellingen bewaard (gebouwd met een oudere versie van de kit).' 'No settings were kept for this version (built with an older version of the kit).'
        return $r
    }
    $d = Read-AppPsd1 $psd
    $r.Data = $d

    # Standard texts as they were when this version was built
    $stdFile = Join-Path $bron 'Standaardteksten.psd1'
    $r.Std   = Get-StandardTexts 'nl' $stdFile
    $r.StdEn = Get-StandardTexts 'en' $stdFile

    $icon = Join-Path $bron $(if ($d.Icon) { $d.Icon } else { 'app.ico' })
    if (Test-Path $icon) { $r.Icon = $icon }

    $timeout = if ($null -ne $d.ConsentTimeoutMinutes) { T "$($d.ConsentTimeoutMinutes) minuten" "$($d.ConsentTimeoutMinutes) minutes" }
               elseif ($null -ne $d.ConsentTimeoutSeconds) { T "$($d.ConsentTimeoutSeconds) seconden" "$($d.ConsentTimeoutSeconds) seconds" } else { T '15 minuten' '15 minutes' }
    $who = if ($d.OnlyUpdateExisting -eq $false) { T 'iedereen in de toegewezen groep' 'everyone in the assigned group' } else { T 'alleen apparaten waar de app al staat' 'only devices where the app is installed' }
    $deadline = if ([int]("0$($d.RestartDeadlineHours)")) { T "$($d.RestartDeadlineHours) uur" "$($d.RestartDeadlineHours) hours" } else { T 'nooit' 'never' }
    $restart = switch ($d.RestartMode) {
        'AlsNodig' { T "alleen als de installer erom vraagt; Later = $($d.RestartReminderMinutes) min, verplicht na $deadline" "only when the installer asks; Later = $($d.RestartReminderMinutes) min, mandatory after $deadline" }
        'Altijd'   { T "altijd; Later = $($d.RestartReminderMinutes) min, verplicht na $deadline" "always; Later = $($d.RestartReminderMinutes) min, mandatory after $deadline" }
        default    { T 'geen melding' 'no prompt' }
    }
    $popup = switch ("$($d.PopupLanguage)") { 'nl' { T 'altijd Nederlands' 'always Dutch' } 'en' { T 'altijd Engels' 'always English' } default { T 'automatisch (Windows-taal van de gebruiker)' 'automatic (user''s Windows language)' } }
    $r.Summary = @(
        "$(T 'Naam in popup        ' 'Name in popup        '): $($d.AppName)"
        "$(T 'Versie               ' 'Version              '): $($d.Version)"
        "$(T 'Apps en onderdelen   ' 'Apps & features      '): $($d.DetectName)"
        "$(T 'Processen            ' 'Processes            '): $(@($d.Processes) -join ', ')"
        "$(T 'Kleur                ' 'Colour               '): $($d.AccentColor)"
        "$(T 'Logo                 ' 'Logo                 '): $(if ($r.Icon) { T 'aanwezig' 'present' } else { T 'ontbreekt' 'missing' })"
        "$(T 'Taal popups          ' 'Popup language       '): $popup"
        "$(T 'Wie krijgt de update ' 'Who gets the update  '): $who"
        "$(T 'Uitstellen           ' 'Postponing           '): $(T "$($d.MaxPostpones) keer, telkens $($d.PostponeHours) uur" "$($d.MaxPostpones) times, $($d.PostponeHours) hours each")"
        "$(T 'Geen keuze           ' 'No choice            '): $(T "venster sluit na $timeout" "popup closes after $timeout")"
        "$(T 'Waarschuwing vooraf  ' 'Warning in advance   '): $(T "$($d.ForcedDelayMinutes) minuten na de laatste keer uitstellen" "$($d.ForcedDelayMinutes) minutes after the last postpone")"
        "$(T 'Tijdvenster          ' 'Time window          '): $(Get-WindowText $d)"
        "$(T 'Inactief             ' 'Idle                 '): $(if ([int]("0$($d.IdleMinutes)") -gt 0) { T "na $($d.IdleMinutes) minuten inactief of vergrendeld direct installeren" "install right away after $($d.IdleMinutes) minutes idle or locked" } else { T 'uit' 'off' })"
        "Autopilot            : $(if ($d.InstallDuringSetup -eq $false) { T 'overslaan, de app komt na de inrichting' 'skip, the app follows after setup' } else { T 'direct installeren, zonder popup' 'install right away, no popup' })"
        "$(T 'Herstart             ' 'Restart              '): $restart"
        "$(T 'Verwijderen          ' 'Uninstall            '): $(if ($d.UninstallNotify -eq $true) { T 'met meldingen' 'with notifications' } else { T 'zonder meldingen' 'without notifications' })"
        "$(T 'Niemand ingelogd     ' 'Nobody signed in     '): $(if ($d.NoUserAction -eq 'Wachten') { T 'wachten tot er iemand is ingelogd' 'wait until someone signs in' } else { T 'direct installeren' 'install right away' })"
    ) -join "`r`n"
    $comps = @($d.Components | Where-Object { $_ })
    if ($comps.Count)
    {
        $n = 0
        $r.Summary += "`r`n`r`n$(T 'Onderdelen (in volgorde)' 'Components (in order)'):"
        foreach ($c in $comps)
        {
            $n++
            $r.Summary += "`r`n  $n. $($c.File)  [$($c.Kind)]$(if ($c.Main) { T '  (hoofdonderdeel)' '  (main component)' })"
            $r.Summary += "`r`n     parameters : $(if ($c.Args) { $c.Args } else { T '(geen)' '(none)' })"
            $r.Summary += "`r`n     $(T 'geslaagd bij exitcode' 'success on exit code'): $($c.Codes)"
        }
        if ("$($d.PreInstall)".Trim())  { $r.Summary += "`r`n`r`n$(T 'Voor de installatie' 'Before the installation'):`r`n$($d.PreInstall)" }
        if ("$($d.PostInstall)".Trim()) { $r.Summary += "`r`n`r`n$(T 'Na de installatie' 'After the installation'):`r`n$($d.PostInstall)" }
    }

    $parts = @()
    foreach ($fname in 'install-app.cmd', 'uninstall-app.cmd')
    {
        $p = Join-Path $bron $fname
        $parts += "==================== $fname ===================="
        $parts += if (Test-Path $p) { [System.IO.File]::ReadAllText($p).TrimEnd() } else { T '(niet bewaard)' '(not kept)' }
        $parts += ''
    }
    $ps = Join-Path $Path 'Intune\Install.ps1'
    if (Test-Path $ps)
    {
        $parts += "==================== Intune\Install.ps1 ($(T 'PowerShell-installer' 'PowerShell installer')) ===================="
        $parts += [System.IO.File]::ReadAllText($ps).TrimEnd()
        $parts += ''
    }
    $r.Install = $parts -join "`r`n"

    $lines = @()
    foreach ($lang in 'nl', 'en')
    {
        $lines += "==================== $(if ($lang -eq 'en') { T 'Engels' 'English' } else { T 'Nederlands' 'Dutch' }) ===================="
        $section = if ($lang -eq 'en') { $d.TextsEn } else { $d.Texts }
        $std = if ($lang -eq 'en') { $r.StdEn } else { $r.Std }
        foreach ($k in $TextKeys)
        {
            $own = [bool]($section -and $section[$k])
            $lines += "[$($TextLabels[$k])]  $(if ($own) { T '(eigen tekst)' '(own text)' } else { T '(standaardtekst)' '(standard text)' })"
            $lines += (Get-EffectiveText $k $d $std -Language $lang)
            $lines += ''
        }
    }
    $r.Texts = $lines -join "`r`n"

    $bi = Join-Path $Path 'Bouwinfo.txt'
    $r.BuildInfo = if (Test-Path $bi) { [System.IO.File]::ReadAllText($bi) } else { T '(geen Bouwinfo.txt)' '(no Bouwinfo.txt)' }
    return $r
}

function Get-WindowText([hashtable]$d)
{
    $h = if ($d.WorkHours) { $d.WorkHours } else { '08:00-17:00' }
    $w = if ($d.WorkDays) { $d.WorkDays } else { 'ma,di,wo,do,vr' }
    switch ($d.InstallWindow)
    {
        'Werktijd'       { return (T "alleen binnen werktijd ($w, $h)" "only during working hours ($w, $h)") }
        'BuitenWerktijd' { return (T "alleen buiten werktijd (buiten $w, $h)" "only outside working hours (outside $w, $h)") }
        default          { return (T 'altijd' 'always') }
    }
}

function Compare-AppData
{
    # Short list of differences between an old version and what is now in the Builder
    param ([hashtable]$Old, [hashtable]$New, [string]$OldInstall, [string]$NewInstall)
    $diff = @()
    $labels = [ordered]@{ Version = (T 'Versie' 'Version'); AppName = (T 'Naam' 'Name'); DetectName = (T 'Apps en onderdelen' 'Apps & features'); AccentColor = (T 'Kleur' 'Colour')
                          PopupLanguage = (T 'Taal popups' 'Popup language')
                          MaxPostpones = (T 'Aantal keer uitstellen' 'Number of postpones'); PostponeHours = (T 'Uren per keer' 'Hours each time'); ForcedDelayMinutes = (T 'Waarschuwing (min)' 'Warning (min)')
                          InstallWindow = (T 'Tijdvenster' 'Time window'); WorkHours = (T 'Werktijd' 'Working hours'); WorkDays = (T 'Werkdagen' 'Working days'); IdleMinutes = (T 'Inactief (min)' 'Idle (min)'); NoUserAction = (T 'Niemand ingelogd' 'Nobody signed in')
                          RestartMode = (T 'Herstart' 'Restart'); RestartReminderMinutes = (T 'Herstart: Later (min)' 'Restart: Later (min)'); RestartDeadlineHours = (T 'Herstart: verplicht na (uur)' 'Restart: mandatory after (hours)'); RestartWarningMinutes = (T 'Herstart: waarschuwing (min)' 'Restart: warning (min)'); UninstallNotify = (T 'Meldingen bij verwijderen' 'Notifications when removing') }
    foreach ($k in $labels.Keys)
    {
        if ("$($Old[$k])" -ne "$($New[$k])") { $diff += "$($labels[$k]): $($Old[$k])  ->  $($New[$k])" }
    }
    if ((@($Old.Processes) -join ',') -ne (@($New.Processes) -join ',')) { $diff += "$(T 'Processen' 'Processes'): $(@($Old.Processes) -join ', ')  ->  $(@($New.Processes) -join ', ')" }
    if ([bool]$Old.OnlyUpdateExisting -ne [bool]$New.OnlyUpdateExisting) { $diff += T 'Wie krijgt de update: gewijzigd' 'Who gets the update: changed' }
    if (($Old.InstallDuringSetup -ne $false) -ne ($New.InstallDuringSetup -ne $false)) { $diff += "$(T 'Installeren tijdens Autopilot' 'Install during Autopilot'): $(if ($New.InstallDuringSetup -ne $false) { T 'aan' 'on' } else { T 'uit' 'off' })" }
    $fmt = { param($list) (@($list | Where-Object { $_ } | ForEach-Object { "$($_.File)|$($_.Args)|$($_.Codes)|$([bool]$_.Main)" }) -join ';') }
    if ((& $fmt $Old.Components) -ne (& $fmt $New.Components))
    {
        $oldF = @($Old.Components | Where-Object { $_ } | ForEach-Object { $_.File }) -join ', '
        $newF = @($New.Components | Where-Object { $_ } | ForEach-Object { $_.File }) -join ', '
        $diff += if ($oldF -ne $newF) { "$(T 'Onderdelen' 'Components'): $oldF  ->  $newF" } else { T 'Parameters of exitcodes van onderdelen gewijzigd' 'Parameters or exit codes of components changed' }
    }
    foreach ($section in 'Texts', 'TextsEn')
    {
        $suffix = if ($section -eq 'TextsEn') { T ' (Engels)' ' (English)' } else { T ' (Nederlands)' ' (Dutch)' }
        foreach ($k in $TextKeys)
        {
            $o = if ($Old[$section]) { "$($Old[$section][$k])" } else { '' }
            $n = if ($New[$section]) { "$($New[$section][$k])" } else { '' }
            if ($o.Trim() -ne $n.Trim()) { $diff += "$(T 'Tekst gewijzigd' 'Text changed'): $($TextLabels[$k])$suffix" }
        }
    }
    $norm = { param($s) (("$s" -replace "`r", '').Trim()) }
    if ($OldInstall -and (& $norm $OldInstall) -ne (& $norm $NewInstall)) { $diff += T 'Installatiestappen (install-app.cmd) gewijzigd' 'Installation steps (install-app.cmd) changed' }
    return $diff
}

function Test-AppData
{
    param ([hashtable]$d)
    $e = @()
    if ($d.AppId -notmatch '^[A-Za-z0-9_-]+$')        { $e += T 'AppId: alleen letters, cijfers, - en _ (geen spaties).' 'AppId: only letters, digits, - and _ (no spaces).' }
    if (-not $d.AppName)                               { $e += T 'Naam is leeg.' 'Name is empty.' }
    if ($d.Version -notmatch '^\d+(\.\d+){0,3}$')      { $e += T 'Versie moet de vorm 1.2.3 hebben.' 'Version must have the form 1.2.3.' }
    if (-not $d.DetectName)                            { $e += T 'Naam in Apps en onderdelen is leeg.' 'Name in Apps & features is empty.' }
    if ($d.AccentColor -notmatch '^#[0-9A-Fa-f]{6}$')  { $e += T 'Kleur moet de vorm #RRGGBB hebben.' 'Colour must have the form #RRGGBB.' }
    if ($d.AutoInstallSteps -and -not @($d.Components | Where-Object { $_ }).Count) { $e += T 'Voeg in tabblad 2 minstens één onderdeel toe (of zet automatisch maken uit).' 'Add at least one component in tab 2 (or switch off create automatically).' }
    if ($d.InstallWindow -and $d.InstallWindow -ne 'Altijd')
    {
        if ($d.WorkHours -notmatch '^([01]?\d|2[0-3]):[0-5]\d-([01]?\d|2[0-3]):[0-5]\d$') { $e += T 'Werktijd moet de vorm 08:00 tot 17:00 hebben.' 'Working hours must have the form 08:00 to 17:00.' }
        elseif (($d.WorkHours -split '-')[0] -eq ($d.WorkHours -split '-')[1]) { $e += T 'Werktijd: begin en einde zijn gelijk.' 'Working hours: start and end are the same.' }
        if (-not "$($d.WorkDays)".Trim()) { $e += T 'Kies minstens één werkdag.' 'Pick at least one working day.' }
    }
    if ("$($d.IdleMinutes)" -notmatch '^\d+$') { $e += T 'Minuten inactief moet een heel getal zijn.' 'Idle minutes must be a whole number.' }
    if ($d.RestartMode -and $d.RestartMode -ne 'Nooit')
    {
        if ("$($d.RestartReminderMinutes)" -notmatch '^\d+$' -or [int]$d.RestartReminderMinutes -lt 15) { $e += T 'Herstart: opnieuw vragen na moet minstens 15 minuten zijn.' 'Restart: ask again after must be at least 15 minutes.' }
        if ("$($d.RestartDeadlineHours)" -notmatch '^\d+$')  { $e += T 'Herstart: verplicht na (uur) moet een heel getal zijn (0 = nooit).' 'Restart: mandatory after (hours) must be a whole number (0 = never).' }
        if ("$($d.RestartWarningMinutes)" -notmatch '^\d+$' -or [int]$d.RestartWarningMinutes -lt 1) { $e += T 'Herstart: waarschuwing vooraf moet minstens 1 minuut zijn.' 'Restart: warning in advance must be at least 1 minute.' }
    }
    foreach ($n in 'MaxPostpones', 'PostponeHours', 'ConsentTimeoutMinutes', 'ForcedDelayMinutes')
    {
        if ("$($d[$n])" -notmatch '^\d+$') { $e += T "$n moet een heel getal zijn." "$n must be a whole number." }
    }
    return $e
}

#endregion

# ---------- English interface: XAML texts are translated before the window is loaded ----------
$UiTextEn = @{
    # by element name (same Dutch text, different meaning)
    'name:BtnCompRemove' = 'Remove'
    'name:BtnVerDelete'  = 'Delete'
    'tag:uninstalling'   = 'Removing'
    'tag:installing'     = 'Installing'
    # by text
    'Vul de gegevens in, bekijk de popup en bouw het Intune-pakket.' = 'Fill in the details, preview the popup and build the Intune package.'
    'Taal van de Builder en van de gemaakte bestanden' = 'Language of the Builder and of the generated files'
    'Opslaan' = 'Save'
    'Map met pakket openen' = 'Open package folder'
    'Bouw pakket (.intunewin)' = 'Build package (.intunewin)'
    '+ Nieuwe app' = '+ New app'
    '1. Basis' = '1. Basics'
    'Kiezen...' = 'Browse...'
    'Kies de installer (.exe of .msi). Naam, versie en stille parameters worden dan automatisch ingevuld.' = 'Pick the installer (.exe or .msi). Name, version and silent parameters are then filled in automatically.'
    'AppId (interne naam, geen spaties)' = 'AppId (internal name, no spaces)'
    'Naam in de popup' = 'Name in the popup'
    'Versie' = 'Version'
    'De versie die dit pakket installeert; Intune detecteert hierop.' = 'The version this package installs; Intune detects on this.'
    'Naam in Apps en onderdelen (begint met)' = 'Name in Apps & features (starts with)'
    'Processen die dicht moeten zijn' = 'Processes that must be closed'
    'Zonder .exe, gescheiden door komma''s. Bijv.: notepad++   of   vmware-view, horizon-client. Leeg = geen procescheck (voor apps zonder eigen programma, zoals een runtime of driver).' = 'Without .exe, separated by commas. E.g.: notepad++   or   vmware-view, horizon-client. Empty = no process check (for apps without their own program, such as a runtime or driver).'
    'Alleen bijwerken op apparaten waar de app al staat' = 'Only update devices where the app is already installed'
    'Installeren op nieuwe laptops (Autopilot), zonder popup' = 'Install on new laptops (Autopilot), without popup'
    'Tijdens de inrichting wordt de app direct geïnstalleerd, ook als hij er nog niet op staat. Uit = de app komt pas na de inrichting, met popup.' = 'During setup the app is installed right away, even when it is not on the laptop yet. Off = the app comes after setup, with popup.'
    'Logo kiezen...' = 'Choose logo...'
    'Uit installer halen' = 'Extract from installer'
    '.svg, .ico, .png of .jpg (wordt omgezet). Liefst vierkant en minstens 256x256.' = '.svg, .ico, .png or .jpg (converted). Preferably square and at least 256x256.'
    'Kleur van kop en knop' = 'Colour of header and button'
    'Vorm #RRGGBB, bijv. #185FA5 (blauw) of #3B7A1E (groen).' = 'Format #RRGGBB, e.g. #185FA5 (blue) or #3B7A1E (green).'
    'Taal van de popups' = 'Popup language'
    'Automatisch (Windows-taal van de gebruiker)' = 'Automatic (user''s Windows language)'
    'Altijd Nederlands' = 'Always Dutch'
    'Altijd Engels' = 'Always English'
    'Engelse Windows = Engelse popups, anders Nederlands. De teksten staan in tabblad 3.' = 'English Windows = English popups, otherwise Dutch. The texts are in tab 3.'
    '2. Installatie' = '2. Installation'
    'Onderdelen (worden in deze volgorde geïnstalleerd)' = 'Components (installed in this order)'
    'Bijv. eerst een runtime, dan de app zelf. Per onderdeel eigen parameters (dubbelklik om te wijzigen) en de exitcodes die als geslaagd tellen. Mislukt een onderdeel, dan stopt de installatie en krijgt de gebruiker de melding ''niet gelukt''. Het hoofdonderdeel is de app zelf (gebruikt voor verwijderen).' = 'E.g. first a runtime, then the app itself. Each component has its own parameters (double-click to change) and the exit codes that count as success. When a component fails, the installation stops and the user gets the ''failed'' notification. The main component is the app itself (used for uninstalling).'
    'Hoofd' = 'Main'
    'Bestand' = 'File'
    'Geslaagd bij exitcode' = 'Success on exit code'
    'Onderdeel toevoegen...' = 'Add component...'
    'Omhoog' = 'Up'
    'Omlaag' = 'Down'
    'Ondersteund: .exe, .msi, .msp, .ps1, .cmd/.bat en .reg. Stille parameters worden voorgesteld.' = 'Supported: .exe, .msi, .msp, .ps1, .cmd/.bat and .reg. Silent parameters are suggested.'
    'Extra stappen vóór de onderdelen' = 'Extra steps before the components'
    'Extra stappen na de onderdelen' = 'Extra steps after the components'
    'Parameters uit Intune gebruiken: install.cmd /noshortcuts maakt APP_NOSHORTCUTS aan. Een stap overslaan doe je zo: ''if defined APP_NOSHORTCUTS goto na_snelkoppelingen'', met '':na_snelkoppelingen'' na die stap. Ingebouwd zijn /noprocesscheck, /noconsent en /silent.' = 'Using parameters from Intune: install.cmd /noshortcuts creates APP_NOSHORTCUTS (with Install.ps1: $Switches). To skip a step: ''if defined APP_NOSHORTCUTS goto after_shortcuts'', with '':after_shortcuts'' after that step. Built in: /noprocesscheck, /noconsent and /silent.'
    'Installatiestappen automatisch maken uit de onderdelen' = 'Create the installation steps automatically from the components'
    'Installatiestappen (install-app.cmd)' = 'Installation steps (install-app.cmd)'
    'Draait als SYSTEM vanuit de pakketmap. Staat automatisch maken aan, dan zie je hier het resultaat; zet het uit om alles met de hand te schrijven.' = 'Runs as SYSTEM from the package folder. With create automatically on, you see the result here; switch it off to write everything by hand.'
    'Verwijderstappen opnieuw maken' = 'Recreate uninstall steps'
    'Verwijderstappen (uninstall-app.cmd)' = 'Uninstall steps (uninstall-app.cmd)'
    'Draait als SYSTEM vanuit de pakketmap. Lukt verwijderen via de setup.exe niet, gebruik dan: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "naam in Apps en onderdelen"' = 'Runs as SYSTEM from the package folder. If removing through the setup.exe does not work, use: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Remove-App.ps1" -Name "name in Apps & features"'
    'Bestanden in het pakket' = 'Files in the package'
    'Alles in deze lijst gaat mee in het .intunewin-pakket (installers, logo, configuratie, eigen scripts).' = 'Everything in this list goes into the .intunewin package (installers, logo, configuration, own scripts).'
    'Bestanden toevoegen...' = 'Add files...'
    'Geselecteerde verwijderen' = 'Remove selected'
    'Map openen' = 'Open folder'
    '3. Teksten' = '3. Texts'
    'Teksten voor deze app en versie, in het Nederlands en het Engels. Laat een veld leeg voor de standaardtekst (grijs eronder). Gebruikers met Engelse Windows krijgen de Engelse teksten (zie Taal van de popups in tabblad 1). Staat de app nog niet op de laptop, dan gelden de teksten "Nieuwe installatie" (onderaan). Je kunt {AppName}, {Versie}, {Minuten} en {MaxUitstel} gebruiken (Engels: {Version}, {Minutes}, {MaxPostpones}); die worden automatisch ingevuld.' = 'Texts for this app and version, in Dutch and English. Leave a field empty for the standard text (grey below it). Users with English Windows get the English texts (see Popup language in tab 1). When the app is not on the laptop yet, the "New installation" texts (at the bottom) apply. You can use {Version}, {Minutes} and {MaxPostpones} (Dutch: {Versie}, {Minuten}, {MaxUitstel}) and {AppName}; they are filled in automatically.'
    'Teksten en voorbeelden in' = 'Texts and previews in'
    'Nederlands' = 'Dutch'
    'Engels' = 'English'
    'Standaardteksten voor alle apps bewerken...' = 'Edit standard texts for all apps...'
    'Voorbeelden tonen als nieuwe installatie (de app staat nog niet op de laptop)' = 'Show previews as a new installation (the app is not on the laptop yet)'
    'Voorbeeld: Update beschikbaar' = 'Preview: update available'
    'Voorbeeld: laatste keer' = 'Preview: last time'
    'Voorbeeld: waarschuwing' = 'Preview: warning'
    'Voorbeeld: installeren' = 'Preview: installing'
    'Voorbeeld: geslaagd' = 'Preview: success'
    'Voorbeeld: mislukt' = 'Preview: failed'
    'Voorbeeld: herstart' = 'Preview: restart'
    'Voorbeeld: verplichte herstart' = 'Preview: mandatory restart'
    'Voorbeeld: verwijderen' = 'Preview: removing'
    'Voorbeeld: verwijderd' = 'Preview: removed'
    '4. Uitstellen' = '4. Postponing'
    'Hoe vaak mag de gebruiker uitstellen?' = 'How often may the user postpone?'
    'Hoe lang duurt een keer uitstellen? (uren)' = 'How long is one postpone? (hours)'
    'Waarschuwing na de laatste keer (minuten)' = 'Warning after the last postpone (minutes)'
    '0 = meteen installeren, zonder waarschuwing.' = '0 = install right away, without warning.'
    'Geen keuze gemaakt: venster sluiten na (minuten)' = 'No choice made: close the popup after (minutes)'
    'Daarna wordt het later opnieuw gevraagd; dit telt niet als uitstellen.' = 'It is then asked again later; this does not count as a postpone.'
    'Wanneer mag de update komen?' = 'When may the update come?'
    'Tijdvenster' = 'Time window'
    'Altijd' = 'Always'
    'Alleen binnen werktijd' = 'Only during working hours'
    'Alleen buiten werktijd (avond, nacht, weekend)' = 'Only outside working hours (evening, night, weekend)'
    'Werktijd van' = 'Working hours from'
    'tot' = 'to'
    'ma' = 'Mon'; 'di' = 'Tue'; 'wo' = 'Wed'; 'do' = 'Thu'; 'vr' = 'Fri'; 'za' = 'Sat'; 'zo' = 'Sun'
    'Direct installeren, zonder popup, als de gebruiker' = 'Install right away, without popup, when the user has been idle for'
    'minuten niets doet of het scherm vergrendeld is' = 'minutes or the screen is locked'
    'Handig voor apps die je liever installeert als iemand weg is, bijvoorbeeld tijdens de lunch. De app moet wel dicht zijn; staat hij open, dan wacht de installatie gewoon.' = 'Useful for apps you prefer to install while someone is away, for example during lunch. The app must be closed; when it is open, the installation simply waits.'
    'Niemand ingelogd' = 'Nobody signed in'
    'Direct installeren (ook buiten het tijdvenster)' = 'Install right away (also outside the time window)'
    'Wachten tot er iemand is ingelogd' = 'Wait until someone signs in'
    'Direct installeren is ook nodig voor nieuwe laptops via Autopilot: dan is er nog niemand ingelogd.' = 'Install right away is also needed for new laptops through Autopilot: nobody is signed in yet.'
    'Herstart na de installatie' = 'Restart after the installation'
    'Herstartmelding tonen' = 'Show restart prompt'
    'Nooit' = 'Never'
    'Alleen als de installer erom vraagt (3010/1641)' = 'Only when the installer asks for it (3010/1641)'
    'Altijd na de installatie' = 'Always after the installation'
    'Later: opnieuw vragen na (min)' = 'Later: ask again after (min)'
    'Verplicht herstarten na (uur)' = 'Mandatory restart after (hours)'
    '0 = nooit verplicht.' = '0 = never mandatory.'
    'Waarschuwing vooraf (min)' = 'Warning in advance (min)'
    'Na een geslaagde installatie krijgt de gebruiker een venster met Nu herstarten en Later. Na de deadline volgt een waarschuwing met aftelklok en wordt de laptop herstart. Is niemand ingelogd, dan herstart de laptop direct. Intune krijgt dan exitcode 0, zodat er geen tweede herstartmelding komt. Tijdens Autopilot regelt de inrichtingspagina de herstart.' = 'After a successful installation the user gets a popup with Restart now and Later. After the deadline a warning with countdown follows and the laptop restarts. When nobody is signed in, the laptop restarts right away. Intune then gets exit code 0, so there is no second restart prompt. During Autopilot the setup page (ESP) handles the restart.'
    'Verwijderen' = 'Uninstall'
    'Meldingen tonen als de app via Intune wordt verwijderd' = 'Show notifications when the app is removed through Intune'
    'Rechtsonder: ''... wordt verwijderd'' met voortgangsbalk, daarna ''... is verwijderd'' (groen) of ''Verwijderen niet gelukt'' (rood). De teksten pas je aan in tabblad 3.' = 'Bottom right: ''Removing ...'' with a progress bar, then ''... has been removed'' (green) or ''Removal failed'' (red). You change the texts in tab 3.'
    '5. Versies' = '5. Versions'
    'Alle builds blijven bewaard, ook eerdere builds van dezelfde versie (vervangen). Klik op een build om te zien hoe die gemaakt is; met Kopie maken en aanpassen ga je er verder mee.' = 'All builds are kept, also earlier builds of the same version (replaced). Click a build to see how it was made; with Copy and edit you continue from it.'
    'Kopie maken en aanpassen' = 'Copy and edit'
    'Gebouwd' = 'Built'
    'Pakket' = 'Package'
    'Kies links een versie' = 'Pick a version on the left'
    'Update beschikbaar' = 'Update available'
    'Laatste keer uitstellen' = 'Last postpone'
    'Waarschuwing' = 'Warning'
    'Geslaagd' = 'Success'
    'Mislukt' = 'Failed'
    'Herstart' = 'Restart'
    'Verplichte herstart' = 'Mandatory restart'
    'Verwijderd' = 'Removed'
    'Voorbeeld van deze versie' = 'Preview this version'
    'Overzicht' = 'Overview'
    'Installatiestappen' = 'Installation steps'
    'Teksten' = 'Texts'
    'Bouwinfo' = 'Build info'
    'Resultaat' = 'Result'
    # standard texts window
    'Standaardteksten voor alle apps' = 'Standard texts for all apps'
    'Deze teksten gebruikt elke app, tenzij je bij een app in tabblad 3 een eigen tekst invult. Je kunt {AppName}, {Versie}, {Minuten} en {MaxUitstel} gebruiken (Engels: {Version}, {Minutes}, {MaxPostpones}). Bouw de pakketten daarna opnieuw.' = 'Every app uses these texts, unless you fill in its own text in tab 3. You can use {AppName}, {Version}, {Minutes} and {MaxPostpones} (Dutch: {Versie}, {Minuten}, {MaxUitstel}). Build the packages again afterwards.'
    'Taal' = 'Language'
    'Ingebouwde teksten terugzetten' = 'Restore built-in texts'
    'Annuleren' = 'Cancel'
}

function Convert-XamlLanguage
{
    # Replaces the Dutch texts in a XAML document by English (only when the Builder language is English)
    param ([xml]$Doc)
    if ($script:Lang -ne 'en') { return $Doc }
    $attrs = 'Content', 'Text', 'Header', 'Title', 'ToolTip'
    foreach ($el in $Doc.SelectNodes('//*'))
    {
        $byName = if ($el.GetAttribute('Name')) { $UiTextEn["name:$($el.GetAttribute('Name'))"] }
        $byTag  = if ($el.LocalName -eq 'ComboBoxItem' -and $el.GetAttribute('Tag')) { $UiTextEn["tag:$($el.GetAttribute('Tag'))"] }
        foreach ($a in $attrs)
        {
            $v = $el.GetAttribute($a)
            if (-not $v) { continue }
            if ($a -eq 'Content' -and $byName) { $el.SetAttribute($a, $byName); continue }
            if ($a -eq 'Content' -and $byTag)  { $el.SetAttribute($a, $byTag);  continue }
            if ($UiTextEn.ContainsKey($v)) { $el.SetAttribute($a, $UiTextEn[$v]) }
        }
        # <TextBlock>text</TextBlock>
        foreach ($child in @($el.ChildNodes))
        {
            if ($child.NodeType -eq 'Text')
            {
                $v = $child.Value.Trim()
                if ($UiTextEn.ContainsKey($v)) { $child.Value = $UiTextEn[$v] }
            }
        }
    }
    return $Doc
}

if ($env:APPKIT_NOGUI) { return }   # for tests: only load the functions

#region ===================== Window =====================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic

# Own identity in the taskbar, so Windows shows the Builder icon and not the PowerShell one
try
{
    Add-Type -Namespace AppKit -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string id);'
    [void][AppKit.Shell]::SetCurrentProcessExplicitAppUserModelID('AppUpdateKit.Builder')
}
catch { }
$BuilderIcon = Join-Path $KitDir 'Builder.ico'

# Row in the components table
if (-not ('AppKit.Component' -as [type]))
{
    Add-Type -TypeDefinition @"
namespace AppKit {
    public class Component {
        public bool   Main        { get; set; }
        public string File        { get; set; }
        public string Kind        { get; set; }
        public string Args        { get; set; }
        public string Codes       { get; set; }
        public string ProductCode { get; set; }
    }
}
"@
}

# Error during start-up (before the window exists): still show a message
trap
{
    $log = Join-Path ([System.IO.Path]::GetTempPath()) 'AppUpdateKit-Builder-fouten.log'
    Add-Content -Path $log -Value "$(Get-Date)`r`n$($_ | Out-String)" -ErrorAction SilentlyContinue
    [void][System.Windows.MessageBox]::Show("$(T 'De Builder kon niet starten' 'The Builder could not start'):`n`n$($_.Exception.Message)`n`nDetails: $log", 'AppUpdateKit Builder', 'OK', 'Error')
    exit 1
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AppUpdateKit Builder" Width="1060" Height="760" MinWidth="900" MinHeight="600"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="13" Background="#F5F6F8">
  <Window.Resources>
    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="Margin" Value="0,2,0,8"/>
      <Setter Property="BorderBrush" Value="#C8CCD2"/>
    </Style>
    <Style TargetType="Label">
      <Setter Property="Padding" Value="0,4,0,0"/>
      <Setter Property="Foreground" Value="#333"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#6B7280"/>
      <Setter Property="FontSize" Value="11.5"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,-4,0,8"/>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Padding" Value="12,6"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="#B0B6BE"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#185FA5"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderBrush" Value="#185FA5"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="#E1E4E8"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="16"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
  </Window.Resources>

  <DockPanel>
    <!-- Kop -->
    <Border DockPanel.Dock="Top" Background="#185FA5" Padding="18,12">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="Taal / Language" Foreground="#D6E6F7" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <ComboBox Name="CmbUiLang" Width="120" ToolTip="Taal van de Builder en van de gemaakte bestanden">
            <ComboBoxItem Tag="nl" Content="Nederlands"/>
            <ComboBoxItem Tag="en" Content="English"/>
          </ComboBox>
        </StackPanel>
        <StackPanel>
          <TextBlock Text="AppUpdateKit Builder" Foreground="White" FontSize="18" FontWeight="SemiBold"/>
          <TextBlock Text="Vul de gegevens in, bekijk de popup en bouw het Intune-pakket." Foreground="#D6E6F7"/>
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Onderbalk -->
    <Border DockPanel.Dock="Bottom" Background="White" BorderBrush="#E1E4E8" BorderThickness="0,1,0,0" Padding="16,10">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button Name="BtnSave" Content="Opslaan"/>
          <Button Name="BtnOpenOutput" Content="Map met pakket openen" IsEnabled="False"/>
          <Button Name="BtnBuild" Content="Bouw pakket (.intunewin)" Style="{StaticResource Primary}" Margin="0"/>
        </StackPanel>
        <TextBlock Name="TxtStatus" VerticalAlignment="Center" Foreground="#555" TextTrimming="CharacterEllipsis"/>
      </DockPanel>
    </Border>

    <!-- Apps -->
    <Border DockPanel.Dock="Left" Width="210" Background="White" BorderBrush="#E1E4E8" BorderThickness="0,0,1,0" Padding="12">
      <DockPanel>
        <TextBlock DockPanel.Dock="Top" Text="Apps" FontWeight="SemiBold" FontSize="14" Margin="0,0,0,8"/>
        <Button DockPanel.Dock="Bottom" Name="BtnNewApp" Content="+ Nieuwe app" Margin="0,8,0,0"/>
        <ListBox Name="LstApps" BorderThickness="0"/>
      </DockPanel>
    </Border>

    <!-- Tabbladen -->
    <TabControl Name="Tabs" Margin="12" IsEnabled="False">

      <TabItem Header="1. Basis">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Installer"/>
                <DockPanel>
                  <Button DockPanel.Dock="Right" Name="BtnInstaller" Content="Kiezen..." Margin="8,2,0,8"/>
                  <TextBox Name="TxtInstaller" IsReadOnly="True" Background="#F7F7F7"/>
                </DockPanel>
                <TextBlock Name="TxtInstallerInfo" Style="{StaticResource Hint}" Text="Kies de installer (.exe of .msi). Naam, versie en stille parameters worden dan automatisch ingevuld."/>
              </StackPanel>
            </Border>

            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                  <Label Content="AppId (interne naam, geen spaties)"/>
                  <TextBox Name="TxtAppId" IsReadOnly="True" Background="#F7F7F7"/>
                  <Label Content="Naam in de popup"/>
                  <TextBox Name="TxtAppName"/>
                  <Label Content="Versie"/>
                  <TextBox Name="TxtVersion"/>
                  <TextBlock Style="{StaticResource Hint}" Text="De versie die dit pakket installeert; Intune detecteert hierop."/>
                </StackPanel>
                <StackPanel Grid.Column="2">
                  <Label Content="Naam in Apps en onderdelen (begint met)"/>
                  <TextBox Name="TxtDetectName"/>
                  <Label Content="Processen die dicht moeten zijn"/>
                  <TextBox Name="TxtProcesses"/>
                  <TextBlock Style="{StaticResource Hint}" Text="Zonder .exe, gescheiden door komma's. Bijv.: notepad++   of   vmware-view, horizon-client. Leeg = geen procescheck (voor apps zonder eigen programma, zoals een runtime of driver)."/>
                  <CheckBox Name="ChkOnlyExisting" Content="Alleen bijwerken op apparaten waar de app al staat" Margin="0,6,0,0"/>
                  <CheckBox Name="ChkDuringSetup" Content="Installeren op nieuwe laptops (Autopilot), zonder popup" Margin="0,6,0,0"/>
                  <TextBlock Style="{StaticResource Hint}" Margin="0,2,0,0" Text="Tijdens de inrichting wordt de app direct geïnstalleerd, ook als hij er nog niet op staat. Uit = de app komt pas na de inrichting, met popup."/>
                </StackPanel>
              </Grid>
            </Border>

            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <Border Grid.Column="0" Width="72" Height="72" CornerRadius="10" Background="#F0F2F5" Margin="0,0,16,0" VerticalAlignment="Top">
                  <Image Name="ImgIcon" Width="52" Height="52"/>
                </Border>
                <StackPanel Grid.Column="1">
                  <Label Content="Logo"/>
                  <StackPanel Orientation="Horizontal" Margin="0,2,0,6">
                    <Button Name="BtnIcon" Content="Logo kiezen..."/>
                    <Button Name="BtnIconFromInstaller" Content="Uit installer halen"/>
                  </StackPanel>
                  <TextBlock Style="{StaticResource Hint}" Text=".svg, .ico, .png of .jpg (wordt omgezet). Liefst vierkant en minstens 256x256."/>
                </StackPanel>
                <StackPanel Grid.Column="3">
                  <Label Content="Kleur van kop en knop"/>
                  <DockPanel>
                    <Border Name="RectAccent" DockPanel.Dock="Left" Width="30" Height="28" CornerRadius="5" Margin="0,2,8,8" Background="#185FA5"/>
                    <TextBox Name="TxtAccent"/>
                  </DockPanel>
                  <TextBlock Style="{StaticResource Hint}" Text="Vorm #RRGGBB, bijv. #185FA5 (blauw) of #3B7A1E (groen)."/>
                  <Label Content="Taal van de popups"/>
                  <ComboBox Name="CmbPopupLang" Margin="0,2,0,6" SelectedIndex="0">
                    <ComboBoxItem Tag="Auto" Content="Automatisch (Windows-taal van de gebruiker)"/>
                    <ComboBoxItem Tag="nl" Content="Altijd Nederlands"/>
                    <ComboBoxItem Tag="en" Content="Altijd Engels"/>
                  </ComboBox>
                  <TextBlock Style="{StaticResource Hint}" Text="Engelse Windows = Engelse popups, anders Nederlands. De teksten staan in tabblad 3."/>
                </StackPanel>
              </Grid>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="2. Installatie">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Onderdelen (worden in deze volgorde geïnstalleerd)"/>
                <TextBlock Style="{StaticResource Hint}" Text="Bijv. eerst een runtime, dan de app zelf. Per onderdeel eigen parameters (dubbelklik om te wijzigen) en de exitcodes die als geslaagd tellen. Mislukt een onderdeel, dan stopt de installatie en krijgt de gebruiker de melding 'niet gelukt'. Het hoofdonderdeel is de app zelf (gebruikt voor verwijderen)."/>
                <DataGrid Name="DgComponents" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False"
                          CanUserSortColumns="False" CanUserReorderColumns="False" HeadersVisibility="Column" SelectionMode="Single"
                          GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#E1E4E8" Height="170" Margin="0,0,0,8"
                          Background="White" BorderBrush="#C8CCD2" RowHeight="26">
                  <DataGrid.Columns>
                    <DataGridCheckBoxColumn Header="Hoofd" Width="50" Binding="{Binding Main, UpdateSourceTrigger=PropertyChanged}"/>
                    <DataGridTextColumn Header="Bestand" Width="2*" IsReadOnly="True" Binding="{Binding File}"/>
                    <DataGridTextColumn Header="Type" Width="60" IsReadOnly="True" Binding="{Binding Kind}"/>
                    <DataGridTextColumn Header="Parameters" Width="2*" FontFamily="Consolas" Binding="{Binding Args, UpdateSourceTrigger=PropertyChanged}"/>
                    <DataGridTextColumn Header="Geslaagd bij exitcode" Width="150" FontFamily="Consolas" Binding="{Binding Codes, UpdateSourceTrigger=PropertyChanged}"/>
                  </DataGrid.Columns>
                </DataGrid>
                <WrapPanel>
                  <Button Name="BtnCompAdd" Content="Onderdeel toevoegen..." Margin="0,0,8,6"/>
                  <Button Name="BtnCompRemove" Content="Verwijderen" Margin="0,0,8,6"/>
                  <Button Name="BtnCompUp" Content="Omhoog" Margin="0,0,8,6"/>
                  <Button Name="BtnCompDown" Content="Omlaag" Margin="0,0,8,6"/>
                </WrapPanel>
                <TextBlock Name="TxtCompInfo" Style="{StaticResource Hint}" Margin="0,2,0,0" Text="Ondersteund: .exe, .msi, .msp, .ps1, .cmd/.bat en .reg. Stille parameters worden voorgesteld."/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="16"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <StackPanel Grid.Column="0">
                  <Label Content="Extra stappen vóór de onderdelen"/>
                  <TextBox Name="TxtPreInstall" AcceptsReturn="True" FontFamily="Consolas" FontSize="12" Height="80"
                           VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                </StackPanel>
                <StackPanel Grid.Column="2">
                  <Label Content="Extra stappen na de onderdelen"/>
                  <TextBox Name="TxtPostInstall" AcceptsReturn="True" FontFamily="Consolas" FontSize="12" Height="80"
                           VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                </StackPanel>
                <TextBlock Grid.Row="1" Grid.ColumnSpan="3" Style="{StaticResource Hint}" Margin="0,8,0,0"
                           Text="Parameters uit Intune gebruiken: install.cmd /noshortcuts maakt APP_NOSHORTCUTS aan. Een stap overslaan doe je zo: 'if defined APP_NOSHORTCUTS goto na_snelkoppelingen', met ':na_snelkoppelingen' na die stap. Ingebouwd zijn /noprocesscheck, /noconsent en /silent."/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <DockPanel>
                  <CheckBox DockPanel.Dock="Left" Name="ChkAutoSteps" VerticalAlignment="Center" Margin="0,0,10,0"
                            Content="Installatiestappen automatisch maken uit de onderdelen"/>
                  <TextBlock/>
                </DockPanel>
                <Label Content="Installatiestappen (install-app.cmd)"/>
                <TextBlock Style="{StaticResource Hint}" Text="Draait als SYSTEM vanuit de pakketmap. Staat automatisch maken aan, dan zie je hier het resultaat; zet het uit om alles met de hand te schrijven."/>
                <TextBox Name="TxtInstallCmd" AcceptsReturn="True" AcceptsTab="True" FontFamily="Consolas" FontSize="12"
                         Height="210" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                <DockPanel>
                  <Button DockPanel.Dock="Right" Name="BtnGenerate" Content="Verwijderstappen opnieuw maken" Margin="8,6,0,0"/>
                  <Label Content="Verwijderstappen (uninstall-app.cmd)"/>
                </DockPanel>
                <TextBlock Style="{StaticResource Hint}" Text="Draait als SYSTEM vanuit de pakketmap. Lukt verwijderen via de setup.exe niet, gebruik dan: powershell.exe -NoProfile -ExecutionPolicy Bypass -File &quot;Remove-App.ps1&quot; -Name &quot;naam in Apps en onderdelen&quot;"/>
                <TextBox Name="TxtUninstallCmd" AcceptsReturn="True" AcceptsTab="True" FontFamily="Consolas" FontSize="12"
                         Height="210" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Bestanden in het pakket"/>
                <TextBlock Style="{StaticResource Hint}" Text="Alles in deze lijst gaat mee in het .intunewin-pakket (installers, logo, configuratie, eigen scripts)."/>
                <ListBox Name="LstFiles" Height="130" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal">
                  <Button Name="BtnAddFiles" Content="Bestanden toevoegen..."/>
                  <Button Name="BtnRemoveFile" Content="Geselecteerde verwijderen"/>
                  <Button Name="BtnOpenAppFolder" Content="Map openen"/>
                </StackPanel>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="3. Teksten">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock TextWrapping="Wrap" Margin="0,0,0,4">Teksten voor deze app en versie, in het Nederlands en het Engels. Laat een veld leeg voor de standaardtekst (grijs eronder). Gebruikers met Engelse Windows krijgen de Engelse teksten (zie Taal van de popups in tabblad 1). Staat de app nog niet op de laptop, dan gelden de teksten "Nieuwe installatie" (onderaan). Je kunt {AppName}, {Versie}, {Minuten} en {MaxUitstel} gebruiken (Engels: {Version}, {Minutes}, {MaxPostpones}); die worden automatisch ingevuld.</TextBlock>
                <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                  <Label Content="Teksten en voorbeelden in" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <ComboBox Name="CmbTextLang" Width="150" SelectedIndex="0">
                    <ComboBoxItem Tag="nl" Content="Nederlands"/>
                    <ComboBoxItem Tag="en" Content="Engels"/>
                  </ComboBox>
                </StackPanel>
                <Button Name="BtnStdTexts" Content="Standaardteksten voor alle apps bewerken..." HorizontalAlignment="Left" Margin="0,6,0,0"/>
                <CheckBox Name="ChkPrevNew" Content="Voorbeelden tonen als nieuwe installatie (de app staat nog niet op de laptop)" Margin="0,10,0,0"/>
                <WrapPanel Margin="0,8,0,0">
                  <Button Name="BtnPrevConsent" Content="Voorbeeld: Update beschikbaar" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevLast" Content="Voorbeeld: laatste keer" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevForced" Content="Voorbeeld: waarschuwing" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevInstalling" Content="Voorbeeld: installeren" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevSuccess" Content="Voorbeeld: geslaagd" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevError" Content="Voorbeeld: mislukt" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevRestart" Content="Voorbeeld: herstart" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevRestartForced" Content="Voorbeeld: verplichte herstart" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevUninstalling" Content="Voorbeeld: verwijderen" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevUninstalled" Content="Voorbeeld: verwijderd" Margin="0,0,8,6"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <StackPanel Name="PnlTexts"/>
                <StackPanel Name="PnlTextsEn" Visibility="Collapsed"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="4. Uitstellen">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                  <Label Content="Hoe vaak mag de gebruiker uitstellen?"/>
                  <TextBox Name="TxtMaxPostpones"/>
                  <Label Content="Hoe lang duurt een keer uitstellen? (uren)"/>
                  <TextBox Name="TxtPostponeHours"/>
                </StackPanel>
                <StackPanel Grid.Column="2">
                  <Label Content="Waarschuwing na de laatste keer (minuten)"/>
                  <TextBox Name="TxtForcedMinutes"/>
                  <TextBlock Style="{StaticResource Hint}" Text="0 = meteen installeren, zonder waarschuwing."/>
                  <Label Content="Geen keuze gemaakt: venster sluiten na (minuten)"/>
                  <TextBox Name="TxtConsentTimeout"/>
                  <TextBlock Style="{StaticResource Hint}" Text="Daarna wordt het later opnieuw gevraagd; dit telt niet als uitstellen."/>
                </StackPanel>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="Wanneer mag de update komen?" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <Label Content="Tijdvenster"/>
                <ComboBox Name="CmbWindow" Width="340" HorizontalAlignment="Left" Margin="0,2,0,6" SelectedIndex="0">
                  <ComboBoxItem Tag="Altijd" Content="Altijd"/>
                  <ComboBoxItem Tag="Werktijd" Content="Alleen binnen werktijd"/>
                  <ComboBoxItem Tag="BuitenWerktijd" Content="Alleen buiten werktijd (avond, nacht, weekend)"/>
                </ComboBox>
                <StackPanel Name="PnlWorkTime" Margin="0,0,0,4">
                  <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                    <Label Content="Werktijd van" VerticalAlignment="Center" Margin="0,0,8,0"/>
                    <TextBox Name="TxtWorkFrom" Width="64"/>
                    <Label Content="tot" VerticalAlignment="Center" Margin="8,0,8,0"/>
                    <TextBox Name="TxtWorkTo" Width="64"/>
                  </StackPanel>
                  <WrapPanel Name="PnlWorkDays" Margin="0,8,0,4">
                    <CheckBox Name="ChkDayMa" Content="ma" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayDi" Content="di" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayWo" Content="wo" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayDo" Content="do" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayVr" Content="vr" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayZa" Content="za" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayZo" Content="zo" Margin="0,0,12,0"/>
                  </WrapPanel>
                </StackPanel>
                <TextBlock Name="TxtWindowHint" Style="{StaticResource Hint}" Margin="0,2,0,10"/>

                <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                  <CheckBox Name="ChkIdle" Content="Direct installeren, zonder popup, als de gebruiker" VerticalAlignment="Center"/>
                  <TextBox Name="TxtIdleMinutes" Width="48" Margin="6,0,6,0"/>
                  <TextBlock Text="minuten niets doet of het scherm vergrendeld is" VerticalAlignment="Center"/>
                </StackPanel>
                <TextBlock Style="{StaticResource Hint}" Margin="0,4,0,10" Text="Handig voor apps die je liever installeert als iemand weg is, bijvoorbeeld tijdens de lunch. De app moet wel dicht zijn; staat hij open, dan wacht de installatie gewoon."/>

                <Label Content="Niemand ingelogd"/>
                <ComboBox Name="CmbNoUser" Width="340" HorizontalAlignment="Left" Margin="0,2,0,6" SelectedIndex="0">
                  <ComboBoxItem Tag="Installeren" Content="Direct installeren (ook buiten het tijdvenster)"/>
                  <ComboBoxItem Tag="Wachten" Content="Wachten tot er iemand is ingelogd"/>
                </ComboBox>
                <TextBlock Style="{StaticResource Hint}" Text="Direct installeren is ook nodig voor nieuwe laptops via Autopilot: dan is er nog niemand ingelogd."/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="Herstart na de installatie" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <Label Content="Herstartmelding tonen"/>
                <ComboBox Name="CmbRestart" Width="340" HorizontalAlignment="Left" Margin="0,2,0,6" SelectedIndex="0">
                  <ComboBoxItem Tag="Nooit" Content="Nooit"/>
                  <ComboBoxItem Tag="AlsNodig" Content="Alleen als de installer erom vraagt (3010/1641)"/>
                  <ComboBoxItem Tag="Altijd" Content="Altijd na de installatie"/>
                </ComboBox>
                <Grid Name="PnlRestart" Margin="0,4,0,0">
                  <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                  <StackPanel Grid.Column="0">
                    <Label Content="Later: opnieuw vragen na (min)"/>
                    <TextBox Name="TxtRestartReminder"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2">
                    <Label Content="Verplicht herstarten na (uur)"/>
                    <TextBox Name="TxtRestartDeadline"/>
                    <TextBlock Style="{StaticResource Hint}" Margin="0,2,0,0" Text="0 = nooit verplicht."/>
                  </StackPanel>
                  <StackPanel Grid.Column="4">
                    <Label Content="Waarschuwing vooraf (min)"/>
                    <TextBox Name="TxtRestartWarning"/>
                  </StackPanel>
                </Grid>
                <TextBlock Style="{StaticResource Hint}" Margin="0,8,0,0" Text="Na een geslaagde installatie krijgt de gebruiker een venster met Nu herstarten en Later. Na de deadline volgt een waarschuwing met aftelklok en wordt de laptop herstart. Is niemand ingelogd, dan herstart de laptop direct. Intune krijgt dan exitcode 0, zodat er geen tweede herstartmelding komt. Tijdens Autopilot regelt de inrichtingspagina de herstart."/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="Verwijderen" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <CheckBox Name="ChkUninstallNotify" Content="Meldingen tonen als de app via Intune wordt verwijderd"/>
                <TextBlock Style="{StaticResource Hint}" Margin="0,4,0,0" Text="Rechtsonder: '... wordt verwijderd' met voortgangsbalk, daarna '... is verwijderd' (groen) of 'Verwijderen niet gelukt' (rood). De teksten pas je aan in tabblad 3."/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Name="TabVersions" Header="5. Versies">
        <Grid Margin="12">
          <Grid.ColumnDefinitions><ColumnDefinition Width="330"/><ColumnDefinition Width="12"/><ColumnDefinition/></Grid.ColumnDefinitions>

          <DockPanel Grid.Column="0">
            <TextBlock DockPanel.Dock="Top" Style="{StaticResource Hint}" Margin="0,0,0,8" Text="Alle builds blijven bewaard, ook eerdere builds van dezelfde versie (vervangen). Klik op een build om te zien hoe die gemaakt is; met Kopie maken en aanpassen ga je er verder mee."/>
            <WrapPanel DockPanel.Dock="Bottom" Margin="0,8,0,0">
              <Button Name="BtnVerOpen" Content="Map openen" Margin="0,0,6,6"/>
              <Button Name="BtnVerRestore" Content="Kopie maken en aanpassen" Margin="0,0,6,6" FontWeight="SemiBold"/>
              <Button Name="BtnVerDelete" Content="Verwijderen" Margin="0,0,6,6"/>
            </WrapPanel>
            <ListView Name="LstVersions">
              <ListView.View>
                <GridView>
                  <GridViewColumn Header="Versie" Width="125" DisplayMemberBinding="{Binding Label}"/>
                  <GridViewColumn Header="Gebouwd" Width="110" DisplayMemberBinding="{Binding BuiltText}"/>
                  <GridViewColumn Header="Pakket" Width="75" DisplayMemberBinding="{Binding PkgText}"/>
                </GridView>
              </ListView.View>
            </ListView>
          </DockPanel>

          <DockPanel Grid.Column="2" Name="PnlVerDetails" IsEnabled="False">
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}">
              <DockPanel>
                <Border DockPanel.Dock="Left" Width="56" Height="56" CornerRadius="10" Background="#F0F2F5" Margin="0,0,14,0">
                  <Image Name="ImgVerIcon" Width="40" Height="40"/>
                </Border>
                <StackPanel>
                  <TextBlock Name="TxtVerTitle" FontSize="15" FontWeight="SemiBold" Text="Kies links een versie"/>
                  <TextBlock Name="TxtVerSub" Style="{StaticResource Hint}" Margin="0,2,0,8"/>
                  <StackPanel Orientation="Horizontal">
                    <ComboBox Name="CmbVerPreview" Width="190" Margin="0,0,8,0" SelectedIndex="0">
                      <ComboBoxItem Tag="consent" Content="Update beschikbaar"/>
                      <ComboBoxItem Tag="last" Content="Laatste keer uitstellen"/>
                      <ComboBoxItem Tag="forced" Content="Waarschuwing"/>
                      <ComboBoxItem Tag="installing" Content="Installeren"/>
                      <ComboBoxItem Tag="success" Content="Geslaagd"/>
                      <ComboBoxItem Tag="error" Content="Mislukt"/>
                      <ComboBoxItem Tag="restart" Content="Herstart"/>
                      <ComboBoxItem Tag="restartforced" Content="Verplichte herstart"/>
                      <ComboBoxItem Tag="uninstalling" Content="Verwijderen"/>
                      <ComboBoxItem Tag="uninstalled" Content="Verwijderd"/>
                    </ComboBox>
                    <Button Name="BtnVerPreview" Content="Voorbeeld van deze versie"/>
                  </StackPanel>
                </StackPanel>
              </DockPanel>
            </Border>
            <TabControl>
              <TabItem Header="Overzicht">
                <TextBox Name="TxtVerSummary" IsReadOnly="True" FontFamily="Consolas" FontSize="12" Margin="0" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
              <TabItem Header="Installatiestappen">
                <TextBox Name="TxtVerInstall" IsReadOnly="True" FontFamily="Consolas" FontSize="12" Margin="0" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
              <TabItem Header="Teksten">
                <TextBox Name="TxtVerTexts" IsReadOnly="True" FontSize="12.5" Margin="0" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
              <TabItem Header="Bouwinfo">
                <TextBox Name="TxtVerBuildInfo" IsReadOnly="True" FontFamily="Consolas" FontSize="11.5" Margin="0" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
            </TabControl>
          </DockPanel>
        </Grid>
      </TabItem>

      <TabItem Name="TabLog" Header="Resultaat">
        <TextBox Name="TxtLog" Margin="12" IsReadOnly="True" FontFamily="Consolas" FontSize="12" Background="#1E1E1E" Foreground="#E6E6E6"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
      </TabItem>
    </TabControl>
  </DockPanel>
</Window>
'@

$xaml = Convert-XamlLanguage $xaml
$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
if (Test-Path $BuilderIcon) { try { $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([uri]$BuilderIcon) } catch { } }

function Update-BuilderShortcut
{
    # Shortcut "AppUpdateKit Builder" with the Builder icon in the kit folder (updated at every start)
    try
    {
        $s = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $KitRoot 'AppUpdateKit Builder.lnk'))
        $s.TargetPath       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $s.Arguments        = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $KitRoot 'AppUpdateKit-Builder.ps1')`""
        $s.WorkingDirectory = $KitRoot
        $s.IconLocation     = "$BuilderIcon,0"
        $s.WindowStyle      = 7
        $s.Description      = 'AppUpdateKit Builder'
        $s.Save()
    }
    catch { }
}
$ui = @{}
$xaml.SelectNodes('//*[@Name]') | ForEach-Object { $ui[$_.Name] = $Window.FindName($_.Name) }

$script:CurrentApp = $null     # AppId of the loaded app
$script:Info = @{ Kind = 'EXE'; ProductCode = '' }
$script:Components = New-Object 'System.Collections.ObjectModel.ObservableCollection[AppKit.Component]'
$ui.DgComponents.ItemsSource = $script:Components
$script:TextBoxes = @{}
$script:TextHints = @{}
$script:TextBoxesEn = @{}
$script:TextHintsEn = @{}

function Set-Status([string]$Text) { $ui.TxtStatus.Text = $Text }
function Show-Error([string]$Text) { [void][System.Windows.MessageBox]::Show($Text, 'AppUpdateKit Builder', 'OK', 'Warning') }

$script:ErrorLog = Join-Path $KitRoot 'Builder-fouten.log'
function Write-BuilderError($ErrorRecord)
{
    # Show and log the error, instead of the Builder closing without a message
    if ($ErrorRecord -is [System.Management.Automation.RuntimeException] -and $ErrorRecord.ErrorRecord) { $ErrorRecord = $ErrorRecord.ErrorRecord }
    $msg = if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
        "$($ErrorRecord.Exception.Message)`r`n$($ErrorRecord.InvocationInfo.PositionMessage)`r`n$($ErrorRecord.ScriptStackTrace)"
    } else { "$ErrorRecord" }
    try { Add-Content -Path $script:ErrorLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n$msg`r`n" -ErrorAction Stop }
    catch { $script:ErrorLog = Join-Path ([System.IO.Path]::GetTempPath()) 'AppUpdateKit-Builder-fouten.log'; Add-Content -Path $script:ErrorLog -Value $msg -ErrorAction SilentlyContinue }
    $first = ($msg -split "`r?`n")[0]
    Show-Error "$(T 'Er ging iets mis' 'Something went wrong'):`n`n$first`n`n$(T 'De details staan in' 'Details are in'):`n$($script:ErrorLog)"
    Set-Status "$(T 'Fout' 'Error'): $first"
}

# Safety net: any unexpected error in a button or timer shows a message instead of closing
$Window.Dispatcher.Add_UnhandledException({
    param($s, $e)
    $e.Handled = $true
    Write-BuilderError $e.Exception
})
function Get-AppFolder { if ($script:CurrentApp) { Join-Path $AppsRoot $script:CurrentApp } }

# Text fields: one set for Dutch (PnlTexts) and one for English (PnlTextsEn)
foreach ($lang in 'nl', 'en')
{
    $panel = if ($lang -eq 'en') { $ui.PnlTextsEn } else { $ui.PnlTexts }
    foreach ($k in $TextKeys)
    {
        $lbl = New-Object System.Windows.Controls.Label
        $lbl.Content = "$($TextLabels[$k])$(if ($lang -eq 'en') { T '  (Engels)' '  (English)' } else { T '' '  (Dutch)' })"
        $tb = New-Object System.Windows.Controls.TextBox
        $tb.TextWrapping = 'Wrap'
        if ($k -like '*Message' -or $k -eq 'ForcedInfo') { $tb.AcceptsReturn = $false; $tb.MinHeight = 48 }
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Style = $Window.FindResource('Hint')
        [void]$panel.Children.Add($lbl)
        [void]$panel.Children.Add($tb)
        [void]$panel.Children.Add($hint)
        if ($lang -eq 'en') { $script:TextBoxesEn[$k] = $tb; $script:TextHintsEn[$k] = $hint }
        else { $script:TextBoxes[$k] = $tb; $script:TextHints[$k] = $hint }
    }
}

function Update-TextHints
{
    $std = Get-StandardTexts 'nl'
    $stdEn = Get-StandardTexts 'en'
    foreach ($k in $TextKeys)
    {
        $script:TextHints[$k].Text   = "$(T 'Standaard' 'Standard'): $($std[$k])"
        $script:TextHintsEn[$k].Text = "$(T 'Standaard' 'Standard'): $($stdEn[$k])"
    }
}
Update-TextHints

function Get-TextLanguage { if ([string]$ui.CmbTextLang.SelectedItem.Tag -eq 'en') { 'en' } else { 'nl' } }
function Update-TextPanels
{
    $en = (Get-TextLanguage) -eq 'en'
    $ui.PnlTexts.Visibility   = if ($en) { 'Collapsed' } else { 'Visible' }
    $ui.PnlTextsEn.Visibility = if ($en) { 'Visible' } else { 'Collapsed' }
}

function Update-AppList
{
    $ui.LstApps.Items.Clear()
    if (-not (Test-Path $AppsRoot)) { New-Item $AppsRoot -ItemType Directory | Out-Null }
    Get-ChildItem $AppsRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'app.psd1') } |
        Sort-Object Name | ForEach-Object { [void]$ui.LstApps.Items.Add($_.Name) }
}

function New-ComponentRow($c)
{
    $o = New-Object AppKit.Component
    $o.Main = [bool]$c.Main; $o.File = "$($c.File)"; $o.Kind = "$($c.Kind)"; $o.Args = "$($c.Args)"
    $o.Codes = if ($c.Codes) { "$($c.Codes)" } else { '0 3010 1641' }
    $o.ProductCode = "$($c.ProductCode)"
    return $o
}

function Get-ComponentList
{
    return @($script:Components | ForEach-Object {
        @{ Main = $_.Main; File = $_.File; Kind = $_.Kind; Args = $_.Args; Codes = $_.Codes; ProductCode = $_.ProductCode } })
}

function Get-MainComponent
{
    $m = $script:Components | Where-Object { $_.Main } | Select-Object -First 1
    if (-not $m) { $m = $script:Components | Select-Object -Last 1 }
    return $m
}

function Update-InstallPreview
{
    $auto = [bool]$ui.ChkAutoSteps.IsChecked
    $ui.TxtInstallCmd.IsReadOnly = $auto
    $ui.TxtInstallCmd.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($(if ($auto) { '#F7F7F7' } else { '#FFFFFF' }))
    if ($auto)
    {
        $ui.TxtInstallCmd.Text = New-InstallCmdFromComponents $ui.TxtAppName.Text (Get-ComponentList) $ui.TxtPreInstall.Text $ui.TxtPostInstall.Text
    }
}

function Add-ComponentFile([string]$Source, [bool]$AsMain = $false)
{
    # Copies the file to the app folder and adds it as a component; returns the info
    $dir = Get-AppFolder
    $name = [System.IO.Path]::GetFileName($Source)
    $dest = Join-Path $dir $name
    if ($Source -ne $dest) { Set-Status "$(T 'Kopiëren van' 'Copying') $name..."; Copy-Item -LiteralPath $Source -Destination $dest -Force }
    $info = Get-ComponentInfo $dest
    $existing = $script:Components | Where-Object { $_.File -eq $name } | Select-Object -First 1
    if ($existing) { $existing.Kind = $info.Kind; $existing.ProductCode = $info.ProductCode }
    else
    {
        if ($AsMain) { foreach ($c in $script:Components) { $c.Main = $false } }
        $info.Main = $AsMain -or ($script:Components.Count -eq 0)
        $script:Components.Add((New-ComponentRow $info))
    }
    $ui.DgComponents.Items.Refresh()
    return $info
}

function Update-FileList
{
    $ui.LstFiles.Items.Clear()
    $dir = Get-AppFolder
    if (-not $dir) { return }
    $skip = @('app.psd1', 'install-app.cmd', 'uninstall-app.cmd')
    Get-ChildItem $dir -File | Where-Object { $_.Name -notin $skip } | Sort-Object Name | ForEach-Object {
        $size = if ($_.Length -ge 1MB) { '{0:N0} MB' -f ($_.Length / 1MB) } else { '{0:N0} kB' -f [math]::Max(1, $_.Length / 1KB) }
        [void]$ui.LstFiles.Items.Add("$($_.Name)   ($size)")
    }
}

function Update-VersionList
{
    $ui.LstVersions.Items.Clear()
    Show-VersionDetails
    if (-not $script:CurrentApp) { return }
    foreach ($v in (Get-AppVersions $script:CurrentApp))
    {
        [void]$ui.LstVersions.Items.Add([pscustomobject]@{
            Version   = $v.Version
            Label     = $v.Label
            IsArchive = $v.IsArchive
            HasInstallers = $v.HasInstallers
            Path      = $v.Path
            HasBron   = $v.HasBron
            BuiltText = $v.Built.ToString('dd-MM-yyyy HH:mm')
            PkgText   = if ($v.HasPkg) { "$($v.SizeMB) MB" } else { T 'nee' 'no' }
            BronText  = if ($v.HasBron) { T 'ja' 'yes' } else { T 'nee' 'no' }
        })
    }
}

function Show-VersionDetails
{
    $v = $ui.LstVersions.SelectedItem
    $script:SelectedVersion = $null
    $ui.ImgVerIcon.Source = $null
    if (-not $v)
    {
        $ui.PnlVerDetails.IsEnabled = $false
        $ui.TxtVerTitle.Text = T 'Kies links een versie' 'Pick a version on the left'
        $ui.TxtVerSub.Text = ''
        foreach ($n in 'TxtVerSummary', 'TxtVerInstall', 'TxtVerTexts', 'TxtVerBuildInfo') { $ui[$n].Text = '' }
        return
    }
    $det = Get-VersionDetails $v.Path
    $script:SelectedVersion = $det
    $ui.PnlVerDetails.IsEnabled = $true
    $ui.TxtVerTitle.Text = "$(if ($det.Data) { $det.Data.AppName } else { $script:CurrentApp }) $($v.Version)"
    $ui.TxtVerSub.Text = "$(T 'Gebouwd op' 'Built on') $($v.BuiltText)  |  install.intunewin: $($v.PkgText)" +
                         $(if ($v.IsArchive) { T '  |  eerdere build, later opnieuw gebouwd' '  |  earlier build, rebuilt later' } else { '' }) +
                         $(if (-not $v.HasInstallers) { T '  |  installers niet bewaard (oude build)' '  |  installers not kept (old build)' } else { '' })

    $summary = $det.Summary
    if ($det.Data)
    {
        $installNow = $ui.TxtInstallCmd.Text
        $installOld = if (Test-Path (Join-Path $v.Path 'Bron\install-app.cmd')) { [System.IO.File]::ReadAllText((Join-Path $v.Path 'Bron\install-app.cmd')) } else { '' }
        $diff = @(Compare-AppData $det.Data (Read-Form) $installOld $installNow)
        $summary += "`r`n`r`n---------- $(T 'Verschil met wat nu in de Builder staat' 'Difference with what is in the Builder now') ----------`r`n"
        $summary += if ($diff.Count) { ($diff | ForEach-Object { "- $_" }) -join "`r`n" } else { T 'Geen verschillen.' 'No differences.' }
    }
    $ui.TxtVerSummary.Text   = $summary
    $ui.TxtVerInstall.Text   = $det.Install
    $ui.TxtVerTexts.Text     = $det.Texts
    $ui.TxtVerBuildInfo.Text = $det.BuildInfo
    $ui.BtnVerPreview.IsEnabled = [bool]$det.Data
    if ($det.Icon)
    {
        try
        {
            $bi = New-Object System.Windows.Media.Imaging.BitmapImage
            $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.CreateOptions = 'IgnoreImageCache'; $bi.UriSource = [uri]$det.Icon; $bi.EndInit()
            $ui.ImgVerIcon.Source = $bi
        }
        catch { }
    }
}

function Get-SelectedVersion
{
    $v = $ui.LstVersions.SelectedItem
    if (-not $v) { Show-Error (T 'Selecteer eerst een versie in de lijst.' 'Select a version in the list first.') }
    return $v
}

function Show-StandardTextsEditor
{
    # Small window to edit _Kit\Standaardteksten.psd1 (applies to all apps), Dutch and English
    [xml]$x = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Standaardteksten voor alle apps" Width="760" Height="680" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" FontSize="13" Background="#F5F6F8">
  <DockPanel Margin="14">
    <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
      <TextBlock TextWrapping="Wrap">Deze teksten gebruikt elke app, tenzij je bij een app in tabblad 3 een eigen tekst invult. Je kunt {AppName}, {Versie}, {Minuten} en {MaxUitstel} gebruiken (Engels: {Version}, {Minutes}, {MaxPostpones}). Bouw de pakketten daarna opnieuw.</TextBlock>
      <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
        <TextBlock Text="Taal" VerticalAlignment="Center" Margin="0,0,8,0" FontWeight="SemiBold"/>
        <ComboBox Name="CmbLang" Width="150" SelectedIndex="0">
          <ComboBoxItem Tag="nl" Content="Nederlands"/>
          <ComboBoxItem Tag="en" Content="Engels"/>
        </ComboBox>
      </StackPanel>
    </StackPanel>
    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
      <Button Name="BtnReset" Content="Ingebouwde teksten terugzetten" Padding="12,6" Margin="0,0,8,0"/>
      <Button Name="BtnCancel" Content="Annuleren" Padding="12,6" Margin="0,0,8,0"/>
      <Button Name="BtnOk" Content="Opslaan" Padding="12,6" Background="#185FA5" Foreground="White" BorderBrush="#185FA5"/>
    </StackPanel>
    <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel><StackPanel Name="Pnl"/><StackPanel Name="PnlEn" Visibility="Collapsed"/></StackPanel></ScrollViewer>
  </DockPanel>
</Window>
'@
    $x = Convert-XamlLanguage $x
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $w.Owner = $Window
    $w.Icon = $Window.Icon
    $boxes = @{ nl = @{}; en = @{} }
    foreach ($lang in 'nl', 'en')
    {
        $std = Get-StandardTexts $lang
        $panel = $w.FindName($(if ($lang -eq 'en') { 'PnlEn' } else { 'Pnl' }))
        foreach ($k in $TextKeys)
        {
            $l = New-Object System.Windows.Controls.Label; $l.Content = $TextLabels[$k]; $l.FontWeight = 'SemiBold'; $l.Padding = '0,6,0,2'
            $b = New-Object System.Windows.Controls.TextBox; $b.Text = $std[$k]; $b.TextWrapping = 'Wrap'; $b.Padding = '6,4'
            if ($k -like '*Message' -or $k -eq 'ForcedInfo') { $b.MinHeight = 48 }
            [void]$panel.Children.Add($l); [void]$panel.Children.Add($b)
            $boxes[$lang][$k] = $b
        }
    }
    $cmb = $w.FindName('CmbLang')
    $cmb.SelectedIndex = if ((Get-TextLanguage) -eq 'en') { 1 } else { 0 }
    $toggle = {
        $en = [string]$cmb.SelectedItem.Tag -eq 'en'
        $w.FindName('Pnl').Visibility   = if ($en) { 'Collapsed' } else { 'Visible' }
        $w.FindName('PnlEn').Visibility = if ($en) { 'Visible' } else { 'Collapsed' }
    }
    & $toggle
    $cmb.Add_SelectionChanged($toggle)
    $w.FindName('BtnReset').Add_Click({
        # Only the language that is shown
        if ([string]$cmb.SelectedItem.Tag -eq 'en') { foreach ($k in $TextKeys) { $boxes.en[$k].Text = $BuiltinTextsEn[$k] } }
        else { foreach ($k in $TextKeys) { $boxes.nl[$k].Text = $BuiltinTexts[$k] } }
    })
    $w.FindName('BtnCancel').Add_Click({ $w.Close() })
    $w.FindName('BtnOk').Add_Click({
        $texts = @{}; $textsEn = @{}
        foreach ($k in $TextKeys) { $texts[$k] = $boxes.nl[$k].Text.Trim(); $textsEn[$k] = $boxes.en[$k].Text.Trim() }
        [System.IO.File]::WriteAllText($StandardTextsPath, (ConvertTo-StandardTextsPsd1 $texts $textsEn), (New-Object System.Text.UTF8Encoding $true))
        Update-TextHints
        Set-Status (T 'Standaardteksten opgeslagen. Bouw de pakketten opnieuw om ze te gebruiken.' 'Standard texts saved. Build the packages again to use them.')
        $w.Close()
    })
    [void]$w.ShowDialog()
}

function Update-IconPreview
{
    $ui.ImgIcon.Source = $null
    $dir = Get-AppFolder
    if (-not $dir) { return }
    $p = Join-Path $dir 'app.ico'
    if (Test-Path $p)
    {
        try
        {
            $bi = New-Object System.Windows.Media.Imaging.BitmapImage
            $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.CreateOptions = 'IgnoreImageCache'
            $bi.UriSource = [uri]$p; $bi.EndInit()
            $ui.ImgIcon.Source = $bi
        }
        catch { }
    }
}

function Update-AccentPreview
{
    try { $ui.RectAccent.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($ui.TxtAccent.Text) } catch { }
}

$DayBoxes = [ordered]@{ 'ma' = 'ChkDayMa'; 'di' = 'ChkDayDi'; 'wo' = 'ChkDayWo'; 'do' = 'ChkDayDo'; 'vr' = 'ChkDayVr'; 'za' = 'ChkDayZa'; 'zo' = 'ChkDayZo' }

function Set-ComboByTag($Combo, [string]$Tag)
{
    foreach ($item in $Combo.Items) { if ([string]$item.Tag -eq $Tag) { $Combo.SelectedItem = $item; return } }
    $Combo.SelectedIndex = 0
}

function Update-WindowHint
{
    $tag = [string]$ui.CmbWindow.SelectedItem.Tag
    $ui.PnlWorkTime.IsEnabled = $tag -ne 'Altijd'
    $ui.PnlWorkTime.Opacity   = if ($tag -eq 'Altijd') { 0.45 } else { 1 }
    $ui.TxtIdleMinutes.IsEnabled = [bool]$ui.ChkIdle.IsChecked
    $ui.TxtWindowHint.Text = switch ($tag)
    {
        'Werktijd'       { T 'De popup en de installatie komen alleen op de gekozen dagen binnen de werktijd. Daarbuiten wacht de update tot de volgende werkdag.' 'The popup and the installation only come on the selected days during working hours. Outside them the update waits until the next working day.' }
        'BuitenWerktijd' { T "De update komt alleen 's avonds, 's nachts en op de dagen die niet zijn aangevinkt. Let op: laptops staan dan vaak uit of slapen. De update komt dan pas als het apparaat buiten werktijd aan staat." 'The update only comes in the evening, at night and on the days that are not ticked. Note: laptops are often off or asleep then. The update only comes when the device is on outside working hours.' }
        default          { T 'De popup kan op elk moment van de dag komen.' 'The popup can come at any time of the day.' }
    }
}

function Update-RestartPanel
{
    $on = [string]$ui.CmbRestart.SelectedItem.Tag -ne 'Nooit'
    $ui.PnlRestart.IsEnabled = $on
    $ui.PnlRestart.Opacity   = if ($on) { 1 } else { 0.45 }
}

function Read-Form
{
    $texts = @{}; $textsEn = @{}
    foreach ($k in $TextKeys) { $texts[$k] = $script:TextBoxes[$k].Text.Trim(); $textsEn[$k] = $script:TextBoxesEn[$k].Text.Trim() }
    return @{
        AppId                 = $ui.TxtAppId.Text.Trim()
        AppName               = $ui.TxtAppName.Text.Trim()
        Version               = $ui.TxtVersion.Text.Trim()
        DetectName            = $ui.TxtDetectName.Text.Trim()
        Processes             = @($ui.TxtProcesses.Text -split '[,;]' | ForEach-Object { ($_.Trim() -replace '\.exe$', '') } | Where-Object { $_ })
        Icon                  = 'app.ico'
        AccentColor           = $ui.TxtAccent.Text.Trim()
        PopupLanguage         = [string]$ui.CmbPopupLang.SelectedItem.Tag
        OnlyUpdateExisting    = [bool]$ui.ChkOnlyExisting.IsChecked
        InstallDuringSetup    = [bool]$ui.ChkDuringSetup.IsChecked
        MaxPostpones          = $ui.TxtMaxPostpones.Text.Trim()
        PostponeHours         = $ui.TxtPostponeHours.Text.Trim()
        ConsentTimeoutMinutes = $ui.TxtConsentTimeout.Text.Trim()
        ForcedDelayMinutes    = $ui.TxtForcedMinutes.Text.Trim()
        InstallWindow         = [string]$ui.CmbWindow.SelectedItem.Tag
        WorkHours             = "$($ui.TxtWorkFrom.Text.Trim())-$($ui.TxtWorkTo.Text.Trim())"
        WorkDays              = (@($DayBoxes.Keys | Where-Object { $ui[$DayBoxes[$_]].IsChecked }) -join ',')
        IdleMinutes           = if ($ui.ChkIdle.IsChecked) { $ui.TxtIdleMinutes.Text.Trim() } else { '0' }
        NoUserAction          = [string]$ui.CmbNoUser.SelectedItem.Tag
        RestartMode            = [string]$ui.CmbRestart.SelectedItem.Tag
        RestartReminderMinutes = $ui.TxtRestartReminder.Text.Trim()
        RestartDeadlineHours   = $ui.TxtRestartDeadline.Text.Trim()
        RestartWarningMinutes  = $ui.TxtRestartWarning.Text.Trim()
        UninstallNotify        = [bool]$ui.ChkUninstallNotify.IsChecked
        Texts                 = $texts
        TextsEn               = $textsEn
        AutoInstallSteps      = [bool]$ui.ChkAutoSteps.IsChecked
        Components            = Get-ComponentList
        PreInstall            = $ui.TxtPreInstall.Text.TrimEnd()
        PostInstall           = $ui.TxtPostInstall.Text.TrimEnd()
    }
}

function Import-App([string]$AppId)
{
    $dir = Join-Path $AppsRoot $AppId
    try { $d = Read-AppPsd1 (Join-Path $dir 'app.psd1') }
    catch { Show-Error "$(T "app.psd1 van $AppId kan niet gelezen worden" "app.psd1 of $AppId cannot be read"):`n$($_.Exception.Message)"; return }

    $script:CurrentApp = $AppId
    $ui.Tabs.IsEnabled = $true
    $ui.TxtAppId.Text       = $d.AppId
    $ui.TxtAppName.Text     = $d.AppName
    $ui.TxtVersion.Text     = $d.Version
    $ui.TxtDetectName.Text  = $d.DetectName
    $ui.TxtProcesses.Text   = (@($d.Processes) -join ', ')
    $ui.TxtAccent.Text      = if ($d.AccentColor) { $d.AccentColor } else { '#185FA5' }
    Set-ComboByTag $ui.CmbPopupLang $(if ("$($d.PopupLanguage)" -in 'nl', 'en') { "$($d.PopupLanguage)" } else { 'Auto' })
    $ui.ChkOnlyExisting.IsChecked = if ($null -eq $d.OnlyUpdateExisting) { $true } else { [bool]$d.OnlyUpdateExisting }
    $ui.ChkDuringSetup.IsChecked  = $d.InstallDuringSetup -ne $false
    $ui.TxtMaxPostpones.Text   = if ($null -ne $d.MaxPostpones) { $d.MaxPostpones } else { 5 }
    $ui.TxtPostponeHours.Text  = if ($null -ne $d.PostponeHours) { $d.PostponeHours } else { 24 }
    $ui.TxtConsentTimeout.Text = if ($null -ne $d.ConsentTimeoutMinutes) { $d.ConsentTimeoutMinutes }
                                 elseif ($null -ne $d.ConsentTimeoutSeconds) { [math]::Max(1, [math]::Round($d.ConsentTimeoutSeconds / 60)) }
                                 else { 15 }
    $ui.TxtForcedMinutes.Text  = if ($null -ne $d.ForcedDelayMinutes) { $d.ForcedDelayMinutes } else { 5 }
    Set-ComboByTag $ui.CmbWindow $(if ($d.InstallWindow) { $d.InstallWindow } else { 'Altijd' })
    Set-ComboByTag $ui.CmbNoUser $(if ($d.NoUserAction) { $d.NoUserAction } else { 'Installeren' })
    $hrs = if ($d.WorkHours -match '^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$') { $Matches[1], $Matches[2] } else { '08:00', '17:00' }
    $ui.TxtWorkFrom.Text = $hrs[0]; $ui.TxtWorkTo.Text = $hrs[1]
    $dayText = if ($d.WorkDays) { "$($d.WorkDays)".ToLower() } else { 'ma,di,wo,do,vr' }
    foreach ($k in $DayBoxes.Keys) { $ui[$DayBoxes[$k]].IsChecked = $dayText -match "(^|[,; ])$k" }
    $idle = [int]("0$($d.IdleMinutes)")
    $ui.ChkIdle.IsChecked = $idle -gt 0
    $ui.TxtIdleMinutes.Text = if ($idle -gt 0) { $idle } else { 30 }
    Update-WindowHint
    Set-ComboByTag $ui.CmbRestart $(if ($d.RestartMode) { $d.RestartMode } else { 'Nooit' })
    $ui.TxtRestartReminder.Text = if ($null -ne $d.RestartReminderMinutes) { $d.RestartReminderMinutes } else { 60 }
    $ui.TxtRestartDeadline.Text = if ($null -ne $d.RestartDeadlineHours) { $d.RestartDeadlineHours } else { 24 }
    $ui.TxtRestartWarning.Text  = if ($null -ne $d.RestartWarningMinutes) { $d.RestartWarningMinutes } else { 15 }
    Update-RestartPanel
    $ui.ChkUninstallNotify.IsChecked = $d.UninstallNotify -eq $true
    foreach ($k in $TextKeys)
    {
        $script:TextBoxes[$k].Text   = if ($d.Texts -and $d.Texts[$k]) { $d.Texts[$k] } else { '' }
        $script:TextBoxesEn[$k].Text = if ($d.TextsEn -and $d.TextsEn[$k]) { $d.TextsEn[$k] } else { '' }
    }

    $ui.TxtInstallCmd.Text   = if (Test-Path (Join-Path $dir 'install-app.cmd')) { [System.IO.File]::ReadAllText((Join-Path $dir 'install-app.cmd')) } else { '' }
    $ui.TxtUninstallCmd.Text = if (Test-Path (Join-Path $dir 'uninstall-app.cmd')) { [System.IO.File]::ReadAllText((Join-Path $dir 'uninstall-app.cmd')) } else { '' }

    # Components and extra steps
    $script:Components.Clear()
    foreach ($c in @($d.Components)) { if ($c) { $script:Components.Add((New-ComponentRow $c)) } }
    $ui.TxtPreInstall.Text  = "$($d.PreInstall)"
    $ui.TxtPostInstall.Text = "$($d.PostInstall)"
    $isTemplate = $ui.TxtInstallCmd.Text -match '(MijnApp|MyApp)-Setup\.exe'
    # Create automatically only when there are components (or for a new app from the template);
    # a hand-written install-app.cmd without components is never overwritten.
    $auto = if ($null -ne $d.AutoInstallSteps) { [bool]$d.AutoInstallSteps } else { $script:Components.Count -gt 0 }
    if ($script:Components.Count -eq 0) { $auto = $isTemplate }
    $ui.ChkAutoSteps.IsChecked = $auto
    Update-InstallPreview

    # Main installer: the main component, otherwise the largest .exe/.msi in the folder
    $main = Get-MainComponent
    $inst = if ($main -and (Test-Path (Join-Path $dir $main.File))) { Get-Item (Join-Path $dir $main.File) }
            else { Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Sort-Object Length -Descending | Select-Object -First 1 }
    $ui.TxtInstaller.Text = if ($inst) { $inst.Name } else { '' }
    $ui.TxtInstallerInfo.Text = if ($inst) { T 'Kies de installer opnieuw om naam, versie en parameters opnieuw te laten herkennen.' 'Pick the installer again to detect name, version and parameters again.' } else { T 'Nog geen installer gekozen.' 'No installer chosen yet.' }
    $script:Info = @{ Kind = if ($inst -and $inst.Extension -eq '.msi') { 'MSI' } else { 'EXE' }; ProductCode = '' }

    Update-FileList; Update-IconPreview; Update-AccentPreview; Update-VersionList
    $ui.BtnOpenOutput.IsEnabled = Test-Path (Join-Path (Join-Path $KitRoot 'Output') $AppId)
    Set-Status "$(T 'Geladen' 'Loaded'): $AppId"
}

function Save-App
{
    if (-not $script:CurrentApp) { return $false }
    Update-InstallPreview
    $d = Read-Form
    $errors = Test-AppData $d
    if ($errors) { Show-Error ((T 'Controleer de volgende punten:' 'Please check the following:') + "`n`n- " + ($errors -join "`n- ")); return $false }

    $dir = Get-AppFolder
    [System.IO.File]::WriteAllText((Join-Path $dir 'app.psd1'), (ConvertTo-Psd1Text $d), (New-Object System.Text.UTF8Encoding $true))

    foreach ($pair in @(@('install-app.cmd', $ui.TxtInstallCmd.Text), @('uninstall-app.cmd', $ui.TxtUninstallCmd.Text)))
    {
        $txt = ($pair[1] -replace "`r?`n", "`r`n")
        if ($txt -match '[^\x00-\x7F]')
        {
            Show-Error "$($pair[0]) $(T 'bevat speciale tekens (zoals é of ï). Die geeft cmd niet goed door; zet zulke teksten in tabblad 3.' 'contains special characters (such as é or ï). cmd does not pass them on correctly; put such texts in tab 3.')"
        }
        [System.IO.File]::WriteAllText((Join-Path $dir $pair[0]), $txt, [System.Text.Encoding]::Default)
    }
    Set-Status "$(T 'Opgeslagen' 'Saved'): Apps\$($script:CurrentApp)"
    return $true
}

function Show-Preview([string]$Kind, [hashtable]$Data = $null, $Std = $null, [string]$IconPath = '', [string]$Language = '')
{
    # Without -Data: what is in the form now. With -Data: an earlier built version.
    # Language: the language chosen in tab 3 (Texts and previews in)
    if (-not $Language) { $Language = Get-TextLanguage }
    $P = { param($nl, $en) if ($Language -eq 'en') { $en } else { $nl } }
    $d = $Data
    if (-not $d)
    {
        $d = Read-Form
        $dir = Get-AppFolder
        if ($dir) { $IconPath = Join-Path $dir 'app.ico' }
    }
    if (-not $Std) { $Std = Get-StandardTexts $Language }
    $newMode = [bool]($ui.ChkPrevNew -and $ui.ChkPrevNew.IsChecked)
    $txt = { param($key, $data = $d) Get-EffectiveText -New:$newMode $key $data $Std -Language $Language }
    $cfg = @{
        Lang          = $Language
        AccentColor   = if ($d.AccentColor -match '^#[0-9A-Fa-f]{6}$') { $d.AccentColor } else { '#185FA5' }
        IconPath      = $IconPath
        Heading       = $d.AppName
        Sender        = $d.AppName
        ForcedMinutes = [int]("0$($d.ForcedDelayMinutes)")
        LaterHint     = & $P 'morgen' 'tomorrow'
    }
    switch ($Kind)
    {
        'consent' { $cfg.Mode = 'consent'; $cfg.Remaining = 3; $cfg.TimeoutSeconds = 900; $cfg.IsNew = $newMode; if ($newMode) { $cfg.NowText = & $P 'Nu installeren' 'Install now' }
                    $cfg.SubHeading = & $txt 'ConsentSubHeading'; $cfg.Message = & $txt 'ConsentMessage' }
        'last'    { $cfg.Mode = 'consent'; $cfg.Remaining = 1; $cfg.TimeoutSeconds = 900; $cfg.IsNew = $newMode; if ($newMode) { $cfg.NowText = & $P 'Nu installeren' 'Install now' }
                    $cfg.SubHeading = & $txt 'ConsentSubHeading'; $cfg.Message = & $txt 'ConsentMessage' }
        'forced'  { $cfg.Mode = 'forced'; $cfg.TimeoutSeconds = [math]::Max(60, $cfg.ForcedMinutes * 60); $cfg.IsNew = $newMode
                    $cfg.SubHeading = & $txt 'ForcedSubHeading'; $cfg.Message = & $txt 'ForcedMessage'
                    $cfg.InfoText = & $txt 'ForcedInfo' }
        'restart' { $cfg.Mode = 'consent'; $cfg.TimeoutSeconds = 900; $cfg.NowText = & $P 'Nu herstarten' 'Restart now'; $cfg.LaterText = 'Later'
                    $cfg.SubHeading = & $txt 'RestartSubHeading'; $cfg.Message = & $txt 'RestartMessage'
                    $rem = [int]("0$($d.RestartReminderMinutes)"); if (-not $rem) { $rem = 60 }
                    $when = if ($rem % 60 -eq 0) { & $P "over $($rem / 60) uur" "in $($rem / 60) hour(s)" } else { & $P "over $rem minuten" "in $rem minutes" }
                    $cfg.InfoOverride = & $P "Kies je Later, dan vragen we het $when opnieuw." "If you choose Later, we will ask again $when."
                    $cfg.TimeoutText = & $P 'Maak je geen keuze, dan vragen we het later opnieuw ({tijd}).' 'If you do not choose, we will ask again later ({tijd}).' }
        'restartforced' {
                    $wm = [int]("0$($d.RestartWarningMinutes)"); if (-not $wm) { $wm = 15 }
                    $dw = @{} + $d; $dw.ForcedDelayMinutes = $wm      # {Minuten}/{Minutes} = warning time before the restart
                    $cfg.Mode = 'forced'; $cfg.TimeoutSeconds = $wm * 60; $cfg.NowText = & $P 'Nu herstarten' 'Restart now'; $cfg.InfoWarning = $true
                    $cfg.InfoOverride = & $P 'Klaar om te herstarten? Sla je werk op en klik op Nu herstarten.' 'Ready to restart? Save your work and click Restart now.'
                    $cfg.CountdownText = & $P 'De laptop herstart automatisch over {tijd}.' 'The laptop restarts automatically in {tijd}.'
                    $cfg.SubHeading = & $txt 'RestartForcedSubHeading' $dw; $cfg.Message = & $txt 'RestartForcedMessage' $dw }
        default   { $cfg.Mode = 'toast'; $cfg.AutoCloseSeconds = 30
                    $cfg.Type = @{ uninstalling = 'installing'; uninstalled = 'success' }[$Kind]; if (-not $cfg.Type) { $cfg.Type = $Kind }
                    $prefix = @{ installing = 'Installing'; success = 'Success'; error = 'Error'; uninstalling = 'Uninstalling'; uninstalled = 'Uninstalled' }[$Kind]
                    $cfg.Heading = & $txt "$($prefix)Heading"; $cfg.Message = & $txt "$($prefix)Message" }
    }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "AppUI_preview_$(Get-Random).json"
    [System.IO.File]::WriteAllText($tmp, ($cfg | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $KitDir 'AppUI.ps1')`"", '-ConfigPath', "`"$tmp`"")
    Set-Status (T 'Voorbeeld geopend (rechtsonder in je scherm). Sluiten via de knoppen; er wordt niets geïnstalleerd.' 'Preview opened (bottom right of your screen). Close it with the buttons; nothing is installed.')
}

function Get-IntuneWinAppUtil
{
    $local = Join-Path $KitRoot 'IntuneWinAppUtil.exe'
    if (Test-Path $local) { return $local }
    $cmd = Get-Command IntuneWinAppUtil.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $r = [System.Windows.MessageBox]::Show(
        (T "IntuneWinAppUtil.exe (van Microsoft) is nodig om het .intunewin-pakket te maken, maar staat nog niet naast de Builder.`n`nNu downloaden van GitHub (microsoft/Microsoft-Win32-Content-Prep-Tool)?" "IntuneWinAppUtil.exe (from Microsoft) is needed to create the .intunewin package, but is not next to the Builder yet.`n`nDownload it now from GitHub (microsoft/Microsoft-Win32-Content-Prep-Tool)?"),
        'AppUpdateKit Builder', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return $null }
    try
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe' -OutFile $local
        Unblock-File $local -ErrorAction SilentlyContinue
        return $local
    }
    catch
    {
        Show-Error (T "Downloaden lukte niet: $($_.Exception.Message)`n`nDownload IntuneWinAppUtil.exe handmatig en zet hem in $KitRoot." "Download failed: $($_.Exception.Message)`n`nDownload IntuneWinAppUtil.exe manually and put it in $KitRoot.")
        return $null
    }
}

$script:BuildProc = $null
$buildTimer = New-Object System.Windows.Threading.DispatcherTimer
$buildTimer.Interval = [TimeSpan]::FromMilliseconds(500)
function Read-SharedText([string]$Path)
{
    # Read while the build script is still writing to the file (ReadAllText would refuse)
    if (-not (Test-Path $Path)) { return '' }
    $fs = $null
    try
    {
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $enc = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
        return (New-Object System.IO.StreamReader($fs, $enc)).ReadToEnd()
    }
    catch { return '' }
    finally { if ($fs) { $fs.Dispose() } }
}

$buildTimer.Add_Tick({
  try
  {
    $log = $script:BuildLog
    $text = (Read-SharedText $log) + (Read-SharedText "$log.err")
    if ($text -ne $ui.TxtLog.Text) { $ui.TxtLog.Text = $text; $ui.TxtLog.ScrollToEnd() }

    if ($script:BuildProc.HasExited)
    {
        $script:BuildProc.WaitForExit()
        $buildTimer.Stop()
        $ui.BtnBuild.IsEnabled = $true
        $out = Join-Path (Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp) $script:BuildVersion
        $pkgFile = Get-Item (Join-Path $out 'install.intunewin') -ErrorAction SilentlyContinue
        Update-VersionList
        if ($script:BuildProc.ExitCode -eq 0 -and $pkgFile -and $pkgFile.LastWriteTime -gt $script:BuildStart)
        {
            $ui.BtnOpenOutput.IsEnabled = $true
            Set-Status "$(T 'Klaar' 'Done'): Output\$($script:CurrentApp)\$($script:BuildVersion)\install.intunewin"
            $r = [System.Windows.MessageBox]::Show((T "Het pakket is klaar:`n$($pkgFile.FullName)`n`nIn dezelfde map staan Intune\Install.ps1, Intune\Uninstall.ps1, Intune\Requirement.ps1, Intune\Detection.ps1, Intune-instellingen.txt en Bouwinfo.txt.`n`nMap openen?" "The package is ready:`n$($pkgFile.FullName)`n`nThe same folder has Intune\Install.ps1, Intune\Uninstall.ps1, Intune\Requirement.ps1, Intune\Detection.ps1, Intune-instellingen.txt (Intune settings) and Bouwinfo.txt (build info).`n`nOpen the folder?"), (T 'Pakket klaar' 'Package ready'), 'YesNo', 'Information')
            if ($r -eq 'Yes') { Start-Process explorer.exe $out }
        }
        elseif ($script:BuildProc.ExitCode -eq 0)
        {
            Set-Status (T 'Bestanden gemaakt, maar geen .intunewin (zie Resultaat).' 'Files created, but no .intunewin (see Result).')
            $ui.BtnOpenOutput.IsEnabled = $true
        }
        else
        {
            Set-Status (T 'Bouwen mislukt: zie het tabblad Resultaat.' 'Build failed: see the Result tab.')
            Show-Error (T 'Het pakket kon niet gebouwd worden. In het tabblad Resultaat staat wat er mis is.' 'The package could not be built. The Result tab shows what is wrong.')
        }
    }
  }
  catch
  {
    $buildTimer.Stop()
    $ui.BtnBuild.IsEnabled = $true
    Write-BuilderError $_
  }
})

function Start-Build
{
    if (-not (Save-App)) { return }
    if (-not (Get-IntuneWinAppUtil)) { Set-Status (T 'Zonder IntuneWinAppUtil.exe worden alleen de bestanden gemaakt.' 'Without IntuneWinAppUtil.exe only the files are created.') }

    $script:BuildVersion = $ui.TxtVersion.Text.Trim()
    $existing = Join-Path (Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp) $script:BuildVersion
    if (Test-Path $existing)
    {
        $q = T "Versie $($script:BuildVersion) is al eens gebouwd.`n`nOpnieuw bouwen? De huidige build van deze versie wordt bewaard in het archief (zichtbaar in tabblad Versies als 'vervangen').`n`nWil je juist een nieuwe versie maken? Kies Nee en pas eerst het versienummer aan of kies de nieuwe installer." "Version $($script:BuildVersion) has been built before.`n`nBuild again? The current build of this version is kept in the archive (shown in the Versions tab as 'replaced').`n`nDo you want a new version instead? Choose No and first change the version number or pick the new installer."
        if ([System.Windows.MessageBox]::Show($q, (T 'Versie bestaat al' 'Version already exists'), 'YesNo', 'Question') -ne 'Yes') { return }
    }
    $script:BuildLog = Join-Path ([System.IO.Path]::GetTempPath()) "AppUpdateKit_build_$(Get-Random).log"
    $script:BuildStart = Get-Date
    $ui.TxtLog.Text = ''
    $ui.TabLog.IsSelected = $true
    $ui.BtnBuild.IsEnabled = $false
    Set-Status (T "Bezig met bouwen van $($script:CurrentApp)... (grote installers kunnen even duren)" "Building $($script:CurrentApp)... (large installers can take a while)")

    $script:BuildProc = Start-Process -FilePath 'powershell.exe' -NoNewWindow -PassThru `
        -RedirectStandardOutput $script:BuildLog -RedirectStandardError "$($script:BuildLog).err" `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $KitRoot '2-Bouw-pakket.ps1')`"", '-App', $script:CurrentApp, '-Lang', $script:Lang)
    # Keep the handle: otherwise Windows PowerShell 5.1 returns no ExitCode afterwards
    $null = $script:BuildProc.Handle
    $buildTimer.Start()
}

#region Events
$ui.LstApps.Add_SelectionChanged({ if ($ui.LstApps.SelectedItem) { Import-App ([string]$ui.LstApps.SelectedItem) } })

$ui.BtnNewApp.Add_Click({
    $id = [Microsoft.VisualBasic.Interaction]::InputBox((T "AppId van de nieuwe app (alleen letters, cijfers, - en _), bijv. 7Zip:" "AppId of the new app (only letters, digits, - and _), e.g. 7Zip:"), (T 'Nieuwe app' 'New app'), '')
    if (-not $id) { return }
    if ($id -notmatch '^[A-Za-z0-9_-]+$') { Show-Error (T 'Alleen letters, cijfers, - en _ (geen spaties).' 'Only letters, digits, - and _ (no spaces).'); return }
    $dir = Join-Path $AppsRoot $id
    if (Test-Path $dir) { Show-Error (T "Apps\$id bestaat al." "Apps\$id already exists."); return }
    New-Item $dir -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path (Join-Path $KitRoot '_Template') '*') $dir
    # Template in the Builder language: *.en.* for English, otherwise the Dutch files
    foreach ($f in 'app.psd1', 'install-app.cmd', 'uninstall-app.cmd')
    {
        $enFile = Join-Path $dir ([System.IO.Path]::GetFileNameWithoutExtension($f) + '.en' + [System.IO.Path]::GetExtension($f))
        if (Test-Path $enFile)
        {
            if ($script:Lang -eq 'en') { Move-Item -Path $enFile -Destination (Join-Path $dir $f) -Force } else { Remove-Item -Path $enFile -Force }
        }
    }
    $d = Read-AppPsd1 (Join-Path $dir 'app.psd1')
    $d.AppId = $id; $d.AppName = $id; $d.DetectName = $id; $d.Processes = @()
    [System.IO.File]::WriteAllText((Join-Path $dir 'app.psd1'), (ConvertTo-Psd1Text $d), (New-Object System.Text.UTF8Encoding $true))
    Update-AppList
    $ui.LstApps.SelectedItem = $id
    Set-Status (T "Nieuwe app $id aangemaakt. Begin met het kiezen van de installer." "New app $id created. Start by picking the installer.")
})

$ui.BtnInstaller.Add_Click({
    # Tab 1: the installer of the app itself = the main component
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Installers (*.exe;*.msi)|*.exe;*.msi'
    if (-not $dlg.ShowDialog()) { return }
    $src = $dlg.FileName; $dir = Get-AppFolder
    $name = [System.IO.Path]::GetFileName($src)

    # Previous installer (old main component) and loose installers that are not a component: clean up?
    $oldMain = $script:Components | Where-Object { $_.Main } | Select-Object -First 1
    $oldIndex = if ($oldMain) { $script:Components.IndexOf($oldMain) } else { -1 }
    $usedFiles = @($script:Components | Where-Object { -not $_.Main } | ForEach-Object { $_.File })
    $old = @(Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' -and $_.Name -ne $name -and $_.Name -notin $usedFiles })
    if ($old.Count -gt 0)
    {
        $list = ($old | ForEach-Object { "  - $($_.Name)" }) -join "`n"
        $q = T "In de app-map staan nog deze installers:`n$list`n`nZijn dat oude versies? Kies Ja om ze te verwijderen, zodat ze niet in het nieuwe pakket komen.`n(Andere onderdelen uit tabblad 2 blijven gewoon staan.)" "The app folder still has these installers:`n$list`n`nAre these old versions? Choose Yes to delete them, so they do not end up in the new package.`n(Other components from tab 2 stay.)"
        if ([System.Windows.MessageBox]::Show($q, (T 'Oude installers opruimen' 'Clean up old installers'), 'YesNo', 'Question') -eq 'Yes')
        {
            $old | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
        }
    }
    if ($oldMain -and $oldMain.File -ne $name) { [void]$script:Components.Remove($oldMain) }

    $info = Add-ComponentFile $src $true
    if ($oldIndex -ge 0)
    {
        $row = $script:Components | Where-Object { $_.File -eq $name } | Select-Object -First 1
        $cur = $script:Components.IndexOf($row)
        if ($cur -ne $oldIndex -and $oldIndex -lt $script:Components.Count) { $script:Components.Move($cur, $oldIndex) }
    }

    $ui.TxtInstaller.Text = $name
    $ui.TxtInstallerInfo.Text = "$(T 'Herkend' 'Detected'): $($info.Kind)$(if ($info.ProductName) { ' - ' + $info.ProductName })$(if ($info.Version) { ' ' + $info.Version }). $($info.Note) $(T 'Parameters en extra onderdelen: tabblad 2.' 'Parameters and extra components: tab 2.')"
    if ($info.Version) { $ui.TxtVersion.Text = $info.Version }
    if ($info.ProductName)
    {
        if (-not $ui.TxtAppName.Text -or $ui.TxtAppName.Text -eq $script:CurrentApp) { $ui.TxtAppName.Text = $info.ProductName }
        if (-not $ui.TxtDetectName.Text -or $ui.TxtDetectName.Text -eq $script:CurrentApp) { $ui.TxtDetectName.Text = $info.ProductName }
    }

    if (-not $ui.ChkAutoSteps.IsChecked)
    {
        $q = T 'De installatiestappen zijn met de hand geschreven. Voortaan automatisch maken uit de onderdelen (tabblad 2)?' 'The installation steps were written by hand. Create them automatically from the components (tab 2) from now on?'
        if ([System.Windows.MessageBox]::Show($q, (T 'Installer gekozen' 'Installer chosen'), 'YesNo', 'Question') -eq 'Yes') { $ui.ChkAutoSteps.IsChecked = $true }
    }
    Update-InstallPreview

    if (-not $ui.TxtUninstallCmd.Text.Trim() -or $ui.TxtUninstallCmd.Text -match 'MijnApp|MyApp|VUL IN|FILL IN')
    {
        $ui.TxtUninstallCmd.Text = New-UninstallCmdText $ui.TxtAppName.Text $info $ui.TxtDetectName.Text
    }
    Update-FileList
    Set-Status (T "Installer $name toegevoegd als hoofdonderdeel. Controleer versie, processen en tabblad 2." "Installer $name added as main component. Check version, processes and tab 2.")
})

$ui.BtnGenerate.Add_Click({
    $main = Get-MainComponent
    if (-not $main) { Show-Error (T 'Voeg eerst een onderdeel toe (tabblad 1 of 2).' 'Add a component first (tab 1 or 2).'); return }
    if ($ui.TxtUninstallCmd.Text.Trim() -and [System.Windows.MessageBox]::Show((T 'De huidige verwijderstappen vervangen?' 'Replace the current uninstall steps?'), (T 'Opnieuw maken' 'Recreate'), 'YesNo', 'Question') -ne 'Yes') { return }
    $info = @{ Kind = $main.Kind; ProductCode = $main.ProductCode }
    $ui.TxtUninstallCmd.Text = New-UninstallCmdText $ui.TxtAppName.Text $info $ui.TxtDetectName.Text
})

$ui.BtnCompAdd.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Multiselect = $true
    $dlg.Filter = (T 'Installatiebestanden' 'Installation files') + ' (*.exe;*.msi;*.msp;*.ps1;*.cmd;*.bat;*.reg)|*.exe;*.msi;*.msp;*.ps1;*.cmd;*.bat;*.reg|' + (T 'Alle bestanden' 'All files') + ' (*.*)|*.*'
    if (-not $dlg.ShowDialog()) { return }
    $notes = @()
    foreach ($fn in $dlg.FileNames)
    {
        $info = Add-ComponentFile $fn $false
        $notes += "$($info.File): $($info.Kind). $($info.Note)"
    }
    # Put new components before the main component (usually they are preparations, such as a runtime)
    $main = $script:Components | Where-Object { $_.Main } | Select-Object -First 1
    if ($main)
    {
        $mi = $script:Components.IndexOf($main)
        if ($mi -lt $script:Components.Count - 1) { $script:Components.Move($mi, $script:Components.Count - 1) }
    }
    $ui.TxtCompInfo.Text = ($notes -join '  |  ') + (T '  Controleer de parameters; dubbelklik om te wijzigen.' '  Check the parameters; double-click to change.')
    Update-InstallPreview; Update-FileList
})

$ui.BtnCompRemove.Add_Click({
    $c = $ui.DgComponents.SelectedItem
    if (-not $c) { Show-Error (T 'Selecteer eerst een onderdeel.' 'Select a component first.'); return }
    $r = [System.Windows.MessageBox]::Show((T "Onderdeel $($c.File) verwijderen.`n`nOok het bestand uit de app-map verwijderen?" "Remove component $($c.File).`n`nAlso delete the file from the app folder?"), (T 'Onderdeel verwijderen' 'Remove component'), 'YesNoCancel', 'Question')
    if ($r -eq 'Cancel') { return }
    [void]$script:Components.Remove($c)
    if ($r -eq 'Yes') { Remove-Item -LiteralPath (Join-Path (Get-AppFolder) $c.File) -Force -ErrorAction SilentlyContinue }
    Update-InstallPreview; Update-FileList
})

$ui.BtnCompUp.Add_Click({
    $c = $ui.DgComponents.SelectedItem; if (-not $c) { return }
    $i = $script:Components.IndexOf($c)
    if ($i -gt 0) { $script:Components.Move($i, $i - 1); Update-InstallPreview }
})
$ui.BtnCompDown.Add_Click({
    $c = $ui.DgComponents.SelectedItem; if (-not $c) { return }
    $i = $script:Components.IndexOf($c)
    if ($i -lt $script:Components.Count - 1) { $script:Components.Move($i, $i + 1); Update-InstallPreview }
})

# After editing a cell (parameters, exit codes, main) update the preview
$ui.DgComponents.Add_CellEditEnding({
    $null = $Window.Dispatcher.BeginInvoke([action]{
        # Only one main component at a time
        $sel = $ui.DgComponents.SelectedItem
        if ($sel -and $sel.Main) { foreach ($c in $script:Components) { if ($c -ne $sel) { $c.Main = $false } } ; $ui.DgComponents.Items.Refresh() }
        Update-InstallPreview
    }, [System.Windows.Threading.DispatcherPriority]::Background)
})
$ui.DgComponents.Add_CurrentCellChanged({ Update-InstallPreview })
$ui.TxtPreInstall.Add_TextChanged({ Update-InstallPreview })
$ui.CmbWindow.Add_SelectionChanged({ Update-WindowHint })
$ui.ChkIdle.Add_Click({ Update-WindowHint })
$ui.TxtPostInstall.Add_TextChanged({ Update-InstallPreview })
$ui.ChkAutoSteps.Add_Click({
    if (-not $ui.ChkAutoSteps.IsChecked)
    {
        Set-Status (T 'Automatisch maken staat uit: je kunt install-app.cmd nu met de hand aanpassen.' 'Create automatically is off: you can now edit install-app.cmd by hand.')
    }
    Update-InstallPreview
})
$ui.TxtAppName.Add_TextChanged({ if ($ui.ChkAutoSteps.IsChecked) { Update-InstallPreview } })

$ui.BtnIcon.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = (T 'Afbeeldingen' 'Images') + ' (*.svg;*.ico;*.png;*.jpg;*.jpeg;*.bmp)|*.svg;*.ico;*.png;*.jpg;*.jpeg;*.bmp'
    if (-not $dlg.ShowDialog()) { return }
    try
    {
        if ([System.IO.Path]::GetExtension($dlg.FileName) -ieq '.svg') { Set-Status (T 'SVG wordt omgezet naar een icoon...' 'Converting SVG to an icon...') }
        New-IcoFromImage $dlg.FileName (Join-Path (Get-AppFolder) 'app.ico'); Update-IconPreview; Update-FileList
        # Keep the original, so you can create a sharper version later (also kept in the version history)
        if ([System.IO.Path]::GetExtension($dlg.FileName) -ieq '.svg') {
            Copy-Item -LiteralPath $dlg.FileName -Destination (Join-Path (Get-AppFolder) 'logo.svg') -Force
            Update-FileList; Set-Status (T 'SVG-logo omgezet naar app.ico (256 x 256).' 'SVG logo converted to app.ico (256 x 256).')
        }
    }
    catch { Show-Error "$(T 'Logo kon niet worden omgezet' 'The logo could not be converted'): $($_.Exception.Message)" }
})

$ui.BtnIconFromInstaller.Add_Click({
    $inst = $ui.TxtInstaller.Text
    if (-not $inst -or $inst -notlike '*.exe') { Show-Error (T 'Dit kan alleen met een .exe-installer. Kies anders zelf een logo.' 'This only works with an .exe installer. Otherwise pick a logo yourself.'); return }
    try
    {
        New-IcoFromImage (Join-Path (Get-AppFolder) $inst) (Join-Path (Get-AppFolder) 'app.ico')
        Update-IconPreview; Update-FileList
        Set-Status (T 'Logo uit de installer gehaald. Is hij wazig? Kies dan een groter logo (.png of .ico).' 'Logo extracted from the installer. Is it blurry? Then pick a larger logo (.svg, .png or .ico).')
    }
    catch { Show-Error "$(T 'Logo kon niet uit de installer worden gehaald' 'The logo could not be extracted from the installer'): $($_.Exception.Message)" }
})

$ui.TxtAccent.Add_TextChanged({ Update-AccentPreview })

$ui.BtnAddFiles.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Multiselect = $true
    if (-not $dlg.ShowDialog()) { return }
    foreach ($f in $dlg.FileNames) { Copy-Item -LiteralPath $f -Destination (Get-AppFolder) -Force }
    Update-FileList
})

$ui.BtnRemoveFile.Add_Click({
    $sel = [string]$ui.LstFiles.SelectedItem
    if (-not $sel) { return }
    $name = ($sel -split '   \(')[0]
    if ([System.Windows.MessageBox]::Show((T "$name verwijderen uit de app-map?" "Delete $name from the app folder?"), (T 'Verwijderen' 'Delete'), 'YesNo', 'Question') -eq 'Yes')
    {
        Remove-Item -LiteralPath (Join-Path (Get-AppFolder) $name) -Force
        Update-FileList; Update-IconPreview
    }
})

$ui.BtnOpenAppFolder.Add_Click({ if (Get-AppFolder) { Start-Process explorer.exe (Get-AppFolder) } })
$ui.BtnOpenOutput.Add_Click({
    $o = Join-Path (Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp) $ui.TxtVersion.Text.Trim()
    if (-not (Test-Path $o)) { $o = Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp }
    if (Test-Path $o) { Start-Process explorer.exe $o }
})

$ui.BtnStdTexts.Add_Click({ Show-StandardTextsEditor })

$ui.LstVersions.Add_SelectionChanged({ Show-VersionDetails })
$ui.BtnVerPreview.Add_Click({
    $det = $script:SelectedVersion
    if (-not $det -or -not $det.Data) { return }
    $kind = [string]$ui.CmbVerPreview.SelectedItem.Tag
    $lang = Get-TextLanguage
    Show-Preview $kind $det.Data $(if ($lang -eq 'en') { $det.StdEn } else { $det.Std }) $det.Icon $lang
})
$ui.BtnVerOpen.Add_Click({ $v = Get-SelectedVersion; if ($v) { Start-Process explorer.exe $v.Path } })

$ui.BtnVerRestore.Add_Click({
    # Full copy of this build (settings, texts, steps, installers) as the working version
    $v = Get-SelectedVersion
    if (-not $v) { return }
    if (-not $v.HasBron) { Show-Error (T "Van build $($v.Label) zijn geen gegevens bewaard." "No data was kept for build $($v.Label)."); return }
    $q = T ("Een kopie maken van $($v.Label) en die als werkversie klaarzetten?`n`n" +
            "Wat nu in de Builder staat (en nog niet gebouwd is) wordt daarmee vervangen. Gebouwde versies blijven altijd bewaard.`n`n" +
            "Daarna:`n- zelfde versienummer houden = deze versie verbeteren (de huidige build gaat naar het archief)`n" +
            "- nieuwe installer of nieuw versienummer = een nieuwe versie") `
           ("Make a copy of $($v.Label) and set it up as the working version?`n`n" +
            "What is in the Builder now (and not built yet) is replaced. Built versions are always kept.`n`n" +
            "Then:`n- keep the same version number = improve this version (the current build goes to the archive)`n" +
            "- new installer or new version number = a new version")
    if ([System.Windows.MessageBox]::Show($q, (T 'Kopie maken en aanpassen' 'Copy and edit'), 'YesNo', 'Question') -ne 'Yes') { return }

    $bronDir = Join-Path $v.Path 'Bron'
    $appDir  = Get-AppFolder
    Set-Status "$(T 'Kopie maken van' 'Copying') $($v.Label)..."
    Get-ChildItem $appDir -Force | Remove-Item -Recurse -Force
    Get-ChildItem $bronDir -Force | Where-Object { $_.Name -ne 'Standaardteksten.psd1' } | Copy-Item -Destination $appDir -Recurse -Force
    Import-App $script:CurrentApp
    $ui.Tabs.SelectedIndex = 0

    $msg = T "Kopie van $($v.Label) staat klaar. Pas aan wat nodig is en klik op Bouw pakket." "Copy of $($v.Label) is ready. Change what is needed and click Build package."
    if (-not $v.HasInstallers) { $msg += T ' Let op: in deze oude build zijn de installers niet bewaard; voeg ze opnieuw toe.' ' Note: this old build did not keep the installers; add them again.' }
    Set-Status $msg
})

$ui.BtnVerDelete.Add_Click({
    $v = Get-SelectedVersion
    if (-not $v) { return }
    if ([System.Windows.MessageBox]::Show((T "Versie $($v.Version) met install.intunewin en alle bestanden in die map verwijderen?" "Delete version $($v.Version) with install.intunewin and all files in that folder?"), (T 'Versie verwijderen' 'Delete version'), 'YesNo', 'Warning') -ne 'Yes') { return }
    Remove-Item -LiteralPath $v.Path -Recurse -Force
    Update-VersionList
    Set-Status (T "Versie $($v.Version) verwijderd." "Version $($v.Version) deleted.")
})

$ui.BtnPrevConsent.Add_Click({ Show-Preview 'consent' })
$ui.BtnPrevLast.Add_Click({ Show-Preview 'last' })
$ui.BtnPrevForced.Add_Click({ Show-Preview 'forced' })
$ui.BtnPrevRestart.Add_Click({ Show-Preview 'restart' })
$ui.BtnPrevRestartForced.Add_Click({ Show-Preview 'restartforced' })
$ui.BtnPrevUninstalling.Add_Click({ Show-Preview 'uninstalling' })
$ui.BtnPrevUninstalled.Add_Click({ Show-Preview 'uninstalled' })
$ui.CmbRestart.Add_SelectionChanged({ Update-RestartPanel })
$ui.BtnPrevInstalling.Add_Click({ Show-Preview 'installing' })
$ui.BtnPrevSuccess.Add_Click({ Show-Preview 'success' })
$ui.BtnPrevError.Add_Click({ Show-Preview 'error' })

$ui.CmbTextLang.Add_SelectionChanged({ Update-TextPanels })

# Builder language: save in _Kit\Settings.psd1 and restart the Builder
Set-ComboByTag $ui.CmbUiLang $script:Lang
$ui.CmbUiLang.Add_SelectionChanged({
    $new = [string]$ui.CmbUiLang.SelectedItem.Tag
    if (-not $new -or $new -eq $script:Lang) { return }
    if ($script:CurrentApp -and -not (Save-App)) { Set-ComboByTag $ui.CmbUiLang $script:Lang; return }
    Save-KitLanguage $new
    $q = if ($new -eq 'en') { "The language is now English (Builder, messages, log files and generated files).`n`nRestart the Builder now?" }
         else { "De taal is nu Nederlands (Builder, meldingen, logbestanden en gemaakte bestanden).`n`nDe Builder nu opnieuw starten?" }
    if ([System.Windows.MessageBox]::Show($q, 'AppUpdateKit Builder', 'YesNo', 'Question') -eq 'Yes')
    {
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $KitRoot 'AppUpdateKit-Builder.ps1')`"")
        $Window.Close()
    }
})

$ui.BtnSave.Add_Click({ [void](Save-App) })
$ui.BtnBuild.Add_Click({ Start-Build })
#endregion

try
{
    Update-BuilderShortcut
    Update-AppList
    Set-Status (T 'Kies links een app, of maak een nieuwe aan.' 'Pick an app on the left, or create a new one.')
    [void]$Window.ShowDialog()
}
catch
{
    Write-BuilderError $_
}
#endregion

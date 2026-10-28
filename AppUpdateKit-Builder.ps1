<#
.SYNOPSIS
    AppUpdateKit Builder - form to create update packages with a popup.
    Start it with Start-Builder.cmd (double-click).

.DESCRIPTION
    - Choose apps or create a new app (folder Apps\<AppId>)
    - Choose the installer: name, version, type and silent parameters are recognised
    - Choose the detection (Apps & features, file, registry or own script) and test it on this PC
    - Fill in the logo (.svg/.ico/.png/.jpg, or from the installer), colour, postpone rules, time blocks and texts
    - Preview every popup on your own screen
    - Save and build the .intunewin package (via Build-Package.ps1) in the chosen package folder
    - See all earlier builds on the Versions tab
#>

$ErrorActionPreference = 'Stop'
# Determine the kit folder (also if $PSScriptRoot is empty, e.g. when started from PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Can't find the AppUpdateKit folder. First go to that folder (cd <path to AppUpdateKit>) and start the script there, e.g. .\Build-Package.ps1 -App NotepadPlusPlus"
}
$AppsRoot = Join-Path $KitRoot 'Apps'
$KitDir   = Join-Path $KitRoot '_Kit'
# Languages: translating the Builder, the scripts for the laptop and the template (Language\Translate.ps1 and Language\<language>.xml)
. (Join-Path (Join-Path $KitRoot 'Language') 'Translate.ps1')
# Language of this Builder. In another language this script runs translated (Language\Translate.ps1); then that language is here.
$ThisBuilderLang = 'en'   # LANGCODE
# Language of the app that is open: decides the default texts, the buttons in the popups and the scripts in the package
$script:TextLang = $ThisBuilderLang
# Version of the kit (file VERSION in the kit folder, e.g. 1.2.0)
$KitVersion = ''
try { $KitVersion = ([System.IO.File]::ReadAllText((Join-Path $KitRoot 'VERSION'))).Trim() } catch { }
# Own settings are not in GitHub: create them from the default version if they don't exist yet.
# Versions before 1.3 used Dutch file names: move those first.
foreach ($pair in @(@('Instellingen.psd1', 'Settings.psd1'), @('Standaardteksten.psd1', 'DefaultTexts.nl.psd1'), @('Standaardteksten.en.psd1', 'DefaultTexts.psd1'))) {
    $oldFile = Join-Path $KitDir $pair[0]; $newFile = Join-Path $KitDir $pair[1]
    if ((Test-Path $oldFile) -and -not (Test-Path $newFile)) { try { Move-Item -LiteralPath $oldFile -Destination $newFile } catch { } }
}
# Files of versions before 1.3 under their old Dutch names (left behind by an update with an older Update-Kit): remove them
if (Test-Path (Join-Path $KitRoot 'Build-Package.ps1'))
{
    foreach ($rel in '1-Nieuwe-app.ps1', '2-Bouw-pakket.ps1', 'Kit-bijwerken.ps1', 'Kit-bijwerken.cmd', 'AppUpdateKit-Builder.en.ps1', '1-Nieuwe-app.en.ps1', '2-Bouw-pakket.en.ps1', 'Kit-bijwerken.en.ps1',
                     '_Kit\Instellingen.standaard.psd1', '_Kit\Standaardteksten.standaard.psd1', '_Kit\Standaardteksten.en.standaard.psd1', '_Kit\Intune\Detection.ps1',
                     '_Kit\Intune\Detection-AppsEnOnderdelen.ps1', '_Kit\Intune\Detection-Bestand.ps1', '_Kit\Intune\Detection-Register.ps1', '_Kit\Intune\Detection-uitleg.ps1',
                     '_Kit\en', '_Template\en', '_Vertaling', 'Language\en.xml', 'Language\Test-Taal.ps1', 'Apps\LEESMIJ.txt', 'Output\LEESMIJ.txt')
    {
        $oldFile = Join-Path $KitRoot $rel
        if (Test-Path -LiteralPath $oldFile) { try { Remove-Item -LiteralPath $oldFile -Recurse -Force } catch { } }
    }
}
foreach ($kitFileName in 'Settings', 'DefaultTexts', 'DefaultTexts.nl') {
    $kitFileOwn = Join-Path $KitDir "$kitFileName.psd1"; $kitFileStd = Join-Path $KitDir "$kitFileName.default.psd1"
    if (-not (Test-Path $kitFileOwn) -and (Test-Path $kitFileStd)) { Copy-Item $kitFileStd $kitFileOwn }
}

$TextKeys = @('ConsentSubHeading', 'ConsentMessage', 'ForcedSubHeading', 'ForcedMessage', 'ForcedInfo',
              'InstallingHeading', 'InstallingMessage', 'SuccessHeading', 'SuccessMessage', 'ErrorHeading', 'ErrorMessage',
              'RestartSubHeading', 'RestartMessage', 'RestartForcedSubHeading', 'RestartForcedMessage',
              'UninstallingHeading', 'UninstallingMessage', 'UninstalledHeading', 'UninstalledMessage', 'UninstallErrorHeading', 'UninstallErrorMessage',
              'NewConsentSubHeading', 'NewConsentMessage', 'NewForcedSubHeading', 'NewForcedMessage', 'NewForcedInfo', 'NewInstallingHeading', 'NewInstallingMessage', 'NewSuccessHeading', 'NewSuccessMessage', 'NewErrorHeading', 'NewErrorMessage', 'NewRestartMessage', 'NewRestartForcedMessage')

# Built-in Dutch texts (for apps with Language = 'nl'); overridden by _Kit\DefaultTexts.nl.psd1 (see Get-DefaultTexts)
$BuiltinTextsNl = [ordered]@{
    ConsentSubHeading = 'Er is een update beschikbaar'
    ConsentMessage    = 'Er staat een nieuwe versie van {AppName} voor je klaar. Tijdens de update (een paar minuten) kun je {AppName} even niet gebruiken.'
    ForcedSubHeading  = 'De update start over {Minutes} minuten'
    ForcedMessage     = 'Je hebt de update van {AppName} {MaxPostpones} keer uitgesteld. Over {Minutes} minuten wordt de nieuwe versie automatisch geïnstalleerd. Sla je werk op en sluit {AppName} af.'
    ForcedInfo        = 'Wil je niet wachten? Sla je werk op, sluit {AppName} af en klik op Nu installeren.'
    InstallingHeading = 'Update wordt geïnstalleerd'
    InstallingMessage = '{AppName} wordt bijgewerkt en is even niet beschikbaar. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    SuccessHeading    = 'Update geïnstalleerd'
    SuccessMessage    = 'De nieuwe versie van {AppName} staat klaar. Je kunt de app weer gebruiken.'
    ErrorHeading      = 'Update niet gelukt'
    ErrorMessage      = 'Er ging iets mis bij het bijwerken van {AppName}. Werkt de app niet? Neem dan contact op met de servicedesk.'
    RestartSubHeading       = 'Herstart nodig'
    RestartMessage          = '{AppName} is bijgewerkt. Herstart je laptop om de update af te ronden. Sla eerst je werk op.'
    RestartForcedSubHeading = 'Je laptop wordt over {Minutes} minuten herstart'
    RestartForcedMessage    = '{AppName} is bijgewerkt en je laptop moet herstarten om de update af te ronden. Sla je werk op en sluit je programma''s af.'
    UninstallingHeading     = '{AppName} wordt verwijderd'
    UninstallingMessage     = '{AppName} wordt van je laptop verwijderd en is even niet beschikbaar. Je hoeft niets te doen.'
    UninstalledHeading      = '{AppName} is verwijderd'
    UninstalledMessage      = '{AppName} staat niet meer op je laptop.'
    UninstallErrorHeading   = 'Verwijderen niet gelukt'
    UninstallErrorMessage   = 'Er ging iets mis bij het verwijderen van {AppName}. Geeft dit problemen? Neem dan contact op met de servicedesk.'
    NewConsentSubHeading    = 'Er staat een nieuwe app voor je klaar'
    NewConsentMessage       = '{AppName} wordt op je laptop geïnstalleerd. Dat duurt een paar minuten.'
    NewForcedSubHeading     = 'De installatie start over {Minutes} minuten'
    NewForcedMessage        = 'Je hebt de installatie van {AppName} {MaxPostpones} keer uitgesteld. Over {Minutes} minuten wordt {AppName} automatisch geïnstalleerd. Sla je werk op.'
    NewForcedInfo           = 'Wil je niet wachten? Sla je werk op en klik op Nu installeren.'
    NewInstallingHeading    = '{AppName} wordt geïnstalleerd'
    NewInstallingMessage    = '{AppName} wordt op je laptop geïnstalleerd. Je hoeft niets te doen; we laten het weten zodra het klaar is.'
    NewSuccessHeading       = '{AppName} is geïnstalleerd'
    NewSuccessMessage       = '{AppName} staat klaar. Je vindt de app in het startmenu.'
    NewErrorHeading         = 'Installatie niet gelukt'
    NewErrorMessage         = 'Er ging iets mis bij het installeren van {AppName}. Heb je de app nodig? Neem dan contact op met de servicedesk.'
    NewRestartMessage       = '{AppName} is geïnstalleerd. Herstart je laptop om de installatie af te ronden. Sla eerst je werk op.'
    NewRestartForcedMessage = '{AppName} is geïnstalleerd en je laptop moet herstarten om de installatie af te ronden. Sla je werk op en sluit je programmas af.'
}
# Built-in texts; overridden by _Kit\DefaultTexts.psd1 (see Get-DefaultTexts)
$BuiltinTexts = [ordered]@{
    ConsentSubHeading       = 'An update is available'
    ConsentMessage          = 'A new version of {AppName} is ready for you. During the update (a few minutes) you can''t use {AppName}.'
    ForcedSubHeading        = 'The update starts in {Minutes} minutes'
    ForcedMessage           = 'You have postponed the {AppName} update {MaxPostpones} times. In {Minutes} minutes the new version will be installed automatically. Save your work and close {AppName}.'
    ForcedInfo              = 'Don''t want to wait? Save your work, close {AppName} and click Install now.'
    InstallingHeading       = 'Installing update'
    InstallingMessage       = '{AppName} is being updated and is unavailable for a moment. You don''t need to do anything; we''ll let you know when it''s done.'
    SuccessHeading          = 'Update installed'
    SuccessMessage          = 'The new version of {AppName} is ready. You can use the app again.'
    ErrorHeading            = 'Update failed'
    ErrorMessage            = 'Something went wrong while updating {AppName}. Is the app not working? Please contact the service desk.'
    RestartSubHeading       = 'Restart required'
    RestartMessage          = '{AppName} has been updated. Restart your laptop to finish the update. Save your work first.'
    RestartForcedSubHeading = 'Your laptop will restart in {Minutes} minutes'
    RestartForcedMessage    = '{AppName} has been updated and your laptop needs to restart to finish the update. Save your work and close your programs.'
    UninstallingHeading     = 'Removing {AppName}'
    UninstallingMessage     = '{AppName} is being removed from your laptop and is unavailable for a moment. You don''t need to do anything.'
    UninstalledHeading      = '{AppName} has been removed'
    UninstalledMessage      = '{AppName} is no longer on your laptop.'
    UninstallErrorHeading   = 'Removal failed'
    UninstallErrorMessage   = 'Something went wrong while removing {AppName}. Is this causing problems? Please contact the service desk.'
    NewConsentSubHeading    = 'A new app is ready for you'
    NewConsentMessage       = '{AppName} will be installed on your laptop. This takes a few minutes.'
    NewForcedSubHeading     = 'The installation starts in {Minutes} minutes'
    NewForcedMessage        = 'You have postponed the installation of {AppName} {MaxPostpones} times. In {Minutes} minutes {AppName} will be installed automatically. Save your work.'
    NewForcedInfo           = 'Don''t want to wait? Save your work and click Install now.'
    NewInstallingHeading    = 'Installing {AppName}'
    NewInstallingMessage    = '{AppName} is being installed on your laptop. You don''t need to do anything; we''ll let you know when it''s done.'
    NewSuccessHeading       = '{AppName} has been installed'
    NewSuccessMessage       = '{AppName} is ready. You can find the app in the Start menu.'
    NewErrorHeading         = 'Installation failed'
    NewErrorMessage         = 'Something went wrong while installing {AppName}. Do you need the app? Please contact the service desk.'
    NewRestartMessage       = '{AppName} has been installed. Restart your laptop to finish the installation. Save your work first.'
    NewRestartForcedMessage = '{AppName} has been installed and your laptop needs to restart to finish the installation. Save your work and close your programs.'
}
function Get-BuiltinTexts([string]$Lang) { if ($Lang -eq 'nl') { return $BuiltinTextsNl } else { return $BuiltinTexts } }
function Get-DefaultTextsPath([string]$Lang) { if ($Lang -eq 'nl') { return (Join-Path $KitDir 'DefaultTexts.nl.psd1') } else { return (Join-Path $KitDir 'DefaultTexts.psd1') } }
function Get-KitFileText([string]$RelPath, [string]$Lang)
{
    # A file from _Kit (or the template) as text, translated to the language (Language\Translate.ps1)
    $path = if ([System.IO.Path]::IsPathRooted($RelPath)) { $RelPath } else { Join-Path $KitDir $RelPath }
    return (Convert-AppKitFile -Path $path -Lang $(if ($Lang) { $Lang } else { 'en' }))
}

# Settings for this kit: default folder for installers and the subfolder for the package (_Kit\Settings.psd1)
$KitSettings = @{ InstallerFolder = ''; PackageSubfolder = '' }
$kitSettingsPath = Join-Path $KitDir 'Settings.psd1'
function Save-InstallerFolder([string]$Folder)
{
    # Change InstallerFolder in _Kit\Settings.psd1; the rest of the file (comments, PackageSubfolder) stays
    $Folder = $Folder.TrimEnd('\') + '\'
    $value = "InstallerFolder = '$($Folder.Replace("'", "''"))'"
    if (Test-Path $kitSettingsPath)
    {
        $text = [System.IO.File]::ReadAllText($kitSettingsPath)
        if ($text -match "(?m)^(\s*)InstallerFolder\s*=\s*'(?:[^']|'')*'") { $text = [regex]::Replace($text, "(?m)^(\s*)InstallerFolder\s*=\s*'(?:[^']|'')*'", { param($m) $m.Groups[1].Value + $value }, 1) }
        else { $text = $text -replace '@\{', "@{`r`n    $value" }
    }
    else
    {
        $text = "# AppUpdateKit - settings for this kit (apply to all apps). Edit with Notepad.`r`n@{`r`n    # Folder where the 'Browse...' window opens by default when choosing an installer.`r`n    $value`r`n`r`n    # If you choose the version folder at 'Save package to', the Builder adds this subfolder.`r`n    PackageSubfolder = 'intune-package'`r`n}`r`n"
    }
    [System.IO.File]::WriteAllText($kitSettingsPath, $text, (New-Object System.Text.UTF8Encoding $true))
    $KitSettings.InstallerFolder = $Folder
}

# Versions before 1.3 used Dutch key names (InstallerMap, PakketSubmap): rename them in the file
if (Test-Path $kitSettingsPath)
{
    try
    {
        $settingsText = [System.IO.File]::ReadAllText($kitSettingsPath)
        if ($settingsText -match '\b(InstallerMap|PakketSubmap)\b')
        {
            $settingsText = $settingsText -replace '\bInstallerMap\b', 'InstallerFolder' -replace '\bPakketSubmap\b', 'PackageSubfolder'
            [System.IO.File]::WriteAllText($kitSettingsPath, $settingsText, (New-Object System.Text.UTF8Encoding $true))
        }
    }
    catch { }
}
if (Test-Path $kitSettingsPath) { try { $kitSettingsFile = Import-PowerShellDataFile $kitSettingsPath; foreach ($settingName in 'InstallerFolder', 'PackageSubfolder') { if ($kitSettingsFile[$settingName]) { $KitSettings[$settingName] = "$($kitSettingsFile[$settingName])" } } } catch { } }
$TextLabels = [ordered]@{
    ConsentSubHeading = 'Window "Update available" - subtitle'
    ConsentMessage    = 'Window "Update available" - text'
    ForcedSubHeading  = 'Warning after the last postpone - subtitle'
    ForcedMessage     = 'Warning after the last postpone - text'
    ForcedInfo        = 'Warning - orange line'
    InstallingHeading = 'Notification while installing - heading'
    InstallingMessage = 'Notification while installing - text'
    SuccessHeading    = 'Notification succeeded - heading'
    SuccessMessage    = 'Notification succeeded - text'
    ErrorHeading      = 'Notification failed - heading'
    ErrorMessage      = 'Notification failed - text'
    RestartSubHeading       = 'Herstartmelding - ondertitel'
    RestartMessage          = 'Restart prompt - text'
    RestartForcedSubHeading = 'Forced restart - subtitle ({Minutes} = warning time)'
    RestartForcedMessage    = 'Forced restart - text'
    UninstallingHeading     = 'Uninstall - notification while removing, heading'
    UninstallingMessage     = 'Uninstall - notification while removing, text'
    UninstalledHeading      = 'Uninstall - notification removed, heading'
    UninstalledMessage      = 'Uninstall - notification removed, text'
    UninstallErrorHeading   = 'Uninstall - notification failed, heading'
    UninstallErrorMessage   = 'Uninstall - notification failed, text'
    NewConsentSubHeading    = 'New installation - window, subtitle'
    NewConsentMessage       = 'New installation - window, text'
    NewForcedSubHeading     = 'New installation - warning, subtitle'
    NewForcedMessage        = 'New installation - warning, text'
    NewForcedInfo           = 'New installation - warning, orange line'
    NewInstallingHeading    = 'New installation - notification while installing, heading'
    NewInstallingMessage    = 'New installation - notification while installing, text'
    NewSuccessHeading       = 'New installation - notification succeeded, heading'
    NewSuccessMessage       = 'New installation - notification succeeded, text'
    NewErrorHeading         = 'New installation - notification failed, heading'
    NewErrorMessage         = 'New installation - notification failed, text'
    NewRestartMessage       = 'New installation - restart prompt, text'
    NewRestartForcedMessage = 'New installation - forced restart, text'
}

#region ===================== Logic (also usable without a window) =====================

function Read-AppPsd1
{
    # Read via a copy with BOM (Notepad saves UTF-8 without BOM)
    param ([string]$Path)
    $tmp = [System.IO.Path]::GetTempFileName() + '.psd1'
    try
    {
        [System.IO.File]::WriteAllText($tmp, [System.IO.File]::ReadAllText($Path), (New-Object System.Text.UTF8Encoding $true))
        return (ConvertTo-CurrentSettings (Import-PowerShellDataFile -Path $tmp))
    }
    finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

function ConvertTo-CurrentSettings($d)
{
    # Versions before 1.3 used Dutch values in app.psd1 (Altijd, Bestand, ma,di,...): convert them
    if (-not $d) { return $d }
    $maps = @{
        InstallWindow   = @{ 'Altijd' = 'Always'; 'Werktijd' = 'DuringWorkHours'; 'BuitenWerktijd' = 'OutsideWorkHours' }
        NoUserAction    = @{ 'Installeren' = 'Install'; 'Wachten' = 'Wait' }
        RestartMode     = @{ 'Nooit' = 'Never'; 'AlsNodig' = 'IfNeeded'; 'Altijd' = 'Always' }
        DetectionMethod = @{ 'AppsEnOnderdelen' = 'AppsAndFeatures'; 'Bestand' = 'File'; 'Register' = 'Registry' }
    }
    foreach ($k in $maps.Keys) { $v = "$($d[$k])"; if ($v -and $maps[$k].ContainsKey($v)) { $d[$k] = $maps[$k][$v] } }
    if ("$($d['WorkDays'])" -match '\b(ma|di|wo|do|vr|za|zo)\b')
    {
        $days = @{ 'ma' = 'mon'; 'di' = 'tue'; 'wo' = 'wed'; 'do' = 'thu'; 'vr' = 'fri'; 'za' = 'sat'; 'zo' = 'sun' }
        $d['WorkDays'] = (@("$($d['WorkDays'])" -split '[,; ]+' | Where-Object { $_ } | ForEach-Object { if ($days.ContainsKey($_)) { $days[$_] } else { $_ } }) -join ',')
    }
    return $d
}

function Get-DefaultTexts
{
    # Default texts for all apps: _Kit\DefaultTexts.psd1, completed with the built-in texts
    param ([string]$Lang = $script:TextLang)
    $r = [ordered]@{}
    $builtin = Get-BuiltinTexts $Lang
    foreach ($k in $TextKeys) { $r[$k] = $builtin[$k] }
    $path = Get-DefaultTextsPath $Lang
    if (Test-Path $path)
    {
        try
        {
            $f = Read-AppPsd1 $path
            foreach ($k in $TextKeys) { if ($f[$k]) { $r[$k] = $f[$k] } }
        }
        catch { }
    }
    return $r
}

function ConvertTo-DefaultTextsPsd1
{
    param ($Texts)
    $q = { param($s) "'" + ([string]$s).Replace("'", "''") + "'" }
    $lines = @(
        '#  DEFAULT TEXTS for all apps (edited with the AppUpdateKit Builder).'
        '#  An app uses this text, unless app.psd1 contains its own text.'
        '#  Filled in: {AppName}, {Version} (version), {Minutes} (minutes) and {MaxPostpones} (max postpones)'
        '@{'
    )
    foreach ($k in $TextKeys) { $lines += "    $($k.PadRight(18))= $(& $q $Texts[$k])" }
    $lines += '}'
    return ($lines -join "`r`n") + "`r`n"
}

function Get-VersionFolder([string]$InstallerPath)
{
    # Version folder of an installer, as starting point for 'Browse...' at 'Save package to' (fills in nothing automatically):
    #   ...\versions\2.4.0\source\setup.exe      -> ...\versions\2.4.0
    #   ...\versions\2.4.0\source\x64\setup.exe  -> ...\versions\2.4.0
    #   ...\8.9.8.1\source\npp.exe                      -> ...\8.9.8.1
    $dir = Split-Path $InstallerPath -Parent
    $d = $dir
    while ($d)
    {
        $parent = Split-Path $d -Parent
        if (-not $parent -or $parent -eq $d) { break }
        if ((Split-Path $parent -Leaf) -ieq 'versies') { return $d }
        $d = $parent
    }
    if ((Split-Path $dir -Leaf) -ieq 'source') { return (Split-Path $dir -Parent) }
    return $dir
}

function Get-BuildItem([string]$Folder, [string]$Name)
{
    # A file or folder of a build. Builds of versions before 1.3 used Dutch names: use those if the new one isn't there.
    $old = @{ 'BuildInfo.txt' = 'Bouwinfo.txt'; 'Source' = 'Bron'; 'PackageLocation.txt' = 'Pakketlocatie.txt'; 'DefaultTexts.psd1' = 'Standaardteksten.psd1'; 'Intune-settings.txt' = 'Intune-instellingen.txt' }
    $p = Join-Path $Folder $Name
    if (-not (Test-Path -LiteralPath $p) -and $old.ContainsKey($Name)) { $o = Join-Path $Folder $old[$Name]; if (Test-Path -LiteralPath $o) { return $o } }
    return $p
}

function Get-AppVersions
{
    # All builds of an app: Output\<AppId>\<version>\ and earlier builds in Output\<AppId>\_archive\<version>_<date>\
    param ([string]$AppId)
    $dir = Join-Path (Join-Path $KitRoot 'Output') $AppId
    if (-not (Test-Path $dir)) { return @() }

    $make = {
        param ($folder, [string]$ver, [bool]$isArchive)
        # Is the package in its own folder (OutputFolder)? Then there is only a reference here.
        $ptr = Get-BuildItem $folder.FullName 'PackageLocation.txt'
        if (Test-Path $ptr)
        {
            $target = ([System.IO.File]::ReadAllText($ptr)).Trim()
            if ($target -and (Test-Path $target)) { $folder = Get-Item -LiteralPath $target }
        }
        $v = $null; try { $v = [version]$ver } catch { }
        $pkgFile = Join-Path $folder.FullName 'install.intunewin'
        $bi = Get-BuildItem $folder.FullName 'BuildInfo.txt'
        $built = if (Test-Path $bi) { (Get-Item $bi).LastWriteTime } else { $folder.LastWriteTime }
        $srcDir = Get-BuildItem $folder.FullName 'Source'
        [pscustomobject]@{
            Version       = $ver
            Label         = if ($isArchive) { "$ver  (replaced)" } else { $ver }
            IsArchive     = $isArchive
            SortKey       = $v
            Path          = $folder.FullName
            Pointer       = if (Test-Path $ptr) { $ptr } else { '' }
            Built         = $built
            HasPkg        = Test-Path $pkgFile
            SizeMB        = if (Test-Path $pkgFile) { [math]::Round((Get-Item $pkgFile).Length / 1MB) } else { 0 }
            HasSource       = Test-Path (Join-Path $srcDir 'app.psd1')
            HasInstallers = [bool](Get-ChildItem $srcDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.exe', '.msi', '.msp' })
        }
    }

    $items = @()
    foreach ($d in (Get-ChildItem $dir -Directory | Where-Object { $_.Name -notin '_archive', '_archief' })) { $items += & $make $d $d.Name $false }
    foreach ($archName in '_archive', '_archief')   # (_archief: versions before 1.3)
    {
        $arch = Join-Path $dir $archName
        if (Test-Path $arch) { foreach ($d in (Get-ChildItem $arch -Directory)) { $items += & $make $d (($d.Name -split '_')[0]) $true } }
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

    $lines = @(
        '#  Made with the AppUpdateKit Builder. You can also edit this file by hand.'
        '#  Filled in in texts: {AppName}, {Version}, {Minutes} and {MaxPostpones}. Empty = default text.'
        '@{'
        '    # ---------- 1. Basics ----------'
        "    AppId      = $(& $q $d.AppId)"
        "    AppName    = $(& $q $d.AppName)"
        "    Version    = $(& $q $d.Version)"
        "    DetectName = $(& $q $d.DetectName)"
        "    Processes  = @($procs)"
        "    OutputFolder = $(& $q $d.OutputFolder)   # folder for the package; empty = Output\<AppId>\<version> in the kit"
        ''
        '    # ---------- 1b. Detection: how Intune sees that the app is present ----------'
        "    DetectionMethod = $(& $q $(if ($d.DetectionMethod) { $d.DetectionMethod } else { 'AppsAndFeatures' }))   # AppsAndFeatures | File | Registry | Script"
        "    DetectVersion   = $(& $q $d.DetectVersion)   # empty = version of this package; '-' = only check whether it exists"
        "    DetectFile      = $(& $q $d.DetectFile)   # with File, e.g. %ProgramFiles%\Remote help\RemoteHelp.exe"
        "    DetectRegKey    = $(& $q $d.DetectRegKey)   # with Registry, e.g. HKLM\SOFTWARE\Vendor\App"
        "    DetectRegValue  = $(& $q $d.DetectRegValue)   # with Registry, e.g. Version (empty = only the key)"
        "    DetectScript    = $(& $q $d.DetectScript)"
        ''
        '    # ---------- 2. Appearance ----------'
        "    Icon        = $(& $q $d.Icon)"
        "    AccentColor = $(& $q $d.AccentColor)"
        "    Language    = $(& $q $(if ("$($d.Language)" -eq 'en') { 'en' } else { 'nl' }))   # language of the popups and scripts on the laptop: nl | en"
        ''
        '    # ---------- 3. Who gets the update ----------'
        "    OnlyUpdateExisting = $bool"
        "    InstallDuringSetup = $(if ($d.InstallDuringSetup -eq $false) { '$false' } else { '$true' })   # `$true = install right away on new laptops (Autopilot), without popup"
        ''
        '    # ---------- 4. Postpone ----------'
        "    MaxPostpones          = $([int]$d.MaxPostpones)"
        "    PostponeHours         = $([int]$d.PostponeHours)"
        "    ConsentTimeoutMinutes = $([int]$d.ConsentTimeoutMinutes)"
        "    ForcedDelayMinutes    = $([int]$d.ForcedDelayMinutes)"
        ''
        '    # ---------- 4b. When ----------'
        "    InstallWindow = $(& $q $(if ($d.InstallWindow) { $d.InstallWindow } else { 'Always' }))   # Always | DuringWorkHours | OutsideWorkHours"
        "    WorkHours     = $(& $q $(if ($d.WorkHours) { $d.WorkHours } else { '08:00-17:00' }))   # multiple blocks allowed: '09:00-10:00,13:00-14:00'"
        "    WorkDays      = $(& $q $(if ($d.WorkDays) { $d.WorkDays } else { 'mon,tue,wed,thu,fri' }))"
        "    IdleMinutes   = $([int]("0$($d.IdleMinutes)"))   # > 0 = install right away after this many minutes idle or locked"
        "    NoUserAction  = $(& $q $(if ($d.NoUserAction) { $d.NoUserAction } else { 'Install' }))   # Install | Wait"
        ''
        '    # ---------- 4c. Restart after the installation ----------'
        "    RestartMode            = $(& $q $(if ($d.RestartMode) { $d.RestartMode } else { 'Never' }))   # Never | IfNeeded (3010/1641) | Always"
        "    RestartReminderMinutes = $([int]$(if ($null -ne $d.RestartReminderMinutes -and "$($d.RestartReminderMinutes)" -ne '') { $d.RestartReminderMinutes } else { 60 }))   # Later: ask again after (minutes)"
        "    RestartDeadlineHours   = $([int]$(if ($null -ne $d.RestartDeadlineHours -and "$($d.RestartDeadlineHours)" -ne '') { $d.RestartDeadlineHours } else { 24 }))   # forced restart after (hours, 0 = never)"
        "    RestartWarningMinutes  = $([int]$(if ($null -ne $d.RestartWarningMinutes -and "$($d.RestartWarningMinutes)" -ne '') { $d.RestartWarningMinutes } else { 15 }))   # warning before the forced restart (minutes)"
        ''
        '    # ---------- 4d. Uninstall ----------'
        "    UninstallNotify = $(if ($d.UninstallNotify -eq $true) { '$true' } else { '$false' })   # `$true = notifications bottom right when uninstalling"
        ''
        '    # ---------- 5. Installation (components are installed in this order) ----------'
        "    AutoInstallSteps = $(if ($d.AutoInstallSteps) { '$true' } else { '$false' })   # `$true = install-app.cmd is created from this"
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
        "    PreInstall  = $(& $q $d.PreInstall)    # cmd lines before the components"
        "    PostInstall = $(& $q $d.PostInstall)    # cmd lines after the components"
        ''
        '    # ---------- 6. Texts for this app/version (empty = _Kit\DefaultTexts.psd1) ----------'
        '    Texts = @{'
    )
    foreach ($k in $TextKeys)
    {
        $v = ''
        if ($d.Texts -and $d.Texts[$k]) { $v = $d.Texts[$k] }
        $lines += "        $($k.PadRight(18))= $(& $q $v)"
    }
    $lines += '    }'
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

function Get-MsiIcon
{
    <#
        Gets the icon from the Icon table of an MSI and returns the path to a temporary .ico/.exe/.dll
        (or $null if the MSI has no icon). Preference: ARPPRODUCTICON (the icon in Apps & features), otherwise the largest.
    #>
    param ([string]$MsiPath, [string]$WorkDir)
    $db = $null
    try
    {
        $wi = New-Object -ComObject WindowsInstaller.Installer
        $db = $wi.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $wi, @($MsiPath, 0))
        # Export the Icon table: the icons become separate files in the subfolder Icon
        $db.GetType().InvokeMember('Export', 'InvokeMethod', $null, $db, @('Icon', $WorkDir, 'Icon.idt')) | Out-Null
    }
    catch { return $null }
    finally { if ($db) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($db) } }

    $files = @(Get-ChildItem -Path $WorkDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'Icon.idt' -and $_.Length -gt 0 })
    if (-not $files.Count) { return $null }
    $pref = Get-MsiProperty $MsiPath 'ARPPRODUCTICON'
    $pick = if ($pref) { $files | Where-Object { $_.Name -like "$pref*" } | Select-Object -First 1 }
    if (-not $pick) { $pick = $files | Sort-Object Length -Descending | Select-Object -First 1 }

    # Determine the kind of file from the first bytes: 00 00 01 00 = .ico, 'MZ' = .exe/.dll
    $head = New-Object byte[] 4
    $fs = [System.IO.File]::OpenRead($pick.FullName); try { [void]$fs.Read($head, 0, 4) } finally { $fs.Dispose() }
    $ext = if ($head[0] -eq 0 -and $head[1] -eq 0 -and $head[2] -eq 1 -and $head[3] -eq 0) { '.ico' }
           elseif ($head[0] -eq 0x4D -and $head[1] -eq 0x5A) { '.exe' } else { $null }
    if (-not $ext) { return $null }
    $out = Join-Path $WorkDir ("msi-icon" + $ext)
    Copy-Item -LiteralPath $pick.FullName -Destination $out -Force
    return $out
}

function Get-InstallerInfo
{
    # Recognises the installer type and suggests silent parameters
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
        $info.Note        = 'MSI: installed silently with msiexec /qn.'
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

    # Search the first 4 MB for marks of the installer program
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
        $info.Kind = 'NSIS'; $info.Args = '/S'; $info.Note = 'NSIS-installer: /S = stil.'
    }
    elseif ($text -match 'Inno Setup')
    {
        $info.Kind = 'Inno'; $info.Args = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'; $info.Note = 'Inno Setup installer.'
    }
    elseif ($text -match 'InstallShield')
    {
        $info.Kind = 'InstallShield'; $info.Args = '/s /v"/qn /norestart"'; $info.Note = 'InstallShield: check the parameters with the vendor.'
    }
    elseif ($text -match 'WixBundle|WiX Toolset|\.wixburn')
    {
        $info.Kind = 'WiX'; $info.Args = '/quiet /norestart'; $info.Note = 'WiX-bundle.'
    }
    else
    {
        $info.Note = 'Type not recognised: check the silent switches with the vendor.'
    }
    return $info
}

function Find-UninstallString
{
    # Searches "Apps & features" on THIS PC for an uninstall command
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
rem  INSTALLATION STEPS - $AppName
rem  Created with the Builder; you may change this (extra steps, files, ...).
rem  The popup, the process check and the notifications are handled by install.cmd.
rem ===========================================================================

rem ---- Preparation (e.g. a runtime that is needed first) ----

rem ---- The app itself ($($Info.Kind)) ----
$line
set APP_EXITCODE=%ERRORLEVEL%

rem ---- Aftercare (extra files, shortcuts, turning off the built-in updater, ...) ----

exit /b %APP_EXITCODE%
"@
}

function Get-ComponentInfo
{
    # Type, suggested parameters and (for MSI) product code of a file that needs to be installed
    param ([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $r = @{ File = [System.IO.Path]::GetFileName($Path); Kind = 'EXE'; Args = ''; Codes = '0 3010 1641'; Main = $false
            ProductCode = ''; ProductName = ''; Version = ''; Note = '' }
    switch ($ext)
    {
        '.msi' { $i = Get-InstallerInfo $Path; $r.Kind = 'MSI'; $r.ProductCode = "$($i.ProductCode)"; $r.ProductName = "$($i.ProductName)"; $r.Version = "$($i.Version)"; $r.Note = $i.Note }
        '.exe' { $i = Get-InstallerInfo $Path; $r.Kind = $i.Kind; $r.Args = $i.Args; $r.ProductName = "$($i.ProductName)"; $r.Version = "$($i.Version)"; $r.Note = $i.Note }
        '.msp' { $r.Kind = 'MSP'; $r.Note = 'MSI-patch (msiexec /p).' }
        '.ps1' { $r.Kind = 'PS1'; $r.Codes = '0'; $r.Note = 'PowerShell-script.' }
        '.cmd' { $r.Kind = 'CMD'; $r.Codes = '0'; $r.Note = 'Batchbestand.' }
        '.bat' { $r.Kind = 'CMD'; $r.Codes = '0'; $r.Note = 'Batchbestand.' }
        '.reg' { $r.Kind = 'REG'; $r.Codes = '0'; $r.Note = 'Registry file (reg import).' }
    }
    # Typical helper components: also accept "already installed" (1638)
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
        'REG'   { "reg.exe import `"$($c.File)`" /reg:64" }   # 64-bit registry, just like Group Policy
        default { "`"$($c.File)`" $a" }
    }
    return $line.Trim()
}

function New-InstallCmdFromComponents
{
    # Creates install-app.cmd: components in order, with their own parameters and allowed exit codes.
    # If a component fails, the installation stops with the exit code of that component.
    param ([string]$AppName, $Components, [string]$PreInstall, [string]$PostInstall)

    $L = @(
        'rem ==========================================================================='
        "rem  INSTALLATION STEPS - $AppName"
        'rem  Created automatically by the Builder from the components in tab 2.'
        'rem  Change the components in the Builder (or turn off "create automatically").'
        'rem ==========================================================================='
        ''
        'set APP_EXITCODE=0'
    )
    if ("$PreInstall".Trim())
    {
        $L += ''; $L += 'rem ---- Before the installation ----'; $L += ("$PreInstall".TrimEnd() -split "`r?`n")
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
        $L += "rem ---- Component ${i}: $($c.File) ($($c.Kind))$(if ($c.Main) { ' - main component' }) ----"
        $L += Get-ComponentCommand $c
        $L += 'set STEP=%ERRORLEVEL%'
        $L += 'set OK='
        $L += "for %%c in ($($codes -join ' ')) do if `"%STEP%`"==`"%%c`" set OK=1"
        $L += 'if not defined OK ('
        $L += "    echo Component $i - $safe - failed with exit code %STEP%"
        $L += '    exit /b %STEP%'
        $L += ')'
        $L += 'if "%STEP%"=="3010" set APP_EXITCODE=3010'
        $L += 'if "%STEP%"=="1641" set APP_EXITCODE=1641'
    }
    if ("$PostInstall".Trim())
    {
        $L += ''; $L += 'rem ---- After the installation ----'; $L += ("$PostInstall".TrimEnd() -split "`r?`n")
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
        # Uninstall by name (MSI product code or the app's own uninstaller); works on every laptop
        $line = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"Remove-App.ps1`" -Name `"$DetectName`""
        if ($Info.Kind -in 'NSIS', 'Inno', 'EXE') { $line += " -ExeArgs `"$(if ($Info.Kind -eq 'Inno') { '/VERYSILENT /NORESTART' } else { '/S' })`"" }
    }
    if (-not $line)
    {
        $line = "rem FILL IN: the uninstall command, for example:`r`nrem `"%ProgramFiles%\$AppName\uninstall.exe`" /S`r`nver > nul"
    }
@"
rem ===========================================================================
rem  UNINSTALL STEPS - $AppName
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
        Converts an .svg to a PNG of Size x Size with a transparent background.
        Windows can't draw SVG itself; that's why Edge (headless) does it.
    #>
    param ([string]$Svg, [string]$Png, [int]$Size = 256, [string]$Browser = (Find-HeadlessBrowser), [string[]]$ExtraArgs = @(), [switch]$NoCrop)
    if (-not $Browser) { throw 'Microsoft Edge or Google Chrome is needed to convert an SVG, but was not found. Save the logo as .png and choose that.' }

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

        # Own profile folder: otherwise Edge passes the command to an Edge window that is already open
        $argList = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
                     '--disable-extensions', '--force-device-scale-factor=1', '--default-background-color=00000000',
                     "--window-size=$($Size * 2 + 200),$($Size * 2 + 200)", "--user-data-dir=`"$(Join-Path $work 'profiel')`"",
                     "--screenshot=`"$out`"") + $ExtraArgs + @("`"file:///$($html.Replace('\', '/').TrimStart('/'))`"")
        $hide = @{}; if ($IsWindows -ne $false) { $hide.WindowStyle = 'Hidden' }   # PS 5.1: $IsWindows doesn't exist
        $proc = Start-Process -FilePath $Browser -ArgumentList $argList -PassThru @hide
        $null = $proc.Handle
        if (-not $proc.WaitForExit(30000)) { try { $proc.Kill() } catch { }; throw 'Converting the SVG took too long.' }
        if (-not (Test-Path $out) -or (Get-Item $out).Length -lt 100) { throw 'The SVG could not be converted. Is the file correct? Otherwise try a .png.' }
        if ($NoCrop) { Copy-Item -LiteralPath $out -Destination $Png -Force; return }

        # The window is rendered larger (small headless windows are cut off at the bottom): cut the logo out at the top left
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
    # Creates an .ico (256x256, PNG inside) from an .svg/.png/.jpg/.bmp, or gets the icon from an .exe
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

    if ($ext -in '.exe', '.dll')
    {
        # Ask for the largest size (256x256) first; ExtractAssociatedIcon only gives 32x32 (blurry)
        $img = $null
        try
        {
            if (-not ('AppKit.IconX' -as [type]))
            {
                Add-Type -Namespace AppKit -Name IconX -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, System.IntPtr[] icons, uint[] ids, uint count, uint flags);
[DllImport("user32.dll")] public static extern bool DestroyIcon(System.IntPtr handle);
'@
            }
            $handles = New-Object System.IntPtr[] 1; $ids = New-Object System.UInt32[] 1
            if ([AppKit.IconX]::PrivateExtractIcons($Source, 0, 256, 256, $handles, $ids, 1, 0) -ge 1 -and $handles[0] -ne [System.IntPtr]::Zero)
            {
                $tmpIcon = [System.Drawing.Icon]::FromHandle($handles[0])
                $img = $tmpIcon.ToBitmap()
                $tmpIcon.Dispose(); [void][AppKit.IconX]::DestroyIcon($handles[0])
            }
        }
        catch { $img = $null }
        if (-not $img) { $img = ([System.Drawing.Icon]::ExtractAssociatedIcon($Source)).ToBitmap() }
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
    return $Text.Replace('{AppName}', $d.AppName).Replace('{Version}', [string]$d.Version).Replace('{Minutes}', [string]$d.ForcedDelayMinutes).Replace('{MaxPostpones}', [string]$d.MaxPostpones).
        Replace('{Versie}', [string]$d.Version).Replace('{Minuten}', [string]$d.ForcedDelayMinutes).Replace('{MaxUitstel}', [string]$d.MaxPostpones)   # placeholders of versions before 1.3
}

function Get-EffectiveText
{
    param ([string]$Key, [hashtable]$d, $Std = $null, [switch]$New)
    if (-not $Std) { $Std = Get-DefaultTexts }
    $t = $null
    if ($New -and $Key -notlike 'New*')
    {
        # New installation: first the New text of the app, then the default New text
        $nk = "New$Key"
        if ($d.Texts -and $d.Texts[$nk]) { $t = $d.Texts[$nk] } elseif ($Std[$nk]) { $t = $Std[$nk] }
    }
    if (-not $t) { $t = if ($d.Texts -and $d.Texts[$Key]) { $d.Texts[$Key] } else { $Std[$Key] } }
    return Expand-AppText $t $d
}

function Get-VersionDetails
{
    # Everything about a built version, from Output\<AppId>\<version>\Source and BuildInfo.txt
    param ([string]$Path)
    $srcDir = Get-BuildItem $Path 'Source'
    $r = @{ Data = $null; Std = $null; Icon = $null; Summary = ''; Install = ''; Texts = ''; BuildInfo = '' }

    $psd = Join-Path $srcDir 'app.psd1'
    if (-not (Test-Path $psd))
    {
        $r.Summary = 'No settings were kept for this version (built with an older version of the kit).'
        return $r
    }
    $d = Read-AppPsd1 $psd
    $r.Data = $d

    # Default texts as they were when this version was built
    $std = [ordered]@{}
    $vb = Get-BuiltinTexts $(if ("$($d.Language)" -eq 'en') { 'en' } else { 'nl' })
    foreach ($k in $TextKeys) { $std[$k] = $vb[$k] }
    $stdFile = Get-BuildItem $srcDir 'DefaultTexts.psd1'
    if (Test-Path $stdFile) { try { $f = Read-AppPsd1 $stdFile; foreach ($k in $TextKeys) { if ($f[$k]) { $std[$k] = $f[$k] } } } catch { } }
    $r.Std = $std

    $icon = Join-Path $srcDir $(if ($d.Icon) { $d.Icon } else { 'app.ico' })
    if (Test-Path $icon) { $r.Icon = $icon }

    $timeout = if ($null -ne $d.ConsentTimeoutMinutes) { "$($d.ConsentTimeoutMinutes) minutes" }
               elseif ($null -ne $d.ConsentTimeoutSeconds) { "$($d.ConsentTimeoutSeconds) seconden" } else { '15 minutes' }
    $who = if ($d.OnlyUpdateExisting -eq $false) { 'everyone in the assigned group' } else { 'only devices that already have the app' }
    $r.Summary = @(
        "Name in popup        : $($d.AppName)"
        "Version              : $($d.Version)"
        "Apps & features      : $($d.DetectName)"
        "Detection            : $(switch ("$($d.DetectionMethod)") { 'File' { "file $($d.DetectFile)" } 'Registry' { "registry $($d.DetectRegKey)$(if ($d.DetectRegValue) { "\$($d.DetectRegValue)" })" } 'Script' { 'own script' } default { 'Apps & features' } })$(if ("$($d.DetectionMethod)" -ne 'Script') { if ("$($d.DetectVersion)" -eq '-') { ', no version' } elseif ($d.DetectVersion) { ", at least $($d.DetectVersion)" } else { ", at least $($d.Version)" } })"
        "Processen            : $(@($d.Processes) -join ', ')"
        "Kleur                : $($d.AccentColor)"
        "Logo                 : $(if ($r.Icon) { 'aanwezig' } else { 'ontbreekt' })"
        "Who gets the update  : $who"
        "Postpone             : $($d.MaxPostpones) times, $($d.PostponeHours) hours each"
        "No choice            : window closes after $timeout"
        "Warning in advance   : $($d.ForcedDelayMinutes) minutes after the last postpone"
        "Tijdvenster          : $(Get-WindowText $d)"
        "Idle                 : $(if ([int]("0$($d.IdleMinutes)") -gt 0) { "install right away after $($d.IdleMinutes) minutes idle or locked" } else { 'off' })"
        "Autopilot            : $(if ($d.InstallDuringSetup -eq $false) { 'skip, the app comes after setup' } else { 'install right away, without popup' })"
        "Restart              : $(switch ($d.RestartMode) { 'IfNeeded' { "only when the installer asks for it; Later = $($d.RestartReminderMinutes) min, forced after $(if ([int]("0$($d.RestartDeadlineHours)")) { "$($d.RestartDeadlineHours) hours" } else { 'never' })" } 'Always' { "always; Later = $($d.RestartReminderMinutes) min, forced after $(if ([int]("0$($d.RestartDeadlineHours)")) { "$($d.RestartDeadlineHours) hours" } else { 'never' })" } default { 'no prompt' } })"
        "Uninstall            : $(if ($d.UninstallNotify -eq $true) { 'with notifications' } else { 'without notifications' })"
        "Nobody signed in     : $(if ($d.NoUserAction -eq 'Wait') { 'wait until someone signs in' } else { 'install right away' })"
    ) -join "`r`n"
    $comps = @($d.Components | Where-Object { $_ })
    if ($comps.Count)
    {
        $n = 0
        $r.Summary += "`r`n`r`nComponents (in order):"
        foreach ($c in $comps)
        {
            $n++
            $r.Summary += "`r`n  $n. $($c.File)  [$($c.Kind)]$(if ($c.Main) { '  (main component)' })"
            $r.Summary += "`r`n     parameters : $(if ($c.Args) { $c.Args } else { '(geen)' })"
            $r.Summary += "`r`n     success exit codes: $($c.Codes)"
        }
        if ("$($d.PreInstall)".Trim())  { $r.Summary += "`r`n`r`nBefore the installation:`r`n$($d.PreInstall)" }
        if ("$($d.PostInstall)".Trim()) { $r.Summary += "`r`n`r`nAfter the installation:`r`n$($d.PostInstall)" }
    }

    $parts = @()
    foreach ($fname in 'install-app.cmd', 'uninstall-app.cmd')
    {
        $p = Join-Path $srcDir $fname
        $parts += "==================== $fname ===================="
        $parts += if (Test-Path $p) { [System.IO.File]::ReadAllText($p).TrimEnd() } else { '(not kept)' }
        $parts += ''
    }
    $ps = Join-Path $Path 'Intune\Install.ps1'
    if (Test-Path $ps)
    {
        $parts += '==================== Intune\Install.ps1 (PowerShell-installer) ===================='
        $parts += [System.IO.File]::ReadAllText($ps).TrimEnd()
        $parts += ''
    }
    $r.Install = $parts -join "`r`n"

    $lines = @()
    foreach ($k in $TextKeys)
    {
        $own = [bool]($d.Texts -and $d.Texts[$k])
        $lines += "[$($TextLabels[$k])]  $(if ($own) { '(own text)' } else { '(default text)' })"
        $lines += (Get-EffectiveText $k $d $std)
        $lines += ''
    }
    $r.Texts = $lines -join "`r`n"

    $bi = Get-BuildItem $Path 'BuildInfo.txt'
    $r.BuildInfo = if (Test-Path $bi) { [System.IO.File]::ReadAllText($bi) } else { '(no BuildInfo.txt)' }
    return $r
}

function Get-WindowText([hashtable]$d)
{
    $h = if ($d.WorkHours) { "$($d.WorkHours)" -replace '\s*,\s*', ', ' } else { '08:00-17:00' }
    $w = if ($d.WorkDays) { $d.WorkDays } else { 'mon,tue,wed,thu,fri' }
    switch ($d.InstallWindow)
    {
        'DuringWorkHours'       { return "only within the chosen times ($w, $h)" }
        'OutsideWorkHours' { return "only outside the chosen times (outside $w, $h)" }
        default          { return 'always' }
    }
}

function Compare-AppData
{
    # Short list of differences between an old version and what is in the Builder now
    param ([hashtable]$Old, [hashtable]$New, [string]$OldInstall, [string]$NewInstall)
    $diff = @()
    $labels = [ordered]@{ Version = 'Version'; AppName = 'Name'; DetectName = 'Apps & features'; AccentColor = 'Colour'
                          MaxPostpones = 'Number of postpones'; PostponeHours = 'Hours per postpone'; ForcedDelayMinutes = 'Warning (min)'
                          InstallWindow = 'Time window'; WorkHours = 'Hours'; WorkDays = 'Work days'; IdleMinutes = 'Idle (min)'; NoUserAction = 'Nobody signed in'
                          RestartMode = 'Restart after install'; RestartReminderMinutes = 'Restart: Later (min)'; RestartDeadlineHours = 'Restart: forced after (hours)'; RestartWarningMinutes = 'Restart: warning (min)'; UninstallNotify = 'Notifications on uninstall' }
    foreach ($k in $labels.Keys)
    {
        if ("$($Old[$k])" -ne "$($New[$k])") { $diff += "$($labels[$k]): $($Old[$k])  ->  $($New[$k])" }
    }
    if ((@($Old.Processes) -join ',') -ne (@($New.Processes) -join ',')) { $diff += "Processen: $(@($Old.Processes) -join ', ')  ->  $(@($New.Processes) -join ', ')" }
    if ([bool]$Old.OnlyUpdateExisting -ne [bool]$New.OnlyUpdateExisting) { $diff += 'Who gets the update: changed' }
    if (($Old.InstallDuringSetup -ne $false) -ne ($New.InstallDuringSetup -ne $false)) { $diff += "Install during Autopilot: $(if ($New.InstallDuringSetup -ne $false) { 'on' } else { 'off' })" }
    $fmt = { param($list) (@($list | Where-Object { $_ } | ForEach-Object { "$($_.File)|$($_.Args)|$($_.Codes)|$([bool]$_.Main)" }) -join ';') }
    if ((& $fmt $Old.Components) -ne (& $fmt $New.Components))
    {
        $oldF = @($Old.Components | Where-Object { $_ } | ForEach-Object { $_.File }) -join ', '
        $newF = @($New.Components | Where-Object { $_ } | ForEach-Object { $_.File }) -join ', '
        $diff += if ($oldF -ne $newF) { "Components: $oldF  ->  $newF" } else { 'Parameters or exit codes of components changed' }
    }
    foreach ($k in $TextKeys)
    {
        $o = if ($Old.Texts) { "$($Old.Texts[$k])" } else { '' }
        $n = if ($New.Texts) { "$($New.Texts[$k])" } else { '' }
        if ($o.Trim() -ne $n.Trim()) { $diff += "Text changed: $($TextLabels[$k])" }
    }
    $norm = { param($s) (("$s" -replace "`r", '').Trim()) }
    if ($OldInstall -and (& $norm $OldInstall) -ne (& $norm $NewInstall)) { $diff += 'Installatiestappen (install-app.cmd) gewijzigd' }
    return $diff
}

function Get-InvalidMsiSwitch([string]$Arguments)
{
    # Options msiexec doesn't know (e.g. /S or /VERYSILENT of an .exe installer): msiexec then stops with 1639
    $ok = '^/(i|x|p|a|j[um]?|f[a-z]*|l[a-z\*\+!]*|log|q[nbrf]?[\+\-!]*|quiet|passive|norestart|forcerestart|promptrestart|package|uninstall|update|help|\?|y|z)$'
    return @(("$Arguments" -split '\s+') | Where-Object { $_ -like '/*' -and $_ -notmatch $ok })
}

function Test-InKitOutput([string]$Path)
{
    # Is this path in the kit's Output folder? Then Build-Package.ps1 always builds in Output\<AppId>\<version>.
    try
    {
        $c = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path)).TrimEnd('\')
        $o = [System.IO.Path]::GetFullPath((Join-Path $KitRoot 'Output')).TrimEnd('\')
        return ($c -eq $o -or $c.StartsWith($o + '\', [System.StringComparison]::OrdinalIgnoreCase))
    }
    catch { return $false }
}

function Test-InAppsFolder([string]$Path)
{
    # Is this path in the kit's Apps\ (the app folders)? The package must not go there.
    try
    {
        $c = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path)).TrimEnd('\')
        $a = [System.IO.Path]::GetFullPath($AppsRoot).TrimEnd('\')
        return ($c -eq $a -or $c.StartsWith($a + '\', [System.StringComparison]::OrdinalIgnoreCase))
    }
    catch { return $false }
}

function Test-AppData
{
    param ([hashtable]$d)
    $e = @()
    if ($d.AppId -notmatch '^[A-Za-z0-9_-]+$')        { $e += 'AppId: only letters, digits, - and _ (no spaces).' }
    if (-not $d.AppName)                               { $e += 'Name is empty.' }
    if ($d.Version -notmatch '^\d+(\.\d+){0,3}$')      { $e += 'Version must have the form 1.2.3.' }
    if (-not $d.DetectName)                            { $e += 'Name in Apps & features is empty.' }
    switch ("$($d.DetectionMethod)")
    {
        'File'  { if (-not $d.DetectFile)   { $e += 'Detection: fill in the file (e.g. %ProgramFiles%\Remote help\RemoteHelp.exe).' } }
        'Registry' { if (-not $d.DetectRegKey) { $e += 'Detection: fill in the registry key.' } }
        'Script'   {
            if (-not "$($d.DetectScript)".Trim()) { $e += 'Detection: the own detection script is empty.' }
            else { $pe = $null; [System.Management.Automation.Language.Parser]::ParseInput("$($d.DetectScript)", [ref]$null, [ref]$pe) | Out-Null; if ($pe) { $e += "Detection: error in the own script, line $($pe[0].Extent.StartLineNumber): $($pe[0].Message)" } }
        }
    }
    if ("$($d.DetectVersion)" -and "$($d.DetectVersion)" -ne '-' -and "$($d.DetectVersion)" -notmatch '^\d+(\.\d+){0,3}$') { $e += 'Detection: the minimum version must have the form 1.2.3.' }
    if ($d.AccentColor -notmatch '^#[0-9A-Fa-f]{6}$')  { $e += 'Colour must have the form #RRGGBB.' }
    # Package folder: when saving it may still be empty or not exist yet; when building it is required (Confirm-OutputFolder)
    if ("$($d.OutputFolder)".Trim())
    {
        $of = [Environment]::ExpandEnvironmentVariables("$($d.OutputFolder)")
        if ($of -notmatch '^([A-Za-z]:\\|\\\\)') { $e += "Save package to: use a full path, e.g. I:\...\intune-package (now: $($d.OutputFolder))." }
        elseif (Test-InAppsFolder $of) { $e += "Save package to is inside the app folder ($of). Choose a folder outside Apps\, e.g. the version folder next to the installer; otherwise every build copies itself into the package." }
    }
    if ($d.AutoInstallSteps -and -not @($d.Components | Where-Object { $_ }).Count) { $e += 'Add at least one component in tab 2 (or turn off create automatically).' }
    foreach ($c in @($d.Components | Where-Object { $_ -and "$($_.Kind)" -in 'MSI', 'MSP' }))
    {
        $bad = Get-InvalidMsiSwitch "$($c.Args)"
        if ($bad) { $e += "Parameters for $($c.File): $($bad -join ' ') is not an msiexec option (an .msi already gets /qn /norestart). Remove it in tab 2; otherwise the installation fails with error code 1639." }
    }
    if ($d.InstallWindow -and $d.InstallWindow -ne 'Always')
    {
        $blocks = @("$($d.WorkHours)" -split ',' | Where-Object { $_ })
        if (-not $blocks.Count) { $e += 'Fill in at least one time block, e.g. 08:00-17:00.' }
        foreach ($b in $blocks)
        {
            if ($b -notmatch '^([01]?\d|2[0-3]):[0-5]\d-([01]?\d|2[0-3]):[0-5]\d$') { $e += "Times: '$b' must have the form 08:00-17:00. Separate multiple blocks with a comma." }
            elseif (($b -split '-')[0] -eq ($b -split '-')[1]) { $e += "Times: in '$b' the start and end are the same." }
        }
        if (-not "$($d.WorkDays)".Trim()) { $e += 'Choose at least one working day.' }
    }
    if ("$($d.IdleMinutes)" -notmatch '^\d+$') { $e += 'Minutes idle must be a whole number.' }
    if ($d.RestartMode -and $d.RestartMode -ne 'Never')
    {
        if ("$($d.RestartReminderMinutes)" -notmatch '^\d+$' -or [int]$d.RestartReminderMinutes -lt 15) { $e += 'Restart: ask again after must be at least 15 minutes.' }
        if ("$($d.RestartDeadlineHours)" -notmatch '^\d+$')  { $e += 'Restart: forced after (hours) must be a whole number (0 = never).' }
        if ("$($d.RestartWarningMinutes)" -notmatch '^\d+$' -or [int]$d.RestartWarningMinutes -lt 1) { $e += 'Restart: warning in advance must be at least 1 minute.' }
    }
    foreach ($n in 'MaxPostpones', 'PostponeHours', 'ConsentTimeoutMinutes', 'ForcedDelayMinutes')
    {
        if ("$($d[$n])" -notmatch '^\d+$') { $e += "$n must be a whole number." }
    }
    return $e
}

#endregion

function Get-DetectionScriptText([hashtable]$d, [switch]$Explain)
{
    # The detection script as the build makes it (for 'Test on this PC'),
    # or with -Explain the explain script that does the same check and tells why
    $method = if ($d.DetectionMethod) { "$($d.DetectionMethod)" } else { 'AppsAndFeatures' }
    if ($method -eq 'Script') { if ($Explain) { return $null } else { return "$($d.DetectScript)" } }
    $ver = if ("$($d.DetectVersion)".Trim()) { "$($d.DetectVersion)".Trim() } else { "$($d.Version)" }
    if ($ver -eq '-') { $ver = '' }
    $q = { param($v) "$v".Replace("'", "''") }
    # Explanation in the Builder's language; the script itself as it goes into the package (the app's language)
    $text = if ($Explain) { Get-KitFileText 'Intune\Detection-Explain.ps1' $ThisBuilderLang } else { Get-KitFileText "Intune\Detection-$method.ps1" $script:TextLang }
    return $text.
        Replace('{{APPNAME}}', $d.AppName).Replace('{{DETECT_METHOD}}', $method).
        Replace('{{DETECT_NAME}}', (& $q $d.DetectName)).Replace('{{DETECT_VERSION}}', (& $q $ver)).
        Replace('{{DETECT_FILE}}', (& $q $d.DetectFile)).Replace('{{DETECT_REGKEY}}', (& $q $d.DetectRegKey)).Replace('{{DETECT_REGVALUE}}', (& $q $d.DetectRegValue))
}

if ($env:APPKIT_NOGUI) { return }   # for tests: only load the functions

#region ===================== Window =====================

# Sharp on screens with 125%/150%/200% scaling: tell Windows that the Builder scales itself.
# Without this Windows enlarges the window as a picture and it becomes blurry. Must be before the first window.
try
{
    Add-Type -Namespace AppKit -Name Dpi -ErrorAction Stop -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(System.IntPtr value);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
'@
    # -2 = DPI_AWARENESS_CONTEXT_SYSTEM_AWARE (Windows 10 1703+); otherwise the older call
    $dpiOk = $false
    try { $dpiOk = [AppKit.Dpi]::SetProcessDpiAwarenessContext([System.IntPtr]::new(-2)) } catch { }
    if (-not $dpiOk) { [void][AppKit.Dpi]::SetProcessDPIAware() }
}
catch { }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic

# ---------- Language of the Builder (English / Nederlands) ----------
# Chosen once at the first start; after that remembered per user in %LOCALAPPDATA%\AppUpdateKit\language.txt.
# If the choice doesn't match this Builder, this script runs translated into that language.
$script:LangFile = Join-Path (Join-Path $env:LOCALAPPDATA 'AppUpdateKit') 'language.txt'
function Show-LanguageChoice
{
    # Small window in two languages; returns 'nl' or 'en' ($null when closed)
    $lx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AppUpdateKit" Width="420" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="13" Background="#F4F6F9" Foreground="#1F2937" Topmost="True">
  <StackPanel Margin="24">
    <TextBlock Text="Choose your language" FontSize="17" FontWeight="SemiBold"/>
    <TextBlock Text="Kies je taal" FontSize="17" FontWeight="SemiBold" Foreground="#6B7280" Margin="0,0,0,14"/>
    <TextBlock TextWrapping="Wrap" Foreground="#4B5563" Margin="0,0,0,16"
               Text="This is remembered. You can switch later with the Language / Taal button. - Dit wordt onthouden. Wisselen kan later met de knop Language / Taal."/>
    <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="12"/><ColumnDefinition/></Grid.ColumnDefinitions>
      <Button Name="BtnLangEn" Content="English" Height="40" Background="#185FA5" Foreground="White" BorderThickness="0" Cursor="Hand"/>
      <Button Name="BtnLangNl" Grid.Column="2" Content="Nederlands" Height="40" Background="#185FA5" Foreground="White" BorderThickness="0" Cursor="Hand"/>
    </Grid>
  </StackPanel>
</Window>
'@
    $lw = [Windows.Markup.XamlReader]::Parse($lx)
    $script:LangChoice = $null
    $lw.FindName('BtnLangNl').Add_Click({ $script:LangChoice = 'nl'; $lw.Close() })
    $lw.FindName('BtnLangEn').Add_Click({ $script:LangChoice = 'en'; $lw.Close() })
    [void]$lw.ShowDialog()
    return $script:LangChoice
}
function Save-BuilderLanguage([string]$Lang)
{
    try
    {
        New-Item -Path (Split-Path $script:LangFile -Parent) -ItemType Directory -Force | Out-Null
        [System.IO.File]::WriteAllText($script:LangFile, $Lang)
    }
    catch { }
}
function Start-BuilderInLanguage([string]$Lang)
{
    # Start the Builder again; it then reads the saved language
    $path = Join-Path $KitRoot 'AppUpdateKit-Builder.ps1'
    if (-not (Test-Path $path)) { return $false }
    Start-Process -FilePath 'powershell.exe' -WorkingDirectory $KitRoot -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$path`"")
    return $true
}
$BuilderLang = ''
try { if (Test-Path $script:LangFile) { $BuilderLang = ([System.IO.File]::ReadAllText($script:LangFile)).Trim() } } catch { }
if (-not $BuilderLang)
{
    # Versions before 1.3 kept the choice in taal.txt
    $oldLangFile = Join-Path (Split-Path $script:LangFile -Parent) 'taal.txt'
    try { if (Test-Path $oldLangFile) { $BuilderLang = ([System.IO.File]::ReadAllText($oldLangFile)).Trim(); if ($BuilderLang) { Save-BuilderLanguage $BuilderLang } } } catch { }
}
if ($BuilderLang -notin 'nl', 'en')
{
    $BuilderLang = Show-LanguageChoice
    if (-not $BuilderLang) { $BuilderLang = $ThisBuilderLang }
    Save-BuilderLanguage $BuilderLang
}
if ($BuilderLang -ne $ThisBuilderLang)
{
    # Other language: run this script translated (Language\<language>.xml, via Language\Translate.ps1) here
    $translated = $null
    try
    {
        $langCode = '$ThisBuilderLang = ''en''   # LANG' + 'CODE'
        $translated = Get-AppKitScriptBlock (Join-Path $KitRoot 'AppUpdateKit-Builder.ps1') -Lang $BuilderLang -Comments $false -Special @{ $langCode = $langCode.Replace("'en'", "'$BuilderLang'") }
    }
    catch { [void][System.Windows.MessageBox]::Show("The translation could not be loaded; the Builder starts in English.`n`n$($_.Exception.Message)", 'AppUpdateKit') }
    if ($translated) { . $translated; return }
}

# Own identity in the taskbar, so Windows shows the Builder icon and not that of PowerShell
try
{
    Add-Type -Namespace AppKit -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string id);'
    [void][AppKit.Shell]::SetCurrentProcessExplicitAppUserModelID('AppUpdateKit.Builder')
}
catch { $script:AumidError = $_.Exception.Message }
$BuilderIcon = Join-Path $KitDir 'Builder.ico'
# From a network drive (e.g. I:\apps) Windows doesn't always load the icon: use a local copy in the own profile
# What happens with the icon goes to %LOCALAPPDATA%\AppUpdateKit\startup.log (overwritten at every start)
$script:StartLog = Join-Path (Join-Path $env:LOCALAPPDATA 'AppUpdateKit') 'startup.log'
function Write-StartLog([string]$Text)
{
    try { Add-Content -LiteralPath $script:StartLog -Value "$(Get-Date -Format 'HH:mm:ss')  $Text" -Encoding UTF8 } catch { }
}
try
{
    $localIconDir = Join-Path $env:LOCALAPPDATA 'AppUpdateKit'
    if (-not (Test-Path -LiteralPath $localIconDir)) { New-Item -Path $localIconDir -ItemType Directory -Force | Out-Null }
    Set-Content -LiteralPath $script:StartLog -Value "AppUpdateKit Builder started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-StartLog "Kit folder     : $KitRoot"
    Write-StartLog "Icon in kit    : $BuilderIcon (exists: $(Test-Path -LiteralPath $BuilderIcon))"
    $localIcon = Join-Path $localIconDir 'Builder.ico'
    if ((Test-Path -LiteralPath $BuilderIcon) -and (-not (Test-Path -LiteralPath $localIcon) -or (Get-Item -LiteralPath $localIcon).Length -ne (Get-Item -LiteralPath $BuilderIcon).Length))
    {
        Copy-Item -LiteralPath $BuilderIcon -Destination $localIcon -Force
        Write-StartLog "Local copy     : created in $localIcon"
    }
    if (Test-Path -LiteralPath $localIcon) { $BuilderIcon = $localIcon; Write-StartLog "Icon used      : $localIcon ($((Get-Item -LiteralPath $localIcon).Length) bytes)" }
    else { Write-StartLog 'Icon used      : NO local copy, the icon from the kit is used' }
    # Copy for the shortcut in the kit folder: Explorer often doesn't show an icon that is itself on a network drive.
    # %ProgramData% is local on every PC and readable for every account.
    $script:SharedIcon = $null
    try
    {
        $sharedDir = Join-Path $env:ProgramData 'AppUpdateKit'
        if (-not (Test-Path -LiteralPath $sharedDir)) { New-Item -Path $sharedDir -ItemType Directory -Force | Out-Null }
        $sharedIcon = Join-Path $sharedDir 'Builder.ico'
        if (-not (Test-Path -LiteralPath $sharedIcon) -or (Get-Item -LiteralPath $sharedIcon).Length -ne (Get-Item -LiteralPath $BuilderIcon).Length)
        {
            Copy-Item -LiteralPath $BuilderIcon -Destination $sharedIcon -Force
        }
        if (Test-Path -LiteralPath $sharedIcon) { $script:SharedIcon = '%ProgramData%\AppUpdateKit\Builder.ico' }
    }
    catch { Write-StartLog "Shared icon    : failed ($($_.Exception.Message))" }
    if ($script:AumidError) { Write-StartLog "ERROR with the taskbar identity: $($script:AumidError)" }
    else { Write-StartLog 'Taakbalk-id    : AppUpdateKit.Builder' }
}
catch { Write-StartLog "ERROR copying the icon: $($_.Exception.Message)" }

# Start menu shortcut with the same taskbar identity (AppUserModelID) and the icon.
# Windows gets the taskbar icon of an app with its own identity from such a shortcut; without a shortcut
# the taskbar sometimes shows an empty icon at the first start (especially from a network drive).
# Created before the window appears, and after that it is also in the Start menu as "AppUpdateKit Builder".
if (-not ('AppKit.AumidShortcut' -as [type]))
{
    try
    {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
namespace AppKit {
    public static class AumidShortcut {
        [ComImport, Guid("00021401-0000-0000-C000-000000000046")] class CShellLink { }

        [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IShellLinkW {
            void GetPath(IntPtr pszFile, int cch, IntPtr pfd, uint fFlags);
            void GetIDList(out IntPtr ppidl);
            void SetIDList(IntPtr pidl);
            void GetDescription(IntPtr pszName, int cch);
            void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
            void GetWorkingDirectory(IntPtr pszDir, int cch);
            void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
            void GetArguments(IntPtr pszArgs, int cch);
            void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
            void GetHotkey(out short pwHotkey);
            void SetHotkey(short wHotkey);
            void GetShowCmd(out int piShowCmd);
            void SetShowCmd(int iShowCmd);
            void GetIconLocation(IntPtr pszIconPath, int cch, out int piIcon);
            void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
            void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
            void Resolve(IntPtr hwnd, uint fFlags);
            void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
        }

        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        struct PropertyKey { public Guid fmtid; public uint pid; }

        [StructLayout(LayoutKind.Sequential)]
        struct PropVariant { public ushort vt; public ushort r1; public ushort r2; public ushort r3; public IntPtr p1; public IntPtr p2; }

        [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IPropertyStore {
            void GetCount(out uint cProps);
            void GetAt(uint iProp, IntPtr pkey);
            void GetValue(ref PropertyKey key, IntPtr pv);
            void SetValue(ref PropertyKey key, ref PropVariant pv);
            void Commit();
        }

        public static void Save(string lnkPath, string target, string args, string workDir, string iconPath, string appId, string description) {
            IShellLinkW link = (IShellLinkW)new CShellLink();
            try {
                link.SetPath(target);
                link.SetArguments(args);
                link.SetWorkingDirectory(workDir);
                link.SetIconLocation(iconPath, 0);
                link.SetDescription(description);
                link.SetShowCmd(7);   // minimised: the PowerShell window stays away
                IPropertyStore store = (IPropertyStore)link;
                PropertyKey key = new PropertyKey();
                key.fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");   // PKEY_AppUserModel_ID
                key.pid = 5;
                PropVariant pv = new PropVariant();
                pv.vt = 31;   // VT_LPWSTR
                pv.p1 = Marshal.StringToCoTaskMemUni(appId);
                try { store.SetValue(ref key, ref pv); store.Commit(); }
                finally { Marshal.FreeCoTaskMem(pv.p1); }
                ((IPersistFile)link).Save(lnkPath, true);
            } finally { Marshal.ReleaseComObject(link); }
        }
    }
}
"@
    }
    catch { }
}
try
{
    $startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'AppUpdateKit Builder.lnk'
    if ('AppKit.AumidShortcut' -as [type])
    {
        [AppKit.AumidShortcut]::Save($startMenu,
            (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'),
            "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $KitRoot 'AppUpdateKit-Builder.ps1')`"",
            $KitRoot, $BuilderIcon, 'AppUpdateKit.Builder', 'AppUpdateKit Builder')
        Write-StartLog "Start menu     : $startMenu updated"
    }
    else { Write-StartLog 'Start menu     : not created (helper code could not load)' }
}
catch { Write-StartLog "ERROR with the Start menu shortcut: $($_.Exception.Message)" }

function Get-BuilderIconImage
{
    # Load the icon from the bytes (not via a file address): also works from a network drive
    try
    {
        $ms = New-Object System.IO.MemoryStream (, [System.IO.File]::ReadAllBytes($BuilderIcon))
        return [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, [System.Windows.Media.Imaging.BitmapCreateOptions]::None, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    }
    catch { return $null }
}

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
        public string Action      { get; set; }   // only for the table: Install (1), Copy, Logo, ...
        public bool   IsFile      { get; set; }   // true = not a component, but another file in the package
    }
}
"@
}

# Error while starting (before the window exists): still show a message
trap
{
    $log = Join-Path ([System.IO.Path]::GetTempPath()) 'AppUpdateKit-Builder-errors.log'
    Add-Content -Path $log -Value "$(Get-Date)`r`n$($_ | Out-String)" -ErrorAction SilentlyContinue
    [void][System.Windows.MessageBox]::Show("The Builder could not start:`n`n$($_.Exception.Message)`n`nDetails: $log", 'AppUpdateKit Builder', 'OK', 'Error')
    exit 1
}

# Shared theme for all Builder windows (buttons, fields, tabs, lists, scrollbars)
$ThemeXaml = @'
    <!-- Theme: colours -->
    <SolidColorBrush x:Key="Accent" Color="#185FA5"/>
    <SolidColorBrush x:Key="AccentHover" Color="#144F8A"/>
    <SolidColorBrush x:Key="AccentPress" Color="#0F3F6F"/>
    <SolidColorBrush x:Key="AccentSoft" Color="#E8F0F9"/>
    <SolidColorBrush x:Key="Line" Color="#D5DAE1"/>
    <SolidColorBrush x:Key="LineHover" Color="#A9B2BE"/>
    <SolidColorBrush x:Key="LineSoft" Color="#E6E9EE"/>
    <SolidColorBrush x:Key="Hover" Color="#F1F4F8"/>
    <SolidColorBrush x:Key="Ink" Color="#1F2937"/>
    <SolidColorBrush x:Key="Muted" Color="#6B7280"/>

    <!-- Text -->
    <Style TargetType="Label">
      <Setter Property="Padding" Value="0,4,0,0"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,-4,0,8"/>
    </Style>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="{StaticResource LineSoft}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="10"/>
      <Setter Property="Padding" Value="18"/>
      <Setter Property="Margin" Value="0,0,0,14"/>
    </Style>
    <Style TargetType="ToolTip">
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="Padding" Value="8,6"/>
    </Style>

    <!-- Input fields: rounded, blue border on focus -->
    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="Margin" Value="0,2,0,8"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="SelectionBrush" Value="{StaticResource Accent}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" SnapsToDevicePixels="True">
              <ScrollViewer x:Name="PART_ContentHost" Focusable="False" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource LineHover}"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.55"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Buttons -->
    <Style TargetType="Button">
      <Setter Property="Padding" Value="14,6"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" SnapsToDevicePixels="True">
              <ContentPresenter Margin="{TemplateBinding Padding}" RecognizesAccessKey="True"
                                HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.5"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="{StaticResource Hover}"/>
          <Setter Property="BorderBrush" Value="{StaticResource LineHover}"/>
        </Trigger>
        <Trigger Property="IsKeyboardFocused" Value="True"><Setter Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="#E4E9F0"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderBrush" Value="{StaticResource Accent}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="{StaticResource AccentHover}"/>
          <Setter Property="BorderBrush" Value="{StaticResource AccentHover}"/>
        </Trigger>
        <Trigger Property="IsKeyboardFocused" Value="True"><Setter Property="BorderBrush" Value="{StaticResource AccentPress}"/></Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Setter Property="Background" Value="{StaticResource AccentPress}"/>
          <Setter Property="BorderBrush" Value="{StaticResource AccentPress}"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Check boxes -->
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Background="Transparent">
              <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/></Grid.ColumnDefinitions>
              <Border Name="Box" Width="18" Height="18" CornerRadius="4" BorderThickness="1.5" BorderBrush="#9AA3AF" Background="White" VerticalAlignment="Center">
                <Path Name="Mark" Data="M 3 7.5 L 6.2 10.7 L 12 4.5" Stroke="White" StrokeThickness="2" Visibility="Collapsed"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
              </Border>
              <ContentPresenter Name="Cp" Grid.Column="1" Margin="8,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="HasContent" Value="False"><Setter TargetName="Cp" Property="Visibility" Value="Collapsed"/></Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="{StaticResource Accent}"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource Accent}"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Radio buttons -->
    <Style TargetType="RadioButton">
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Grid Background="Transparent">
              <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/></Grid.ColumnDefinitions>
              <Border Name="Ring" Width="18" Height="18" CornerRadius="9" BorderThickness="1.5" BorderBrush="#9AA3AF" Background="White" VerticalAlignment="Center">
                <Ellipse Name="Dot" Width="8" Height="8" Fill="#185FA5" Visibility="Collapsed"/>
              </Border>
              <ContentPresenter Grid.Column="1" Margin="8,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Ring" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Ring" Property="BorderBrush" Value="{StaticResource Accent}"/>
                <Setter TargetName="Dot" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Combo boxes -->
    <Style TargetType="ComboBoxItem">
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border Name="Bd" Background="Transparent" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Bd" Property="Background" Value="{StaticResource Hover}"/></Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{StaticResource AccentSoft}"/>
                <Setter Property="Foreground" Value="{StaticResource Accent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Padding" Value="10,6,30,6"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid SnapsToDevicePixels="True">
              <ToggleButton Name="Toggle" Focusable="False" ClickMode="Press"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border Name="Bd" Background="White" BorderBrush="#D5DAE1" BorderThickness="1" CornerRadius="6">
                      <Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0" Data="M 0 0 L 4.5 4.5 L 9 0"
                            Stroke="#6B7280" StrokeThickness="1.6" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="#A9B2BE"/></Trigger>
                      <Trigger Property="IsChecked" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="#185FA5"/></Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter Name="ContentSite" IsHitTestVisible="False" Margin="{TemplateBinding Padding}"
                                Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                VerticalAlignment="{TemplateBinding VerticalContentAlignment}" HorizontalAlignment="Left"/>
              <Popup Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True"
                     Focusable="False" PopupAnimation="Fade" VerticalOffset="4">
                <Grid MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}" Margin="0,0,10,10">
                  <Border Background="White" CornerRadius="8">
                    <Border.Effect><DropShadowEffect BlurRadius="14" ShadowDepth="3" Direction="270" Opacity="0.16"/></Border.Effect>
                  </Border>
                  <Border Background="White" BorderBrush="#D5DAE1" BorderThickness="1" CornerRadius="8" Padding="4">
                    <ScrollViewer SnapsToDevicePixels="True">
                      <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                    </ScrollViewer>
                  </Border>
                </Grid>
              </Popup>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Lists -->
    <Style TargetType="ListBox">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="4"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBox">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
              <ScrollViewer Focusable="False"><ItemsPresenter/></ScrollViewer>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListBoxItem">
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="Margin" Value="0,1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border Name="Bd" Background="Transparent" CornerRadius="6" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Background" Value="{StaticResource Hover}"/></Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{StaticResource AccentSoft}"/>
                <Setter Property="Foreground" Value="{StaticResource Accent}"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListView">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
    </Style>
    <Style TargetType="GridViewColumnHeader">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="GridViewColumnHeader">
            <Border Background="#F7F8FA" BorderBrush="#E6E9EE" BorderThickness="0,0,0,1" Padding="8,7">
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListViewItem">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListViewItem">
            <Border Name="Bd" Background="Transparent" BorderBrush="#EEF0F3" BorderThickness="0,0,0,1" Padding="2,6" SnapsToDevicePixels="True">
              <GridViewRowPresenter Content="{TemplateBinding Content}" Columns="{TemplateBinding GridView.ColumnCollection}" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Background" Value="{StaticResource Hover}"/></Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{StaticResource AccentSoft}"/>
                <Setter Property="Foreground" Value="{StaticResource Accent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Table (components) -->
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="DataGridColumnHeader">
            <Border Background="#F7F8FA" BorderBrush="#E6E9EE" BorderThickness="0,0,0,1" Padding="8,7">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="DataGridCell">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="DataGridCell">
            <Border Background="{TemplateBinding Background}" Padding="8,0" SnapsToDevicePixels="True">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{StaticResource AccentSoft}"/>
          <Setter Property="Foreground" Value="{StaticResource Ink}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="DataGrid">
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="RowBackground" Value="White"/>
      <Setter Property="VerticalGridLinesBrush" Value="Transparent"/>
      <Style.Resources>
        <!-- When editing a cell: plain text box without rounding and margins -->
        <Style TargetType="TextBox">
          <Setter Property="Padding" Value="2,0"/>
          <Setter Property="Margin" Value="0"/>
          <Setter Property="BorderThickness" Value="0"/>
        </Style>
      </Style.Resources>
    </Style>

    <!-- Tabs: flat tabs with a blue line below the active tab -->
    <Style TargetType="TabControl">
      <Setter Property="Padding" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabControl">
            <DockPanel>
              <Border DockPanel.Dock="Top" BorderBrush="{StaticResource LineSoft}" BorderThickness="0,0,0,1" Margin="0,0,0,4">
                <TabPanel IsItemsHost="True" Background="Transparent"/>
              </Border>
              <ContentPresenter x:Name="PART_SelectedContentHost" ContentSource="SelectedContent" Margin="{TemplateBinding Padding}"/>
            </DockPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.6"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Padding" Value="14,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Grid Background="Transparent">
              <ContentPresenter Name="Hdr" ContentSource="Header" Margin="{TemplateBinding Padding}" RecognizesAccessKey="True"
                                HorizontalAlignment="Center" TextElement.Foreground="#6B7280"/>
              <Border Name="Bar" Height="3" VerticalAlignment="Bottom" CornerRadius="1.5" Margin="8,0,8,-1" Background="Transparent"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Hdr" Property="TextElement.Foreground" Value="#1F2937"/>
                <Setter TargetName="Bar" Property="Background" Value="#D5DAE1"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Hdr" Property="TextElement.Foreground" Value="#185FA5"/>
                <Setter TargetName="Hdr" Property="TextElement.FontWeight" Value="SemiBold"/>
                <Setter TargetName="Bar" Property="Background" Value="#185FA5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Narrow scrollbars -->
    <Style x:Key="ScrollPage" TargetType="RepeatButton">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="ScrollThumb" TargetType="Thumb">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Thumb">
            <Border Name="T" CornerRadius="4" Background="#C3C9D1" Margin="2"/>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="T" Property="Background" Value="#9AA3AF"/></Trigger>
              <Trigger Property="IsDragging" Value="True"><Setter TargetName="T" Property="Background" Value="#7D8693"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ScrollBar">
      <Setter Property="MinWidth" Value="0"/>
      <Setter Property="MinHeight" Value="0"/>
      <Setter Property="Width" Value="11"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent">
              <Track Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Style="{StaticResource ScrollPage}"/></Track.DecreaseRepeatButton>
                <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Style="{StaticResource ScrollPage}"/></Track.IncreaseRepeatButton>
                <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" MinHeight="24"/></Track.Thumb>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/>
          <Setter Property="Height" Value="11"/>
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="ScrollBar">
                <Grid Background="Transparent">
                  <Track Name="PART_Track" IsDirectionReversed="False">
                    <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageLeftCommand" Style="{StaticResource ScrollPage}"/></Track.DecreaseRepeatButton>
                    <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageRightCommand" Style="{StaticResource ScrollPage}"/></Track.IncreaseRepeatButton>
                    <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" MinWidth="24"/></Track.Thumb>
                  </Track>
                </Grid>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
'@

$xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AppUpdateKit Builder" Width="1120" Height="800" MinWidth="940" MinHeight="620"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="13" Background="#F4F6F9" Foreground="#1F2937"
        UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
<!--THEME-->
  </Window.Resources>

  <DockPanel>
    <!-- Header -->
    <Border DockPanel.Dock="Top" Background="#185FA5" Padding="20,14">
      <DockPanel>
        <Border DockPanel.Dock="Left" Width="42" Height="42" CornerRadius="10" Background="White" Margin="0,0,14,0">
          <Grid>
            <TextBlock Name="TxtHeaderGlyph" Text="&#xE895;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#185FA5"
                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
            <Image Name="ImgHeader" Width="28" Height="28" RenderOptions.BitmapScalingMode="HighQuality"/>
          </Grid>
        </Border>
        <StackPanel VerticalAlignment="Center">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="AppUpdateKit Builder" Foreground="White" FontSize="19" FontWeight="SemiBold"/>
            <TextBlock Name="TxtKitVersion" Foreground="#CFE0F3" FontSize="12.5" Margin="8,0,0,2" VerticalAlignment="Bottom"/>
          </StackPanel>
          <TextBlock Text="Fill in the details, preview the popup and build the Intune package." Foreground="#CFE0F3" FontSize="12.5" Margin="0,1,0,0"/>
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Bottom bar -->
    <Border DockPanel.Dock="Bottom" Background="White" BorderBrush="#E6E9EE" BorderThickness="0,1,0,0" Padding="20,12">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button Name="BtnSave" Content="Save"/>
          <Button Name="BtnOpenOutput" Content="Open package folder" IsEnabled="False"/>
          <Button Name="BtnBuild" Content="Build package (.intunewin)" Style="{StaticResource Primary}" Margin="0"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" Margin="0,0,16,0">
          <Button Name="BtnPrevTab" Content="‹  Previous" IsEnabled="False" ToolTip="Go to the previous tab"/>
          <Button Name="BtnNextTab" Content="Next  ›" IsEnabled="False" ToolTip="Go to the next tab" Margin="0"/>
        </StackPanel>
        <TextBlock Name="TxtStatus" VerticalAlignment="Center" Foreground="#6B7280" TextTrimming="CharacterEllipsis"/>
      </DockPanel>
    </Border>

    <!-- Apps -->
    <Border DockPanel.Dock="Left" Width="230" Background="White" BorderBrush="#E6E9EE" BorderThickness="0,0,1,0" Padding="14,16">
      <DockPanel>
        <TextBlock DockPanel.Dock="Top" Text="APPS" FontWeight="SemiBold" FontSize="11" Foreground="#6B7280" Margin="10,0,0,8"/>
        <Button DockPanel.Dock="Bottom" Name="BtnLanguage" Content="Language / Taal" Margin="0,6,0,0"
                ToolTip="Use the Builder in Dutch or in English"/>
        <Button DockPanel.Dock="Bottom" Name="BtnUpdateKit" Content="Update kit..." Margin="0,6,0,0"
                ToolTip="Get the latest version of AppUpdateKit from GitHub. Your apps, packages and settings are kept."/>
        <Button DockPanel.Dock="Bottom" Name="BtnInstallerFolder" Content="Default folder..." Margin="0,6,0,0"
                ToolTip="Folder where 'Browse...' opens by default when choosing an installer (_Kit\Settings.psd1)"/>
        <Button DockPanel.Dock="Bottom" Name="BtnNewApp" Content="+ New app" Margin="0,8,0,0" Style="{StaticResource Primary}"/>
        <ListBox Name="LstApps" BorderThickness="0" Padding="0"/>
      </DockPanel>
    </Border>

    <!-- Tabs -->
    <TabControl Name="Tabs" Margin="16,10,16,0" IsEnabled="False">

      <TabItem Header="1. Basics">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Installer"/>
                <DockPanel>
                  <Button DockPanel.Dock="Right" Name="BtnInstaller" Content="Browse..." Margin="8,2,0,8"/>
                  <TextBox Name="TxtInstaller" IsReadOnly="True" Background="#F7F8FA"/>
                </DockPanel>
                <TextBlock Name="TxtInstallerInfo" Style="{StaticResource Hint}" Text="Choose the installer (.exe or .msi). Name, version and silent switches are then filled in automatically."/>
                <Label Content="Save package to (required)"/>
                <DockPanel>
                  <Button DockPanel.Dock="Right" Name="BtnOutputFolder" Content="Browse..." Margin="8,2,0,8"/>
                  <TextBox Name="TxtOutputFolder"/>
                </DockPanel>
                <TextBlock Name="TxtOutputHint" Style="{StaticResource Hint}" Text="Click Browse... and choose the version folder, e.g. ...\versions\2.4.0. The Builder adds \intune-package. You can also type or paste the path."/>
              </StackPanel>
            </Border>

            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                  <Label Content="AppId (internal name, no spaces)"/>
                  <TextBox Name="TxtAppId" IsReadOnly="True" Background="#F7F8FA"/>
                  <Label Content="Name in the popup"/>
                  <TextBox Name="TxtAppName"/>
                  <Label Content="Version"/>
                  <TextBox Name="TxtVersion"/>
                  <TextBlock Style="{StaticResource Hint}" Text="The version this package installs; Intune detects on this."/>
                </StackPanel>
                <StackPanel Grid.Column="2">
                  <Label Content="Name in Apps &amp; features (starts with)"/>
                  <TextBox Name="TxtDetectName"/>
                  <Label Content="Processes that must be closed"/>
                  <TextBox Name="TxtProcesses"/>
                  <TextBlock Style="{StaticResource Hint}" Text="Without .exe, separated by commas. E.g.: notepad++   or   winword, excel. Empty = no process check (for apps without their own program, such as a runtime or driver)."/>
                  <CheckBox Name="ChkOnlyExisting" Content="Only update devices that already have the app" Margin="0,6,0,0"/>
                  <CheckBox Name="ChkDuringSetup" Content="Install on new laptops (Autopilot), without popup" Margin="0,6,0,0"/>
                  <TextBlock Style="{StaticResource Hint}" Margin="0,2,0,0" Text="During setup the app is installed right away, even if it isn't on the device yet. Off = the app only arrives after setup, with a popup."/>
                </StackPanel>
              </Grid>
            </Border>

            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Detection: how Intune sees that the app (in this version) is on the laptop"/>
                <ComboBox Name="CmbDetect" Width="420" HorizontalAlignment="Left" Margin="0,2,0,8" SelectedIndex="0">
                  <ComboBoxItem Tag="AppsAndFeatures" Content="Apps &amp; features (name and version, default)"/>
                  <ComboBoxItem Tag="File" Content="File (path and file version)"/>
                  <ComboBoxItem Tag="Registry" Content="Registry (key and value)"/>
                  <ComboBoxItem Tag="Script" Content="Own detection script"/>
                </ComboBox>
                <TextBlock Name="TxtDetectHint" Style="{StaticResource Hint}"/>
                <StackPanel Name="PnlDetectFile">
                  <Label Content="File"/>
                  <TextBox Name="TxtDetectFile"/>
                  <TextBlock Style="{StaticResource Hint}" Text="Full path; %ProgramFiles% and other environment variables are allowed. E.g. %ProgramFiles%\Remote help\RemoteHelp.exe"/>
                </StackPanel>
                <Grid Name="PnlDetectReg">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="2*"/><ColumnDefinition Width="16"/><ColumnDefinition/></Grid.ColumnDefinitions>
                  <StackPanel Grid.Column="0">
                    <Label Content="Registry key"/>
                    <TextBox Name="TxtDetectRegKey"/>
                    <TextBlock Style="{StaticResource Hint}" Text="E.g. HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{GUID} (copy the path from regedit)"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2">
                    <Label Content="Value"/>
                    <TextBox Name="TxtDetectRegValue"/>
                    <TextBlock Style="{StaticResource Hint}" Text="E.g. DisplayVersion or Version. Empty = only check whether the key exists."/>
                  </StackPanel>
                </Grid>
                <StackPanel Name="PnlDetectVersion" Orientation="Horizontal" Margin="0,2,0,0">
                  <Label Content="Minimum version" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <TextBox Name="TxtDetectVersion" Width="160" Margin="0,2,12,2"/>
                  <CheckBox Name="ChkDetectAnyVersion" Content="No version, only check whether it exists" VerticalAlignment="Center"/>
                </StackPanel>
                <TextBlock Name="TxtDetectVersionHint" Style="{StaticResource Hint}" Margin="0,2,0,8" Text="Empty = the version of this package (tab 1). Enter another version if the app registers itself with a different number."/>
                <StackPanel Name="PnlDetectScript">
                  <Label Content="Own detection script (PowerShell)"/>
                  <TextBox Name="TxtDetectScript" AcceptsReturn="True" AcceptsTab="True" FontFamily="Consolas" FontSize="12" Height="150"
                           VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                  <TextBlock Style="{StaticResource Hint}" Text="Write something to the output (Write-Output) if the app is present; writing nothing = not detected. End with exit 0."/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                  <Button Name="BtnDetectTest" Content="Test on this PC"/>
                  <TextBlock Name="TxtDetectResult" VerticalAlignment="Center" TextWrapping="Wrap" MaxWidth="760"/>
                </StackPanel>
              </StackPanel>
            </Border>

            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <Border Grid.Column="0" Width="72" Height="72" CornerRadius="10" Background="#F0F2F5" Margin="0,0,16,0" VerticalAlignment="Top">
                  <Image Name="ImgIcon" Width="52" Height="52" RenderOptions.BitmapScalingMode="HighQuality"/>
                </Border>
                <StackPanel Grid.Column="1">
                  <Label Content="Logo"/>
                  <StackPanel Orientation="Horizontal" Margin="0,2,0,6">
                    <Button Name="BtnIcon" Content="Choose logo..."/>
                    <Button Name="BtnIconFromInstaller" Content="Get from installer"/>
                  </StackPanel>
                  <TextBlock Style="{StaticResource Hint}" Text=".ico, .png or .jpg (gets converted). Preferably square and at least 256x256."/>
                </StackPanel>
                <StackPanel Grid.Column="3">
                  <Label Content="Colour of header and button"/>
                  <DockPanel>
                    <Border Name="RectAccent" DockPanel.Dock="Left" Width="30" Height="28" CornerRadius="5" Margin="0,2,8,8" Background="#185FA5"/>
                    <TextBox Name="TxtAccent" Text="#185FA5"/>
                  </DockPanel>
                  <TextBlock Style="{StaticResource Hint}" Text="Format #RRGGBB. Default #185FA5 (blue); empty = default. Another example: #3B7A1E (green)."/>
                </StackPanel>
              </Grid>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="2. Installation">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Components and files"/>
                <TextBlock Style="{StaticResource Hint}" Text="Everything that goes into the package. Components are installed in this order, each with its own parameters and the exit codes that count as success (double-click to change). If a component fails, the installation stops. The main component is the app itself (used for uninstalling). For a file that is copied, you change the target folder in the same column."/>
                <DataGrid Name="DgComponents" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False"
                          CanUserSortColumns="False" CanUserReorderColumns="False" HeadersVisibility="Column" SelectionMode="Single"
                          GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#E6E9EE" Height="230" Margin="0,4,0,10"
                          Background="White" BorderBrush="#D5DAE1" RowHeight="34">
                  <DataGrid.RowStyle>
                    <Style TargetType="DataGridRow">
                      <Style.Triggers>
                        <DataTrigger Binding="{Binding IsFile}" Value="True"><Setter Property="Foreground" Value="#4B5563"/></DataTrigger>
                      </Style.Triggers>
                    </Style>
                  </DataGrid.RowStyle>
                  <DataGrid.Columns>
                    <DataGridCheckBoxColumn Header="Main" Width="62" Binding="{Binding Main, UpdateSourceTrigger=PropertyChanged}">
                      <DataGridCheckBoxColumn.ElementStyle>
                        <Style TargetType="CheckBox" BasedOn="{x:Static DataGridCheckBoxColumn.DefaultElementStyle}">
                          <Setter Property="HorizontalAlignment" Value="Left"/>
                          <Setter Property="Margin" Value="2,0,0,0"/>
                          <Style.Triggers><DataTrigger Binding="{Binding IsFile}" Value="True"><Setter Property="Visibility" Value="Hidden"/></DataTrigger></Style.Triggers>
                        </Style>
                      </DataGridCheckBoxColumn.ElementStyle>
                      <DataGridCheckBoxColumn.EditingElementStyle>
                        <Style TargetType="CheckBox" BasedOn="{x:Static DataGridCheckBoxColumn.DefaultEditingElementStyle}">
                          <Setter Property="HorizontalAlignment" Value="Left"/>
                          <Setter Property="Margin" Value="2,0,0,0"/>
                        </Style>
                      </DataGridCheckBoxColumn.EditingElementStyle>
                    </DataGridCheckBoxColumn>
                    <DataGridTextColumn Header="File" Width="2*" IsReadOnly="True" Binding="{Binding File}"/>
                    <DataGridTextColumn Header="Type" Width="58" IsReadOnly="True" Binding="{Binding Kind}"/>
                    <DataGridTextColumn Header="What" Width="118" IsReadOnly="True" Binding="{Binding Action}"/>
                    <DataGridTextColumn Header="Parameters / target folder" Width="2*" FontFamily="Consolas" Binding="{Binding Args, UpdateSourceTrigger=PropertyChanged}"/>
                    <DataGridTextColumn Header="Success exit codes" Width="150" FontFamily="Consolas" Binding="{Binding Codes, UpdateSourceTrigger=PropertyChanged}"/>
                  </DataGrid.Columns>
                </DataGrid>
                <WrapPanel>
                  <Button Name="BtnCompAdd" Content="Add..." Margin="0,0,8,6" Style="{StaticResource Primary}"/>
                  <Button Name="BtnCompRemove" Content="Remove" Margin="0,0,8,6"/>
                  <Button Name="BtnCompUp" Content="Up" Margin="0,0,8,6"/>
                  <Button Name="BtnCompDown" Content="Down" Margin="0,0,8,6"/>
                  <Button Name="BtnOpenAppFolder" Content="Open folder" Margin="0,0,8,6"/>
                  <Button Name="BtnAdmx" Content="Settings from ADMX..." Margin="0,0,8,6"
                          ToolTip="Optional: choose policy settings of the app (e.g. turn off automatic updates) from an ADMX. They go into the package as a registry file and are cleaned up on uninstall. Already chose settings? Edit them here, or double-click the registry file in the table."/>
                </WrapPanel>
                <TextBlock Name="TxtCompInfo" Style="{StaticResource Hint}" Margin="0,2,0,0" Text="Add: choose per file whether it is installed (component), copied to a folder on the laptop, or only included. Installing works for .exe, .msi, .msp, .ps1, .cmd/.bat and .reg; silent switches are suggested."/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="16"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <StackPanel Grid.Column="0">
                  <Label Content="Extra steps before the components"/>
                  <TextBox Name="TxtPreInstall" AcceptsReturn="True" FontFamily="Consolas" FontSize="12" Height="80"
                           VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                </StackPanel>
                <StackPanel Grid.Column="2">
                  <Label Content="Extra steps after the components"/>
                  <TextBox Name="TxtPostInstall" AcceptsReturn="True" FontFamily="Consolas" FontSize="12" Height="80"
                           VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                </StackPanel>
                <TextBlock Grid.Row="1" Grid.ColumnSpan="3" Style="{StaticResource Hint}" Margin="0,8,0,0"
                           Text="Using parameters from Intune: install.cmd /noshortcuts creates APP_NOSHORTCUTS. To skip a step: 'if defined APP_NOSHORTCUTS goto after_shortcuts', with ':after_shortcuts' after that step. Built in are /noprocesscheck, /noconsent and /silent."/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <DockPanel>
                  <CheckBox DockPanel.Dock="Left" Name="ChkAutoSteps" VerticalAlignment="Center" Margin="0,0,10,0"
                            Content="Create installation steps automatically from the components"/>
                  <TextBlock/>
                </DockPanel>
                <Label Content="Installation steps (install-app.cmd)"/>
                <TextBlock Style="{StaticResource Hint}" Text="Runs as SYSTEM from the package folder. With automatic creation on, you see the result here; turn it off to write everything by hand."/>
                <TextBox Name="TxtInstallCmd" AcceptsReturn="True" AcceptsTab="True" FontFamily="Consolas" FontSize="12"
                         Height="210" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                <DockPanel>
                  <Button DockPanel.Dock="Right" Name="BtnGenerate" Content="Recreate uninstall steps" Margin="8,6,0,0"/>
                  <Label Content="Uninstall steps (uninstall-app.cmd)"/>
                </DockPanel>
                <TextBlock Style="{StaticResource Hint}" Text="Runs as SYSTEM from the package folder. If uninstalling via the setup.exe doesn't work, use: powershell.exe -NoProfile -ExecutionPolicy Bypass -File &quot;Remove-App.ps1&quot; -Name &quot;name in Apps &amp; features&quot;"/>
                <TextBox Name="TxtUninstallCmd" AcceptsReturn="True" AcceptsTab="True" FontFamily="Consolas" FontSize="12"
                         Height="210" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="3. Texts">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock TextWrapping="Wrap" Margin="0,0,0,4">Texts for this app and version. Leave a field empty for the default text (grey underneath). If the app isn't on the laptop yet, the "New installation" texts apply (at the bottom). You can use {AppName}, {Version} (version), {Minutes} (minutes) and {MaxPostpones} (max postpones); they are filled in automatically.</TextBlock>
                <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                  <TextBlock Text="Language on the laptop" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,10,0"/>
                  <ComboBox Name="CmbTextLang" Width="170" SelectedIndex="0">
                    <ComboBoxItem Tag="nl" Content="Nederlands"/>
                    <ComboBoxItem Tag="en" Content="English"/>
                  </ComboBox>
                </StackPanel>
                <TextBlock Style="{StaticResource Hint}" TextWrapping="Wrap" Text="Language of the popups, the buttons and the default texts on the laptop, and of the scripts in the package. Separate from the Builder language."/>
                <Button Name="BtnStdTexts" Content="Edit default texts for all apps..." HorizontalAlignment="Left" Margin="0,6,0,0"/>
                <CheckBox Name="ChkPrevNew" Content="Show previews as a new installation (the app isn't on the laptop yet)" Margin="0,10,0,0"/>
                <WrapPanel Margin="0,8,0,0">
                  <Button Name="BtnPrevConsent" Content="Preview: Update available" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevLast" Content="Preview: last time" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevForced" Content="Preview: warning" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevInstalling" Content="Preview: installing" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevSuccess" Content="Preview: succeeded" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevError" Content="Preview: failed" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevRestart" Content="Preview: restart" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevRestartForced" Content="Preview: forced restart" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevUninstalling" Content="Preview: removing" Margin="0,0,8,6"/>
                  <Button Name="BtnPrevUninstalled" Content="Preview: removed" Margin="0,0,8,6"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel Name="PnlTexts"/>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="4. Postpone">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                  <Label Content="How often may the user postpone?"/>
                  <TextBox Name="TxtMaxPostpones"/>
                  <Label Content="How long does one postpone last? (hours)"/>
                  <TextBox Name="TxtPostponeHours"/>
                </StackPanel>
                <StackPanel Grid.Column="2">
                  <Label Content="Warning after the last time (minutes)"/>
                  <TextBox Name="TxtForcedMinutes"/>
                  <TextBlock Style="{StaticResource Hint}" Text="0 = install right away, without warning."/>
                  <Label Content="No choice made: close window after (minutes)"/>
                  <TextBox Name="TxtConsentTimeout"/>
                  <TextBlock Style="{StaticResource Hint}" Text="It is asked again later; this doesn't count as postponing."/>
                </StackPanel>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="When may the update come?" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <Label Content="Time window"/>
                <ComboBox Name="CmbWindow" Width="340" HorizontalAlignment="Left" Margin="0,2,0,6" SelectedIndex="0">
                  <ComboBoxItem Tag="Always" Content="Always"/>
                  <ComboBoxItem Tag="DuringWorkHours" Content="Only within the chosen times"/>
                  <ComboBoxItem Tag="OutsideWorkHours" Content="Only outside the chosen times (e.g. evening, night, weekend)"/>
                </ComboBox>
                <StackPanel Name="PnlWorkTime" Margin="0,0,0,4">
                  <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                    <Label Content="Times" VerticalAlignment="Center"/>
                    <Border Name="InfoTimes" Width="18" Height="18" CornerRadius="9" Background="#185FA5" Margin="8,4,0,0"
                            VerticalAlignment="Center" Cursor="Hand" ToolTipService.ShowDuration="60000" ToolTipService.InitialShowDelay="100">
                      <TextBlock Text="i" Foreground="White" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,-1,0,0"/>
                      <Border.ToolTip>
                        <ToolTip MaxWidth="380">
                          <StackPanel Margin="4">
                            <TextBlock FontWeight="SemiBold" Text="Entering multiple time blocks" Margin="0,0,0,6"/>
                            <TextBlock TextWrapping="Wrap" Text="Write each block as from-to and separate the blocks with a comma."/>
                            <TextBlock TextWrapping="Wrap" Margin="0,8,0,2" FontWeight="SemiBold" Text="Examples"/>
                            <TextBlock FontFamily="Consolas" Text="08:00-17:00"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#555" Margin="0,0,0,4" Text="one block: the whole working day"/>
                            <TextBlock FontFamily="Consolas" Text="08:00-09:00, 12:00-13:00, 16:00-17:00"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#555" Margin="0,0,0,4" Text="three blocks: at sign-in, during the break and at shutdown"/>
                            <TextBlock FontFamily="Consolas" Text="22:00-06:00"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#555" Margin="0,0,0,4" Text="across midnight: evening and night"/>
                            <TextBlock TextWrapping="Wrap" Margin="0,6,0,0" Text="Use 24-hour times with a colon (08:00, not 8.00). The end time doesn't count: with 08:00-09:00 the popup can still come at 08:59, but not at 09:00. Click the icon for more information."/>
                          </StackPanel>
                        </ToolTip>
                      </Border.ToolTip>
                    </Border>
                  </StackPanel>
                  <TextBox Name="TxtWorkHours" Width="340" HorizontalAlignment="Left"/>
                  <TextBlock Style="{StaticResource Hint}" Margin="0,-4,0,0" Text="One or more blocks, separated by commas. E.g. 08:00-17:00, or 09:00-10:00, 13:00-14:00. Across midnight is allowed too: 22:00-06:00."/>
                  <WrapPanel Name="PnlWorkDays" Margin="0,8,0,4">
                    <CheckBox Name="ChkDayMa" Content="Mon" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayDi" Content="Tue" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayWo" Content="Wed" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayDo" Content="Thu" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayVr" Content="Fri" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayZa" Content="Sat" Margin="0,0,12,0"/>
                    <CheckBox Name="ChkDayZo" Content="Sun" Margin="0,0,12,0"/>
                  </WrapPanel>
                </StackPanel>
                <TextBlock Name="TxtWindowHint" Style="{StaticResource Hint}" Margin="0,2,0,10"/>

                <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                  <CheckBox Name="ChkIdle" Content="Install right away, without popup, if the user does nothing for" VerticalAlignment="Center"/>
                  <TextBox Name="TxtIdleMinutes" Width="48" Margin="6,0,6,0"/>
                  <TextBlock Text="minutes or the screen is locked" VerticalAlignment="Center"/>
                </StackPanel>
                <TextBlock Style="{StaticResource Hint}" Margin="0,4,0,10" Text="Useful for apps you prefer to install when someone is away, for example during lunch. The app does have to be closed; if it's open, the installation simply waits."/>

                <Label Content="Nobody signed in"/>
                <ComboBox Name="CmbNoUser" Width="340" HorizontalAlignment="Left" Margin="0,2,0,6" SelectedIndex="0">
                  <ComboBoxItem Tag="Install" Content="Install right away (also outside the time window)"/>
                  <ComboBoxItem Tag="Wait" Content="Wait until someone signs in"/>
                </ComboBox>
                <TextBlock Style="{StaticResource Hint}" Text="Installing right away is also needed for new laptops via Autopilot: nobody is signed in yet then."/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="Restart after the installation" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <Label Content="Show restart prompt"/>
                <ComboBox Name="CmbRestart" Width="340" HorizontalAlignment="Left" Margin="0,2,0,6" SelectedIndex="0">
                  <ComboBoxItem Tag="Never" Content="Never"/>
                  <ComboBoxItem Tag="IfNeeded" Content="Only when the installer asks for it (3010/1641)"/>
                  <ComboBoxItem Tag="Always" Content="Always after the installation"/>
                </ComboBox>
                <Grid Name="PnlRestart" Margin="0,4,0,0">
                  <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                  <StackPanel Grid.Column="0">
                    <Label Content="Later: ask again after (min)"/>
                    <TextBox Name="TxtRestartReminder"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2">
                    <Label Content="Forced restart after (hours)"/>
                    <TextBox Name="TxtRestartDeadline"/>
                    <TextBlock Style="{StaticResource Hint}" Margin="0,2,0,0" Text="0 = never forced."/>
                  </StackPanel>
                  <StackPanel Grid.Column="4">
                    <Label Content="Warning in advance (min)"/>
                    <TextBox Name="TxtRestartWarning"/>
                  </StackPanel>
                </Grid>
                <TextBlock Style="{StaticResource Hint}" Margin="0,8,0,0" Text="After a successful installation the user gets a window with Restart now and Later. After the deadline a warning with a countdown follows and the laptop restarts. If nobody is signed in, the laptop restarts right away. Intune then gets exit code 0, so there's no second restart prompt. During Autopilot the setup page handles the restart."/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="Remove" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <CheckBox Name="ChkUninstallNotify" Content="Show notifications when the app is removed via Intune"/>
                <TextBlock Style="{StaticResource Hint}" Margin="0,4,0,0" Text="Bottom right: '... is being removed' with a progress bar, then '... has been removed' (green) or 'Removal failed' (red). You change the texts in tab 3."/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Name="TabVersions" Header="5. Versions">
        <Grid Margin="12">
          <Grid.ColumnDefinitions><ColumnDefinition Width="330"/><ColumnDefinition Width="12"/><ColumnDefinition/></Grid.ColumnDefinitions>

          <DockPanel Grid.Column="0">
            <TextBlock DockPanel.Dock="Top" Style="{StaticResource Hint}" Margin="0,0,0,8" Text="All builds are kept, including earlier builds of the same version (replaced). Click a build to see how it was made; with Make a copy and edit you continue from it."/>
            <WrapPanel DockPanel.Dock="Bottom" Margin="0,8,0,0">
              <Button Name="BtnVerOpen" Content="Open folder" Margin="0,0,6,6"/>
              <Button Name="BtnVerRestore" Content="Make a copy and edit" Margin="0,0,6,6" FontWeight="SemiBold"/>
              <Button Name="BtnVerDelete" Content="Remove" Margin="0,0,6,6"/>
            </WrapPanel>
            <ListView Name="LstVersions">
              <ListView.View>
                <GridView>
                  <GridViewColumn Header="Version" Width="125" DisplayMemberBinding="{Binding Label}"/>
                  <GridViewColumn Header="Built" Width="110" DisplayMemberBinding="{Binding BuiltText}"/>
                  <GridViewColumn Header="Package" Width="75" DisplayMemberBinding="{Binding PkgText}"/>
                </GridView>
              </ListView.View>
            </ListView>
          </DockPanel>

          <DockPanel Grid.Column="2" Name="PnlVerDetails" IsEnabled="False">
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}">
              <DockPanel>
                <Border DockPanel.Dock="Left" Width="56" Height="56" CornerRadius="10" Background="#F0F2F5" Margin="0,0,14,0">
                  <Image Name="ImgVerIcon" Width="40" Height="40" RenderOptions.BitmapScalingMode="HighQuality"/>
                </Border>
                <StackPanel>
                  <TextBlock Name="TxtVerTitle" FontSize="15" FontWeight="SemiBold" Text="Choose a version on the left"/>
                  <TextBlock Name="TxtVerSub" Style="{StaticResource Hint}" Margin="0,2,0,8"/>
                  <StackPanel Orientation="Horizontal">
                    <ComboBox Name="CmbVerPreview" Width="190" Margin="0,0,8,0" SelectedIndex="0" VerticalAlignment="Center">
                      <ComboBoxItem Tag="consent" Content="Update available"/>
                      <ComboBoxItem Tag="last" Content="Last postpone"/>
                      <ComboBoxItem Tag="forced" Content="Warning"/>
                      <ComboBoxItem Tag="installing" Content="Installing"/>
                      <ComboBoxItem Tag="success" Content="Succeeded"/>
                      <ComboBoxItem Tag="error" Content="Failed"/>
                      <ComboBoxItem Tag="restart" Content="Restart"/>
                      <ComboBoxItem Tag="restartforced" Content="Forced restart"/>
                      <ComboBoxItem Tag="uninstalling" Content="Remove"/>
                      <ComboBoxItem Tag="uninstalled" Content="Removed"/>
                    </ComboBox>
                    <Button Name="BtnVerPreview" Content="Preview of this version" VerticalAlignment="Center"/>
                  </StackPanel>
                </StackPanel>
              </DockPanel>
            </Border>
            <TabControl>
              <TabItem Header="Overview">
                <TextBox Name="TxtVerSummary" IsReadOnly="True" FontFamily="Consolas" FontSize="12" Margin="0" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
              <TabItem Header="Installation steps">
                <TextBox Name="TxtVerInstall" IsReadOnly="True" FontFamily="Consolas" FontSize="12" Margin="0" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
              <TabItem Header="Texts">
                <TextBox Name="TxtVerTexts" IsReadOnly="True" FontSize="12.5" Margin="0" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
              <TabItem Header="Build info">
                <TextBox Name="TxtVerBuildInfo" IsReadOnly="True" FontFamily="Consolas" FontSize="11.5" Margin="0" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" BorderThickness="0"/>
              </TabItem>
            </TabControl>
          </DockPanel>
        </Grid>
      </TabItem>

      <TabItem Name="TabLog" Header="Result">
        <TextBox Name="TxtLog" Margin="12" Padding="12,10" BorderThickness="0" IsReadOnly="True" FontFamily="Consolas" FontSize="12" Background="#1E2430" Foreground="#E6E6E6"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
      </TabItem>
    </TabControl>
  </DockPanel>
</Window>
'@
[xml]$xaml = $xamlText.Replace('<!--THEME-->', $ThemeXaml)

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
if (Test-Path -LiteralPath $BuilderIcon) { $img = Get-BuilderIconImage; if ($img) { $Window.Icon = $img; Write-StartLog "Venstericoon   : ingesteld ($($img.PixelWidth)x$($img.PixelHeight))" } else { Write-StartLog 'Window icon    : ERROR, icon could not be read' } }
else { Write-StartLog "Window icon    : ERROR, $BuilderIcon not found" }
# Header: largest size from the .ico (sharp), otherwise the symbol stays
try
{
    $icoStream = New-Object System.IO.MemoryStream (, [System.IO.File]::ReadAllBytes($BuilderIcon))
    $icoFrames = [System.Windows.Media.Imaging.BitmapDecoder]::Create($icoStream, [System.Windows.Media.Imaging.BitmapCreateOptions]::None, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad).Frames
    $icoBig = $icoFrames | Sort-Object { $_.PixelWidth } -Descending | Select-Object -First 1
    if ($icoBig) { $Window.FindName('ImgHeader').Source = $icoBig; $Window.FindName('TxtHeaderGlyph').Visibility = 'Collapsed' }
}
catch { }

function Update-BuilderShortcut
{
    # Shortcut "AppUpdateKit Builder" in the kit folder (updated at every start).
    # The icon points to a local copy (%ProgramData% or %LOCALAPPDATA%): Explorer often leaves an icon on a
    # network drive in a shortcut empty. The variable is filled in on every PC and for every account.
    $lnk    = Join-Path $KitRoot 'AppUpdateKit Builder.lnk'
    $target = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnkArgs = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $KitRoot 'AppUpdateKit-Builder.ps1')`""
    $icon   = if ($script:SharedIcon) { $script:SharedIcon } else { '%LOCALAPPDATA%\AppUpdateKit\Builder.ico' }
    try
    {
        if (-not ('AppKit.AumidShortcut' -as [type])) { throw 'helper code not loaded' }
        [AppKit.AumidShortcut]::Save($lnk, $target, $lnkArgs, $KitRoot, $icon, 'AppUpdateKit.Builder', 'AppUpdateKit Builder')
        Write-StartLog "Snelkoppeling  : $lnk (icoon $icon)"
    }
    catch
    {
        try
        {
            $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            $s.TargetPath = $target; $s.Arguments = $lnkArgs; $s.WorkingDirectory = $KitRoot
            $s.IconLocation = "$BuilderIcon,0"; $s.WindowStyle = 7; $s.Description = 'AppUpdateKit Builder'
            $s.Save()
            Write-StartLog "Snelkoppeling  : $lnk (reserve, icoon $BuilderIcon)"
        }
        catch { Write-StartLog "ERROR with the shortcut in the kit folder: $($_.Exception.Message)" }
    }
}
$ui = @{}
$xaml.SelectNodes('//*[@Name]') | ForEach-Object { $ui[$_.Name] = $Window.FindName($_.Name) }

$script:CurrentApp = $null     # AppId of the loaded app
$script:Info = @{ Kind = 'EXE'; ProductCode = '' }
$script:Components = New-Object 'System.Collections.ObjectModel.ObservableCollection[AppKit.Component]'
# The table shows the components and the other files in the app folder (Update-FileList)
$script:Rows = New-Object 'System.Collections.ObjectModel.ObservableCollection[AppKit.Component]'
$ui.DgComponents.ItemsSource = $script:Rows
$script:TextBoxes = @{}
$script:TextHints = @{}

function Set-Status([string]$Text) { $ui.TxtStatus.Text = $Text }
function Show-Error([string]$Text) { [void][System.Windows.MessageBox]::Show($Text, 'AppUpdateKit Builder', 'OK', 'Warning') }
function Show-Info([string]$Text) { [void][System.Windows.MessageBox]::Show($Text, 'AppUpdateKit Builder', 'OK', 'Information') }

$script:ErrorLog = Join-Path $KitRoot 'Builder-errors.log'
function Write-BuilderError($ErrorRecord)
{
    # Show and log an error, instead of the Builder closing without a message
    if ($ErrorRecord -is [System.Management.Automation.RuntimeException] -and $ErrorRecord.ErrorRecord) { $ErrorRecord = $ErrorRecord.ErrorRecord }
    $msg = if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
        "$($ErrorRecord.Exception.Message)`r`n$($ErrorRecord.InvocationInfo.PositionMessage)`r`n$($ErrorRecord.ScriptStackTrace)"
    } else { "$ErrorRecord" }
    try { Add-Content -Path $script:ErrorLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n$msg`r`n" -ErrorAction Stop }
    catch { $script:ErrorLog = Join-Path ([System.IO.Path]::GetTempPath()) 'AppUpdateKit-Builder-errors.log'; Add-Content -Path $script:ErrorLog -Value $msg -ErrorAction SilentlyContinue }
    $first = ($msg -split "`r?`n")[0]
    Show-Error "Something went wrong:`n`n$first`n`nThe details are in:`n$($script:ErrorLog)"
    Set-Status "Error: $first"
}

# Safety net: every unexpected error in a button or timer gives a message instead of closing
$Window.Dispatcher.Add_UnhandledException({
    param($s, $e)
    $e.Handled = $true
    Write-BuilderError $e.Exception
})
function Get-AppFolder { if ($script:CurrentApp) { Join-Path $AppsRoot $script:CurrentApp } }

function Get-OutputRoot
{
    # Where the package of this version comes from: the folder at 'Save package to', otherwise Output\<AppId>\<version> in the kit
    $o = $ui.TxtOutputFolder.Text.Trim()
    $kitOut = Join-Path $KitRoot 'Output'
    $kitVersion = Join-Path (Join-Path $kitOut $script:CurrentApp) $ui.TxtVersion.Text.Trim()
    if (-not $o) { return $kitVersion }
    $p = [Environment]::ExpandEnvironmentVariables($o).TrimEnd('\')
    # In the kit's Output folder: normal layout Output\<AppId>\<version> (same rule as Build-Package.ps1)
    try
    {
        $full = [System.IO.Path]::GetFullPath($p).TrimEnd('\'); $outFull = [System.IO.Path]::GetFullPath($kitOut).TrimEnd('\')
        if ($full -eq $outFull -or $full.StartsWith($outFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $kitVersion }
    }
    catch { }
    return $p
}

function Set-StartFolder($Dialog, [switch]$NewInstaller)
{
    # Open the file dialog in the folder of the current installer, otherwise in the default folder (_Kit\Settings.psd1).
    # For a new installer (an update) in the 'versions' folder, so all versions are next to each other.
    $candidates = @()
    $o = $ui.TxtOutputFolder.Text.Trim()
    if ($o)
    {
        $versionDir = Split-Path $o -Parent
        $versionsDir = Split-Path $versionDir -Parent
        if ($NewInstaller -and $versionsDir -and (Split-Path $versionsDir -Leaf) -ieq 'versies') { $candidates += $versionsDir }
        $candidates += (Join-Path $versionDir 'source')   # that's usually where the installers are
        $candidates += $versionDir
    }
    if ($KitSettings.InstallerFolder) { $candidates += $KitSettings.InstallerFolder }
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { $Dialog.InitialDirectory = $c; return } }
}

# Build the text fields
foreach ($k in $TextKeys)
{
    $lbl = New-Object System.Windows.Controls.Label
    $lbl.Content = $TextLabels[$k]
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.TextWrapping = 'Wrap'
    if ($k -like '*Message' -or $k -eq 'ForcedInfo') { $tb.AcceptsReturn = $false; $tb.MinHeight = 48 }
    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Style = $Window.FindResource('Hint')
    [void]$ui.PnlTexts.Children.Add($lbl)
    [void]$ui.PnlTexts.Children.Add($tb)
    [void]$ui.PnlTexts.Children.Add($hint)
    $script:TextBoxes[$k] = $tb
    $script:TextHints[$k] = $hint
}

function Update-TextHints
{
    $std = Get-DefaultTexts
    foreach ($k in $TextKeys) { $script:TextHints[$k].Text = "Default: $($std[$k])" }
}
Update-TextHints

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
    $ui.TxtInstallCmd.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($(if ($auto) { '#F7F8FA' } else { '#FFFFFF' }))
    if ($auto)
    {
        $ui.TxtInstallCmd.Text = New-InstallCmdFromComponents $ui.TxtAppName.Text (Get-ComponentList) $ui.TxtPreInstall.Text $ui.TxtPostInstall.Text
    }
    # Update the uninstall steps with the components and copy steps. Don't let an error in here disappear silently.
    try { Sync-UninstallCleanup } catch { Write-BuilderError $_ }
}

function Confirm-AutoSteps
{
    # Components changed while the installation steps were written by hand: then install-app.cmd doesn't change along
    if ($ui.ChkAutoSteps.IsChecked) { return }
    $q = "The installation steps are now written by hand ('Create installation steps automatically from the components' is off), so install-app.cmd doesn't change along with the components.`n`nTurn on automatic creation? Your own text is then replaced by the steps from the components."
    if ([System.Windows.MessageBox]::Show($q, 'Installatiestappen', 'YesNo', 'Question') -eq 'Yes')
    {
        $ui.ChkAutoSteps.IsChecked = $true
        Update-InstallPreview
    }
}

function Add-ComponentFile([string]$Source, [bool]$AsMain = $false)
{
    # Copies the file to the app folder and adds it as a component; returns the info
    $dir = Get-AppFolder
    $name = [System.IO.Path]::GetFileName($Source)
    $dest = Join-Path $dir $name
    if ([System.IO.Path]::GetFullPath($Source) -ine [System.IO.Path]::GetFullPath($dest)) { Set-Status "Copying $name..."; Copy-Item -LiteralPath $Source -Destination $dest -Force }
    $info = Get-ComponentInfo $dest
    $existing = $script:Components | Where-Object { $_.File -eq $name } | Select-Object -First 1
    if ($existing)
    {
        # Different type (e.g. first .exe, now .msi with the same name)? Then the old parameters no longer apply.
        if ("$($existing.Kind)" -ne "$($info.Kind)") { $existing.Args = "$($info.Args)"; $existing.Codes = "$($info.Codes)" }
        $existing.Kind = $info.Kind; $existing.ProductCode = $info.ProductCode
    }
    else
    {
        if ($AsMain) { foreach ($c in $script:Components) { $c.Main = $false } }
        $info.Main = $AsMain -or ($script:Components.Count -eq 0)
        $script:Components.Add((New-ComponentRow $info))
    }
    $ui.DgComponents.Items.Refresh()
    return $info
}

function Get-FileUse([string]$Name)
{
    # What the installation does with a file from the app folder (for the list "Files in the package")
    if (@($script:Components | ForEach-Object { $_.File }) -contains $Name) { return 'component (tab 2)' }
    $steps = "$($ui.TxtPreInstall.Text)`n$($ui.TxtPostInstall.Text)"
    $m = [regex]::Match($steps, 'copy /Y "' + [regex]::Escape($Name) + '" "([^"]+)"', 'IgnoreCase')
    if ($m.Success) { return "copy to $($m.Groups[1].Value.TrimEnd('\'))" }
    if ($steps -match [regex]::Escape($Name)) { return 'used in extra steps' }
    if ($Name -in @('app.ico', 'logo.svg')) { return 'logo' }
    return 'not used in a step yet'
}

function Update-FileList
{
    # One table: first the components (in installation order), then the other files from the app folder
    try { [void]$ui.DgComponents.CommitEdit('Row', $true) } catch { }
    $selName = if ($ui.DgComponents.SelectedItem) { $ui.DgComponents.SelectedItem.File } else { $null }
    $script:Rows.Clear()
    $n = 0
    foreach ($c in $script:Components) { $n++; $c.IsFile = $false; $c.Action = "Install ($n)"; $script:Rows.Add($c) }
    $dir = Get-AppFolder
    if ($dir -and (Test-Path -LiteralPath $dir))
    {
        $skip = @('app.psd1', 'install-app.cmd', 'uninstall-app.cmd') + @($script:Components | ForEach-Object { $_.File })
        Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -notin $skip } | Sort-Object Name | ForEach-Object {
            $use = Get-FileUse $_.Name
            $r = New-Object AppKit.Component
            $r.IsFile = $true; $r.File = $_.Name; $r.Kind = $_.Extension.TrimStart('.').ToUpper(); $r.Codes = ''; $r.Args = ''
            if ($use -like 'copy to *')                { $r.Action = 'Copy'; $r.Args = ($use -replace '^\S+ to ', '') }
            elseif ($use -eq 'used in extra steps') { $r.Action = 'Extra step' }
            elseif ($use -eq 'logo')                      { $r.Action = 'Logo' }
            else                                          { $r.Action = 'Include only' }
            $script:Rows.Add($r)
        }
    }
    if ($selName) { $ui.DgComponents.SelectedItem = $script:Rows | Where-Object { $_.File -eq $selName } | Select-Object -First 1 }
}

#region Read ADMX and convert to registry settings
# An ADMX describes policy settings of an app; every setting is in the end one or more registry values
# (usually under HKLM\Software\Policies\...). The Builder reads the ADMX and the ADML (the texts), lets you choose
# and makes a .reg file of it that is installed as a component and cleaned up again on uninstall.

function Find-AdmlFile([string]$AdmxPath)
{
    # The ADML belongs in a language folder next to the ADMX (nl-NL, en-US, ...) or next to it with the same name
    $dir = Split-Path $AdmxPath -Parent; $base = [System.IO.Path]::GetFileNameWithoutExtension($AdmxPath)
    $cands = @()
    foreach ($lang in @([System.Globalization.CultureInfo]::CurrentUICulture.Name, 'nl-NL', 'en-US'))
    {
        $cands += (Join-Path (Join-Path $dir $lang) "$base.adml")
    }
    $cands += (Join-Path $dir "$base.adml")
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    $any = Get-ChildItem -LiteralPath $dir -Recurse -Filter "$base.adml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($any) { return $any.FullName }
    return $null
}

function Read-AdmxValue($Node)
{
    # <decimal value="1"/>, <longDecimal value=".."/>, <string>..</string>, <delete/>  ->  @{ Type; Data }
    if (-not $Node) { return $null }
    $c = $Node.SelectSingleNode('*')
    if (-not $c) { return $null }
    switch ($c.LocalName)
    {
        'decimal'     { return @{ Type = 'DWORD'; Data = [uint32]$c.GetAttribute('value') } }
        'longDecimal' { return @{ Type = 'QWORD'; Data = [uint64]$c.GetAttribute('value') } }
        'string'      { return @{ Type = 'SZ'; Data = $c.InnerText } }
        'delete'      { return @{ Type = 'DELETE'; Data = $null } }
    }
    return $null
}

function Read-AdmxValueList($Node, [string]$DefaultKey)
{
    # <enabledList defaultKey=".."><item key=".." valueName=".."><value>..</value></item></enabledList>
    $out = @()
    if (-not $Node) { return ,$out }
    $dk = $Node.GetAttribute('defaultKey'); if (-not $dk) { $dk = $DefaultKey }
    foreach ($it in @($Node.SelectNodes("*[local-name()='item']")))
    {
        $k = $it.GetAttribute('key'); if (-not $k) { $k = $dk }
        $v = Read-AdmxValue ($it.SelectSingleNode("*[local-name()='value']"))
        if ($v) { $out += @{ Key = $k; ValueName = $it.GetAttribute('valueName'); Value = $v } }
    }
    return ,$out
}

function Read-Admx([string]$AdmxPath)
{
    # Returns @{ Name; AdmlPath; Policies = @(...) }. Only the parts the kit needs.
    [xml]$admx = [System.IO.File]::ReadAllText($AdmxPath)
    $admlPath = Find-AdmlFile $AdmxPath
    $strings = @{}; $pres = @{}
    if ($admlPath)
    {
        [xml]$adml = [System.IO.File]::ReadAllText($admlPath)
        foreach ($s in @($adml.SelectNodes("//*[local-name()='stringTable']/*[local-name()='string']"))) { $strings[$s.GetAttribute('id')] = $s.InnerText }
        foreach ($p in @($adml.SelectNodes("//*[local-name()='presentationTable']/*[local-name()='presentation']")))
        {
            $labels = @{}
            foreach ($e in @($p.ChildNodes | Where-Object { $_.NodeType -eq 'Element' }))
            {
                $rid = $e.GetAttribute('refId'); if (-not $rid) { continue }
                $lbl = $e.SelectSingleNode("*[local-name()='label']")
                $labels[$rid] = if ($lbl) { $lbl.InnerText.Trim() } else { $e.InnerText.Trim() }
            }
            $pres[$p.GetAttribute('id')] = $labels
        }
    }
    $str = { param([string]$s) if ($s -match '^\$\(string\.(.+)\)$') { if ($strings.ContainsKey($Matches[1])) { return $strings[$Matches[1]] } else { return $Matches[1] } }; return $s }

    # Categories (only those in this file; references to other ADMX files become the name of the reference)
    $cats = @{}
    foreach ($c in @($admx.SelectNodes("//*[local-name()='categories']/*[local-name()='category']")))
    {
        $parent = $c.SelectSingleNode("*[local-name()='parentCategory']")
        $cats[$c.GetAttribute('name')] = @{ Name = (& $str $c.GetAttribute('displayName')); Parent = $(if ($parent) { $parent.GetAttribute('ref') } else { '' }) }
    }
    $catPath = {
        param([string]$ref)
        $parts = @(); $seen = 0
        while ($ref -and $seen -lt 10)
        {
            $seen++
            $id = ($ref -split ':')[-1]
            if ($cats.ContainsKey($id)) { $parts = @($cats[$id].Name) + $parts; $ref = $cats[$id].Parent } else { break }
        }
        return ($parts -join ' > ')
    }

    $policies = New-Object System.Collections.ArrayList
    foreach ($p in @($admx.SelectNodes("//*[local-name()='policies']/*[local-name()='policy']")))
    {
        $key = $p.GetAttribute('key')
        $parentCat = $p.SelectSingleNode("*[local-name()='parentCategory']")
        $presId = $p.GetAttribute('presentation') -replace '^\$\(presentation\.(.+)\)$', '$1'
        $labels = if ($pres.ContainsKey($presId)) { $pres[$presId] } else { @{} }
        $pol = @{
            Id = $p.GetAttribute('name'); Name = (& $str $p.GetAttribute('displayName')); Explain = (& $str $p.GetAttribute('explainText'))
            Class = $p.GetAttribute('class'); Key = $key; ValueName = $p.GetAttribute('valueName')
            Category = $(if ($parentCat) { & $catPath $parentCat.GetAttribute('ref') } else { '' })
            EnabledValue  = (Read-AdmxValue $p.SelectSingleNode("*[local-name()='enabledValue']"))
            DisabledValue = (Read-AdmxValue $p.SelectSingleNode("*[local-name()='disabledValue']"))
            EnabledList   = (Read-AdmxValueList $p.SelectSingleNode("*[local-name()='enabledList']") $key)
            DisabledList  = (Read-AdmxValueList $p.SelectSingleNode("*[local-name()='disabledList']") $key)
            Elements = New-Object System.Collections.ArrayList
        }
        $elRoot = $p.SelectSingleNode("*[local-name()='elements']")
        if ($elRoot)
        {
            foreach ($e in @($elRoot.ChildNodes | Where-Object { $_.NodeType -eq 'Element' }))
            {
                $ek = $e.GetAttribute('key'); if (-not $ek) { $ek = $key }
                $el = @{ Id = $e.GetAttribute('id'); Type = $e.LocalName; Key = $ek; ValueName = $e.GetAttribute('valueName')
                         Label = $(if ($labels.ContainsKey($e.GetAttribute('id')) -and $labels[$e.GetAttribute('id')]) { $labels[$e.GetAttribute('id')] } elseif ($e.GetAttribute('valueName')) { $e.GetAttribute('valueName') } else { $e.GetAttribute('id') })
                         Required = ($e.GetAttribute('required') -eq 'true') }
                switch ($e.LocalName)
                {
                    'boolean'
                    {
                        $el.TrueValue  = Read-AdmxValue $e.SelectSingleNode("*[local-name()='trueValue']")
                        $el.FalseValue = Read-AdmxValue $e.SelectSingleNode("*[local-name()='falseValue']")
                        $el.TrueList   = Read-AdmxValueList $e.SelectSingleNode("*[local-name()='trueList']") $ek
                        $el.FalseList  = Read-AdmxValueList $e.SelectSingleNode("*[local-name()='falseList']") $ek
                    }
                    { $_ -in 'decimal', 'longDecimal' }
                    {
                        $el.Min = $e.GetAttribute('minValue'); $el.Max = $e.GetAttribute('maxValue'); $el.StoreAsText = ($e.GetAttribute('storeAsText') -eq 'true')
                    }
                    'text' { $el.Expandable = ($e.GetAttribute('expandable') -eq 'true'); $el.MaxLength = $e.GetAttribute('maxLength') }
                    'list'
                    {
                        $el.ValuePrefix = $e.GetAttribute('valuePrefix'); $el.Additive = ($e.GetAttribute('additive') -eq 'true')
                        $el.ExplicitValue = ($e.GetAttribute('explicitValue') -eq 'true'); $el.Expandable = ($e.GetAttribute('expandable') -eq 'true')
                    }
                    'enum'
                    {
                        $el.Items = @()
                        foreach ($it in @($e.SelectNodes("*[local-name()='item']")))
                        {
                            $el.Items += @{ Name = (& $str $it.GetAttribute('displayName'))
                                            Value = (Read-AdmxValue $it.SelectSingleNode("*[local-name()='value']"))
                                            ValueList = (Read-AdmxValueList $it.SelectSingleNode("*[local-name()='valueList']") $ek) }
                        }
                    }
                }
                [void]$pol.Elements.Add($el)
            }
        }
        [void]$policies.Add($pol)
    }
    return @{ Name = [System.IO.Path]::GetFileNameWithoutExtension($AdmxPath); AdmlPath = $admlPath; Policies = $policies }
}

function ConvertTo-RegHex([byte[]]$Bytes) { return (($Bytes | ForEach-Object { $_.ToString('x2') }) -join ',') }

function Format-RegValue([string]$Name, $Value)
{
    # One line for a .reg file. $Value = @{ Type = SZ|EXPAND|MULTI|DWORD|QWORD|DELETE; Data }
    $n = if ($Name) { '"' + $Name.Replace('\', '\\').Replace('"', '\"') + '"' } else { '@' }
    switch ($Value.Type)
    {
        'DELETE' { return "$n=-" }
        'DWORD'  { return "$n=dword:" + ([uint32]$Value.Data).ToString('x8') }
        'QWORD'  { return "$n=hex(b):" + (ConvertTo-RegHex ([BitConverter]::GetBytes([uint64]$Value.Data))) }
        'EXPAND' { return "$n=hex(2):" + (ConvertTo-RegHex ([System.Text.Encoding]::Unicode.GetBytes("$($Value.Data)") + [byte[]](0, 0))) }
        'MULTI'
        {
            $bytes = New-Object System.Collections.Generic.List[byte]
            foreach ($s in @($Value.Data)) { $bytes.AddRange([System.Text.Encoding]::Unicode.GetBytes("$s")); $bytes.AddRange([byte[]](0, 0)) }
            $bytes.AddRange([byte[]](0, 0))
            return "$n=hex(7):" + (ConvertTo-RegHex $bytes.ToArray())
        }
        default  { return "$n=`"" + "$($Value.Data)".Replace('\', '\\').Replace('"', '\"') + '"' }
    }
}

function Get-AdmxRegEntries($Policy, $Choice)
{
    # Registry values for one chosen setting: list of @{ Key; ValueName; Value }
    $out = New-Object System.Collections.ArrayList
    $add = { param($k, $n, $v) [void]$out.Add(@{ Key = $k; ValueName = $n; Value = $v }) }
    $enabled = $Choice.State -eq 'Enabled'
    if ($enabled)
    {
        if ($Policy.EnabledValue) { & $add $Policy.Key $Policy.ValueName $Policy.EnabledValue }
        elseif ($Policy.ValueName) { & $add $Policy.Key $Policy.ValueName @{ Type = 'DWORD'; Data = 1 } }
        foreach ($i in $Policy.EnabledList) { & $add $i.Key $i.ValueName $i.Value }
    }
    else
    {
        if ($Policy.DisabledValue) { & $add $Policy.Key $Policy.ValueName $Policy.DisabledValue }
        elseif ($Policy.ValueName) { & $add $Policy.Key $Policy.ValueName @{ Type = 'DWORD'; Data = 0 } }
        foreach ($i in $Policy.DisabledList) { & $add $i.Key $i.ValueName $i.Value }
    }
    foreach ($el in $Policy.Elements)
    {
        $f = $Choice['Fields']
        $v = if ($f -and $f.ContainsKey($el.Id)) { $f[$el.Id] } else { $null }
        if (-not $enabled)
        {
            # Disabled: Group Policy removes the values of the elements
            if ($el.Type -ne 'list' -and $el.ValueName) { & $add $el.Key $el.ValueName @{ Type = 'DELETE' } }
            continue
        }
        switch ($el.Type)
        {
            'boolean'
            {
                $on = "$v" -match '^(?i)(true|1|ja|yes)$'
                if ($on) { if ($el.TrueValue) { & $add $el.Key $el.ValueName $el.TrueValue } elseif (-not $el.TrueList.Count) { & $add $el.Key $el.ValueName @{ Type = 'DWORD'; Data = 1 } }; foreach ($i in $el.TrueList) { & $add $i.Key $i.ValueName $i.Value } }
                else     { if ($el.FalseValue) { & $add $el.Key $el.ValueName $el.FalseValue } elseif (-not $el.FalseList.Count) { & $add $el.Key $el.ValueName @{ Type = 'DWORD'; Data = 0 } }; foreach ($i in $el.FalseList) { & $add $i.Key $i.ValueName $i.Value } }
            }
            'decimal'     { if ("$v" -ne '') { & $add $el.Key $el.ValueName $(if ($el.StoreAsText) { @{ Type = 'SZ'; Data = "$v" } } else { @{ Type = 'DWORD'; Data = [uint32]"$v" } }) } }
            'longDecimal' { if ("$v" -ne '') { & $add $el.Key $el.ValueName $(if ($el.StoreAsText) { @{ Type = 'SZ'; Data = "$v" } } else { @{ Type = 'QWORD'; Data = [uint64]"$v" } }) } }
            'text'        { if ($null -ne $v) { & $add $el.Key $el.ValueName @{ Type = $(if ($el.Expandable) { 'EXPAND' } else { 'SZ' }); Data = "$v" } } }
            'multiText'   { if ($null -ne $v) { & $add $el.Key $el.ValueName @{ Type = 'MULTI'; Data = @("$v" -split "`r?`n" | Where-Object { $_ -ne '' }) } } }
            'enum'
            {
                $item = $el.Items | Where-Object { $_.Name -eq "$v" } | Select-Object -First 1
                if (-not $item -and $el.Items.Count) { $item = $el.Items[0] }
                if ($item) { if ($item.Value) { & $add $el.Key $el.ValueName $item.Value }; foreach ($i in $item.ValueList) { & $add $i.Key $i.ValueName $i.Value } }
            }
            'list'
            {
                $lines = @("$v" -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                $type = if ($el.Expandable) { 'EXPAND' } else { 'SZ' }
                $n = 0
                foreach ($line in $lines)
                {
                    $n++
                    if ($el.ExplicitValue)
                    {
                        $i = $line.IndexOf('=')
                        if ($i -gt 0) { & $add $el.Key $line.Substring(0, $i).Trim() @{ Type = $type; Data = $line.Substring($i + 1).Trim() } }
                    }
                    elseif ($el.ValuePrefix -or $el.ValuePrefix -eq '') { & $add $el.Key "$($el.ValuePrefix)$n" @{ Type = $type; Data = $line } }
                    else { & $add $el.Key $line @{ Type = $type; Data = $line } }
                }
            }
        }
    }
    return ,$out
}

function ConvertTo-AdmxRegText($Admx, [hashtable]$Choices)
{
    # .reg text for all chosen settings, grouped per key. HKLM: the installation runs as SYSTEM.
    $byKey = [ordered]@{}
    foreach ($pol in $Admx.Policies)
    {
        if (-not $Choices.ContainsKey($pol.Id)) { continue }
        $ch = $Choices[$pol.Id]
        if ($ch.State -notin 'Enabled', 'Disabled') { continue }
        foreach ($e in (Get-AdmxRegEntries $pol $ch))
        {
            $k = "HKEY_LOCAL_MACHINE\$($e.Key)"
            if (-not $byKey.Contains($k)) { $byKey[$k] = New-Object System.Collections.ArrayList }
            [void]$byKey[$k].Add((Format-RegValue $e.ValueName $e.Value))
        }
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('Windows Registry Editor Version 5.00')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("; Created by the AppUpdateKit Builder from $($Admx.Name).admx - change it in the Builder (tab 2, Settings from ADMX)")
    foreach ($k in $byKey.Keys)
    {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("[$k]")
        foreach ($l in $byKey[$k]) { [void]$sb.AppendLine($l) }
    }
    return $sb.ToString()
}
#endregion

function Get-RegUndoLines([string]$Path)
{
    # Undo a .reg file: remove every value that the file sets.
    # Not whole keys: they may already exist and also contain values of others.
    $out = New-Object System.Collections.Generic.List[string]
    $map = @{ 'HKEY_LOCAL_MACHINE' = 'HKLM'; 'HKEY_CURRENT_USER' = 'HKCU'; 'HKEY_CLASSES_ROOT' = 'HKCR'; 'HKEY_USERS' = 'HKU'; 'HKEY_CURRENT_CONFIG' = 'HKCC' }
    $key = $null; $policyKeys = @{}
    try { $text = [System.IO.File]::ReadAllText($Path) } catch { return $out }
    foreach ($l in ($text -split "`r?`n"))
    {
        if ($l -match '^\[(-?)([^\]]+)\]\s*$')
        {
            $key = if ($Matches[1]) { $null } else { $Matches[2] }
            if ($key) { foreach ($h in $map.Keys) { if ($key -like "$h\*" -or $key -eq $h) { $key = $map[$h] + $key.Substring($h.Length); break } } }
            continue
        }
        if (-not $key) { continue }
        if ($l -match '^@=(?!-)') { $out.Add("reg.exe delete `"$key`" /ve /f /reg:64 >nul 2>&1"); continue }
        if ($l -match '^"((?:[^"\\]|\\.)*)"=(?!-)')
        {
            $name = $Matches[1] -replace '\\(.)', '$1'
            $out.Add("reg.exe delete `"$key`" /v `"$name`" /f /reg:64 >nul 2>&1")
            if ($key -match '\\Policies\\') { $policyKeys[$key] = 1 }
        }
    }
    # Policy keys (...\Policies\...) that are empty afterwards are removed too, up to just below Policies.
    # Only if there is really nothing left in them: values or subkeys of others stay.
    if ($policyKeys.Count)
    {
        $all = @{}
        foreach ($k in $policyKeys.Keys)
        {
            $cur = $k
            while ($cur -match '\\Policies\\.+') { $all[$cur] = 1; $cur = $cur.Substring(0, $cur.LastIndexOf('\')) }
        }
        # Via the 64-bit registry view, also when cmd runs as a 32-bit process (HKLM only)
        $list = (@($all.Keys | Where-Object { $_ -like 'HKLM\*' } | Sort-Object { $_.Length } -Descending) | ForEach-Object { "'" + $_.Substring(5).Replace("'", "''") + "'" }) -join ','
        if ($list) { $out.Add("powershell.exe -NoProfile -Command `"`$b = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64'); foreach (`$k in $list) { `$s = `$b.OpenSubKey(`$k); if (`$s) { `$leeg = (`$s.ValueCount -eq 0 -and `$s.SubKeyCount -eq 0); `$s.Close(); if (`$leeg) { `$b.DeleteSubKey(`$k) } } }`"") }
    }
    return $out
}

#region Read a script and undo it
# The Builder reads an installation script (.ps1 or .cmd) and looks for what it creates permanently:
# shortcuts, files, folders, registry values, scheduled tasks, services, firewall rules and
# environment variables. For those it makes uninstall lines (for uninstall-app.cmd), in reverse order.
# What it can't undo goes into the block as 'rem FILL IN', with the line number.

function ConvertTo-CmdPath([string]$p)
{
    # PowerShell path -> path for cmd.exe (registry: HKLM:\ -> HKLM\)
    if ($null -eq $p) { return $null }
    $p = $p.Trim().Replace('/', '\')
    $p = $p -replace '^(?i)Microsoft\.PowerShell\.Core\\Registry::', '' -replace '^(?i)Registry::', ''
    $p = $p -replace '^(?i)HKEY_LOCAL_MACHINE', 'HKLM' -replace '^(?i)HKEY_CURRENT_USER', 'HKCU' -replace '^(?i)HKEY_CLASSES_ROOT', 'HKCR' -replace '^(?i)HKEY_USERS', 'HKU'
    $p = $p -replace '^(?i)(HKLM|HKCU|HKCR|HKU):\\?', '$1\'
    $p = $p -replace '^\.\\', ''
    $p = $p -replace '(?<!^)\\{2,}', '\'
    return $p.TrimEnd('\')
}

function Test-FileName([string]$p)
{
    # Does this look like a file (name.ext with a real extension)? 'v2.0' or '8.18' is a folder.
    if (-not $p -or -not $p.TrimEnd('\')) { return $false }
    return ((Split-Path ($p.TrimEnd('\')) -Leaf) -match '\.[A-Za-z][A-Za-z0-9_]{0,7}$')
}

function Test-RegPath([string]$p) { return ($p -match '^(?i)(HKLM|HKCU|HKCR|HKU)(\\|$)') }

function Get-PsFolderPath([string]$Name)
{
    switch -Regex ($Name)
    {
        '^(?i)CommonDesktopDirectory$' { return '%PUBLIC%\Desktop' }
        '^(?i)(Desktop|DesktopDirectory)$' { return '%USERPROFILE%\Desktop' }
        '^(?i)CommonStartMenu$'        { return '%ProgramData%\Microsoft\Windows\Start Menu' }
        '^(?i)CommonPrograms$'         { return '%ProgramData%\Microsoft\Windows\Start Menu\Programs' }
        '^(?i)CommonStartup$'          { return '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup' }
        '^(?i)StartMenu$'              { return '%APPDATA%\Microsoft\Windows\Start Menu' }
        '^(?i)Programs$'               { return '%APPDATA%\Microsoft\Windows\Start Menu\Programs' }
        '^(?i)Startup$'                { return '%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup' }
        '^(?i)CommonApplicationData$'  { return '%ProgramData%' }
        '^(?i)ApplicationData$'        { return '%APPDATA%' }
        '^(?i)LocalApplicationData$'   { return '%LOCALAPPDATA%' }
        '^(?i)ProgramFiles$'           { return '%ProgramFiles%' }
        '^(?i)ProgramFilesX86$'        { return '%ProgramFiles(x86)%' }
        '^(?i)CommonDocuments$'        { return '%PUBLIC%\Documents' }
        '^(?i)Windows$'                { return '%SystemRoot%' }
        '^(?i)System$'                 { return '%SystemRoot%\System32' }
    }
    return $null
}

function Resolve-PsValue($Ast, [hashtable]$Vars)
{
    # Returns the possible text values of an expression (usually one), or $null if it can't be determined
    if ($null -eq $Ast) { return $null }
    $A = [System.Management.Automation.Language.Ast]
    switch ($Ast.GetType().Name)
    {
        'StringConstantExpressionAst' { return ,@($Ast.Value) }
        'ConstantExpressionAst'       { return ,@("$($Ast.Value)") }
        'ExpandableStringExpressionAst'
        {
            $results = @("$($Ast.Value)")
            # Replace nested expressions, from back to front (the offsets then stay right)
            $raw = $Ast.Extent.Text; $q = 1
            if ($raw.StartsWith('@')) { return $null }
            $text = $raw.Substring($q, $raw.Length - 2 * $q)
            $base = $Ast.Extent.StartOffset + $q
            $parts = @($Ast.NestedExpressions | Sort-Object { $_.Extent.StartOffset } -Descending)
            $vals = @($text)
            foreach ($n in $parts)
            {
                $r = Resolve-PsValue $n $Vars
                if ($null -eq $r) { return $null }
                $s = $n.Extent.StartOffset - $base; $len = $n.Extent.EndOffset - $n.Extent.StartOffset
                $vals = @(foreach ($v in $vals) { foreach ($x in $r) { $v.Substring(0, $s) + $x + $v.Substring($s + $len) } })
                if ($vals.Count -gt 20) { return $null }
            }
            # Remove `-escapes (like `$)
            return ,@($vals | ForEach-Object { $_ -replace '`(.)', '$1' })
        }
        'VariableExpressionAst'
        {
            $vp = $Ast.VariablePath
            if ($vp.IsDriveQualified -and $vp.DriveName -ieq 'env') { return ,@("%$($vp.UserPath.Substring(4))%") }
            $name = $vp.UserPath
            if ($name -ieq 'PSScriptRoot' -or $name -ieq 'PWD') { return ,@('.') }
            if ($Vars.ContainsKey($name.ToLower())) { return ,@($Vars[$name.ToLower()]) }
            return $null
        }
        'ParenExpressionAst' { return Resolve-PsValue $Ast.Pipeline $Vars }
        'ConvertExpressionAst' { return Resolve-PsValue $Ast.Child $Vars }   # [pscustomobject]@{...}, [string]$x
        'HashtableAst'
        {
            # @{ Name = 'Horizon'; Folder = "$env:PUBLIC\Desktop" }: fields that can be determined
            $h = @{}
            foreach ($kv in $Ast.KeyValuePairs)
            {
                $k = Resolve-PsValue $kv.Item1 $Vars; $v = Resolve-PsValue $kv.Item2 $Vars
                if ($k -and $null -ne $v) { $h["$($k[0])".ToLower()] = $v[0] }
            }
            return ,@($h)
        }
        'MemberExpressionAst'
        {
            # $item.Name for a list of @{...}
            if ($Ast.Static) { return $null }
            $obj = Resolve-PsValue $Ast.Expression $Vars; $m = Resolve-PsValue $Ast.Member $Vars
            if ($null -eq $obj -or -not $m) { return $null }
            $out = @()
            foreach ($o in $obj) { if ($o -is [hashtable] -and $o.ContainsKey("$($m[0])".ToLower())) { $out += $o["$($m[0])".ToLower()] } else { return $null } }
            return ,$out
        }
        'SubExpressionAst'
        {
            $st = @($Ast.SubExpression.Statements)
            if ($st.Count -eq 1) { return Resolve-PsValue $st[0] $Vars }
            return $null
        }
        'PipelineAst'
        {
            $el = @($Ast.PipelineElements)
            if ($el.Count -eq 1) { return Resolve-PsValue $el[0] $Vars }
            return $null
        }
        'CommandExpressionAst' { return Resolve-PsValue $Ast.Expression $Vars }
        'ArrayLiteralAst'
        {
            $all = @(); foreach ($e in $Ast.Elements) { $r = Resolve-PsValue $e $Vars; if ($null -eq $r) { return $null }; $all += $r }
            return ,$all
        }
        'ArrayExpressionAst'
        {
            $all = @()
            foreach ($st in $Ast.SubExpression.Statements) { $r = Resolve-PsValue $st $Vars; if ($null -eq $r) { return $null }; $all += $r }
            return ,$all
        }
        'BinaryExpressionAst'
        {
            if ($Ast.Operator -ne 'Plus') { return $null }
            $l = Resolve-PsValue $Ast.Left $Vars; $r = Resolve-PsValue $Ast.Right $Vars
            if ($null -eq $l -or $null -eq $r) { return $null }
            return ,@(foreach ($a in $l) { foreach ($b in $r) { "$a$b" } })
        }
        'InvokeMemberExpressionAst'
        {
            $m = "$($Ast.Member.Value)"; $t = "$($Ast.Expression.Extent.Text)"
            $args1 = @($Ast.Arguments)
            if ($Ast.Static -and $t -match '(?i)Environment\]$' -and $m -ieq 'GetFolderPath' -and $args1.Count)
            {
                $r = Resolve-PsValue $args1[0] $Vars
                if ($null -eq $r) { $r = @(($args1[0].Extent.Text -replace '^.*::', '' -replace "['`"\)]", '')) }
                $f = Get-PsFolderPath ($r[0] -replace '^.*::', '')
                if ($f) { return ,@($f) }
                return $null
            }
            if ($Ast.Static -and $t -match '(?i)Environment\]$' -and $m -ieq 'GetEnvironmentVariable' -and $args1.Count)
            {
                $r = Resolve-PsValue $args1[0] $Vars; if ($r) { return ,@("%$($r[0])%") }
                return $null
            }
            if ($Ast.Static -and $t -match '(?i)IO\.Path\]$' -and $m -ieq 'Combine')
            {
                $res = @('')
                foreach ($a in $args1)
                {
                    $r = Resolve-PsValue $a $Vars; if ($null -eq $r) { return $null }
                    $res = @(foreach ($x in $res) { foreach ($y in $r) { if ($x) { $x.TrimEnd('\') + '\' + $y.TrimStart('\') } else { $y } } })
                }
                return ,$res
            }
            return $null
        }
        'CommandAst'
        {
            $name = "$($Ast.GetCommandName())"
            if ($name -ieq 'Join-Path')
            {
                $a = Get-PsCommandArgs $Ast
                $p = if ($a.Named['path']) { $a.Named['path'] } elseif ($a.Positional.Count -ge 1) { $a.Positional[0] } else { $null }
                $c = if ($a.Named['childpath']) { $a.Named['childpath'] } elseif ($a.Named['path'] -and $a.Positional.Count -ge 1) { $a.Positional[0] } elseif ($a.Positional.Count -ge 2) { $a.Positional[1] } else { $null }
                $pv = Resolve-PsValue $p $Vars; $cv = Resolve-PsValue $c $Vars
                if ($null -eq $pv -or $null -eq $cv) { return $null }
                return ,@(foreach ($x in $pv) { foreach ($y in $cv) { $x.TrimEnd('\') + '\' + $y.TrimStart('\') } })
            }
            return $null
        }
    }
    return $null
}

function Get-PsCommandArgs($Cmd)
{
    # Parameters of a command: Named (name in lower case -> value AST; switch -> $true) and Positional
    $named = @{}; $pos = New-Object System.Collections.ArrayList
    $el = @($Cmd.CommandElements)
    for ($i = 1; $i -lt $el.Count; $i++)
    {
        $e = $el[$i]
        if ($e -is [System.Management.Automation.Language.CommandParameterAst])
        {
            $n = $e.ParameterName.ToLower()
            if ($e.Argument) { $named[$n] = $e.Argument }
            elseif ($i + 1 -lt $el.Count -and $el[$i + 1] -isnot [System.Management.Automation.Language.CommandParameterAst] -and
                    $n -notin 'force', 'recurse', 'passthru', 'whatif', 'confirm', 'verbose', 'wait', 'nonewwindow', 'append', 'noclobber', 'container')
            { $named[$n] = $el[$i + 1]; $i++ }
            else { $named[$n] = $true }
        }
        else { [void]$pos.Add($e) }
    }
    return @{ Named = $named; Positional = $pos }
}

function Get-NamedArg($A, [string[]]$Names, [int]$Position = -1)
{
    foreach ($n in $Names) { foreach ($k in $A.Named.Keys) { if ($k -eq $n -or ($k.Length -ge 3 -and $n.StartsWith($k))) { $v = $A.Named[$k]; if ($v -isnot [bool]) { return $v } } } }
    if ($Position -ge 0 -and $A.Positional.Count -gt $Position) { return $A.Positional[$Position] }
    return $null
}

function Get-UndoForFile([string]$p, [switch]$Folder, [switch]$Tree)
{
    if ($Tree) { return "if exist `"$p\`" rd /S /Q `"$p`"" }
    if ($Folder) { return "rd `"$p`" 2>nul" }
    return "if exist `"$p`" del /F /Q `"$p`""
}

function Get-EnvUndo([string]$Name, [bool]$Machine)
{
    if ($Machine) { return "reg.exe delete `"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment`" /v `"$Name`" /f >nul 2>&1" }
    return "reg.exe delete `"HKCU\Environment`" /v `"$Name`" /f >nul 2>&1"
}

function Get-CmdLineUndo([string]$Line, [string]$AppDir)
{
    # One cmd line (also reg.exe/schtasks/... from PowerShell): @{ Undo = @(...) } , @{ Unknown = $true } or $null (nothing permanent)
    $l = $Line.Trim() -replace '^@', ''
    if (-not $l -or $l -match '^(?i)(rem\b|::|:)') { return $null }
    # Tokens with quotes
    $tok = @([regex]::Matches($l, '"[^"]*"|\S+') | ForEach-Object { $_.Value })
    $uq = @($tok | ForEach-Object { $_.Trim('"') })
    $cmd = ($uq[0] -replace '(?i)\.exe$', '').ToLower()
    $opt = { param([string]$o) for ($i = 1; $i -lt $uq.Count - 1; $i++) { if ($uq[$i] -ieq $o) { return $uq[$i + 1] } }; return $null }
    $has = { param([string]$o) return [bool]($uq | Where-Object { $_ -ieq $o }) }
    # Redirect to a file: echo ... > file (>> appends to an existing file: can't be undone)
    if ($l -match '>>\s*"?[^"\s]' -and $l -notmatch '>>\s*nul') { return @{ Unknown = $true } }
    if ($l -match '(?<!>)>\s*"?([^">|&]+?)"?\s*$' -and $l -notmatch '>\s*nul\s*$' -and $l -notmatch '2>&1\s*$')
    {
        $f = ConvertTo-CmdPath $Matches[1]
        if ($l -match '>>') { return @{ Unknown = $true } }
        return @{ Undo = @(Get-UndoForFile $f) }
    }
    switch -Regex ($cmd)
    {
        '^(echo|set|setlocal|endlocal|if|exit|goto|cd|chdir|pushd|popd|timeout|ping|start|del|erase|rd|rmdir|title|cls|pause|for|shift|ver|call|net|taskkill|tasklist|whoami|hostname|powershell|pwsh|wscript|cscript|icacls|attrib|choice|find|findstr|type|dir|wmic|msg|explorer|gpupdate|klist|ipconfig|nslookup|w32tm)$'
        {
            if ($cmd -eq 'net' -and $uq.Count -gt 1 -and $uq[1] -ieq 'use') { return $null }
            if ($cmd -in 'powershell', 'pwsh', 'call', 'wscript', 'cscript', 'icacls', 'attrib', 'wmic') { return @{ Unknown = $true } }
            return $null
        }
        '^(md|mkdir)$' { return @{ Undo = @(Get-UndoForFile (ConvertTo-CmdPath $uq[1]) -Folder) } }
        '^(copy|xcopy|move)$'
        {
            $args2 = @($uq | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^/' })
            if ($args2.Count -lt 2) { return @{ Unknown = $true } }
            $src = $args2[0]; $dst = ConvertTo-CmdPath $args2[1]
            if ($src -match '[\*\?]') { return @{ Unknown = $true } }
            $leaf = Split-Path ($src.Replace('/', '\')) -Leaf
            $isDir = $args2[1].EndsWith('\') -or -not (Test-FileName $dst)
            if ($cmd -eq 'xcopy' -and ((& $has '/s') -or (& $has '/e'))) { return @{ Undo = @(Get-UndoForFile $dst -Tree) } }
            return @{ Undo = @(Get-UndoForFile $(if ($isDir) { "$dst\$leaf" } else { $dst })) }
        }
        '^robocopy$'
        {
            $args2 = @($uq | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^/' })
            if ($args2.Count -lt 2) { return @{ Unknown = $true } }
            $dst = ConvertTo-CmdPath $args2[1]
            if ($args2.Count -ge 3 -and -not ((& $has '/s') -or (& $has '/e') -or (& $has '/mir'))) {
                return @{ Undo = @($args2 | Select-Object -Skip 2 | ForEach-Object { if ($_ -match '[\*\?]') { "rem FILL IN: files '$_' from $dst" } else { Get-UndoForFile "$dst\$_" } }) }
            }
            return @{ Undo = @(Get-UndoForFile $dst -Tree) }
        }
        '^mklink$'
        {
            $args2 = @($uq | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^/' })
            if (-not $args2.Count) { return @{ Unknown = $true } }
            $link = ConvertTo-CmdPath $args2[0]
            if ((& $has '/d') -or (& $has '/j')) { return @{ Undo = @("rd `"$link`" 2>nul") } }
            return @{ Undo = @(Get-UndoForFile $link) }
        }
        '^reg$'
        {
            if ($uq.Count -lt 3) { return @{ Unknown = $true } }
            $sub = $uq[1].ToLower(); $key = ConvertTo-CmdPath $uq[2]
            if ($sub -eq 'add')
            {
                $v = & $opt '/v'
                if ($v) { return @{ Undo = @("reg.exe delete `"$key`" /v `"$v`" /f >nul 2>&1") } }
                if (& $has '/ve') { return @{ Undo = @("reg.exe delete `"$key`" /ve /f >nul 2>&1") } }
                return @{ Undo = @("reg.exe delete `"$key`" /f >nul 2>&1") }
            }
            if ($sub -eq 'import')
            {
                $f = $uq[2]; $full = if ($AppDir) { Join-Path $AppDir (Split-Path $f -Leaf) } else { $f }
                $r = @(Get-RegUndoLines $full); if ($r.Count) { return @{ Undo = $r } }
                return @{ Unknown = $true }
            }
            if ($sub -in 'query', 'delete', 'export', 'compare') { return $null }
            return @{ Unknown = $true }
        }
        '^schtasks$'
        {
            if (& $has '/create') { $tn = & $opt '/tn'; if ($tn) { return @{ Undo = @("schtasks.exe /Delete /TN `"$tn`" /F >nul 2>&1") } } ; return @{ Unknown = $true } }
            if ((& $has '/change') -and ((& $has '/enable') -or (& $has '/disable'))) { return @{ Unknown = $true } }
            return $null
        }
        '^sc$'
        {
            if ($uq.Count -ge 3 -and $uq[1] -ieq 'create') { return @{ Undo = @("sc.exe stop `"$($uq[2])`" >nul 2>&1", "sc.exe delete `"$($uq[2])`" >nul 2>&1") } }
            if ($uq.Count -ge 2 -and $uq[1] -imatch '^(start|stop|query|queryex|qc)$') { return $null }
            return @{ Unknown = $true }
        }
        '^netsh$'
        {
            if ($l -match '(?i)firewall\s+add\s+rule\s+.*name\s*=\s*("([^"]+)"|(\S+))')
            {
                $n = if ($Matches[2]) { $Matches[2] } else { $Matches[3] }
                return @{ Undo = @("netsh.exe advfirewall firewall delete rule name=`"$n`" >nul 2>&1") }
            }
            return @{ Unknown = $true }
        }
        '^setx$'
        {
            if ($uq.Count -ge 2) { return @{ Undo = @(Get-EnvUndo $uq[1] (& $has '/m')) } }
            return @{ Unknown = $true }
        }
        '^(regsvr32|msiexec|dism|bcdedit|certutil|wusa|pnputil)$' { return @{ Unknown = $true } }
    }
    # Another program (e.g. a setup.exe): unknown what it does permanently
    return @{ Unknown = $true }
}

function Get-PsScriptUndo([string]$Path)
{
    # Reads a PowerShell script; returns @{ Undo = lines (in order of execution); Unknown = 'line N: text' }
    $undo = New-Object System.Collections.ArrayList; $unknown = New-Object System.Collections.ArrayList
    $tokens = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errs)
    # Own functions in the script (e.g. function New-Shortcut($Path, $Target) { ... }): they are read
    # where they are called, with the values passed there.
    $funcs = @{}
    foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) { $funcs[$f.Name.ToLower()] = $f }
    Invoke-PsUndoScan $ast @{} $undo $unknown $funcs (Split-Path $Path -Parent) 0
    return @{ Undo = $undo; Unknown = $unknown }
}

function Invoke-PsUndoScan($Root, [hashtable]$Vars, $Undo, $Unknown, [hashtable]$Funcs, [string]$AppDir, [int]$Depth)
{
    # ($Vars/$Undo/$Unknown/$AppDir are $vars/$undo/$unknown/$appDir below: PowerShell ignores case)
    $harmless = '^(?i)(Get|Test|Write|Out|Join|Split|Select|Where|ForEach|Sort|Measure|Wait|Read|Format|ConvertTo|ConvertFrom|Resolve|Start-Sleep|Start-Transcript|Stop-Transcript|Stop|Remove|Unregister|Clear|Import-Module|New-Object|Add-Type|Invoke-WebRequest|Invoke-RestMethod|Compare|Group|Tee|Trace|Show|Exit|Return|Throw|Push|Pop|Set-Location|Set-Variable|New-Variable|Set-StrictMode|Set-ExecutionPolicy|Get-Date|Start-Process)'
    $nodes = @($Root.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -or
        $n -is [System.Management.Automation.Language.CommandAst] -or
        $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -or
        $n -is [System.Management.Automation.Language.ForEachStatementAst] }, $true) | Where-Object {
            # Not in functions (we read those at the call) and not in foreach loops (we read those per value)
            $p = $_.Parent; $inFunc = $false
            while ($p -and $p -ne $Root) { if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst] -or $p -is [System.Management.Automation.Language.ForEachStatementAst]) { $inFunc = $true; break }; $p = $p.Parent }
            -not $inFunc } | Sort-Object { $_.Extent.StartOffset })
    $where = { param($n) "line $($n.Extent.StartLineNumber): $(($n.Extent.Text -split "`r?`n")[0].Trim())" }
    foreach ($n in $nodes)
    {
        $T = $n.GetType().Name
        if ($T -eq 'AssignmentStatementAst')
        {
            if ($n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and -not $n.Left.VariablePath.IsDriveQualified)
            {
                $name = $n.Left.VariablePath.UserPath.ToLower()
                $r = Resolve-PsValue $n.Right $vars
                if ($null -ne $r -and $n.Operator -eq 'Equals') { $vars[$name] = @($r) }
                elseif ($null -ne $r -and $n.Operator -eq 'PlusEquals' -and $vars.ContainsKey($name)) { $vars[$name] = @($vars[$name]) + @($r) }
                else { $vars.Remove($name) }
            }
            elseif ($n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Left.VariablePath.DriveName -ieq 'env')
            {
                # $env:X = ... only applies to this process: nothing permanent
            }
            continue
        }
        if ($T -eq 'ForEachStatementAst')
        {
            # Read the loop per value, so fields that belong together (e.g. $i.Folder and $i.Name) stay together
            if ($Depth -ge 5) { continue }
            $r = Resolve-PsValue $n.Condition $vars
            $name = $n.Variable.VariablePath.UserPath.ToLower()
            $values = if ($null -ne $r -and @($r).Count -le 50) { @($r) } else { @($null) }
            foreach ($v in $values)
            {
                $lv = @{}; foreach ($k in $vars.Keys) { $lv[$k] = $vars[$k] }
                if ($null -ne $v) { $lv[$name] = @(,$v) } else { $lv.Remove($name) }
                Invoke-PsUndoScan $n.Body $lv $undo $unknown $Funcs $appDir ($Depth + 1)
            }
            continue
        }
        if ($T -eq 'InvokeMemberExpressionAst')
        {
            $m = "$($n.Member.Value)"
            if ($m -ieq 'CreateShortcut' -and -not $n.Static)
            {
                $r = Resolve-PsValue @($n.Arguments)[0] $vars
                if ($null -eq $r) { [void]$unknown.Add((& $where $n) + ' (shortcut path could not be determined)') }
                else { foreach ($p in $r) { [void]$undo.Add((Get-UndoForFile (ConvertTo-CmdPath $p))) } }
            }
            elseif ($m -ieq 'SetEnvironmentVariable' -and $n.Static)
            {
                $a = @($n.Arguments); $r = Resolve-PsValue $a[0] $vars
                $scope = if ($a.Count -ge 3) { "$($a[2].Extent.Text)" } else { 'Process' }
                if ($scope -match '(?i)Machine') { if ($r) { [void]$undo.Add((Get-EnvUndo $r[0] $true)) } else { [void]$unknown.Add((& $where $n)) } }
                elseif ($scope -match '(?i)User') { if ($r) { [void]$undo.Add((Get-EnvUndo $r[0] $false)) } else { [void]$unknown.Add((& $where $n)) } }
            }
            elseif ($m -imatch '^(WriteAllText|WriteAllBytes|WriteAllLines|Copy)$' -and $n.Static -and "$($n.Expression.Extent.Text)" -match '(?i)IO\.File\]$')
            {
                $a = @($n.Arguments); $target = if ($m -ieq 'copy') { $a[1] } else { $a[0] }
                $r = Resolve-PsValue $target $vars
                if ($r) { foreach ($p in $r) { [void]$undo.Add((Get-UndoForFile (ConvertTo-CmdPath $p))) } } else { [void]$unknown.Add((& $where $n)) }
            }
            elseif ($m -ieq 'CreateDirectory' -and $n.Static)
            {
                $r = Resolve-PsValue @($n.Arguments)[0] $vars
                if ($r) { foreach ($p in $r) { [void]$undo.Add((Get-UndoForFile (ConvertTo-CmdPath $p) -Folder)) } } else { [void]$unknown.Add((& $where $n)) }
            }
            continue
        }
        # CommandAst
        $name = "$($n.GetCommandName())"
        if (-not $name)
        {
            # & "path\something.exe" ... : another program
            if ($n.InvocationOperator -ne 'Unknown') { [void]$unknown.Add((& $where $n)) }
            continue
        }
        $a = Get-PsCommandArgs $n
        if ($Funcs.ContainsKey($name.ToLower()))
        {
            # Own function: bind the parameters to the values passed and read the function
            if ($Depth -ge 5) { continue }
            $f = $Funcs[$name.ToLower()]
            $params = @(if ($f.Body.ParamBlock) { $f.Body.ParamBlock.Parameters } elseif ($f.Parameters) { $f.Parameters })
            $fv = @{}; foreach ($k in $vars.Keys) { $fv[$k] = $vars[$k] }
            $posIdx = 0
            foreach ($prm in $params)
            {
                $pn = $prm.Name.VariablePath.UserPath.ToLower()
                $valAst = $null
                foreach ($k in $a.Named.Keys) { if ($pn -eq $k -or $pn.StartsWith($k)) { $valAst = $a.Named[$k]; break } }
                if ($null -eq $valAst -and $posIdx -lt $a.Positional.Count) { $valAst = $a.Positional[$posIdx]; $posIdx++ }
                if ($null -eq $valAst) { $valAst = $prm.DefaultValue }
                $r = if ($valAst -is [System.Management.Automation.Language.Ast]) { Resolve-PsValue $valAst $vars } else { $null }
                if ($null -ne $r) { $fv[$pn] = @($r) } else { $fv.Remove($pn) }
            }
            Invoke-PsUndoScan $f.Body $fv $undo $unknown $Funcs $appDir ($Depth + 1)
            continue
        }
        $resolve1 = { param($ast) if ($null -eq $ast) { return $null }; $r = Resolve-PsValue $ast $vars; if ($null -eq $r) { return $null }; return ,@($r | ForEach-Object { ConvertTo-CmdPath $_ }) }
        switch -Regex ($name)
        {
            '^(?i)(New-Item|ni|md|mkdir)$'
            {
                $p = & $resolve1 (Get-NamedArg $a 'path' 0); $nm = Get-NamedArg $a 'name'
                $type = "$(& $resolve1 (Get-NamedArg $a 'itemtype','type'))"
                if ($name -imatch '^(md|mkdir)$') { $type = 'Directory' }
                if ($nm) { $nv = Resolve-PsValue $nm $vars; if ($null -eq $nv -or $null -eq $p) { $p = $null } else { $p = @(foreach ($x in $p) { foreach ($y in $nv) { "$x\$y" } }) } }
                if ($null -eq $p) { [void]$unknown.Add((& $where $n)); break }
                foreach ($x in $p)
                {
                    if (Test-RegPath $x) { [void]$undo.Add("reg.exe delete `"$x`" /f >nul 2>&1") }
                    elseif ($type -imatch 'Dir') { [void]$undo.Add((Get-UndoForFile $x -Folder)) }
                    elseif ($type -imatch 'Junction|SymbolicLink|HardLink') { [void]$undo.Add("rd `"$x`" 2>nul"); [void]$undo.Add((Get-UndoForFile $x)) }
                    else { [void]$undo.Add((Get-UndoForFile $x)) }
                }
                break
            }
            '^(?i)(New-ItemProperty|Set-ItemProperty|sp)$'
            {
                $p = & $resolve1 (Get-NamedArg $a 'path','literalpath' 0); $nv = Resolve-PsValue (Get-NamedArg $a 'name' 1) $vars
                if ($null -eq $p -or $null -eq $nv) { [void]$unknown.Add((& $where $n)); break }
                foreach ($x in $p) { foreach ($y in $nv) { if (Test-RegPath $x) { [void]$undo.Add("reg.exe delete `"$x`" /v `"$y`" /f >nul 2>&1") } } }
                break
            }
            '^(?i)(Set-Content|sc|Out-File|Export-Csv|Export-Clixml)$'
            {
                $p = & $resolve1 (Get-NamedArg $a 'path','literalpath','filepath' 0)
                if ($a.Named.ContainsKey('append')) { [void]$unknown.Add((& $where $n) + ' (appends to an existing file)'); break }
                if ($null -eq $p) { [void]$unknown.Add((& $where $n)); break }
                foreach ($x in $p) { [void]$undo.Add((Get-UndoForFile $x)) }
                break
            }
            '^(?i)(Add-Content|ac)$' { [void]$unknown.Add((& $where $n) + ' (appends to an existing file)'); break }
            '^(?i)(Copy-Item|copy|cp|cpi|Move-Item|move|mv|mi)$'
            {
                $src = Resolve-PsValue (Get-NamedArg $a 'path','literalpath' 0) $vars
                $dst = & $resolve1 (Get-NamedArg $a 'destination' 1)
                if ($null -eq $src -or $null -eq $dst -or ($src -match '[\*\?]')) { [void]$unknown.Add((& $where $n)); break }
                foreach ($s in $src) { foreach ($d in $dst)
                {
                    $leaf = Split-Path ($s.Replace('/', '\').TrimEnd('\')) -Leaf
                    $srcIsDir = -not (Test-FileName $leaf)
                    $dstIsDir = (Get-NamedArg $a 'destination' 1).Extent.Text -match '\\["'']?$' -or -not (Test-FileName $d)
                    if ($srcIsDir) { [void]$undo.Add((Get-UndoForFile $(if ($dstIsDir -and $a.Named.ContainsKey('recurse') -and (Split-Path $d -Leaf) -ine $leaf) { "$d\$leaf" } else { $d }) -Tree)) }
                    elseif ($dstIsDir) { [void]$undo.Add((Get-UndoForFile "$d\$leaf")) }
                    else { [void]$undo.Add((Get-UndoForFile $d)) }
                } }
                break
            }
            '^(?i)Expand-Archive$'
            {
                $d = & $resolve1 (Get-NamedArg $a 'destinationpath' 1)
                if ($d) { foreach ($x in $d) { [void]$undo.Add((Get-UndoForFile $x -Tree)) } } else { [void]$unknown.Add((& $where $n)) }
                break
            }
            '^(?i)Register-ScheduledTask$'
            {
                $tn = Resolve-PsValue (Get-NamedArg $a 'taskname' 0) $vars; $tp = Resolve-PsValue (Get-NamedArg $a 'taskpath') $vars
                if ($null -eq $tn) { [void]$unknown.Add((& $where $n)); break }
                foreach ($t in $tn) { $full = if ($tp) { ($tp[0].TrimEnd('\') + '\' + $t) } else { $t }; [void]$undo.Add("schtasks.exe /Delete /TN `"$full`" /F >nul 2>&1") }
                break
            }
            '^(?i)New-Service$'
            {
                $sn = Resolve-PsValue (Get-NamedArg $a 'name' 0) $vars
                if ($null -eq $sn) { [void]$unknown.Add((& $where $n)); break }
                foreach ($s in $sn) { [void]$undo.Add("sc.exe stop `"$s`" >nul 2>&1"); [void]$undo.Add("sc.exe delete `"$s`" >nul 2>&1") }
                break
            }
            '^(?i)New-NetFirewallRule$'
            {
                $dn = Resolve-PsValue (Get-NamedArg $a 'displayname') $vars; $nn = Resolve-PsValue (Get-NamedArg $a 'name') $vars
                if ($dn) { foreach ($d in $dn) { [void]$undo.Add("netsh.exe advfirewall firewall delete rule name=`"$d`" >nul 2>&1") } }
                elseif ($nn) { foreach ($d in $nn) { [void]$undo.Add("powershell.exe -NoProfile -Command `"Remove-NetFirewallRule -Name '$d' -ErrorAction SilentlyContinue`"") } }
                else { [void]$unknown.Add((& $where $n)) }
                break
            }
            '^(?i)(New-SmbMapping|New-PSDrive)$' { if ($a.Named.ContainsKey('persist') -or $name -ieq 'New-SmbMapping') { [void]$unknown.Add((& $where $n)) }; break }
            '^(?i)Start-Process$'
            {
                # Starting a program is not permanent; starting an installer or command maybe is
                $fp = Resolve-PsValue (Get-NamedArg $a 'filepath' 0) $vars
                $al = Get-NamedArg $a 'argumentlist' 1
                if ($fp -and ($fp[0] -match '(?i)(^|\\)(reg|schtasks|sc|netsh|setx|cmd)(\.exe)?$'))
                {
                    $argText = if ($al) { $v = Resolve-PsValue $al $vars; if ($v) { $v -join ' ' } else { $null } } else { '' }
                    if ($null -eq $argText) { [void]$unknown.Add((& $where $n)); break }
                    $r = Get-CmdLineUndo ("$(Split-Path $fp[0] -Leaf) $argText" -replace '^(?i)cmd(\.exe)?\s+/c\s+', '') $appDir
                    if ($r -and $r.Undo) { foreach ($u in $r.Undo) { [void]$undo.Add($u) } } elseif ($r -and $r.Unknown) { [void]$unknown.Add((& $where $n)) }
                }
                elseif ($fp -and ($fp[0] -match '(?i)msiexec|setup|install|\.msi$')) { [void]$unknown.Add((& $where $n)) }
                break
            }
            '^(?i)(reg|reg\.exe|schtasks|schtasks\.exe|sc\.exe|netsh|netsh\.exe|setx|setx\.exe|robocopy|robocopy\.exe|xcopy|xcopy\.exe|cmd|cmd\.exe|regsvr32|regsvr32\.exe|msiexec|msiexec\.exe)$'
            {
                # A cmd command from PowerShell: resolve the arguments and read it as a cmd line
                $parts = @($name)
                foreach ($e in @($n.CommandElements | Select-Object -Skip 1))
                {
                    if ($e -is [System.Management.Automation.Language.CommandParameterAst]) { $parts += $e.Extent.Text; continue }
                    $v = Resolve-PsValue $e $vars
                    if ($null -eq $v) { $parts = $null; break }
                    $parts += $(if ($v[0] -match '\s') { "`"$($v[0])`"" } else { $v[0] })
                }
                if ($null -eq $parts) { [void]$unknown.Add((& $where $n)); break }
                $text = ($parts -join ' ') -replace '^(?i)cmd(\.exe)?\s+/c\s+', ''
                $r = Get-CmdLineUndo $text $appDir
                if ($r -and $r.Undo) { foreach ($u in $r.Undo) { [void]$undo.Add($u) } } elseif ($r -and $r.Unknown) { [void]$unknown.Add((& $where $n)) }
                break
            }
            default
            {
                if ($name -match $harmless) { break }
                if ($name -match '^(?i)New-(ScheduledTask(Action|Trigger|Settings|SettingsSet|Principal)?|TimeSpan|Guid|CimSession|PSSession|Item(Property)?Value)$') { break }   # only creating an object
                if ($name -match '^(?i)(New|Set|Add|Register|Install|Enable|Disable|Copy|Move|Rename|Import|Expand|Grant|Publish|Mount|Update|Initialize)-') { [void]$unknown.Add((& $where $n)); break }
                if ($name -match '\.(exe|cmd|bat|ps1|msi)$' -or $name -match '\\') { [void]$unknown.Add((& $where $n)) }
            }
        }
    }
}

function Get-CmdScriptUndo([string]$Path)
{
    $undo = New-Object System.Collections.ArrayList; $unknown = New-Object System.Collections.ArrayList
    $appDir = Split-Path $Path -Parent
    $vars = @{}
    $nr = 0
    foreach ($raw in ([System.IO.File]::ReadAllText($Path) -split "`r?`n"))
    {
        $nr++
        $line = $raw.Trim()
        if (-not $line) { continue }
        # Fill in own variables (set NAME=value): they no longer exist when uninstalling
        foreach ($k in @($vars.Keys)) { $line = [regex]::Replace($line, "%$([regex]::Escape($k))%", [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $vars[$k] }, 'IgnoreCase') }
        $line = $line -replace '(?i)%~dp0\\?', ''
        if ($line -match '^@?set\s+"?([^=/"]+)=([^"]*)"?\s*$') { $vars[$Matches[1].Trim()] = $Matches[2]; continue }
        # if ... ( command )  /  if ... command  -> only read the command
        $cmdPart = $line -replace '^(?i)if\s+(not\s+)?(exist\s+("[^"]*"|\S+)|defined\s+\S+|errorlevel\s+\d+|"[^"]*"\s*==\s*"[^"]*"|\S+==\S+)\s+', ''
        $cmdPart = $cmdPart.Trim().TrimStart('(').TrimEnd(')').Trim()
        foreach ($piece in ($cmdPart -split '\s*&&?\s*'))
        {
            $r = Get-CmdLineUndo $piece $appDir
            if ($r -and $r.Undo) { foreach ($u in $r.Undo) { [void]$undo.Add($u) } }
            elseif ($r -and $r.Unknown) { [void]$unknown.Add("line ${nr}: $($raw.Trim())") }
        }
    }
    return @{ Undo = $undo; Unknown = $unknown }
}

function Get-ScriptUndo([string]$Path, [string]$File)
{
    # Uninstall lines for a script, derived from its content. First line: origin with a checksum,
    # so the Builder can later see whether you changed the block yourself.
    $res = $null
    try
    {
        $res = if ($Path -match '(?i)\.ps1$') { Get-PsScriptUndo $Path } else { Get-CmdScriptUndo $Path }
    }
    catch { return $null }
    $body = New-Object System.Collections.Generic.List[string]
    # Reverse order: first files, then the folders they were in
    # If a line occurs more than once (e.g. a function that creates the same key twice), the first time
    # the script creates it counts: that one comes last in the reverse order.
    $seen = @{}
    for ($i = 0; $i -lt $res.Undo.Count; $i++) { $u = $res.Undo[$i]; if (-not $seen.ContainsKey($u)) { $seen[$u] = $i } }
    for ($i = $res.Undo.Count - 1; $i -ge 0; $i--) { $u = $res.Undo[$i]; if ($seen[$u] -eq $i) { $body.Add($u) } }
    foreach ($x in @($res.Unknown | Select-Object -Unique)) { $body.Add("rem FILL IN: can't be undone automatically, $x") }
    if (-not $body.Count) { $body.Add("rem The script doesn't create anything permanent: nothing needs to be undone.") }
    return ,(@(New-DerivedMarker $File $body) + @($body))
}

function Get-TextHash([string[]]$Lines)
{
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $b = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Lines -join "`n").Trim()))
    return (-join ($b[0..3] | ForEach-Object { $_.ToString('x2') }))
}
function New-DerivedMarker([string]$File, $Body) { return "rem Derived from $File by the Builder - feel free to edit [#$(Get-TextHash @($Body))]" }
function Test-UntouchedDerived($Lines)
{
    # Is this block still exactly as the Builder derived it from the script?
    $l = @($Lines)
    if (-not $l.Count -or $l[0] -notmatch '^rem (?:Afgeleid uit|Derived from) .+ \[#([0-9a-f]{8})\]$') { return $false }   # English or Dutch
    $h = $Matches[1]
    return ((Get-TextHash @($l | Select-Object -Skip 1)) -eq $h)
}
#endregion

function Get-ComponentUndo($c)
{
    # Uninstall lines that undo a component (not the main component). 'FILL IN' = the Builder doesn't know.
    $file = "$($c.File)"; $base = [System.IO.Path]::GetFileNameWithoutExtension($file); $ext = [System.IO.Path]::GetExtension($file)
    $dir = Get-AppFolder
    $path = if ($dir) { Join-Path $dir $file } else { $file }
    if ($file -match '(?i)runtime|redist|vcredist|dotnet|webview')
    {
        return @('rem Shared component: not removed, other apps may use it too.')
    }
    switch ("$($c.Kind)".ToUpper())
    {
        'MSI'
        {
            if ($c.ProductCode) { return @("msiexec.exe /x $($c.ProductCode) /qn /norestart") }
            return @("rem FILL IN: uninstall command for $file (no product code found).")
        }
        'MSP' { return @('rem MSI patch: removed together with the product.') }
        'REG'
        {
            $r = @(Get-RegUndoLines $path)
            if ($r.Count) { return $r }
            return @("rem FILL IN: which registry values of $file need to be removed?")
        }
        { $_ -in 'PS1', 'CMD' }
        {
            # 1) An uninstall script next to the script (same name + -uninstall/-verwijderen, or Uninstall-<name>)
            $names = foreach ($e in @($ext, '.ps1', '.cmd', '.bat') | Select-Object -Unique) {
                "$base-uninstall$e"; "$base-verwijderen$e"; "${base}_uninstall$e"; "Uninstall-$base$e"; "Verwijder-$base$e" }
            foreach ($n in $names)
            {
                if ($dir -and (Test-Path -LiteralPath (Join-Path $dir $n)))
                {
                    if ($n -like '*.ps1') { return @("powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$n`"") }
                    return @("call `"$n`"")
                }
            }
            # 2) A PowerShell script with a switch -Uninstall / -Remove / -Verwijderen
            if ($ext -ieq '.ps1' -and $dir -and (Test-Path -LiteralPath $path))
            {
                $ast = $null
                try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null) } catch { }
                $p = if ($ast -and $ast.ParamBlock) { @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) } else { @() }
                $sw = @($p | Where-Object { $_ -in 'Uninstall', 'Remove', 'Verwijderen', 'Verwijder' }) | Select-Object -First 1
                if ($sw) { return @("powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$file`" -$sw") }
            }
            # 3) Read the script and derive what it creates
            if ($dir -and (Test-Path -LiteralPath $path))
            {
                $d = Get-ScriptUndo $path $file
                if ($d) { return $d }
            }
            return @(
                "rem FILL IN: what undoes $file? E.g. put $base-uninstall$ext in the package (Add... > Include only),"
                "rem         give the script an -Uninstall switch, or write the lines here."
            )
        }
        default
        {
            # EXE: uninstall by name (MSI product code or own uninstaller)
            if (-not $script:ExeNameCache) { $script:ExeNameCache = @{} }
            if (-not $script:ExeNameCache.ContainsKey($path))
            {
                $pn = ''
                if (Test-Path -LiteralPath $path) { try { $pn = "$((Get-InstallerInfo $path).ProductName)" } catch { } }
                $script:ExeNameCache[$path] = $pn
            }
            $pn = $script:ExeNameCache[$path]
            if ($pn)
            {
                $exeArgs = if ("$($c.Kind)" -eq 'Inno') { '/VERYSILENT /NORESTART' } else { '/S' }
                return @("powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"Remove-App.ps1`" -Name `"$pn`" -ExeArgs `"$exeArgs`"")
            }
            return @("rem FILL IN: uninstall command for $file.")
        }
    }
}

function Sync-UninstallComponents
{
    # Uninstall steps for the extra components (not the main component), in reverse order of installing.
    # Every block starts with 'rem Component: <file> undo' and runs until the next empty line.
    # A block you changed yourself stays; a block that is not filled in yet or is still as the Builder derived it, is made again.
    $text = "$($ui.TxtUninstallCmd.Text)"
    if (-not $text.Trim()) { return }
    $comps = @(Get-ComponentList | Where-Object { $_ })
    $mainIdx = -1
    for ($i = 0; $i -lt $comps.Count; $i++) { if ($comps[$i].Main) { $mainIdx = $i; break } }

    # Read and remove the existing blocks
    $lines = @($text -split "`r?`n")
    $keep = New-Object System.Collections.Generic.List[string]
    $old = @{}
    for ($i = 0; $i -lt $lines.Count; $i++)
    {
        if ($lines[$i] -match '^rem (?:Onderdeel|Component): (.+) (?:ongedaan maken|undo)$')   # English or Dutch
        {
            $name = $Matches[1]; $body = New-Object System.Collections.Generic.List[string]
            while ($i + 1 -lt $lines.Count -and $lines[$i + 1].Trim()) { $i++; $body.Add($lines[$i]) }
            if ($i + 1 -lt $lines.Count) { $i++ }   # the empty line after it belongs to the block
            $old[$name] = $body
            continue
        }
        $keep.Add($lines[$i])
    }
    $makeBlock = {
        param($c)
        $b = New-Object System.Collections.Generic.List[string]
        $b.Add("rem Component: $($c.File) undo")
        $prev = $old["$($c.File)"]
        # Make again: not filled in yet (FILL IN, not derived) or still exactly as the Builder derived it from the script.
        # A block you changed yourself stays.
        $derived = $prev -and @($prev)[0] -match '^rem (?:Afgeleid uit|Derived from) '
        $regen = (-not $prev) -or (Test-UntouchedDerived $prev) -or ((-not $derived) -and ($prev -match 'VUL IN|FILL IN'))
        if (-not $regen) { $b.AddRange([string[]]@($prev)) }
        else { $b.AddRange([string[]]@(Get-ComponentUndo $c)) }
        $b.Add('')
        return ,$b
    }
    # Installed after the main component -> undo first (before the uninstall line of the app);
    # installed before it (e.g. a runtime) -> afterwards (before the last 'exit /b').
    $before = New-Object System.Collections.Generic.List[string]
    $after  = New-Object System.Collections.Generic.List[string]
    for ($i = $comps.Count - 1; $i -ge 0; $i--)
    {
        if ($i -eq $mainIdx) { continue }
        $blk = & $makeBlock $comps[$i]
        if ($mainIdx -ge 0 -and $i -lt $mainIdx) { $after.AddRange([string[]]@($blk)) } else { $before.AddRange([string[]]@($blk)) }
    }
    # Place of the uninstall line of the app: the first line after the header that isn't rem/empty
    $appAt = -1
    for ($i = 0; $i -lt $keep.Count; $i++) { if ($keep[$i].Trim() -and $keep[$i] -notmatch '^\s*(rem\b|::|@?echo off)') { $appAt = $i; break } }
    $exitAt = -1
    for ($i = $keep.Count - 1; $i -ge 0; $i--) { if ($keep[$i] -match '^\s*exit\s+/b') { $exitAt = $i; break } }
    if ($after.Count)
    {
        if ($exitAt -ge 0) { $keep.InsertRange($exitAt, [string[]]@($after)) } else { $keep.Add(''); $keep.AddRange([string[]]@($after)) }
    }
    if ($before.Count)
    {
        if ($appAt -lt 0) { $appAt = if ($exitAt -ge 0) { $exitAt } else { $keep.Count } }
        $keep.InsertRange($appAt, [string[]]@($before))
    }
    $new = ($keep -join "`r`n") -replace "(`r`n){3,}", "`r`n`r`n"
    if ($new -ne $text) { $ui.TxtUninstallCmd.Text = $new }
}

function Sync-UninstallCleanup
{
    # Keep the uninstall steps in line with the copy steps: every file the installation puts somewhere,
    # is cleaned up again on uninstall (and the folder, if it is empty afterwards). Own lines stay.
    Sync-UninstallComponents   # first the uninstall steps for the extra components
    $text = "$($ui.TxtUninstallCmd.Text)"
    if (-not $text.Trim()) { return }
    # Remove old cleanup blocks
    $lines = @($text -split "`r?`n")
    $keep = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++)
    {
        if ($lines[$i] -match '^rem (?:Bestand|File): .+ (?:opruimen uit|remove from) ')   # English or Dutch
        {
            while ($i + 1 -lt $lines.Count -and ($lines[$i + 1] -like 'if exist "*" del /F /Q "*"' -or $lines[$i + 1] -like 'rd "*" 2>nul')) { $i++ }
            continue
        }
        $keep.Add($lines[$i])
    }
    # New blocks from the copy steps
    $block = New-Object System.Collections.Generic.List[string]
    # Copy lines in the extra steps (before and after): those of the Builder (copy /Y "x" "folder\") and own copy/xcopy lines
    $steps = "$($ui.TxtPreInstall.Text)`n$($ui.TxtPostInstall.Text)"
    foreach ($m in [regex]::Matches($steps, '(?im)^\s*x?copy\s+(?:/\S+\s+)*"?([^"\s\\]+)"?\s+"([^"]+)"'))
    {
        $file = $m.Groups[1].Value; $dir = $m.Groups[2].Value.TrimEnd('\')
        if (Test-FileName $dir) { if ((Split-Path $dir -Leaf) -ine $file) { continue }; $dir = Split-Path $dir -Parent }   # copy x "folder\x"
        $block.Add("rem File: $file remove from $dir")
        $block.Add("if exist `"$dir\$file`" del /F /Q `"$dir\$file`"")
        $block.Add("rd `"$dir`" 2>nul")
    }
    # Put it before the last 'exit /b' (the exit code of the uninstall then still applies), otherwise at the end
    $exitAt = -1
    for ($i = $keep.Count - 1; $i -ge 0; $i--) { if ($keep[$i] -match '^\s*exit\s+/b') { $exitAt = $i; break } }
    if ($block.Count)
    {
        if ($exitAt -ge 0) { $keep.InsertRange($exitAt, [string[]](@($block) + '')) }
        else { $keep.Add(''); $keep.AddRange([string[]]@($block)) }
    }
    $new = ($keep -join "`r`n") -replace "(`r`n){3,}", "`r`n`r`n"
    if ($new -ne $text) { $ui.TxtUninstallCmd.Text = $new }
}

function Copy-ToAppFolder([string]$Source)
{
    # Copies a file to the app folder; if it is already there (same file), do nothing
    $dir = Get-AppFolder
    $dest = Join-Path $dir ([System.IO.Path]::GetFileName($Source))
    if ([System.IO.Path]::GetFullPath($Source) -ieq [System.IO.Path]::GetFullPath($dest)) { return }
    Copy-Item -LiteralPath $Source -Destination $dest -Force
}

function Test-InstallerFile([string]$Name)
{
    return ([System.IO.Path]::GetExtension($Name).ToLower() -in @('.exe', '.msi', '.msp', '.ps1', '.cmd', '.bat', '.reg'))
}

function Remove-CopyStep([string]$Name, [string]$Text)
{
    # Removes the block "rem File: <name> copy to ..." (plus the md and copy line) from the extra steps
    $out = New-Object System.Collections.Generic.List[string]
    $lines = @("$Text" -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++)
    {
        if ($lines[$i] -match "^rem (?:Bestand|File): $([regex]::Escape($Name)) (?:kopieren naar|copy to) ")   # English or Dutch
        {
            while ($i + 1 -lt $lines.Count -and ($lines[$i + 1] -like 'if not exist "*" md "*"' -or $lines[$i + 1] -like "copy /Y `"$Name`" *")) { $i++ }
            continue
        }
        $out.Add($lines[$i])
    }
    return (($out -join "`r`n").TrimEnd())
}

function Add-CopyStep([string]$Name, [string]$Target)
{
    # Puts a copy step in "Extra steps after the components" (replaces an earlier step for the same file)
    $t = $Target.Trim().TrimEnd('\')
    $block = "rem File: $Name copy to $t`r`nif not exist `"$t\`" md `"$t`"`r`ncopy /Y `"$Name`" `"$t\`" >nul"
    $cur = Remove-CopyStep $Name $ui.TxtPostInstall.Text
    $ui.TxtPostInstall.Text = if ($cur) { "$cur`r`n$block" } else { $block }
    Sync-UninstallCleanup
}

$FileActionXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Add file" Width="580" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" FontSize="13" Background="#F4F6F9" Foreground="#1F2937" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
<!--THEME-->
  </Window.Resources>
  <StackPanel Margin="20">
    <TextBlock Name="TxtTitle" FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <TextBlock Style="{StaticResource Hint}" Margin="0,4,0,14" Text="The file goes into the package. Choose what the installation does with it; the Builder prepares the step in tab 2."/>
    <Border Style="{StaticResource Card}" Margin="0,0,0,12">
      <StackPanel>
        <RadioButton Name="OptComp" GroupName="Actie" Content="Install as a component (with its own parameters and exit codes)" Margin="0,0,0,10"/>
        <RadioButton Name="OptCopy" GroupName="Actie" Content="Copy to a folder on the laptop"/>
        <TextBox Name="TxtTarget" Margin="22,6,0,4"/>
        <TextBlock Style="{StaticResource Hint}" Margin="22,0,0,10" Text="E.g. %ProgramData%\My app or %ProgramFiles%\My app. The installation runs as SYSTEM: %APPDATA% and %USERPROFILE% then don't point to the user."/>
        <RadioButton Name="OptKeep" GroupName="Actie" Content="Only include in the package (I use it myself in an extra step)"/>
      </StackPanel>
    </Border>
    <CheckBox Name="ChkAll" Margin="0,0,0,12"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
      <Button Name="BtnCancel" Content="Skip"/>
      <Button Name="BtnOk" Content="Add" Style="{StaticResource Primary}" Margin="0"/>
    </StackPanel>
  </StackPanel>
</Window>
'@

$AdmxXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Settings from ADMX" Width="1040" Height="700" MinWidth="820" MinHeight="520" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" FontSize="13" Background="#F4F6F9" Foreground="#1F2937" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
<!--THEME-->
  </Window.Resources>
  <DockPanel Margin="18">
    <StackPanel DockPanel.Dock="Top" Margin="0,0,0,12">
      <TextBlock Name="TxtAdmxTitle" FontSize="16" FontWeight="SemiBold"/>
      <TextBlock Style="{StaticResource Hint}" TextWrapping="Wrap" Margin="0,4,0,0"
                 Text="Choose the settings that belong to this app, for example turning off the automatic updater. They are installed as a registry file and cleaned up again on uninstall. Policy you want to manage and monitor centrally is better placed in a configuration profile in Intune."/>
    </StackPanel>
    <DockPanel DockPanel.Dock="Bottom" Margin="0,12,0,0">
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
        <Button Name="BtnAdmxCancel" Content="Cancel"/>
        <Button Name="BtnAdmxSave" Content="Save in the package" Style="{StaticResource Primary}" Margin="0"/>
      </StackPanel>
      <TextBlock Name="TxtAdmxCount" VerticalAlignment="Center" Foreground="#4B5563"/>
    </DockPanel>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="400"/>
        <ColumnDefinition Width="14"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border Style="{StaticResource Card}" Margin="0" Padding="12">
        <DockPanel>
          <StackPanel DockPanel.Dock="Top">
            <TextBox Name="TxtAdmxFilter" ToolTip="Search by name, category or registry name"/>
            <CheckBox Name="ChkAdmxChosen" Content="Only chosen settings" Margin="0,8,0,8"/>
          </StackPanel>
          <ListBox Name="LstAdmx" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
            <ListBox.ItemTemplate>
              <DataTemplate>
                <StackPanel Margin="0,2,0,2">
                  <TextBlock Text="{Binding Display}" FontWeight="{Binding Weight}" TextTrimming="CharacterEllipsis"/>
                  <TextBlock Text="{Binding Sub}" FontSize="11.5" Foreground="#6B7280" TextTrimming="CharacterEllipsis"/>
                </StackPanel>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </DockPanel>
      </Border>
      <Border Grid.Column="2" Style="{StaticResource Card}" Margin="0" Padding="16">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Name="PnlAdmxRight">
            <TextBlock Name="TxtAdmxPolicy" FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Text="Choose a setting on the left."/>
            <TextBlock Name="TxtAdmxCat" Style="{StaticResource Hint}" TextWrapping="Wrap" Margin="0,2,0,10"/>
            <WrapPanel Name="PnlAdmxState" Margin="0,0,0,8" Visibility="Collapsed">
              <RadioButton Name="OptAdmxNot" GroupName="AdmxState" Content="Not configured" Margin="0,0,18,0"/>
              <RadioButton Name="OptAdmxOn" GroupName="AdmxState" Content="Enabled" Margin="0,0,18,0"/>
              <RadioButton Name="OptAdmxOff" GroupName="AdmxState" Content="Disabled"/>
            </WrapPanel>
            <TextBlock Name="TxtAdmxUserOnly" TextWrapping="Wrap" Foreground="#854F0B" Margin="0,0,0,8" Visibility="Collapsed"
                       Text="This is a user setting. The installation runs as SYSTEM and can't set it for the user. Use a configuration profile in Intune for this."/>
            <StackPanel Name="PnlAdmxFields" Margin="0,4,0,8"/>
            <TextBlock Name="TxtAdmxReg" FontFamily="Consolas" FontSize="11.5" Foreground="#4B5563" TextWrapping="Wrap" Margin="0,0,0,10"/>
            <TextBlock Name="TxtAdmxExplain" TextWrapping="Wrap" Foreground="#374151" LineHeight="19"/>
          </StackPanel>
        </ScrollViewer>
      </Border>
    </Grid>
  </DockPanel>
</Window>
'@

function ConvertTo-AdmxChoices($Obj)
{
    # Choices from JSON (PSCustomObject) back to hashtables
    $h = @{}
    if (-not $Obj) { return $h }
    foreach ($p in $Obj.PSObject.Properties)
    {
        $f = @{}
        if ($p.Value.Fields) { foreach ($q in $p.Value.Fields.PSObject.Properties) { $f[$q.Name] = "$($q.Value)" } }
        $h[$p.Name] = @{ State = "$($p.Value.State)"; Fields = $f }
    }
    return $h
}

function Show-AdmxDialog([string]$AdmxPath)
{
    # Window to choose settings from an ADMX. Saves them as <name>-settings.reg (component) in the app folder,
    # with the ADMX, ADML and the choices in the subfolder _admx (so you can later continue where you left off).
    $dir = Get-AppFolder
    if (-not $dir) { return }
    Set-Status "Reading ADMX: $(Split-Path $AdmxPath -Leaf)..."
    try { $admx = Read-Admx $AdmxPath }
    catch { Show-Error "This ADMX can't be read:`n`n$($_.Exception.Message)"; return }
    if (-not $admx.Policies.Count) { Show-Error 'This ADMX contains no settings.'; return }
    $base = $admx.Name
    $choicesPath = Join-Path (Join-Path $dir '_admx') "$base.choices.json"
    $oldChoicesPath = Join-Path (Join-Path $dir '_admx') "$base.keuzes.json"   # name in versions before 1.3
    $readPath = if (Test-Path -LiteralPath $choicesPath) { $choicesPath } else { $oldChoicesPath }
    $script:AdmxChoices = @{}
    if (Test-Path -LiteralPath $readPath)
    {
        try { $script:AdmxChoices = ConvertTo-AdmxChoices ((Get-Content -LiteralPath $readPath -Raw -Encoding UTF8 | ConvertFrom-Json).Choices) } catch { }
    }
    $script:Admx = $admx
    $script:AdmxCurrent = $null
    $script:AdmxControls = @{}

    [xml]$x = $AdmxXaml.Replace('<!--THEME-->', $ThemeXaml)
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $w.Owner = $Window; $w.Icon = $Window.Icon
    $a = @{}
    foreach ($n in 'TxtAdmxTitle', 'BtnAdmxCancel', 'BtnAdmxSave', 'TxtAdmxCount', 'TxtAdmxFilter', 'ChkAdmxChosen', 'LstAdmx', 'TxtAdmxPolicy', 'TxtAdmxCat',
                   'PnlAdmxState', 'OptAdmxNot', 'OptAdmxOn', 'OptAdmxOff', 'TxtAdmxUserOnly', 'PnlAdmxFields', 'TxtAdmxReg', 'TxtAdmxExplain') { $a[$n] = $w.FindName($n) }
    $script:AdmxUi = $a
    $a.TxtAdmxTitle.Text = "Settings from $base.admx$(if (-not $admx.AdmlPath) { '  (no ADML found: names without explanation)' })"
    Set-Status ''

    $script:AdmxSaveCurrent = {
        # Keep the fields of the shown setting in the choices
        $pol = $script:AdmxCurrent
        if (-not $pol) { return }
        $u = $script:AdmxUi
        $state = if ($u.OptAdmxOn.IsChecked) { 'Enabled' } elseif ($u.OptAdmxOff.IsChecked) { 'Disabled' } else { '' }
        if (-not $state) { $script:AdmxChoices.Remove($pol.Id); return }
        $fields = @{}
        foreach ($el in $pol.Elements)
        {
            $c = $script:AdmxControls[$el.Id]; if (-not $c) { continue }
            $fields[$el.Id] = if ($c -is [System.Windows.Controls.CheckBox]) { "$([bool]$c.IsChecked)" } elseif ($c -is [System.Windows.Controls.ComboBox]) { "$($c.SelectedItem)" } else { "$($c.Text)" }
        }
        $script:AdmxChoices[$pol.Id] = @{ State = $state; Fields = $fields }
    }
    $script:AdmxUpdateCount = {
        $n = @($script:AdmxChoices.Keys).Count
        $script:AdmxUi.TxtAdmxCount.Text = if ($n) { "$n setting$(if ($n -ne 1) { 's' }) selected" } else { 'Nothing chosen yet' }
    }
    $script:AdmxShowReg = {
        # Preview of the registry values of the shown setting
        $pol = $script:AdmxCurrent; $u = $script:AdmxUi
        if (-not $pol) { $u.TxtAdmxReg.Text = ''; return }
        & $script:AdmxSaveCurrent
        if (-not $script:AdmxChoices.ContainsKey($pol.Id)) { $u.TxtAdmxReg.Text = "Register: HKLM\$($pol.Key)"; return }
        try
        {
            $lines = foreach ($e in (Get-AdmxRegEntries $pol $script:AdmxChoices[$pol.Id])) { "HKLM\$($e.Key)  " + (Format-RegValue $e.ValueName $e.Value) }
            $u.TxtAdmxReg.Text = (@($lines) | Select-Object -First 12) -join "`n"
        }
        catch { $u.TxtAdmxReg.Text = "Check the values: $($_.Exception.Message)" }
        & $script:AdmxUpdateCount
    }
    $script:AdmxFill = {
        # Fill the list on the left again (search / only chosen)
        $u = $script:AdmxUi
        $q = $u.TxtAdmxFilter.Text.Trim()
        $items = foreach ($p in $script:Admx.Policies)
        {
            $chosen = $script:AdmxChoices.ContainsKey($p.Id)
            if ($u.ChkAdmxChosen.IsChecked -and -not $chosen) { continue }
            if ($q -and -not ("$($p.Name) $($p.Category) $($p.Id) $($p.ValueName)" -like "*$q*")) { continue }
            $mark = if ($chosen) { if ($script:AdmxChoices[$p.Id].State -eq 'Enabled') { [char]0x2713 + ' ' } else { [char]0x2715 + ' ' } } else { '' }
            [pscustomobject]@{ Display = "$mark$($p.Name)"; Sub = $p.Category; Weight = $(if ($chosen) { 'SemiBold' } else { 'Normal' }); Id = $p.Id }
        }
        $u.LstAdmx.ItemsSource = @($items | Sort-Object Sub, Display)
    }
    $script:AdmxShow = {
        param($Policy)
        $u = $script:AdmxUi
        $script:AdmxCurrent = $null   # don't save while building up
        $script:AdmxControls = @{}
        $u.PnlAdmxFields.Children.Clear()
        $u.TxtAdmxPolicy.Text = $Policy.Name
        $u.TxtAdmxCat.Text = (@($Policy.Category, "($($Policy.Id))") | Where-Object { $_ }) -join '  '
        $u.TxtAdmxExplain.Text = $Policy.Explain
        $userOnly = $Policy.Class -eq 'User'
        $u.TxtAdmxUserOnly.Visibility = if ($userOnly) { 'Visible' } else { 'Collapsed' }
        $u.PnlAdmxState.Visibility = 'Visible'
        $u.PnlAdmxState.IsEnabled = -not $userOnly
        $ch = if ($script:AdmxChoices.ContainsKey($Policy.Id)) { $script:AdmxChoices[$Policy.Id] } else { $null }
        $u.OptAdmxOn.IsChecked = ($ch -and $ch.State -eq 'Enabled'); $u.OptAdmxOff.IsChecked = ($ch -and $ch.State -eq 'Disabled'); $u.OptAdmxNot.IsChecked = -not $ch
        foreach ($el in $Policy.Elements)
        {
            $val = if ($ch -and $ch.Fields -and $ch.Fields.ContainsKey($el.Id)) { $ch.Fields[$el.Id] } else { $null }
            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = $el.Label + $(if ($el.Required) { ' *' } else { '' }); $lbl.TextWrapping = 'Wrap'; $lbl.Margin = '0,6,0,3'; $lbl.FontWeight = 'SemiBold'
            switch ($el.Type)
            {
                'boolean'
                {
                    $c = New-Object System.Windows.Controls.CheckBox; $c.Content = $el.Label; $c.Margin = '0,6,0,2'
                    $c.IsChecked = ("$val" -match '^(?i)true$'); $c.Add_Click({ & $script:AdmxShowReg })
                    $lbl = $null
                }
                'enum'
                {
                    $c = New-Object System.Windows.Controls.ComboBox; $c.Width = 360; $c.HorizontalAlignment = 'Left'
                    foreach ($it in $el.Items) { [void]$c.Items.Add($it.Name) }
                    $c.SelectedItem = if ($val) { $val } elseif ($el.Items.Count) { $el.Items[0].Name } else { $null }
                    $c.Add_SelectionChanged({ & $script:AdmxShowReg })
                }
                default
                {
                    $c = New-Object System.Windows.Controls.TextBox
                    if ($el.Type -in 'list', 'multiText') { $c.AcceptsReturn = $true; $c.MinHeight = 90; $c.TextWrapping = 'NoWrap'; $c.VerticalScrollBarVisibility = 'Auto' }
                    if ($el.Type -in 'decimal', 'longDecimal') { $c.Width = 160; $c.HorizontalAlignment = 'Left' }
                    $c.Text = "$val"
                    $c.Add_LostFocus({ & $script:AdmxShowReg })
                }
            }
            if ($lbl) { [void]$u.PnlAdmxFields.Children.Add($lbl) }
            [void]$u.PnlAdmxFields.Children.Add($c)
            $hint = switch ($el.Type)
            {
                'list'        { if ($el.ExplicitValue) { 'One per line, as name=value.' } else { 'One value per line.' } }
                'multiText'   { 'One line per value.' }
                'decimal'     { "A number$(if ($el.Min -or $el.Max) { " ($($el.Min) to $($el.Max))" })." }
                'longDecimal' { 'A number.' }
                default       { '' }
            }
            if ($hint) { $h = New-Object System.Windows.Controls.TextBlock; $h.Text = $hint; $h.Foreground = '#6B7280'; $h.FontSize = 11.5; $h.Margin = '0,2,0,0'; [void]$u.PnlAdmxFields.Children.Add($h) }
            $script:AdmxControls[$el.Id] = $c
        }
        $u.PnlAdmxFields.IsEnabled = [bool]$u.OptAdmxOn.IsChecked
        $script:AdmxCurrent = $Policy
        & $script:AdmxShowReg
    }

    $stateChanged = {
        $u = $script:AdmxUi
        $u.PnlAdmxFields.IsEnabled = [bool]$u.OptAdmxOn.IsChecked
        if ($script:AdmxCurrent) { & $script:AdmxShowReg; & $script:AdmxFill; Select-AdmxListItem $script:AdmxCurrent.Id }
    }
    $a.OptAdmxOn.Add_Checked($stateChanged); $a.OptAdmxOff.Add_Checked($stateChanged); $a.OptAdmxNot.Add_Checked($stateChanged)
    $a.LstAdmx.Add_SelectionChanged({
        $sel = $script:AdmxUi.LstAdmx.SelectedItem
        if (-not $sel -or ($script:AdmxCurrent -and $sel.Id -eq $script:AdmxCurrent.Id)) { return }
        & $script:AdmxSaveCurrent
        $pol = $script:Admx.Policies | Where-Object { $_.Id -eq $sel.Id } | Select-Object -First 1
        if ($pol) { & $script:AdmxShow $pol }
    })
    $a.TxtAdmxFilter.Add_TextChanged({ & $script:AdmxFill })
    $a.ChkAdmxChosen.Add_Click({ & $script:AdmxSaveCurrent; & $script:AdmxFill })
    $a.BtnAdmxCancel.Add_Click({ $w.Close() })
    $script:AdmxSaved = $false
    $a.BtnAdmxSave.Add_Click({
        & $script:AdmxSaveCurrent
        # Required fields of enabled settings filled in?
        foreach ($id in @($script:AdmxChoices.Keys))
        {
            $ch = $script:AdmxChoices[$id]; if ($ch.State -ne 'Enabled') { continue }
            $pol = $script:Admx.Policies | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            foreach ($el in @($pol.Elements | Where-Object { $_.Required -and $_.Type -ne 'boolean' }))
            {
                if (-not "$($ch.Fields[$el.Id])".Trim())
                {
                    [void][System.Windows.MessageBox]::Show($w, "Fill in the field '$($el.Label)' for '$($pol.Name)'.", 'Settings from ADMX', 'OK', 'Warning'); return
                }
            }
            try { [void](Get-AdmxRegEntries $pol $ch) }
            catch { [void][System.Windows.MessageBox]::Show($w, "A value for '$($pol.Name)' is not correct: $($_.Exception.Message)", 'Settings from ADMX', 'OK', 'Warning'); return }
        }
        $script:AdmxSaved = $true
        $w.Close()
    })

    & $script:AdmxFill
    & $script:AdmxUpdateCount
    [void]$w.ShowDialog()
    if (-not $script:AdmxSaved) { return }

    # ---------- Save ----------
    $regName = "$base-settings.reg"
    # An app from a version before 1.3 already has <name>-instellingen.reg as a component: keep that name
    if ($script:Components | Where-Object { $_.File -eq "$base-instellingen.reg" }) { $regName = "$base-instellingen.reg" }
    $regPath = Join-Path $dir $regName
    $store = Join-Path $dir '_admx'
    New-Item -Path $store -ItemType Directory -Force | Out-Null
    # Keep the ADMX and ADML with the app (not in the package for the laptop; but in the source of every build)
    $admxDest = Join-Path $store (Split-Path $AdmxPath -Leaf)
    if ([System.IO.Path]::GetFullPath($AdmxPath) -ine [System.IO.Path]::GetFullPath($admxDest)) { Copy-Item -LiteralPath $AdmxPath -Destination $admxDest -Force }
    if ($admx.AdmlPath)
    {
        $lang = Split-Path (Split-Path $admx.AdmlPath -Parent) -Leaf
        $admlDir = if ($lang -match '^[a-z]{2}-[A-Z]{2}$') { Join-Path $store $lang } else { $store }
        New-Item -Path $admlDir -ItemType Directory -Force | Out-Null
        $admlDest = Join-Path $admlDir (Split-Path $admx.AdmlPath -Leaf)
        if ([System.IO.Path]::GetFullPath($admx.AdmlPath) -ine [System.IO.Path]::GetFullPath($admlDest)) { Copy-Item -LiteralPath $admx.AdmlPath -Destination $admlDest -Force }
    }
    $json = [ordered]@{ AdmxFile = (Split-Path $AdmxPath -Leaf); Saved = (Get-Date -Format 's'); Choices = $script:AdmxChoices } | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($choicesPath, $json, (New-Object System.Text.UTF8Encoding $false))
    if (Test-Path -LiteralPath $oldChoicesPath) { Remove-Item -LiteralPath $oldChoicesPath -Force -ErrorAction SilentlyContinue }

    if (-not @($script:AdmxChoices.Keys).Count)
    {
        # Nothing chosen anymore: remove the registry file and the component
        $row = $script:Components | Where-Object { $_.File -eq $regName } | Select-Object -First 1
        if ($row) { [void]$script:Components.Remove($row) }
        Remove-Item -LiteralPath $regPath -Force -ErrorAction SilentlyContinue
        Update-InstallPreview; Update-FileList
        Set-Status "No more settings from $base.admx: $regName has been removed."
        return
    }
    [System.IO.File]::WriteAllText($regPath, (ConvertTo-AdmxRegText $admx $script:AdmxChoices), [System.Text.Encoding]::Unicode)
    [void](Add-ComponentFile $regPath $false)
    # Install the settings after the app: put the component after the main component
    $row = $script:Components | Where-Object { $_.File -eq $regName } | Select-Object -First 1
    if ($row) { $i = $script:Components.IndexOf($row); if ($i -ne $script:Components.Count - 1) { $script:Components.Move($i, $script:Components.Count - 1) } }
    # Make the uninstall steps for this file again (the values may have changed)
    $ut = "$($ui.TxtUninstallCmd.Text)"
    if ($ut -match "(?m)^rem (?:Onderdeel|Component): $([regex]::Escape($regName)) (?:ongedaan maken|undo)")
    {
        $ui.TxtUninstallCmd.Text = [regex]::Replace($ut, "(?ms)^rem (?:Onderdeel|Component): $([regex]::Escape($regName)) (?:ongedaan maken|undo)\r?\n.*?(\r?\n\r?\n|\z)", '')
    }
    Update-InstallPreview; Update-FileList
    Set-Status "$(@($script:AdmxChoices.Keys).Count) setting(s) from $base.admx saved in $regName (component, after the app)."
}

function Select-AdmxListItem([string]$Id)
{
    $lst = $script:AdmxUi.LstAdmx
    $it = @($lst.ItemsSource) | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if ($it) { $script:AdmxSkipSelect = $true; $lst.SelectedItem = $it; $lst.ScrollIntoView($it) }
}

function Get-SavedAdmx
{
    # ADMX files of this app whose choices are saved (in _admx): Base, AdmxPath, File, Count
    $dir = Get-AppFolder
    if (-not $dir) { return }
    $store = Join-Path $dir '_admx'
    if (-not (Test-Path -LiteralPath $store)) { return }
    $seen = @{}
    foreach ($f in @(Get-ChildItem -LiteralPath $store -File | Where-Object { $_.Name -match '\.(choices|keuzes)\.json$' } | Sort-Object Name))
    {
        $fb = $f.Name -replace '\.(choices|keuzes)\.json$', ''
        if ($seen.ContainsKey($fb)) { continue }; $seen[$fb] = $true
        try { $j = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
        if (-not $j.AdmxFile) { continue }
        $admxPath = Join-Path $store "$($j.AdmxFile)"
        if (-not (Test-Path -LiteralPath $admxPath)) { continue }
        $count = if ($j.Choices) { @($j.Choices.PSObject.Properties).Count } else { 0 }
        [pscustomobject]@{ Base = $fb; AdmxPath = $admxPath; File = "$($j.AdmxFile)"; Count = $count }
    }
}

function Select-AdmxFile
{
    # Choose an (other) ADMX and open its settings
    $dir = Get-AppFolder
    if (-not $dir) { Show-Error 'Choose or create an app first.'; return }
    $store = Join-Path $dir '_admx'
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'ADMX file (*.admx)|*.admx'
    $dlg.Title = 'Choose the ADMX of the app (the ADML in the language folder next to it is found automatically)'
    if (Test-Path -LiteralPath $store) { $dlg.InitialDirectory = $store } else { Set-StartFolder $dlg }
    if (-not $dlg.ShowDialog()) { return }
    Show-AdmxDialog $dlg.FileName
}

function Start-AdmxImport
{
    # Button 'Settings from ADMX...': edit settings already chosen, or import an (other) ADMX
    if (-not (Get-AppFolder)) { Show-Error 'Choose or create an app first.'; return }
    $saved = @(Get-SavedAdmx)
    if (-not $saved.Count) { Select-AdmxFile; return }
    $menu = New-Object System.Windows.Controls.ContextMenu
    foreach ($s in $saved)
    {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = "Edit: $($s.File)  ($($s.Count) chosen)"
        $mi.Tag = $s.AdmxPath
        $mi.Add_Click({ Show-AdmxDialog "$($this.Tag)" })
        [void]$menu.Items.Add($mi)
    }
    [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
    $other = New-Object System.Windows.Controls.MenuItem
    $other.Header = 'Import another ADMX...'
    $other.Add_Click({ Select-AdmxFile })
    [void]$menu.Items.Add($other)
    $menu.PlacementTarget = $ui.BtnAdmx
    $menu.Placement = 'Bottom'
    $menu.IsOpen = $true
}

function Get-AdmxForRow($Row)
{
    # Is this row the registry file from an ADMX (<name>-settings.reg)? Then the saved ADMX, otherwise $null
    if (-not $Row -or "$($Row.File)" -notmatch '^(.+)-(settings|instellingen)\.reg$') { return $null }
    $base = $Matches[1]
    return (@(Get-SavedAdmx) | Where-Object { $_.Base -eq $base } | Select-Object -First 1)
}

function Show-FileActionDialog([string]$Name, [int]$Others)
{
    # Asks what should happen with an added file. Returns @{ Action; Target; All }, or $null for Skip.
    [xml]$x = $FileActionXaml.Replace('<!--THEME-->', $ThemeXaml)
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $w.Owner = $Window; $w.Icon = $Window.Icon
    $f = @{}
    foreach ($n in 'TxtTitle', 'OptComp', 'OptCopy', 'OptKeep', 'TxtTarget', 'ChkAll', 'BtnOk', 'BtnCancel') { $f[$n] = $w.FindName($n) }
    $f.TxtTitle.Text = "What should the installation do with $($Name)?"
    $isInstaller = Test-InstallerFile $Name
    $f.OptComp.IsEnabled = $isInstaller
    if (-not $isInstaller) { $f.OptComp.Content = 'Install as a component (only for .exe, .msi, .msp, .ps1, .cmd, .bat and .reg)' }
    if ([System.IO.Path]::GetExtension($Name).ToLower() -in @('.exe', '.msi', '.msp')) { $f.OptComp.IsChecked = $true } else { $f.OptCopy.IsChecked = $true }
    $appName = if ($ui.TxtAppName.Text.Trim()) { $ui.TxtAppName.Text.Trim() } else { "$script:CurrentApp" }
    $f.TxtTarget.Text = "%ProgramData%\$appName"
    $f.TxtTarget.IsEnabled = [bool]$f.OptCopy.IsChecked
    $f.OptCopy.Add_Checked({ $f.TxtTarget.IsEnabled = $true })
    $f.OptCopy.Add_Unchecked({ $f.TxtTarget.IsEnabled = $false })
    if ($Others -gt 0) { $f.ChkAll.Content = "Do the same with the other $Others chosen file$(if ($Others -gt 1) { 's' })" }
    else { $f.ChkAll.Visibility = 'Collapsed' }
    $script:FileActionResult = $null
    $f.BtnOk.Add_Click({
        $action = if ($f.OptComp.IsChecked) { 'Component' } elseif ($f.OptCopy.IsChecked) { 'CopyTo' } else { 'KeepOnly' }
        if ($action -eq 'CopyTo' -and -not $f.TxtTarget.Text.Trim())
        {
            [void][System.Windows.MessageBox]::Show($w, 'Fill in the folder the file should go to.', 'Add file', 'OK', 'Warning'); return
        }
        $script:FileActionResult = @{ Action = $action; Target = $f.TxtTarget.Text.Trim(); All = [bool]$f.ChkAll.IsChecked }
        $w.Close()
    })
    $f.BtnCancel.Add_Click({ $w.Close() })
    [void]$w.ShowDialog()
    return $script:FileActionResult
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
            HasSource   = $v.HasSource
            BuiltText = $v.Built.ToString('dd-MM-yyyy HH:mm')
            PkgText   = if ($v.HasPkg) { "$($v.SizeMB) MB" } else { 'no' }
            SourceText  = if ($v.HasSource) { 'yes' } else { 'no' }
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
        $ui.TxtVerTitle.Text = 'Choose a version on the left'
        $ui.TxtVerSub.Text = ''
        foreach ($n in 'TxtVerSummary', 'TxtVerInstall', 'TxtVerTexts', 'TxtVerBuildInfo') { $ui[$n].Text = '' }
        return
    }
    $det = Get-VersionDetails $v.Path
    $script:SelectedVersion = $det
    $ui.PnlVerDetails.IsEnabled = $true
    $ui.TxtVerTitle.Text = "$(if ($det.Data) { $det.Data.AppName } else { $script:CurrentApp }) $($v.Version)"
    $ui.TxtVerSub.Text = "Built on $($v.BuiltText)  |  install.intunewin: $($v.PkgText)" +
                         $(if ($v.IsArchive) { '  |  earlier build, rebuilt later' } else { '' }) +
                         $(if (-not $v.HasInstallers) { '  |  installers not kept (old build)' } else { '' })

    $summary = $det.Summary
    if ($det.Data)
    {
        $installNow = $ui.TxtInstallCmd.Text
        $installOld = if (Test-Path (Join-Path $v.Path 'Bron\install-app.cmd')) { [System.IO.File]::ReadAllText((Join-Path $v.Path 'Bron\install-app.cmd')) } else { '' }
        $diff = @(Compare-AppData $det.Data (Read-Form) $installOld $installNow)
        $summary += "`r`n`r`n---------- Differences with what is in the Builder now ----------`r`n"
        $summary += if ($diff.Count) { ($diff | ForEach-Object { "- $_" }) -join "`r`n" } else { 'No differences.' }
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
    if (-not $v) { Show-Error 'Select a version in the list first.' }
    return $v
}

function Show-DefaultTextsEditor
{
    # Small window to edit _Kit\DefaultTexts.psd1 (applies to all apps)
    [xml]$x = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Default texts for all apps" Width="760" Height="680" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" FontSize="13" Background="#F4F6F9" Foreground="#1F2937" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
<!--THEME-->
  </Window.Resources>
  <DockPanel Margin="16">
    <TextBlock DockPanel.Dock="Top" TextWrapping="Wrap" Margin="0,0,0,10">Every app uses these texts, unless you enter its own text for an app in tab 3. You can use {AppName}, {Version}, {Minutes} and {MaxPostpones}. Rebuild the packages afterwards.</TextBlock>
    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
      <Button Name="BtnReset" Content="Restore built-in texts"/>
      <Button Name="BtnCancel" Content="Cancel"/>
      <Button Name="BtnOk" Content="Save" Style="{StaticResource Primary}" Margin="0"/>
    </StackPanel>
    <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel Name="Pnl"/></ScrollViewer>
  </DockPanel>
</Window>
'@
    $x = [xml]$x.OuterXml.Replace('<!--THEME-->', $ThemeXaml)
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $w.Owner = $Window
    $w.Icon = $Window.Icon
    $boxes = @{}
    $std = Get-DefaultTexts
    foreach ($k in $TextKeys)
    {
        $l = New-Object System.Windows.Controls.Label; $l.Content = $TextLabels[$k]; $l.FontWeight = 'SemiBold'; $l.Padding = '0,6,0,2'
        $b = New-Object System.Windows.Controls.TextBox; $b.Text = $std[$k]; $b.TextWrapping = 'Wrap'; $b.Padding = '6,4'
        if ($k -like '*Message' -or $k -eq 'ForcedInfo') { $b.MinHeight = 48 }
        [void]$w.FindName('Pnl').Children.Add($l); [void]$w.FindName('Pnl').Children.Add($b)
        $boxes[$k] = $b
    }
    $w.FindName('BtnReset').Add_Click({ $bt = Get-BuiltinTexts $script:TextLang; foreach ($k in $TextKeys) { $boxes[$k].Text = $bt[$k] } })
    $w.FindName('BtnCancel').Add_Click({ $w.Close() })
    $w.FindName('BtnOk').Add_Click({
        $texts = @{}
        foreach ($k in $TextKeys) { $texts[$k] = $boxes[$k].Text.Trim() }
        [System.IO.File]::WriteAllText((Get-DefaultTextsPath $script:TextLang), (ConvertTo-DefaultTextsPsd1 $texts), (New-Object System.Text.UTF8Encoding $true))
        Update-TextHints
        Set-Status 'Default texts saved. Rebuild the packages to use them.'
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

$DayBoxes = [ordered]@{ 'mon' = 'ChkDayMa'; 'tue' = 'ChkDayDi'; 'wed' = 'ChkDayWo'; 'thu' = 'ChkDayDo'; 'fri' = 'ChkDayVr'; 'sat' = 'ChkDayZa'; 'sun' = 'ChkDayZo' }

function Set-ComboByTag($Combo, [string]$Tag)
{
    foreach ($item in $Combo.Items) { if ([string]$item.Tag -eq $Tag) { $Combo.SelectedItem = $item; return } }
    $Combo.SelectedIndex = 0
}

function Update-WindowHint
{
    $tag = [string]$ui.CmbWindow.SelectedItem.Tag
    $ui.PnlWorkTime.IsEnabled = $tag -ne 'Always'
    $ui.PnlWorkTime.Opacity   = if ($tag -eq 'Always') { 0.45 } else { 1 }
    $ui.TxtIdleMinutes.IsEnabled = [bool]$ui.ChkIdle.IsChecked
    $ui.TxtWindowHint.Text = switch ($tag)
    {
        'DuringWorkHours'       { 'The popup and the installation only come on the chosen days, within one of the time blocks. Outside them the update waits for the next block.' }
        'OutsideWorkHours' { "The update only comes outside the time blocks and on the days that aren't ticked, for example in the evening, at night and at the weekend. Note: laptops are often off or asleep then. The update only comes when the device is on outside working hours." }
        default          { 'The popup can come at any time of day.' }
    }
}

function Update-DetectPanels
{
    $m = [string]$ui.CmbDetect.SelectedItem.Tag
    $ui.PnlDetectFile.Visibility    = if ($m -eq 'File') { 'Visible' } else { 'Collapsed' }
    $ui.PnlDetectReg.Visibility     = if ($m -eq 'Registry') { 'Visible' } else { 'Collapsed' }
    $ui.PnlDetectScript.Visibility  = if ($m -eq 'Script') { 'Visible' } else { 'Collapsed' }
    $ver = if ($m -eq 'Script') { 'Collapsed' } else { 'Visible' }
    $ui.PnlDetectVersion.Visibility = $ver; $ui.TxtDetectVersionHint.Visibility = $ver
    $ui.TxtDetectVersion.IsEnabled  = -not $ui.ChkDetectAnyVersion.IsChecked
    $ui.TxtDetectHint.Text = switch ($m)
    {
        'File'  { 'Detected if the file exists and the file version is at least the version below.' }
        'Registry' { 'Detected if the registry key (and value) exists and the value is at least the version below.' }
        'Script'   { 'Your own PowerShell script becomes the detection script for Intune.' }
        default    { "Detected if Apps & features contains an app whose name starts with '$($ui.TxtDetectName.Text.Trim())' (field above), with at least the version below." }
    }
    $ui.TxtDetectResult.Text = ''
}

function Set-DetectionFromMsi($Info)
{
    # For an MSI fill in the detection: the uninstall key of the product code, DisplayVersion, at least the ProductVersion
    if (-not $Info.ProductCode) { return }
    $key = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($Info.ProductCode)"
    $m = [string]$ui.CmbDetect.SelectedItem.Tag
    $isDefault    = $m -eq 'AppsAndFeatures' -and -not $ui.TxtDetectVersion.Text.Trim() -and -not $ui.ChkDetectAnyVersion.IsChecked
    $isEarlierMsi = $m -eq 'Registry' -and $ui.TxtDetectRegKey.Text.Trim() -match '\\Uninstall\\\{[0-9A-Fa-f-]{36}\}\\?$' -and $ui.TxtDetectRegValue.Text.Trim() -eq 'DisplayVersion'
    if ($ui.TxtDetectRegKey.Text.Trim().TrimEnd('\') -eq $key -and $m -eq 'Registry') { return }
    if (-not ($isDefault -or $isEarlierMsi))
    {
        $q = "From the MSI: product code $($Info.ProductCode), version $($Info.Version).`n`n" +
             "Set detection to:`n$key`nvalue DisplayVersion, at least $($Info.Version)?`n`nYour current detection setting will be replaced."
        if ([System.Windows.MessageBox]::Show($q, 'Detection from the MSI', 'YesNo', 'Question') -ne 'Yes') { return }
    }
    Set-ComboByTag $ui.CmbDetect 'Registry'
    $ui.TxtDetectRegKey.Text   = $key
    $ui.TxtDetectRegValue.Text = 'DisplayVersion'
    $ui.ChkDetectAnyVersion.IsChecked = $false
    $ui.TxtDetectVersion.Text  = ''        # empty = the version of the package (= ProductVersion from the MSI)
    Update-DetectPanels
    $ui.TxtDetectResult.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#555555')
    $ui.TxtDetectResult.Text = "  Detection filled in from the MSI (product code $($Info.ProductCode)). Click Test on this PC if this version is already installed here."
}

function Update-RestartPanel
{
    $on = [string]$ui.CmbRestart.SelectedItem.Tag -ne 'Never'
    $ui.PnlRestart.IsEnabled = $on
    $ui.PnlRestart.Opacity   = if ($on) { 1 } else { 0.45 }
}

function Read-Form
{
    $texts = @{}
    foreach ($k in $TextKeys) { $texts[$k] = $script:TextBoxes[$k].Text.Trim() }
    return @{
        AppId                 = $ui.TxtAppId.Text.Trim()
        AppName               = $ui.TxtAppName.Text.Trim()
        Version               = $ui.TxtVersion.Text.Trim()
        DetectName            = $ui.TxtDetectName.Text.Trim()
        OutputFolder          = $ui.TxtOutputFolder.Text.Trim()
        Processes             = @($ui.TxtProcesses.Text -split '[,;]' | ForEach-Object { ($_.Trim() -replace '\.exe$', '') } | Where-Object { $_ })
        Icon                  = 'app.ico'
        AccentColor           = if ($ui.TxtAccent.Text.Trim()) { $ui.TxtAccent.Text.Trim() } else { '#185FA5' }   # empty = default colour
        Language              = $(if ($ui.CmbTextLang.SelectedItem) { [string]$ui.CmbTextLang.SelectedItem.Tag } else { $ThisBuilderLang })
        OnlyUpdateExisting    = [bool]$ui.ChkOnlyExisting.IsChecked
        DetectionMethod       = [string]$ui.CmbDetect.SelectedItem.Tag
        DetectVersion         = if ($ui.ChkDetectAnyVersion.IsChecked) { '-' } else { $ui.TxtDetectVersion.Text.Trim() }
        DetectFile            = $ui.TxtDetectFile.Text.Trim()
        DetectRegKey          = $ui.TxtDetectRegKey.Text.Trim()
        DetectRegValue        = $ui.TxtDetectRegValue.Text.Trim()
        DetectScript          = $ui.TxtDetectScript.Text.TrimEnd()
        InstallDuringSetup    = [bool]$ui.ChkDuringSetup.IsChecked
        MaxPostpones          = $ui.TxtMaxPostpones.Text.Trim()
        PostponeHours         = $ui.TxtPostponeHours.Text.Trim()
        ConsentTimeoutMinutes = $ui.TxtConsentTimeout.Text.Trim()
        ForcedDelayMinutes    = $ui.TxtForcedMinutes.Text.Trim()
        InstallWindow         = [string]$ui.CmbWindow.SelectedItem.Tag
        WorkHours             = (($ui.TxtWorkHours.Text -split '[,;]') | ForEach-Object { $_ -replace '\s', '' } | Where-Object { $_ }) -join ','
        WorkDays              = (@($DayBoxes.Keys | Where-Object { $ui[$DayBoxes[$_]].IsChecked }) -join ',')
        IdleMinutes           = if ($ui.ChkIdle.IsChecked) { $ui.TxtIdleMinutes.Text.Trim() } else { '0' }
        NoUserAction          = [string]$ui.CmbNoUser.SelectedItem.Tag
        RestartMode            = [string]$ui.CmbRestart.SelectedItem.Tag
        RestartReminderMinutes = $ui.TxtRestartReminder.Text.Trim()
        RestartDeadlineHours   = $ui.TxtRestartDeadline.Text.Trim()
        RestartWarningMinutes  = $ui.TxtRestartWarning.Text.Trim()
        UninstallNotify        = [bool]$ui.ChkUninstallNotify.IsChecked
        Texts                 = $texts
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
    catch { Show-Error "app.psd1 of $AppId can't be read:`n$($_.Exception.Message)"; return }

    $script:CurrentApp = $AppId; $script:LastInstallerPath = $null   # other app: determine the start folder again
    $ui.Tabs.IsEnabled = $true
    $ui.TxtAppId.Text       = $d.AppId
    $ui.TxtAppName.Text     = $d.AppName
    $ui.TxtVersion.Text     = $d.Version
    $ui.TxtDetectName.Text  = $d.DetectName
    $ui.TxtProcesses.Text   = (@($d.Processes) -join ', ')
    $ui.TxtOutputFolder.Text = "$($d.OutputFolder)"
    $ui.TxtAccent.Text      = if ($d.AccentColor) { $d.AccentColor } else { '#185FA5' }
    $ui.ChkOnlyExisting.IsChecked = if ($null -eq $d.OnlyUpdateExisting) { $true } else { [bool]$d.OnlyUpdateExisting }
    $ui.ChkDuringSetup.IsChecked  = $d.InstallDuringSetup -ne $false
    $ui.TxtMaxPostpones.Text   = if ($null -ne $d.MaxPostpones) { $d.MaxPostpones } else { 5 }
    $ui.TxtPostponeHours.Text  = if ($null -ne $d.PostponeHours) { $d.PostponeHours } else { 24 }
    $ui.TxtConsentTimeout.Text = if ($null -ne $d.ConsentTimeoutMinutes) { $d.ConsentTimeoutMinutes }
                                 elseif ($null -ne $d.ConsentTimeoutSeconds) { [math]::Max(1, [math]::Round($d.ConsentTimeoutSeconds / 60)) }
                                 else { 15 }
    $ui.TxtForcedMinutes.Text  = if ($null -ne $d.ForcedDelayMinutes) { $d.ForcedDelayMinutes } else { 5 }
    Set-ComboByTag $ui.CmbWindow $(if ($d.InstallWindow) { $d.InstallWindow } else { 'Always' })
    # Language on the laptop (older apps without Language: Dutch)
    $script:TextLang = if ("$($d.Language)" -eq 'en') { 'en' } else { 'nl' }
    Set-ComboByTag $ui.CmbTextLang $script:TextLang
    Update-TextHints
    Set-ComboByTag $ui.CmbNoUser $(if ($d.NoUserAction) { $d.NoUserAction } else { 'Install' })
    $ui.TxtWorkHours.Text = if ($d.WorkHours) { ("$($d.WorkHours)" -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ', ' } else { '08:00-17:00' }
    $dayText = if ($d.WorkDays) { "$($d.WorkDays)".ToLower() } else { 'mon,tue,wed,thu,fri' }
    foreach ($k in $DayBoxes.Keys) { $ui[$DayBoxes[$k]].IsChecked = $dayText -match "(^|[,; ])$k" }
    $idle = [int]("0$($d.IdleMinutes)")
    $ui.ChkIdle.IsChecked = $idle -gt 0
    $ui.TxtIdleMinutes.Text = if ($idle -gt 0) { $idle } else { 30 }
    Update-WindowHint
    Set-ComboByTag $ui.CmbRestart $(if ($d.RestartMode) { $d.RestartMode } else { 'Never' })
    Set-ComboByTag $ui.CmbDetect $(if ($d.DetectionMethod) { $d.DetectionMethod } else { 'AppsAndFeatures' })
    $ui.ChkDetectAnyVersion.IsChecked = "$($d.DetectVersion)" -eq '-'
    $ui.TxtDetectVersion.Text  = if ("$($d.DetectVersion)" -eq '-') { '' } else { "$($d.DetectVersion)" }
    $ui.TxtDetectFile.Text     = "$($d.DetectFile)"
    $ui.TxtDetectRegKey.Text   = "$($d.DetectRegKey)"
    $ui.TxtDetectRegValue.Text = "$($d.DetectRegValue)"
    $ui.TxtDetectScript.Text   = "$($d.DetectScript)"
    Update-DetectPanels
    $ui.TxtRestartReminder.Text = if ($null -ne $d.RestartReminderMinutes) { $d.RestartReminderMinutes } else { 60 }
    $ui.TxtRestartDeadline.Text = if ($null -ne $d.RestartDeadlineHours) { $d.RestartDeadlineHours } else { 24 }
    $ui.TxtRestartWarning.Text  = if ($null -ne $d.RestartWarningMinutes) { $d.RestartWarningMinutes } else { 15 }
    Update-RestartPanel
    $ui.ChkUninstallNotify.IsChecked = $d.UninstallNotify -eq $true
    foreach ($k in $TextKeys) { $script:TextBoxes[$k].Text = if ($d.Texts -and $d.Texts[$k]) { $d.Texts[$k] } else { '' } }

    $ui.TxtInstallCmd.Text   = if (Test-Path (Join-Path $dir 'install-app.cmd')) { [System.IO.File]::ReadAllText((Join-Path $dir 'install-app.cmd')) } else { '' }
    $ui.TxtUninstallCmd.Text = if (Test-Path (Join-Path $dir 'uninstall-app.cmd')) { [System.IO.File]::ReadAllText((Join-Path $dir 'uninstall-app.cmd')) } else { '' }

    # Components and extra steps
    $script:Components.Clear()
    foreach ($c in @($d.Components)) { if ($c) { $script:Components.Add((New-ComponentRow $c)) } }
    $ui.TxtPreInstall.Text  = "$($d.PreInstall)"
    $ui.TxtPostInstall.Text = "$($d.PostInstall)"
    $isTemplate = $ui.TxtInstallCmd.Text -match '(?:MijnApp|MyApp)-Setup\.exe'
    # Create automatically only if there are components (or for a new app from the template);
    # an install-app.cmd written by hand without components is never overwritten.
    $auto = if ($null -ne $d.AutoInstallSteps) { [bool]$d.AutoInstallSteps } else { $script:Components.Count -gt 0 }
    if ($script:Components.Count -eq 0) { $auto = $isTemplate }
    $ui.ChkAutoSteps.IsChecked = $auto
    Update-InstallPreview

    # Main installer: the main component, otherwise the largest .exe/.msi in the folder
    $main = Get-MainComponent
    $inst = if ($main -and (Test-Path (Join-Path $dir $main.File))) { Get-Item (Join-Path $dir $main.File) }
            else { Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Sort-Object Length -Descending | Select-Object -First 1 }
    $ui.TxtInstaller.Text = if ($inst) { $inst.Name } else { '' }
    $ui.TxtInstallerInfo.Text = if ($inst) { 'Choose the installer again to have name, version and parameters recognised again.' } else { 'No installer chosen yet.' }
    $script:Info = @{ Kind = if ($inst -and $inst.Extension -eq '.msi') { 'MSI' } else { 'EXE' }; ProductCode = '' }

    Update-FileList; Update-IconPreview; Update-AccentPreview; Update-VersionList
    $ui.BtnOpenOutput.IsEnabled = (Test-Path (Join-Path (Join-Path $KitRoot 'Output') $AppId)) -or ($d.OutputFolder -and (Test-Path "$($d.OutputFolder)"))
    Set-Status "Loaded: $AppId"
}

function Save-App
{
    if (-not $script:CurrentApp) { return $false }
    Update-InstallPreview
    $d = Read-Form
    $errors = Test-AppData $d
    if ($errors) { Show-Error ("Check the following:`n`n- " + ($errors -join "`n- ")); return $false }

    $dir = Get-AppFolder
    [System.IO.File]::WriteAllText((Join-Path $dir 'app.psd1'), (ConvertTo-Psd1Text $d), (New-Object System.Text.UTF8Encoding $true))

    foreach ($pair in @(@('install-app.cmd', $ui.TxtInstallCmd.Text), @('uninstall-app.cmd', $ui.TxtUninstallCmd.Text)))
    {
        $txt = ($pair[1] -replace "`r?`n", "`r`n")
        if ($txt -match '[^\x00-\x7F]')
        {
            Show-Error "$($pair[0]) contains special characters (such as é or ï). cmd doesn't pass them on correctly; put such texts in tab 3."
        }
        [System.IO.File]::WriteAllText((Join-Path $dir $pair[0]), $txt, [System.Text.Encoding]::Default)
    }
    Set-Status "Saved: Apps\$($script:CurrentApp)"
    return $true
}

function Show-Preview([string]$Kind, [hashtable]$Data = $null, $Std = $null, [string]$IconPath = '')
{
    # Without -Data: what is in the form now. With -Data: an earlier built version.
    $d = $Data
    if (-not $d)
    {
        $d = Read-Form
        $dir = Get-AppFolder
        if ($dir) { $IconPath = Join-Path $dir 'app.ico' }
    }
    $newMode = [bool]($ui.ChkPrevNew -and $ui.ChkPrevNew.IsChecked)
    $cfg = @{
        AccentColor   = if ($d.AccentColor -match '^#[0-9A-Fa-f]{6}$') { $d.AccentColor } else { '#185FA5' }
        IconPath      = $IconPath
        Heading       = $d.AppName
        Sender        = $d.AppName
        ForcedMinutes = [int]("0$($d.ForcedDelayMinutes)")
        LaterHint     = $(if ($script:TextLang -eq 'en') { 'tomorrow' } else { 'morgen' })
    }
    # Texts in the previews in the language of the app (Language on the laptop), just like on the laptop
    $en = $script:TextLang -eq 'en'
    switch ($Kind)
    {
        'consent' { $cfg.Mode = 'consent'; $cfg.Remaining = 3; $cfg.TimeoutSeconds = 900; $cfg.IsNew = $newMode; if ($newMode) { $cfg.NowText = $(if ($en) { 'Install now' } else { 'Nu installeren' }) }
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'ConsentSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'ConsentMessage' $d $Std }
        'last'    { $cfg.Mode = 'consent'; $cfg.Remaining = 1; $cfg.TimeoutSeconds = 900; $cfg.IsNew = $newMode; if ($newMode) { $cfg.NowText = $(if ($en) { 'Install now' } else { 'Nu installeren' }) }
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'ConsentSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'ConsentMessage' $d $Std }
        'forced'  { $cfg.Mode = 'forced'; $cfg.TimeoutSeconds = [math]::Max(60, $cfg.ForcedMinutes * 60)
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'ForcedSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'ForcedMessage' $d $Std
                    $cfg.InfoText = Get-EffectiveText -New:$newMode 'ForcedInfo' $d $Std }
        'restart' { $cfg.Mode = 'consent'; $cfg.TimeoutSeconds = 900; $cfg.NowText = $(if ($en) { 'Restart now' } else { 'Nu herstarten' }); $cfg.LaterText = 'Later'
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'RestartSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'RestartMessage' $d $Std
                    $rem = [int]("0$($d.RestartReminderMinutes)"); if (-not $rem) { $rem = 60 }
                    $cfg.InfoOverride = if ($en) { "If you choose Later, we'll ask again $(if ($rem % 60 -eq 0) { "in $($rem / 60) hour(s)" } else { "in $rem minutes" })." }
                                        else { "Kies je Later, dan vragen we het $(if ($rem % 60 -eq 0) { "over $($rem / 60) uur" } else { "over $rem minuten" }) opnieuw." }
                    $cfg.TimeoutText = $(if ($en) { "If you don't choose, we'll ask again later ({time})." } else { "Maak je geen keuze, dan vragen we het later opnieuw ({time})." }) }
        'restartforced' {
                    $wm = [int]("0$($d.RestartWarningMinutes)"); if (-not $wm) { $wm = 15 }
                    $dw = @{} + $d; $dw.ForcedDelayMinutes = $wm      # {Minutes} = warning time before the restart
                    $cfg.Mode = 'forced'; $cfg.TimeoutSeconds = $wm * 60; $cfg.NowText = $(if ($en) { 'Restart now' } else { 'Nu herstarten' }); $cfg.InfoWarning = $true
                    $cfg.InfoOverride = $(if ($en) { 'Ready to restart? Save your work and click Restart now.' } else { "Klaar om te herstarten? Sla je werk op en klik op Nu herstarten." })
                    $cfg.CountdownText = $(if ($en) { 'The laptop restarts automatically in {time}.' } else { "De laptop herstart automatisch over {time}." })
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'RestartForcedSubHeading' $dw $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'RestartForcedMessage' $dw $Std }
        default   { $cfg.Mode = 'toast'; $cfg.AutoCloseSeconds = 30
                    $cfg.Type = @{ uninstalling = 'installing'; uninstalled = 'success' }[$Kind]; if (-not $cfg.Type) { $cfg.Type = $Kind }
                    $prefix = @{ installing = 'Installing'; success = 'Success'; error = 'Error'; uninstalling = 'Uninstalling'; uninstalled = 'Uninstalled' }[$Kind]
                    $cfg.Heading = Get-EffectiveText -New:$newMode "$($prefix)Heading" $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode "$($prefix)Message" $d $Std }
    }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "AppUI_preview_$(Get-Random).json"
    [System.IO.File]::WriteAllText($tmp, ($cfg | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
    # The popup as on the laptop: AppUI.ps1 in the language of the app
    $ui1 = Join-Path ([System.IO.Path]::GetTempPath()) "AppUI_preview_$($script:TextLang).ps1"
    [System.IO.File]::WriteAllText($ui1, (Get-KitFileText 'AppUI.ps1' $script:TextLang), (New-Object System.Text.UTF8Encoding $true))
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', "`"$ui1`"", '-ConfigPath', "`"$tmp`"")
    Set-Status 'Preview opened (bottom right of your screen). Close it with the buttons; nothing is installed.'
}

function Get-IntuneWinAppUtil
{
    $local = Join-Path $KitRoot 'IntuneWinAppUtil.exe'
    if (Test-Path $local) { return $local }
    $cmd = Get-Command IntuneWinAppUtil.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $r = [System.Windows.MessageBox]::Show(
        "IntuneWinAppUtil.exe (from Microsoft) is needed to create the .intunewin package, but isn't next to the Builder yet.`n`nDownload it now from GitHub (microsoft/Microsoft-Win32-Content-Prep-Tool)?",
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
        Show-Error "Download failed: $($_.Exception.Message)`n`nDownload IntuneWinAppUtil.exe manually and put it in $KitRoot."
        return $null
    }
}

$script:BuildProc = $null
$buildTimer = New-Object System.Windows.Threading.DispatcherTimer
$buildTimer.Interval = [TimeSpan]::FromMilliseconds(500)
function Read-SharedText([string]$Path)
{
    # Read while the build script is still writing to the file (ReadAllText would refuse then)
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
        $out = $script:BuildRoot
        $pkgFile = Get-Item (Join-Path $out 'install.intunewin') -ErrorAction SilentlyContinue
        Update-VersionList
        if ($script:BuildProc.ExitCode -eq 0 -and $pkgFile -and $pkgFile.LastWriteTime -gt $script:BuildStart)
        {
            $ui.BtnOpenOutput.IsEnabled = $true
            Set-Status "Done: $(Join-Path $out 'install.intunewin')"
            $r = [System.Windows.MessageBox]::Show("The package is ready:`n$($pkgFile.FullName)`n`nThe same folder contains Intune\Requirement.ps1, Intune\Detection.ps1, Intune-settings.txt and BuildInfo.txt.`n`nOpen the folder?", 'Package ready', 'YesNo', 'Information')
            if ($r -eq 'Yes') { Start-Process explorer.exe $out }
        }
        elseif ($script:BuildProc.ExitCode -eq 0)
        {
            Set-Status 'Files created, but no .intunewin (see Result).'
            $ui.BtnOpenOutput.IsEnabled = $true
        }
        else
        {
            Set-Status 'Build failed: see the Result tab.'
            Show-Error 'The package could not be built. The Result tab shows what went wrong.'
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

function Confirm-OutputFolder
{
    # For building: package folder required; if it doesn't exist yet, offer to create it
    $o = $ui.TxtOutputFolder.Text.Trim()
    if (-not $o)
    {
        Show-Error "First choose the folder for the package at 'Save package to' in tab 1, e.g. ...\versions\2.4.0\intune-package."
        $ui.Tabs.SelectedIndex = 0
        return $false
    }
    $path = [Environment]::ExpandEnvironmentVariables($o).TrimEnd('\')
    if (Test-InAppsFolder $path)
    {
        Show-Error "Save package to is inside the app folder:`n`n$path`n`nChoose a folder outside Apps\ in tab 1, e.g. the version folder next to the installer."
        $ui.Tabs.SelectedIndex = 0
        return $false
    }
    if (Test-Path -LiteralPath $path -PathType Container) { return $true }
    # In the kit's Output folder: the build script creates Output\<AppId>\<version> itself; create nothing here
    if (Test-InKitOutput $path) { return $true }
    # Drive or network share reachable? (I:\ or \\server\share)
    $root = if ($path -match '^(\\\\[^\\]+\\[^\\]+)') { $Matches[1] } else { [System.IO.Path]::GetPathRoot($path) }
    if (-not $root -or -not (Test-Path -LiteralPath $root))
    {
        Show-Error "The drive or share $root can't be reached. Is the drive mapped?`n`nSave package to: $path"
        return $false
    }
    $q = "The folder for the package doesn't exist yet:`n`n$path`n`nCreate it now?"
    if ([System.Windows.MessageBox]::Show($q, 'Create folder', 'YesNo', 'Question') -ne 'Yes') { return $false }
    try { New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop | Out-Null; return $true }
    catch { Show-Error "The folder could not be created: $($_.Exception.Message)"; return $false }
}

function Start-Build
{
    if (-not (Save-App)) { return }
    if (-not (Confirm-OutputFolder)) { return }
    if (-not (Get-IntuneWinAppUtil)) { Set-Status 'Without IntuneWinAppUtil.exe only the files are created.' }

    $script:BuildVersion = $ui.TxtVersion.Text.Trim()
    $script:BuildRoot = Get-OutputRoot
    $kitCopy = Join-Path (Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp) $script:BuildVersion
    if ((Test-Path (Get-BuildItem $script:BuildRoot 'BuildInfo.txt')) -or ((Test-Path $kitCopy) -and $script:BuildRoot -eq $kitCopy))
    {
        $q = "Version $($script:BuildVersion) has already been built.`n`nBuild again? The current build of this version is kept in the archive (visible in the Versions tab as 'replaced').`n`nDo you want to make a new version instead? Choose No and first change the version number or choose the new installer."
        if ([System.Windows.MessageBox]::Show($q, 'Version already exists', 'YesNo', 'Question') -ne 'Yes') { return }
    }
    $script:BuildLog = Join-Path ([System.IO.Path]::GetTempPath()) "AppUpdateKit_build_$(Get-Random).log"
    $script:BuildStart = Get-Date
    $ui.TxtLog.Text = ''
    $ui.TabLog.IsSelected = $true
    $ui.BtnBuild.IsEnabled = $false
    Set-Status "Building $($script:CurrentApp)... (large installers can take a while)"

    $script:BuildProc = Start-Process -FilePath 'powershell.exe' -NoNewWindow -PassThru `
        -RedirectStandardOutput $script:BuildLog -RedirectStandardError "$($script:BuildLog).err" `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $KitRoot 'Build-Package.ps1')`"", '-App', $script:CurrentApp)
    # Hold the handle: otherwise Windows PowerShell 5.1 gives no ExitCode afterwards
    $null = $script:BuildProc.Handle
    $buildTimer.Start()
}

#region Events
$ui.LstApps.Add_SelectionChanged({ if ($ui.LstApps.SelectedItem) { Import-App ([string]$ui.LstApps.SelectedItem) } })

$ui.BtnNewApp.Add_Click({
    $id = [Microsoft.VisualBasic.Interaction]::InputBox("AppId of the new app (only letters, digits, - and _), e.g. 7Zip:", 'New app', '')
    if (-not $id) { return }
    if ($id -notmatch '^[A-Za-z0-9_-]+$') { Show-Error 'Only letters, digits, - and _ (no spaces).'; return }
    $dir = Join-Path $AppsRoot $id
    if (Test-Path $dir) { Show-Error "Apps\$id already exists."; return }
    New-Item $dir -ItemType Directory -Force | Out-Null
    # Template in the language of this Builder (translated with Language\Translate.ps1)
    $tpl = Join-Path $KitRoot '_Template'
    foreach ($f in Get-ChildItem -LiteralPath $tpl -File)
    {
        $enc = if ($f.Extension -eq '.cmd') { New-Object System.Text.UTF8Encoding $false } else { New-Object System.Text.UTF8Encoding $true }
        [System.IO.File]::WriteAllText((Join-Path $dir $f.Name), (Get-KitFileText $f.FullName $ThisBuilderLang), $enc)
    }
    $d = Read-AppPsd1 (Join-Path $dir 'app.psd1')
    $d.AppId = $id; $d.AppName = $id; $d.DetectName = $id; $d.Processes = @(); $d.Language = $ThisBuilderLang
    [System.IO.File]::WriteAllText((Join-Path $dir 'app.psd1'), (ConvertTo-Psd1Text $d), (New-Object System.Text.UTF8Encoding $true))
    Update-AppList
    $ui.LstApps.SelectedItem = $id
    Set-Status "New app $id created. Start by choosing the installer."
})

$ui.BtnInstaller.Add_Click({
    # Tab 1: the installer of the app itself = the main component
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Installers (*.exe;*.msi)|*.exe;*.msi'
    Set-StartFolder $dlg -NewInstaller
    if (-not $dlg.ShowDialog()) { return }
    $script:LastInstallerPath = $dlg.FileName   # starting point for 'Browse...' at 'Save package to'
    $src = $dlg.FileName; $dir = Get-AppFolder
    $name = [System.IO.Path]::GetFileName($src)

    # Previous installer (old main component) and loose installers that aren't components: clean up?
    $oldMain = $script:Components | Where-Object { $_.Main } | Select-Object -First 1
    $oldIndex = if ($oldMain) { $script:Components.IndexOf($oldMain) } else { -1 }
    $usedFiles = @($script:Components | Where-Object { -not $_.Main } | ForEach-Object { $_.File })
    $old = @(Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' -and $_.Name -ne $name -and $_.Name -notin $usedFiles })
    if ($old.Count -gt 0)
    {
        $list = ($old | ForEach-Object { "  - $($_.Name)" }) -join "`n"
        $q = "The app folder still contains these installers:`n$list`n`nAre these old versions? Choose Yes to remove them, so they don't end up in the new package.`n(Other components from tab 2 stay as they are.)"
        if ([System.Windows.MessageBox]::Show($q, 'Clean up old installers', 'YesNo', 'Question') -eq 'Yes')
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
    $ui.TxtInstallerInfo.Text = "Recognised: $($info.Kind)$(if ($info.ProductName) { ' - ' + $info.ProductName })$(if ($info.Version) { ' ' + $info.Version }). $($info.Note) Parameters and extra components: tab 2."
    if ($info.Version) { $ui.TxtVersion.Text = $info.Version }
    if ($info.ProductName)
    {
        if (-not $ui.TxtAppName.Text -or $ui.TxtAppName.Text -eq $script:CurrentApp) { $ui.TxtAppName.Text = $info.ProductName }
        if (-not $ui.TxtDetectName.Text -or $ui.TxtDetectName.Text -eq $script:CurrentApp) { $ui.TxtDetectName.Text = $info.ProductName }
    }
    if ($info.Kind -eq 'MSI' -and $info.ProductCode) { Set-DetectionFromMsi $info }

    if (-not $ui.ChkAutoSteps.IsChecked)
    {
        $q = 'The installation steps were written by hand. Create them automatically from the components (tab 2) from now on?'
        if ([System.Windows.MessageBox]::Show($q, 'Installer chosen', 'YesNo', 'Question') -eq 'Yes') { $ui.ChkAutoSteps.IsChecked = $true }
    }
    Update-InstallPreview

    if (-not $ui.TxtUninstallCmd.Text.Trim() -or $ui.TxtUninstallCmd.Text -match 'MyApp|MijnApp|VUL IN: het verwijdercommando|FILL IN: the uninstall command')
    {
        $ui.TxtUninstallCmd.Text = New-UninstallCmdText $ui.TxtAppName.Text $info $ui.TxtDetectName.Text
        Sync-UninstallCleanup
    }
    Update-FileList

    # Save package to: does it still match the folder of this installer? With an update it often still points to the previous version.
    $newVersionDir = Get-VersionFolder $src
    if ($newVersionDir -and -not (Test-InAppsFolder $newVersionDir))
    {
        $sub = $KitSettings.PackageSubfolder
        $newOut = if ($sub) { Join-Path $newVersionDir $sub } else { $newVersionDir }
        $curOut = $ui.TxtOutputFolder.Text.Trim().TrimEnd('\')
        if ($curOut -ine $newOut.TrimEnd('\'))
        {
            $q = if ($curOut) { "Save package to is still set to:`n`n$curOut`n`nChange it to the folder of the chosen installer?`n`n$newOut" }
                 else { "Fill in Save package to with the folder of the chosen installer?`n`n$newOut" }
            if ([System.Windows.MessageBox]::Show($q, 'Save package to', 'YesNo', 'Question') -eq 'Yes') { $ui.TxtOutputFolder.Text = $newOut }
        }
    }
    Set-Status "Installer $name added as the main component. Check the version, processes and tab 2."
})

$ui.BtnGenerate.Add_Click({
    $main = Get-MainComponent
    if (-not $main) { Show-Error 'Add a component first (tab 1 or 2).'; return }
    if ($ui.TxtUninstallCmd.Text.Trim() -and [System.Windows.MessageBox]::Show('Replace the current uninstall steps?', 'Recreate', 'YesNo', 'Question') -ne 'Yes') { return }
    $info = @{ Kind = $main.Kind; ProductCode = $main.ProductCode }
    $ui.TxtUninstallCmd.Text = New-UninstallCmdText $ui.TxtAppName.Text $info $ui.TxtDetectName.Text
    Sync-UninstallCleanup
})


$ui.BtnCompRemove.Add_Click({
    $c = $ui.DgComponents.SelectedItem
    if (-not $c) { Show-Error 'Select a row in the table first.'; return }
    if ($c.IsFile) { Remove-PackageFile $c.File; return }
    $r = [System.Windows.MessageBox]::Show("Remove component $($c.File).`n`nAlso delete the file from the app folder?", 'Remove component', 'YesNoCancel', 'Question')
    if ($r -eq 'Cancel') { return }
    [void]$script:Components.Remove($c)
    if ($r -eq 'Yes') { Remove-Item -LiteralPath (Join-Path (Get-AppFolder) $c.File) -Force -ErrorAction SilentlyContinue }
    Update-InstallPreview; Update-FileList
    Confirm-AutoSteps
})

$ui.BtnCompUp.Add_Click({
    $c = $ui.DgComponents.SelectedItem; if (-not $c) { return }
    if ($c.IsFile) { Set-Status 'Only components have an order.'; return }
    $i = $script:Components.IndexOf($c)
    if ($i -gt 0) { $script:Components.Move($i, $i - 1); Update-FileList; Update-InstallPreview }
})
$ui.BtnCompDown.Add_Click({
    $c = $ui.DgComponents.SelectedItem; if (-not $c) { return }
    if ($c.IsFile) { Set-Status 'Only components have an order.'; return }
    $i = $script:Components.IndexOf($c)
    if ($i -lt $script:Components.Count - 1) { $script:Components.Move($i, $i + 1); Update-FileList; Update-InstallPreview }
})

# Files (not a component): only the target folder of a copy file can be changed
$ui.DgComponents.Add_BeginningEdit({
    $r = $_.Row.Item
    if ($r -and $r.IsFile -and -not ($r.Action -eq 'Copy' -and "$($_.Column.Header)" -like 'Parameters*')) { $_.Cancel = $true }
    # Registry file from an ADMX: don't change it in the table, double-click opens the settings
    elseif ($r -and -not $r.IsFile -and "$($_.Column.Header)" -like 'Parameters*' -and (Get-AdmxForRow $r)) { $_.Cancel = $true }
})

# Double-click on <name>-settings.reg: open and edit the chosen ADMX settings
$ui.DgComponents.Add_MouseDoubleClick({
    # Only for a double-click on a row (not on the header or the scrollbar)
    $el = $_.OriginalSource
    while ($el -and -not ($el -is [System.Windows.Controls.DataGridRow])) { $el = if ($el -is [System.Windows.Media.Visual]) { [System.Windows.Media.VisualTreeHelper]::GetParent($el) } elseif ($el -is [System.Windows.FrameworkContentElement]) { $el.Parent } else { $null } }
    if (-not $el) { return }
    $s = Get-AdmxForRow $el.Item
    if ($s) { $_.Handled = $true; Show-AdmxDialog $s.AdmxPath }
})

# After changing a cell (parameters, exit codes, main) update the preview
$ui.DgComponents.Add_CellEditEnding({
    $r = $_.Row.Item
    $script:PendingCopyEdit = if ($r -and $r.IsFile -and $r.Action -eq 'Copy' -and $_.EditingElement -is [System.Windows.Controls.TextBox]) { @{ File = $r.File; Target = $_.EditingElement.Text.Trim() } } else { $null }
    $null = $Window.Dispatcher.BeginInvoke([action]{
        if ($script:PendingCopyEdit -and $script:PendingCopyEdit.Target)
        {
            Add-CopyStep $script:PendingCopyEdit.File $script:PendingCopyEdit.Target
            $script:PendingCopyEdit = $null
            Update-FileList
        }
        # Only one main component at a time
        $sel = $ui.DgComponents.SelectedItem
        if ($sel -and $sel.Main) { foreach ($c in $script:Components) { if ($c -ne $sel) { $c.Main = $false } } ; $ui.DgComponents.Items.Refresh() }
        Update-InstallPreview
    }, [System.Windows.Threading.DispatcherPriority]::Background)
})
$ui.DgComponents.Add_CurrentCellChanged({ Update-InstallPreview })
$ui.TxtPreInstall.Add_TextChanged({ Update-InstallPreview })
$ui.CmbWindow.Add_SelectionChanged({ Update-WindowHint })
$ui.InfoTimes.Add_MouseLeftButtonUp({
    $msg = "Time blocks determine when the popup and the installation may come.`n`n" +
           "How to fill them in:`n" +
           "- Each block as from-to, in 24-hour time with a colon: 08:00-09:00`n" +
           "- Separate multiple blocks with a comma`n" +
           "- Across midnight is allowed: 22:00-06:00`n" +
           "- The end time doesn't count: with 08:00-09:00 the popup can still come at 08:59, but not at 09:00`n`n" +
           "Voorbeelden:`n" +
           "  08:00-17:00`t`t`t`twhole working day`n" +
           "  08:00-09:00, 12:00-13:00, 16:00-17:00`tinloggen, pauze, afsluiten`n" +
           "  22:00-06:00`t`t`t`tevening and night`n`n" +
           "With 'Only outside the chosen times' it works the other way round: the popup comes outside the blocks.`n`n" +
           "Note: Intune checks at intervals, not continuously. With short blocks (an hour) the popup may therefore only come in a later block. " +
           "Make 'How long does one postpone last?' shorter (e.g. 3 hours) if the popup should come back in a later block on the same day."
    [void][System.Windows.MessageBox]::Show($msg, 'Entering time blocks', 'OK', 'Information')
})
$ui.ChkIdle.Add_Click({ Update-WindowHint })
$ui.TxtPostInstall.Add_TextChanged({ Update-InstallPreview })
$ui.TxtPostInstall.Add_LostFocus({ Sync-UninstallCleanup; Update-FileList })
$ui.TxtPreInstall.Add_LostFocus({ Update-FileList })
$ui.ChkAutoSteps.Add_Click({
    if (-not $ui.ChkAutoSteps.IsChecked)
    {
        Set-Status 'Create automatically is off: you can now edit install-app.cmd by hand.'
    }
    Update-InstallPreview
})
$ui.TxtAppName.Add_TextChanged({ if ($ui.ChkAutoSteps.IsChecked) { Update-InstallPreview } })

$ui.BtnIcon.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Afbeeldingen (*.svg;*.ico;*.png;*.jpg;*.jpeg;*.bmp)|*.svg;*.ico;*.png;*.jpg;*.jpeg;*.bmp'
    Set-StartFolder $dlg
    if (-not $dlg.ShowDialog()) { return }
    try
    {
        if ([System.IO.Path]::GetExtension($dlg.FileName) -ieq '.svg') { Set-Status 'Converting SVG to an icon...' }
        New-IcoFromImage $dlg.FileName (Join-Path (Get-AppFolder) 'app.ico'); Update-IconPreview; Update-FileList
        # Keep the original, so you can make a sharper version later (also goes into the version history)
        if ([System.IO.Path]::GetExtension($dlg.FileName) -ieq '.svg') {
            Copy-Item -LiteralPath $dlg.FileName -Destination (Join-Path (Get-AppFolder) 'logo.svg') -Force
            Update-FileList; Set-Status 'SVG logo converted to app.ico (256 x 256).'
        }
    }
    catch { Show-Error "Logo could not be converted: $($_.Exception.Message)" }
})

$ui.BtnIconFromInstaller.Add_Click({
    $inst = $ui.TxtInstaller.Text
    if (-not $inst -or $inst -notmatch '\.(exe|msi)$') { Show-Error 'This only works with an .exe or .msi installer. Otherwise choose a logo yourself.'; return }
    $work = $null
    try
    {
        $source = Join-Path (Get-AppFolder) $inst
        if ($inst -like '*.msi')
        {
            $work = Join-Path ([System.IO.Path]::GetTempPath()) ("AppKitMsiIcon_" + [guid]::NewGuid().ToString('N'))
            New-Item -Path $work -ItemType Directory -Force | Out-Null
            $source = Get-MsiIcon -MsiPath $source -WorkDir $work
            if (-not $source) { Show-Error 'This MSI contains no icon. Choose a logo yourself (.svg, .png or .ico).'; return }
        }
        New-IcoFromImage $source (Join-Path (Get-AppFolder) 'app.ico')
        Update-IconPreview; Update-FileList
        Set-Status 'Logo taken from the installer. Is it blurry? Then choose a larger logo (.svg, .png or .ico).'
    }
    catch { Show-Error "Logo could not be taken from the installer: $($_.Exception.Message)" }
    finally { if ($work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } }
})

$ui.TxtAccent.Add_TextChanged({ Update-AccentPreview })

$ui.BtnCompAdd.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Multiselect = $true
    Set-StartFolder $dlg
    $dlg.Filter = 'All files (*.*)|*.*|Installation files (*.exe;*.msi;*.msp;*.ps1;*.cmd;*.bat;*.reg)|*.exe;*.msi;*.msp;*.ps1;*.cmd;*.bat;*.reg'
    if (-not $dlg.ShowDialog()) { return }
    $files = @($dlg.FileNames)
    $all = $null; $added = @(); $copied = @()
    for ($i = 0; $i -lt $files.Count; $i++)
    {
        $fn = $files[$i]; $name = [System.IO.Path]::GetFileName($fn)
        if ([System.IO.Path]::GetExtension($fn) -ieq '.admx') { Show-AdmxDialog $fn; continue }   # ADMX: choose settings
        if ([System.IO.Path]::GetExtension($fn) -ieq '.adml') { Show-Info "$name is the text file of an ADMX. Choose the .admx; the Builder finds the ADML itself."; continue }
        # "The same for all files" doesn't apply to "component" for a file that isn't an installer
        $choice = if ($all -and -not ($all.Action -eq 'Component' -and -not (Test-InstallerFile $name))) { $all } else { Show-FileActionDialog $name ($files.Count - $i - 1) }
        if (-not $choice) { continue }
        if ($choice.All) { $all = $choice }
        switch ($choice.Action)
        {
            'Component'
            {
                $info = Add-ComponentFile $fn $false
                $ui.TxtCompInfo.Text = "$($info.File): $($info.Kind). $($info.Note)  Check the parameters; double-click to change."
                # New components before the main component (usually a preparation, like a runtime)
                $main = $script:Components | Where-Object { $_.Main } | Select-Object -First 1
                if ($main) { $mi = $script:Components.IndexOf($main); if ($mi -lt $script:Components.Count - 1) { $script:Components.Move($mi, $script:Components.Count - 1) } }
                $added += $name
            }
            'CopyTo' { Copy-ToAppFolder $fn; Add-CopyStep $name $choice.Target; $copied += $name }
            default    { Copy-ToAppFolder $fn }
        }
    }
    Update-InstallPreview; Update-FileList
    if ($added) { Confirm-AutoSteps }
    if ($copied -and -not $ui.ChkAutoSteps.IsChecked)
    {
        Show-Info "The copy steps are in 'Extra steps after the components'. You write the installation steps by hand (create automatically is off): add them there too."
    }
    elseif ($added -or $copied) { Set-Status "Added: $((@($added) + @($copied)) -join ', '). See tab 2 for the steps." }
})

function Remove-PackageFile([string]$Name)
{
    # Take a file (not a component) out of the package, with its copy and cleanup step
    if ([System.Windows.MessageBox]::Show("Delete $Name from the app folder?", 'Delete file', 'YesNo', 'Question') -ne 'Yes') { return }
    Remove-Item -LiteralPath (Join-Path (Get-AppFolder) $Name) -Force
    $ui.TxtPostInstall.Text = Remove-CopyStep $Name $ui.TxtPostInstall.Text
    Sync-UninstallCleanup
    if ("$($ui.TxtPreInstall.Text)`n$($ui.TxtPostInstall.Text)" -match [regex]::Escape($Name)) { Show-Info "$Name is still mentioned in the extra steps (tab 2). Remove those lines, otherwise the installation fails." }
    Update-InstallPreview; Update-FileList; Update-IconPreview
}

$ui.BtnAdmx.Add_Click({ Start-AdmxImport })
$ui.BtnOpenAppFolder.Add_Click({ if (Get-AppFolder) { Start-Process explorer.exe (Get-AppFolder) } })
# Modern Windows folder picker (like in Explorer: address bar to type or paste a path, quick access on the left).
# The old FolderBrowserDialog (tree view) is only the fallback if this doesn't work.
if (-not ('AppKit.FolderPicker' -as [type]))
{
    try
    {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace AppKit {
    public static class FolderPicker {
        [ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")] class FileOpenDialogCom { }

        [ComImport, Guid("42f85136-db7e-439c-85f1-e4075d135fc8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IFileOpenDialog {
            [PreserveSig] int Show(IntPtr parent);
            void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
            void SetFileTypeIndex(uint iFileType);
            void GetFileTypeIndex(out uint piFileType);
            void Advise(IntPtr pfde, out uint pdwCookie);
            void Unadvise(uint dwCookie);
            void SetOptions(uint fos);
            void GetOptions(out uint pfos);
            void SetDefaultFolder(IShellItem psi);
            void SetFolder(IShellItem psi);
            void GetFolder(out IShellItem ppsi);
            void GetCurrentSelection(out IShellItem ppsi);
            void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
            void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
            void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
            void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
            void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
            void GetResult(out IShellItem ppsi);
            void AddPlace(IShellItem psi, int fdap);
            void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
            void Close(int hr);
            void SetClientGuid(ref Guid guid);
            void ClearClientData();
            void SetFilter(IntPtr pFilter);
            void GetResults(out IntPtr ppenum);
            void GetSelectedItems(out IntPtr ppsai);
        }

        [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IShellItem {
            void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
            void GetParent(out IShellItem ppsi);
            void GetDisplayName(uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
            void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
            void Compare(IShellItem psi, uint hint, out int piOrder);
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        static extern void SHCreateItemFromParsingName(string pszPath, IntPtr pbc, [MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItem ppv);

        // Returns the chosen path, or null on Cancel
        public static string Show(IntPtr owner, string title, string okLabel, string startFolder) {
            IFileOpenDialog dlg = (IFileOpenDialog)new FileOpenDialogCom();
            try {
                uint opts;
                dlg.GetOptions(out opts);
                dlg.SetOptions(opts | 0x20 | 0x40 | 0x8 | 0x800);   // pick folders, file system only, don't change folder, path must exist
                if (!String.IsNullOrEmpty(title)) dlg.SetTitle(title);
                if (!String.IsNullOrEmpty(okLabel)) dlg.SetOkButtonLabel(okLabel);
                if (!String.IsNullOrEmpty(startFolder)) {
                    try {
                        IShellItem start;
                        SHCreateItemFromParsingName(startFolder, IntPtr.Zero, typeof(IShellItem).GUID, out start);
                        dlg.SetFolder(start);
                    } catch { }
                }
                int hr = dlg.Show(owner);
                if (hr == unchecked((int)0x800704C7)) return null;   // Cancel
                if (hr != 0) Marshal.ThrowExceptionForHR(hr);
                IShellItem item;
                dlg.GetResult(out item);
                string path;
                item.GetDisplayName(0x80058000, out path);           // SIGDN_FILESYSPATH
                return path;
            } finally { Marshal.ReleaseComObject(dlg); }
        }
    }
}
"@
    }
    catch { }
}

function Select-Folder([string]$Title, [string]$StartFolder, [string]$OkLabel = 'Choose folder')
{
    # Returns the chosen path, or $null on Cancel
    if ('AppKit.FolderPicker' -as [type])
    {
        try
        {
            $owner = (New-Object System.Windows.Interop.WindowInteropHelper $Window).Handle
            return [AppKit.FolderPicker]::Show($owner, $Title, $OkLabel, $StartFolder)
        }
        catch { }
    }
    Add-Type -AssemblyName System.Windows.Forms
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    $f.Description = $Title
    $f.ShowNewFolderButton = $true
    if ($StartFolder) { $f.SelectedPath = $StartFolder }
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $f.SelectedPath }
    return $null
}

$ui.BtnOutputFolder.Add_Click({
    $cur = $ui.TxtOutputFolder.Text.Trim()
    # Starting point: the version folder of the installer just chosen, otherwise the current folder, otherwise the default folder
    $start = @()
    if ($script:LastInstallerPath) { $start += (Get-VersionFolder $script:LastInstallerPath) }
    if ($cur) { $start += $cur; $start += (Split-Path $cur -Parent) }
    $start += $KitSettings.InstallerFolder
    $startDir = $start | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    $picked = Select-Folder 'Choose the version folder (the package goes into \intune-package inside it)' $startDir
    if ($picked)
    {
        # Chosen version folder -> <version folder>\intune-package (PackageSubfolder in _Kit\Settings.psd1)
        $chosen = $picked.TrimEnd('\')
        if (Test-InAppsFolder $chosen)
        {
            Show-Error "This folder is inside the app folder of the kit ($chosen).`n`nThe package can't go there: every build would copy itself into the package. Choose the version folder next to the installer, e.g. ...\versions\2.4.0."
            return
        }
        if (Test-InKitOutput $chosen)
        {
            # In the kit's Output folder the layout is fixed: Output\<AppId>\<version>. No \intune-package after it.
            $ui.TxtOutputFolder.Text = Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp
            Set-Status "Package goes into the kit: Output\$($script:CurrentApp)\<version> (each version its own folder)."
            return
        }
        $sub = $KitSettings.PackageSubfolder
        $ui.TxtOutputFolder.Text = if ($sub -and (Split-Path $chosen -Leaf) -ine $sub) { Join-Path $chosen $sub } else { $chosen }
        Set-Status "Package goes into: $($ui.TxtOutputFolder.Text)"
    }
})

function Update-OutputHint
{
    # Explanation below 'Save package to', matching the chosen folder
    $o = $ui.TxtOutputFolder.Text.Trim()
    $ui.TxtOutputHint.Text = if ($o -and (Test-InKitOutput $o))
    {
        $v = $ui.TxtVersion.Text.Trim(); if (-not $v) { $v = '<version>' }
        "Folder in the kit: the package goes into Output\$($script:CurrentApp)\$v (each version its own folder)."
    }
    else { 'Click Browse... and choose the version folder, e.g. ...\versions\2.4.0. The Builder adds \intune-package. You can also type or paste the path.' }
}
$ui.TxtOutputFolder.Add_TextChanged({ Update-OutputHint })
$ui.TxtVersion.Add_TextChanged({ Update-OutputHint })

$ui.BtnOpenOutput.Add_Click({
    $o = Get-OutputRoot
    if (-not (Test-Path $o)) { $o = Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp }
    if (Test-Path $o) { Start-Process explorer.exe $o }
})

$ui.BtnStdTexts.Add_Click({ Show-DefaultTextsEditor })
$ui.BtnLanguage.Add_Click({
    # Choose another language: remember it and start the Builder again in that language
    $lang = Show-LanguageChoice
    if (-not $lang -or $lang -eq $ThisBuilderLang) { return }
    if ($script:CurrentApp -and -not (Save-App)) { return }   # first save the open app
    Save-BuilderLanguage $lang
    if (Start-BuilderInLanguage $lang) { $Window.Close() }
})
$ui.CmbTextLang.Add_SelectionChanged({
    # Other language on the laptop: default texts (grey below the fields) and previews in that language
    if (-not $ui.CmbTextLang.SelectedItem) { return }
    $script:TextLang = [string]$ui.CmbTextLang.SelectedItem.Tag
    Update-TextHints
})

$ui.BtnUpdateKit.Add_Click({
    # Update the kit from GitHub: Update-Kit.ps1 in its own window, the Builder closes and starts again afterwards
    $script = Join-Path $KitRoot 'Update-Kit.ps1'
    if (-not (Test-Path $script)) { Show-Error "Update-Kit.ps1 is missing from $KitRoot."; return }
    $q = "Get the latest version of AppUpdateKit from GitHub (github.com/Fonfey/AppUpdateKit)?`n`nYour apps (Apps\), built packages (Output\), default folder and default texts are kept.`n`nThe Builder closes and then starts again. Save your app first if you changed something."
    if ([System.Windows.MessageBox]::Show($q, 'Update kit', 'OKCancel', 'Question') -ne 'OK') { return }
    Start-Process -FilePath 'powershell.exe' -WorkingDirectory $KitRoot -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"", '-RestartBuilder')
    $Window.Close()
})

$ui.LstVersions.Add_SelectionChanged({ Show-VersionDetails })
$ui.BtnVerPreview.Add_Click({
    $det = $script:SelectedVersion
    if (-not $det -or -not $det.Data) { return }
    $kind = [string]$ui.CmbVerPreview.SelectedItem.Tag
    Show-Preview $kind $det.Data $det.Std $det.Icon
})
$ui.BtnVerOpen.Add_Click({ $v = Get-SelectedVersion; if ($v) { Start-Process explorer.exe $v.Path } })

$ui.BtnVerRestore.Add_Click({
    # Prepare a full copy of this build (settings, texts, steps, installers) as the working version
    $v = Get-SelectedVersion
    if (-not $v) { return }
    if (-not $v.HasSource) { Show-Error "No data was kept for build $($v.Label)."; return }
    $q = "Make a copy of $($v.Label) and set it up as the working version?`n`n" +
         "What is in the Builder now (and not built yet) is replaced by it. Built versions are always kept.`n`n" +
         "Then:`n- keep the same version number = improve this version (the current build goes to the archive)`n" +
         "- new installer or new version number = a new version"
    if ([System.Windows.MessageBox]::Show($q, 'Make a copy and edit', 'YesNo', 'Question') -ne 'Yes') { return }

    $sourceCopyDir = Get-BuildItem $v.Path 'Source'
    $appDir  = Get-AppFolder
    Set-Status "Making a copy of $($v.Label)..."
    Get-ChildItem $appDir -Force | Remove-Item -Recurse -Force
    Get-ChildItem $sourceCopyDir -Force | Where-Object { $_.Name -notin 'DefaultTexts.psd1', 'Standaardteksten.psd1' } | Copy-Item -Destination $appDir -Recurse -Force
    Import-App $script:CurrentApp
    $ui.Tabs.SelectedIndex = 0

    $msg = "Copy of $($v.Label) is ready. Change what's needed and click Build package."
    if (-not $v.HasInstallers) { $msg += ' Note: the installers were not kept in this old build; add them again.' }
    Set-Status $msg
})

$ui.BtnVerDelete.Add_Click({
    $v = Get-SelectedVersion
    if (-not $v) { return }
    if ([System.Windows.MessageBox]::Show("Delete version $($v.Version) with install.intunewin and all files in this folder?`n`n$($v.Path)", 'Delete version', 'YesNo', 'Warning') -ne 'Yes') { return }
    Remove-Item -LiteralPath $v.Path -Recurse -Force
    if ($v.Pointer) { Remove-Item -LiteralPath (Split-Path $v.Pointer -Parent) -Recurse -Force -ErrorAction SilentlyContinue }
    Update-VersionList
    Set-Status "Version $($v.Version) deleted."
})

$ui.BtnPrevConsent.Add_Click({ Show-Preview 'consent' })
$ui.BtnPrevLast.Add_Click({ Show-Preview 'last' })
$ui.BtnPrevForced.Add_Click({ Show-Preview 'forced' })
$ui.BtnPrevRestart.Add_Click({ Show-Preview 'restart' })
$ui.BtnPrevRestartForced.Add_Click({ Show-Preview 'restartforced' })
$ui.BtnPrevUninstalling.Add_Click({ Show-Preview 'uninstalling' })
$ui.BtnPrevUninstalled.Add_Click({ Show-Preview 'uninstalled' })
$ui.CmbRestart.Add_SelectionChanged({ Update-RestartPanel })
$ui.CmbDetect.Add_SelectionChanged({ Update-DetectPanels })
$ui.ChkDetectAnyVersion.Add_Click({ Update-DetectPanels })
$ui.TxtDetectName.Add_TextChanged({ if ([string]$ui.CmbDetect.SelectedItem.Tag -eq 'AppsAndFeatures') { Update-DetectPanels } })
$ui.BtnDetectTest.Add_Click({
    # Run the detection script here (64-bit PowerShell, like Intune) and show the result
    $d = Read-Form
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "AppKit_detect_$(Get-Random).ps1"
    try
    {
        # 1. The script that goes to Intune: that decides whether the app is found
        $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $run = {
            param([string]$Text)
            [System.IO.File]::WriteAllText($tmp, $Text, (New-Object System.Text.UTF8Encoding $true))
            $psi = New-Object System.Diagnostics.ProcessStartInfo $ps, "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
            $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
            $psi.EnvironmentVariables['APPKIT_DETECT_DEBUG'] = '1'   # explanation on the error output; Intune never sets this
            $p = [System.Diagnostics.Process]::Start($psi)
            $o = $p.StandardOutput.ReadToEnd(); $e = $p.StandardError.ReadToEnd()
            if (-not $p.WaitForExit(30000)) { $p.Kill() }
            return @{ Out = $o; Err = $e }
        }
        $r = & $run (Get-DetectionScriptText $d)
        $out = $r.Out; $err = $r.Err
        # 2. The explain script: the same check, with the reason
        $explainText = Get-DetectionScriptText $d -Explain
        if ($explainText) { $err = (& $run $explainText).Err }
        $brush = New-Object System.Windows.Media.BrushConverter
        $why = (("$err" -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 6) -join "`n  "
        if ("$out".Trim())
        {
            $ui.TxtDetectResult.Foreground = $brush.ConvertFromString('#2E7D32')
            $ui.TxtDetectResult.Text = "  Detected on this PC.$(if ($why) { "`n  $why" } else { "`n  $("$out".Trim())" })"
        }
        else
        {
            $ui.TxtDetectResult.Foreground = $brush.ConvertFromString('#C62828')
            $ui.TxtDetectResult.Text = "  Not detected on this PC.$(if ($why) { "`n  $why" })"
        }
    }
    catch { Show-Error "Test failed: $($_.Exception.Message)" }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
})
$ui.BtnPrevInstalling.Add_Click({ Show-Preview 'installing' })
$ui.BtnPrevSuccess.Add_Click({ Show-Preview 'success' })
$ui.BtnPrevError.Add_Click({ Show-Preview 'error' })

$ui.BtnSave.Add_Click({ [void](Save-App) })

# Previous / Next: through all tabs (Basics to Result)
function Update-TabNav
{
    $i = $ui.Tabs.SelectedIndex
    $on = $ui.Tabs.IsEnabled
    $ui.BtnPrevTab.IsEnabled = $on -and $i -gt 0
    $ui.BtnNextTab.IsEnabled = $on -and $i -ge 0 -and $i -lt ($ui.Tabs.Items.Count - 1)
}
$ui.BtnNextTab.Add_Click({ if ($ui.Tabs.SelectedIndex -lt ($ui.Tabs.Items.Count - 1)) { $ui.Tabs.SelectedIndex++ }; Update-TabNav })
$ui.BtnPrevTab.Add_Click({ if ($ui.Tabs.SelectedIndex -gt 0) { $ui.Tabs.SelectedIndex-- }; Update-TabNav })
$ui.Tabs.Add_SelectionChanged({ Update-TabNav })
$ui.Tabs.Add_IsEnabledChanged({ Update-TabNav })
$ui.BtnBuild.Add_Click({ Start-Build })
#endregion

function Select-InstallerFolder([switch]$FirstRun)
{
    # Choose the default folder for installers and save it in _Kit\Settings.psd1
    $startDir = if ($KitSettings.InstallerFolder -and (Test-Path -LiteralPath $KitSettings.InstallerFolder)) { $KitSettings.InstallerFolder } else { $null }
    $picked = Select-Folder 'Choose the default folder for installers ("Browse..." opens here from now on)' $startDir
    if (-not $picked) { return }
    try
    {
        Save-InstallerFolder $picked
        Set-Status "Default folder for installers: $($KitSettings.InstallerFolder)"
    }
    catch { Show-Error "The default folder could not be saved in _Kit\Settings.psd1: $($_.Exception.Message)" }
}

$ui.BtnInstallerFolder.Add_Click({ Select-InstallerFolder })

# New version of the kit on GitHub? Ask in the background (at most once a day), so the Builder doesn't wait.
function Compare-KitVersion([string]$A, [string]$B)
{
    # >0 if A is newer than B
    try { return ([version]($A.TrimStart('v') -replace '[^0-9.].*$', '')).CompareTo([version]($B.TrimStart('v') -replace '[^0-9.].*$', '')) } catch { return 0 }
}
function Show-NewKitVersion([string]$Latest)
{
    if (-not $Latest -or -not $KitVersion -or (Compare-KitVersion $Latest $KitVersion) -le 0) { return }
    $ui.BtnUpdateKit.Content = "Update kit ($($Latest.TrimStart('v')))..."
    $ui.BtnUpdateKit.Style = $Window.FindResource('Primary')
    $ui.TxtKitVersion.Text = "version $KitVersion - new version $($Latest.TrimStart('v')) available"
}
$script:VersionTask = $null
function Start-KitVersionCheck
{
    $cache = Join-Path (Join-Path $env:LOCALAPPDATA 'AppUpdateKit') 'latest-version.txt'
    $script:VersionCache = $cache
    try
    {
        # Already asked today? Then use the answer from then
        if ((Test-Path $cache) -and ((Get-Item $cache).LastWriteTime -gt (Get-Date).AddHours(-20))) { Show-NewKitVersion ([System.IO.File]::ReadAllText($cache).Trim()); return }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'AppUpdateKit')
        $wc.Proxy = [System.Net.WebRequest]::GetSystemWebProxy(); $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $script:VersionTask = $wc.DownloadStringTaskAsync('https://api.github.com/repos/Fonfey/AppUpdateKit/releases/latest')
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(500)
        $script:VersionTimerStart = Get-Date
        $timer.Add_Tick({
            param($t)
            $task = $script:VersionTask
            if (-not $task.IsCompleted -and ((Get-Date) - $script:VersionTimerStart).TotalSeconds -lt 20) { return }
            $t.Stop()
            try
            {
                if ($task.Status -eq 'RanToCompletion' -and $task.Result -match '"tag_name"\s*:\s*"([^"]+)"')
                {
                    $latest = $Matches[1]
                    New-Item -Path (Split-Path $script:VersionCache -Parent) -ItemType Directory -Force | Out-Null
                    [System.IO.File]::WriteAllText($script:VersionCache, $latest)
                    Show-NewKitVersion $latest
                }
            }
            catch { }   # no internet or no release: simply show nothing
        })
        $timer.Start()
    }
    catch { }
}

# First start: default folder for installers not set yet? Ask once per user.
$Window.Add_ContentRendered({
    $marker = Join-Path (Join-Path $env:LOCALAPPDATA 'AppUpdateKit') 'default-folder-asked.txt'
    $oldMarker = Join-Path (Join-Path $env:LOCALAPPDATA 'AppUpdateKit') 'standaardmap-gevraagd.txt'   # name in versions before 1.3
    if ($KitSettings.InstallerFolder -or (Test-Path $marker) -or (Test-Path $oldMarker)) { return }
    try { New-Item -Path (Split-Path $marker -Parent) -ItemType Directory -Force | Out-Null; Set-Content -Path $marker -Value (Get-Date -Format 's') } catch { }
    $q = "Welcome to the AppUpdateKit Builder.`n`nDo you want to set a default folder for installers? 'Browse...' then opens straight in that folder, for example I:\Software\projects.`n`nYou can change this later with the Default folder... button (left)."
    if ([System.Windows.MessageBox]::Show($Window, $q, 'Set default folder', 'YesNo', 'Question') -eq 'Yes') { Select-InstallerFolder -FirstRun }
})

try
{
    Update-BuilderShortcut
    Update-AppList
    Set-Status 'Choose an app on the left, or create a new one.'
    if ($KitVersion) { $ui.TxtKitVersion.Text = "version $KitVersion"; $Window.Title = "AppUpdateKit Builder $KitVersion" }
    Start-KitVersionCheck
    [void]$Window.ShowDialog()
}
catch
{
    Write-BuilderError $_
}
#endregion

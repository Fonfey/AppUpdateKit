<#
.SYNOPSIS
    Step 2: builds the Intune package from a completed app folder.

.DESCRIPTION
    Reads Apps\<App>\app.psd1, checks everything and creates one folder per version:
      Output\<AppId>\<version>\install.intunewin        the package for Intune
      Output\<AppId>\<version>\Intune\Install.ps1       PowerShell installer (upload separately)
      Output\<AppId>\<version>\Intune\Uninstall.ps1     PowerShell uninstaller (upload separately)
      Output\<AppId>\<version>\Intune\Requirement.ps1   upload separately under Requirements
      Output\<AppId>\<version>\Intune\Detection.ps1     upload separately under Detection rules
      Output\<AppId>\<version>\Intune-instellingen.txt  all Intune settings in one place
      Output\<AppId>\<version>\Bron\                    full copy of this version (including installers)
      Output\<AppId>\_archief\<version>_<date>\         earlier builds of the same version (when rebuilding)
      Output\<AppId>\<version>\Bouwinfo.txt             when, by whom, which files (with SHA-256)
    install.intunewin is created when IntuneWinAppUtil.exe is next to this script or in PATH.
    When that works, the temporary Pakket\ folder is removed (use -KeepPackageFolder to keep it).

    Language of messages and generated files: -Lang, otherwise _Kit\Settings.psd1 (Language = 'nl' | 'en').

.EXAMPLE
    .\2-Bouw-pakket.ps1 -App NotepadPlusPlus
    .\2-Bouw-pakket.ps1 -App NotepadPlusPlus -Lang en
#>

param
(
    [Parameter(Mandatory)][string]$App,                       # folder name under Apps\, or a full path
    [string]$Output = '',                                     # default: Output next to this script
    [switch]$KeepPackageFolder,                               # keep the Pakket\ folder after packing
    [ValidateSet('', 'nl', 'en')][string]$Lang = ''           # language of messages and generated files
)

$ErrorActionPreference = 'Stop'
# Kit folder (also when $PSScriptRoot is empty, e.g. when started from PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Kan de AppUpdateKit-map niet vinden / Cannot find the AppUpdateKit folder. cd <AppUpdateKit> ; .\2-Bouw-pakket.ps1 -App <AppId>"
}
$kit = Join-Path $KitRoot '_Kit'

# ---------- Language ----------
if (-not $Lang) {
    $Lang = 'nl'
    $settingsFile = Join-Path $kit 'Settings.psd1'
    if (Test-Path $settingsFile) { try { if ((Import-PowerShellDataFile $settingsFile).Language -eq 'en') { $Lang = 'en' } } catch { } }
}
function T([string]$Nl, [string]$En) { if ($Lang -eq 'en') { return $En } else { return $Nl } }

if (-not $Output) { $Output = Join-Path $KitRoot 'Output' }

$source = if (Test-Path $App) { (Resolve-Path $App).Path } else { Join-Path (Join-Path $KitRoot 'Apps') $App }
if (-not (Test-Path (Join-Path $source 'app.psd1'))) { throw (T "Geen app.psd1 gevonden in $source" "No app.psd1 found in $source") }

# Read through a copy with BOM: Notepad saves UTF-8 without BOM, and Windows PowerShell 5.1
# would then read accented characters incorrectly.
$psdTemp = [System.IO.Path]::GetTempFileName() + '.psd1'
[System.IO.File]::WriteAllText($psdTemp, [System.IO.File]::ReadAllText((Join-Path $source 'app.psd1')), (New-Object System.Text.UTF8Encoding $true))
try { $cfg = Import-PowerShellDataFile -Path $psdTemp }
catch { throw (T "app.psd1 bevat een fout (controleer aanhalingstekens en haakjes): $($_.Exception.Message)" "app.psd1 contains an error (check quotes and brackets): $($_.Exception.Message)") }
finally { Remove-Item $psdTemp -Force -ErrorAction SilentlyContinue }

# ---------- Checks ----------
$problems = @(); $warnings = @()
if ($cfg.AppId -notmatch '^[A-Za-z0-9_-]+$')   { $problems += T 'AppId mag alleen letters, cijfers, - en _ bevatten.' 'AppId may only contain letters, digits, - and _.' }
if (-not $cfg.AppName)                          { $problems += T 'AppName is leeg.' 'AppName is empty.' }
if ($cfg.Version -notmatch '^\d+(\.\d+){0,3}$') { $problems += T "Version '$($cfg.Version)' is geen geldige versie (bijv. 1.2.3)." "Version '$($cfg.Version)' is not a valid version (e.g. 1.2.3)." }
if (-not $cfg.DetectName)                       { $problems += T 'DetectName is leeg.' 'DetectName is empty.' }
if (-not @($cfg.Processes | Where-Object { $_ }).Count) { $warnings += T 'Geen processen ingevuld: de installatie controleert niet of de app open staat.' 'No processes entered: the installation does not check whether the app is running.' }
if ($cfg.AccentColor -and $cfg.AccentColor -notmatch '^#[0-9A-Fa-f]{6}$') { $problems += T "AccentColor '$($cfg.AccentColor)' moet de vorm #RRGGBB hebben." "AccentColor '$($cfg.AccentColor)' must have the form #RRGGBB." }

foreach ($f in 'install-app.cmd', 'uninstall-app.cmd') {
    if (-not (Test-Path (Join-Path $source $f))) { $problems += T "$f ontbreekt." "$f is missing." }
}

$icon = if ($cfg.Icon) { $cfg.Icon } else { 'app.ico' }
if (-not (Test-Path (Join-Path $source $icon))) { $warnings += T "Logo '$icon' niet gevonden: de vensters tonen dan geen logo." "Logo '$icon' not found: the popups will show no logo." }

# Installers referenced in install-app.cmd must be in the folder
$installText = Get-Content -Path (Join-Path $source 'install-app.cmd') -Raw -ErrorAction SilentlyContinue
if ($installText) {
    $active = ($installText -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(rem|::)' }) -join "`n"
    foreach ($m in [regex]::Matches($active, '"([^"\\/:%]+\.(exe|msi|msp|ps1|cmd|bat|reg))"', 'IgnoreCase')) {
        $want = $m.Groups[1].Value
        if ((Test-Path (Join-Path $source $want)) -or (Test-Path (Join-Path $kit $want))) { continue }
        $ext  = [System.IO.Path]::GetExtension($want)
        $have = @(Get-ChildItem -Path $source -File -Filter "*$ext" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        $msg  = T "install-app.cmd gebruikt '$want', maar dat bestand staat niet in de map." "install-app.cmd uses '$want', but that file is not in the folder."
        $msg += if ($have.Count) { T "`n      Wel in de map ($ext): $($have -join ', ')`n      Andere naam? Hernoem het bestand, of kies het in tabblad 2 opnieuw als onderdeel." "`n      In the folder ($ext): $($have -join ', ')`n      Different name? Rename the file, or select it again as a component in tab 2." }
                else { T "`n      Er staat geen enkel $ext-bestand in de map. Zet de installer in $source." "`n      There is no $ext file in the folder. Put the installer in $source." }
        $problems += $msg
    }
    if ($active -notmatch 'APP_EXITCODE') { $warnings += T 'install-app.cmd zet APP_EXITCODE niet; succes/fout wordt dan niet goed gemeld.' 'install-app.cmd does not set APP_EXITCODE; success/failure will not be reported correctly.' }
}

$warnings | ForEach-Object { Write-Warning $_ }
if ($problems) {
    $problems | ForEach-Object { Write-Host "$(T 'FOUT' 'ERROR'): $_" -ForegroundColor Red }
    throw (T "Pakket niet gebouwd: los eerst de fouten hierboven op in $source" "Package not built: first fix the errors above in $source")
}

# ---------- Folders: Output\<AppId>\<version>\ ----------
$root   = Join-Path (Join-Path $Output $cfg.AppId) $cfg.Version
$pkg    = Join-Path $root 'Pakket'
$intune = Join-Path $root 'Intune'
$bron   = Join-Path $root 'Bron'
if (Test-Path $root) {
    # Keep everything: the previous build of this version goes to the archive
    $stampSource = if (Test-Path (Join-Path $root 'Bouwinfo.txt')) { Get-Item (Join-Path $root 'Bouwinfo.txt') } else { Get-Item $root }
    $archiveDir = Join-Path (Join-Path $Output $cfg.AppId) '_archief'
    $archive = Join-Path $archiveDir "$($cfg.Version)_$($stampSource.LastWriteTime.ToString('yyyyMMdd-HHmmss'))"
    New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null
    if (Test-Path (Join-Path $root 'Pakket')) { Remove-Item -Path (Join-Path $root 'Pakket') -Recurse -Force }   # temporary folder, not kept
    Move-Item -Path $root -Destination $archive
    Write-Warning (T "Versie $($cfg.Version) was al gebouwd. Die build is bewaard in _archief\$(Split-Path $archive -Leaf)." "Version $($cfg.Version) was already built. That build has been kept in _archief\$(Split-Path $archive -Leaf).")
}
New-Item -Path $pkg, $intune, $bron -ItemType Directory -Force | Out-Null

$utf8Bom = New-Object System.Text.UTF8Encoding $true
function Write-Text($Path, $Text, [switch]$Cmd) {
    $Text = $Text -replace "`r?`n", "`r`n"
    if ($Cmd) {
        if ($Text -match '[^\x00-\x7F]') { Write-Warning (T "$(Split-Path $Path -Leaf) bevat speciale tekens (é, ï, ...); cmd geeft die mogelijk verkeerd door." "$(Split-Path $Path -Leaf) contains special characters (é, ï, ...); cmd may pass them on incorrectly.") }
        [System.IO.File]::WriteAllText($Path, $Text, [System.Text.Encoding]::Default)
    }
    else { [System.IO.File]::WriteAllText($Path, $Text, $utf8Bom) }
}
function Read-Text($Path) { [System.IO.File]::ReadAllText($Path) }   # detects UTF-8 with/without BOM itself

$processList = ($cfg.Processes | Where-Object { $_ } | ForEach-Object { "'$($_ -replace '\.exe$', '')'" }) -join ', '
$onlyExisting = if ($null -eq $cfg.OnlyUpdateExisting) { $true } else { [bool]$cfg.OnlyUpdateExisting }
$window   = if ($cfg.InstallWindow) { $cfg.InstallWindow } else { 'Altijd' }
$hours    = if ($cfg.WorkHours) { $cfg.WorkHours } else { '08:00-17:00' }
$days     = if ($cfg.WorkDays) { $cfg.WorkDays } else { 'ma,di,wo,do,vr' }
$noUser   = if ($cfg.NoUserAction) { $cfg.NoUserAction } else { 'Installeren' }
$idleMin  = [int]("0$($cfg.IdleMinutes)")
$popupLang = if ("$($cfg.PopupLanguage)" -in 'nl', 'en') { "$($cfg.PopupLanguage)" } else { 'Auto' }
# Own parameters used by install-app.cmd (APP_XXX), for the list in Intune-instellingen.txt
$appCmdPath = Join-Path $source 'install-app.cmd'
$appParams = @()
if (Test-Path $appCmdPath) {
    $appParams = @([regex]::Matches((Get-Content $appCmdPath -Raw), '(?i)defined\s+APP_(\w+)') | ForEach-Object { '/' + $_.Groups[1].Value.ToLower() } | Sort-Object -Unique)
}
$restartMode = if ($cfg.RestartMode) { $cfg.RestartMode } else { 'Nooit' }
if ($restartMode -notin 'Nooit', 'AlsNodig', 'Altijd') { throw (T "RestartMode moet 'Nooit', 'AlsNodig' of 'Altijd' zijn (nu: '$restartMode')." "RestartMode must be 'Nooit', 'AlsNodig' or 'Altijd' (now: '$restartMode').") }
$restartReminder = if ($null -ne $cfg.RestartReminderMinutes) { [int]$cfg.RestartReminderMinutes } else { 60 }
$restartDeadline = if ($null -ne $cfg.RestartDeadlineHours) { [int]$cfg.RestartDeadlineHours } else { 24 }
$restartWarning  = if ($null -ne $cfg.RestartWarningMinutes) { [int]$cfg.RestartWarningMinutes } else { 15 }
$duringSetup = if ($null -eq $cfg.InstallDuringSetup) { $true } else { [bool]$cfg.InstallDuringSetup }
if ($window -notin 'Altijd', 'Werktijd', 'BuitenWerktijd') { throw (T "InstallWindow moet 'Altijd', 'Werktijd' of 'BuitenWerktijd' zijn (nu: '$window')." "InstallWindow must be 'Altijd', 'Werktijd' or 'BuitenWerktijd' (now: '$window').") }
if ($noUser -notin 'Installeren', 'Wachten') { throw (T "NoUserAction moet 'Installeren' of 'Wachten' zijn (nu: '$noUser')." "NoUserAction must be 'Installeren' or 'Wachten' (now: '$noUser').") }
if ($window -ne 'Altijd' -and $hours -notmatch '^\s*\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}\s*$') { throw (T "WorkHours moet de vorm '08:00-17:00' hebben (nu: '$hours')." "WorkHours must have the form '08:00-17:00' (now: '$hours').") }
$windowText = switch ($window) {
    'Werktijd'       { T "alleen binnen werktijd ($days, $hours)" "only during working hours ($days, $hours)" }
    'BuitenWerktijd' { T "alleen buiten werktijd (buiten $days, $hours)" "only outside working hours (outside $days, $hours)" }
    default          { T 'altijd' 'always' }
}

function Fill($Text) {
    # {{T:Dutch|English}} -> text in the kit language, then the app placeholders
    $Text = [regex]::Replace($Text, '\{\{T:([^|}]*)\|([^}]*)\}\}', { param($m) if ($Lang -eq 'en') { $m.Groups[2].Value } else { $m.Groups[1].Value } })
    $Text.Replace('{{APPID}}', $cfg.AppId).Replace('{{APPNAME}}', $cfg.AppName).
          Replace('{{DETECT_NAME}}', $cfg.DetectName.Replace("'", "''")).Replace('{{VERSION}}', $cfg.Version).
          Replace('{{PROCESSES}}', $processList).Replace('{{ONLY_IF_INSTALLED}}', $onlyExisting.ToString().ToLower()).
          Replace('{{INSTALL_WINDOW}}', $window).Replace('{{WORK_HOURS}}', $hours).Replace('{{WORK_DAYS}}', $days).
          Replace('{{NO_USER_ACTION}}', $noUser).Replace('{{INSTALL_DURING_SETUP}}', $duringSetup.ToString().ToLower())
}

# ---------- Package ----------
# 1. Everything from the app folder (installers, logo, own scripts, extra files)
Get-ChildItem -Path $source -Force | Where-Object { $_.Extension -ne '.intunewin' } |
    Copy-Item -Destination $pkg -Recurse -Force

# 2. app.psd1 (with the kit language for the logs) and the own cmd files with the right encoding
$psdText = Read-Text (Join-Path $source 'app.psd1')
$psdText = $psdText -replace "(?m)^\s*KitLanguage\s*=.*\r?\n", ''
$psdText = [regex]::Replace($psdText, '(?m)^(\s*)@\{\s*$', "`$0`r`n    KitLanguage = '$Lang'   # language of the log files (set by the build)", 1)
Write-Text (Join-Path $pkg 'app.psd1') $psdText
foreach ($f in 'install-app.cmd', 'uninstall-app.cmd') { Write-Text (Join-Path $pkg $f) (Read-Text (Join-Path $source $f)) -Cmd }

# 3. Shared scripts and standard texts (identical for every app)
foreach ($f in 'AppUI.ps1', 'AppUI-Launcher.ps1', 'Ask-InstallConsent.ps1', 'Show-Toast.ps1', 'Test-AppRunning.ps1', 'Get-IdleTime.ps1', 'Set-RestartPrompt.ps1', 'Restart-Prompt.ps1', 'Remove-App.ps1', 'Test-AppInstalled.ps1', 'Standaardteksten.psd1') {
    if (Test-Path (Join-Path $kit $f)) { Write-Text (Join-Path $pkg $f) (Read-Text (Join-Path $kit $f)) }
}
foreach ($f in 'install.cmd', 'uninstall.cmd') {
    Write-Text (Join-Path $pkg $f) (Fill (Read-Text (Join-Path $kit $f))) -Cmd
}

# ---------- Intune scripts ----------
foreach ($f in 'Requirement.ps1', 'Detection.ps1') {
    Write-Text (Join-Path $intune $f) ((Fill (Read-Text (Join-Path (Join-Path $kit 'Intune') $f))).Replace('{{CHECK_PROCESSES}}', 'true'))
}
# Variant for /noprocesscheck: without checking whether the app is running
Write-Text (Join-Path $intune 'Requirement-zonder-procescheck.ps1') ((Fill (Read-Text (Join-Path (Join-Path $kit 'Intune') 'Requirement.ps1'))).Replace('{{CHECK_PROCESSES}}', 'false'))

# ---------- PowerShell installer for Intune (Install.ps1 / Uninstall.ps1, upload separately) ----------
function ConvertTo-PsLiteral($v) {
    if ($null -eq $v) { return "''" }
    if ($v -is [bool]) { return '$' + $v.ToString().ToLower() }
    if ($v -is [int] -or $v -is [long] -or $v -is [double]) { return "$v" }
    if ($v -is [array]) { return '@(' + ((@($v) | ForEach-Object { ConvertTo-PsLiteral $_ }) -join ', ') + ')' }
    return "'" + ([string]$v).Replace("'", "''") + "'"
}
function Get-StepCommand($c) {
    # Same command lines as install-app.cmd
    $a = "$($c.Args)".Trim()
    $line = switch ("$($c.Kind)".ToUpper()) {
        'MSI'   { "msiexec.exe /i `"$($c.File)`" /qn /norestart $a" }
        'MSP'   { "msiexec.exe /p `"$($c.File)`" /qn /norestart $a" }
        'PS1'   { "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$($c.File)`" $a" }
        'CMD'   { "call `"$($c.File)`" $a" }
        'REG'   { "reg.exe import `"$($c.File)`"" }
        default { "`"$($c.File)`" $a" }
    }
    return $line.Trim()
}
function Assert-HereString([string]$Text, [string]$What) {
    if ($Text -match "(?m)^'@") { throw (T "$What bevat een regel die begint met '@; dat kan niet in Install.ps1. Pas die regel aan." "$What contains a line starting with '@; that is not possible in Install.ps1. Change that line.") }
    return $Text.TrimEnd()
}

$settingLines = @()
$settingSpec = [ordered]@{
    AppId                  = @($cfg.AppId, (T 'niet wijzigen: map, teller en log' 'do not change: folder, counter and log'))
    AppName                = @($cfg.AppName, (T 'naam in de vensters' 'name in the popups'))
    DetectName             = @($cfg.DetectName, (T 'naam in Apps en onderdelen: bepaalt nieuwe installatie of update' 'name in Apps & features: decides new installation or update'))
    Version                = @($cfg.Version, (T 'versie in dit pakket (nieuwe versie = nieuw pakket)' 'version in this package (new version = new package)'))
    Processes              = @(@($cfg.Processes | Where-Object { $_ }), (T 'staan ook in Requirement.ps1' 'also in Requirement.ps1'))
    Icon                   = @($(if ($cfg.Icon) { $cfg.Icon } else { 'app.ico' }), (T 'logo in het pakket' 'logo in the package'))
    AccentColor            = @($(if ($cfg.AccentColor) { $cfg.AccentColor } else { '#185FA5' }), (T 'kleur van de kop en de knop' 'colour of the header and the button'))
    PopupLanguage          = @($popupLang, (T 'taal van de popups: Auto (Windows-taal van de gebruiker) | nl | en' 'popup language: Auto (user''s Windows language) | nl | en'))
    KitLanguage            = @($Lang, (T 'taal van de logbestanden: nl | en' 'language of the log files: nl | en'))
    MaxPostpones           = @([int]$(if ($null -ne $cfg.MaxPostpones) { $cfg.MaxPostpones } else { 5 }), (T 'hoe vaak Later mag' 'how often Later is allowed'))
    PostponeHours          = @([int]$(if ($null -ne $cfg.PostponeHours) { $cfg.PostponeHours } else { 24 }), (T 'hoe lang een keer uitstellen duurt (uren)' 'how long one postpone lasts (hours)'))
    ConsentTimeoutMinutes  = @([int]$(if ($null -ne $cfg.ConsentTimeoutMinutes) { $cfg.ConsentTimeoutMinutes } else { 15 }), (T 'geen keuze: venster sluiten na (minuten)' 'no choice: close the popup after (minutes)'))
    ForcedDelayMinutes     = @([int]$(if ($null -ne $cfg.ForcedDelayMinutes) { $cfg.ForcedDelayMinutes } else { 5 }), (T 'waarschuwing na de laatste keer uitstellen (minuten)' 'warning after the last postpone (minutes)'))
    InstallWindow          = @($window, (T 'Altijd | Werktijd | BuitenWerktijd  (staat ook in Requirement.ps1)' 'Altijd (always) | Werktijd (working hours) | BuitenWerktijd (outside)  (also in Requirement.ps1)'))
    WorkHours              = @($hours, (T 'werktijd (van-tot)' 'working hours (from-to)'))
    WorkDays               = @($days, (T 'werkdagen' 'working days (ma=Mon di=Tue wo=Wed do=Thu vr=Fri za=Sat zo=Sun)'))
    IdleMinutes            = @($idleMin, (T '> 0 = na zoveel minuten inactief of vergrendeld direct installeren' '> 0 = install right away after this many minutes idle or locked'))
    NoUserAction           = @($noUser, (T 'niemand ingelogd: Installeren | Wachten' 'nobody signed in: Installeren (install) | Wachten (wait)'))
    InstallDuringSetup     = @($duringSetup, (T 'nieuwe laptops (Autopilot) direct installeren (staat ook in Requirement.ps1)' 'new laptops (Autopilot): install right away (also in Requirement.ps1)'))
    RestartMode            = @($restartMode, (T 'herstartmelding na de installatie: Nooit | AlsNodig (exitcode 3010/1641) | Altijd' 'restart prompt after installation: Nooit (never) | AlsNodig (exit code 3010/1641) | Altijd (always)'))
    RestartReminderMinutes = @($restartReminder, (T 'Later bij de herstartmelding: opnieuw vragen na (minuten)' 'Later on the restart prompt: ask again after (minutes)'))
    RestartDeadlineHours   = @($restartDeadline, (T 'na zoveel uur verplicht herstarten (0 = nooit verplicht)' 'mandatory restart after this many hours (0 = never mandatory)'))
    RestartWarningMinutes  = @($restartWarning, (T 'waarschuwing voor de verplichte herstart (minuten)' 'warning before the mandatory restart (minutes)'))
}
foreach ($k in $settingSpec.Keys) {
    $settingLines += ('    {0,-22} = {1}   # {2}' -f $k, (ConvertTo-PsLiteral $settingSpec[$k][0]), $settingSpec[$k][1])
}
$textKeys = @('ConsentSubHeading', 'ConsentMessage', 'ForcedSubHeading', 'ForcedMessage', 'ForcedInfo',
              'InstallingHeading', 'InstallingMessage', 'SuccessHeading', 'SuccessMessage', 'ErrorHeading', 'ErrorMessage',
              'RestartSubHeading', 'RestartMessage', 'RestartForcedSubHeading', 'RestartForcedMessage',
              'UninstallingHeading', 'UninstallingMessage', 'UninstalledHeading', 'UninstalledMessage', 'UninstallErrorHeading', 'UninstallErrorMessage',
              'NewConsentSubHeading', 'NewConsentMessage', 'NewForcedSubHeading', 'NewForcedMessage', 'NewForcedInfo', 'NewInstallingHeading', 'NewInstallingMessage', 'NewSuccessHeading', 'NewSuccessMessage', 'NewErrorHeading', 'NewErrorMessage', 'NewRestartMessage', 'NewRestartForcedMessage')
foreach ($section in 'Texts', 'TextsEn') {
    $own = $cfg[$section]
    $keys = $textKeys + @(if ($own) { $own.Keys | Where-Object { $_ -notin $textKeys } | Sort-Object })
    $settingLines += "    $section = @{"
    foreach ($k in $keys) {
        $t = if ($own -and $own[$k]) { $own[$k] } else { '' }
        $settingLines += ('        {0,-23} = {1}' -f $k, (ConvertTo-PsLiteral $t))
    }
    $settingLines += '    }'
}

$installCmdText = if (Test-Path $appCmdPath) { Read-Text $appCmdPath } else { '' }
$switchNames = @([regex]::Matches($installCmdText + "`n" + "$($cfg.PreInstall)" + "`n" + "$($cfg.PostInstall)", '(?i)defined\s+APP_(\w+)') |
    ForEach-Object { $_.Groups[1].Value.ToUpper() } | Where-Object { $_ -notin 'NOPROCESSCHECK', 'NOCONSENT', 'SILENT', 'EXITCODE' } | Sort-Object -Unique)
$switchLines = if ($switchNames) { ($switchNames | ForEach-Object { "    $_ = `$false" }) -join "`r`n" } else { "    # $(T 'bijvoorbeeld' 'for example'): NOSHORTCUTS = `$true" }

$comps = @($cfg.Components | Where-Object { $_ })
$useComponents = ($cfg.AutoInstallSteps -ne $false) -and $comps.Count
$compLines = @(); $n = 0
if ($useComponents) {
    foreach ($c in $comps) {
        $n++
        $codes = @("$($c.Codes)" -split '[\s,;]+' | Where-Object { $_ -match '^-?\d+$' })
        if (-not $codes) { $codes = '0', '3010', '1641' }
        $name = [System.IO.Path]::GetFileNameWithoutExtension("$($c.File)")
        $compLines += "    @{ Name = $(ConvertTo-PsLiteral $name); Command = $(ConvertTo-PsLiteral (Get-StepCommand $c)); SuccessCodes = $($codes -join ', ') }"
    }
}
$fillPs = {
    param($Text)
    (Fill $Text).Replace('{{BUILDDATE}}', (Get-Date -Format 'yyyy-MM-dd HH:mm'))
}
$installPs = (& $fillPs (Read-Text (Join-Path (Join-Path $kit 'Intune') 'Install.ps1'))).
    Replace('{{SCHAKELAARS}}', $switchLines).
    Replace('{{INSTELLINGEN}}', ($settingLines -join "`r`n")).
    Replace('{{ONDERDELEN}}', ($compLines -join "`r`n")).
    Replace('{{VOOR}}', $(if ($useComponents) { Assert-HereString "$($cfg.PreInstall)" 'PreInstall' } else { '' })).
    Replace('{{NA}}', $(if ($useComponents) { Assert-HereString "$($cfg.PostInstall)" 'PostInstall' } else { '' })).
    Replace('{{EIGEN_SCRIPT}}', $(if ($useComponents) { '' } else { Assert-HereString $installCmdText 'install-app.cmd' }))
Write-Text (Join-Path $intune 'Install.ps1') $installPs

$uninstallCmdText = if (Test-Path (Join-Path $source 'uninstall-app.cmd')) { Read-Text (Join-Path $source 'uninstall-app.cmd') } else { '' }
Write-Text (Join-Path $intune 'Uninstall.ps1') ((& $fillPs (Read-Text (Join-Path (Join-Path $kit 'Intune') 'Uninstall.ps1'))).Replace('{{UNINSTALL}}', (Assert-HereString $uninstallCmdText 'uninstall-app.cmd')).Replace('{{UNINSTALL_NOTIFY}}', $(if ($cfg.UninstallNotify -eq $true) { '$true' } else { '$false' })))
foreach ($f in 'Install.ps1', 'Uninstall.ps1') {
    $kb = [math]::Round((Get-Item (Join-Path $intune $f)).Length / 1KB, 1)
    if ($kb -gt 50) { Write-Warning (T "$f is $kb KB; Intune staat maximaal 50 KB toe. Gebruik dan install.cmd als install command." "$f is $kb KB; Intune allows at most 50 KB. Use install.cmd as install command instead.") }
}

# ---------- Bron: full copy of this version (settings, installers, all files) ----------
Get-ChildItem -Path $source -Force | Where-Object { $_.Extension -ne '.intunewin' } |
    Copy-Item -Destination $bron -Recurse -Force
# Standard texts as they were at this build (for the history)
if (Test-Path (Join-Path $kit 'Standaardteksten.psd1')) { Copy-Item (Join-Path $kit 'Standaardteksten.psd1') $bron -Force }

# ---------- Build info ----------
$fileLines = Get-ChildItem -Path $source -File -Force | Where-Object { $_.Extension -ne '.intunewin' } | Sort-Object Name | ForEach-Object {
    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
    '  {0,-50} {1,14:N0} bytes  SHA256 {2}' -f $_.Name, $_.Length, $hash
}
Write-Text (Join-Path $root 'Bouwinfo.txt') @"
$($cfg.AppName) $($cfg.Version)
$(T 'Gebouwd op  ' 'Built on    '): $(Get-Date -Format 'yyyy-MM-dd HH:mm')
$(T 'Door        ' 'By          '): $env:USERNAME $(T 'op' 'on') $env:COMPUTERNAME
$(T 'Bronmap     ' 'Source      '): $source
$(T 'Taal        ' 'Language    '): $Lang

$(T 'Bestanden in het pakket' 'Files in the package'):
$($fileLines -join "`r`n")
"@

if ($Lang -eq 'en') {
    $restartLine = switch ($restartMode) { 'AlsNodig' { '  (only when the installer returns 3010 or 1641)' } 'Altijd' { '  (after every successful installation)' } default { '  (no restart prompt from the kit)' } }
    $settingsText = @"
$($cfg.AppName) $($cfg.Version) - Intune Win32 app
==========================================

Package
  install.intunewin
  (pack yourself: IntuneWinAppUtil.exe -c .\Pakket -s install.cmd -o .)

Program
  Installer type     : PowerShell script (recommended)
    Install script   : Intune\Install.ps1     (upload separately; can be changed later without repackaging)
    Uninstall script : Intune\Uninstall.ps1
    32-bit: No  |  Signature check: No
    Parameters are switches at the top of Install.ps1 (`$NoProcessCheck, `$NoPopup, `$Silent, `$Switches).
  Or the classic type Command line:
    Install command  : install.cmd    (optionally with parameters, see below)
    Uninstall command: uninstall.cmd
  Install behavior   : System
  Restart behavior   : Determine behavior based on return codes
  Return codes       : keep the defaults (1618 = Retry is already there)

Requirements
  Script             : Intune\Requirement.ps1
  Output data type   : String  |  Operator: Equals  |  Value: Voldaan
  32-bit: No  |  Logged on credentials: No  |  Signature check: No
  (The value is always "Voldaan", Dutch for "met".)

Detection rules
  Custom script      : Intune\Detection.ps1   ("$($cfg.DetectName)" version $($cfg.Version) or higher)
  32-bit: No  |  Signature check: No

Supersedence
  Add the previous version, Uninstall previous version: No

Assignments
  Required. OnlyUpdateExisting = $onlyExisting
  $(if ($onlyExisting) { "-> only devices where $($cfg.DetectName) is already installed." } else { '-> everyone in the assigned group.' })

When
  Time window        : $windowText
  Idle               : $(if ($idleMin -gt 0) { "install right away without popup after $idleMin minutes idle or when the screen is locked" } else { 'off (always show the popup first)' })
  Nobody signed in   : $(if ($noUser -eq 'Wachten') { 'wait until someone signs in' } else { 'install right away (also outside the time window)' })
  Outside the time window the requirement script reports "Outside time window"; Intune tries
  again at a later check. So the installation does not start exactly on the minute.

Languages
  Popups             : $(switch ($popupLang) { 'nl' { 'always Dutch' } 'en' { 'always English' } default { 'English for users with English Windows, otherwise Dutch' } })
  Logs and scripts   : English

Parameters after install.cmd (may be combined, e.g. install.cmd /noshortcuts /noprocesscheck)
  /noprocesscheck  do not check whether the app is running.
                   Then use Intune\Requirement-zonder-procescheck.ps1 as requirement script,
                   otherwise the normal requirement script still holds the installation back.
                   Note: the installer itself must be able to handle a running app.
  /noconsent       no popup, install right away (notifications remain)
  /silent          no popup and no notifications
  /<own name>      available in install-app.cmd as APP_<NAME>, e.g. /noshortcuts -> APP_NOSHORTCUTS
$(if ($appParams) { "  This app uses: $($appParams -join ', ')" })

Restart after installation
  RestartMode        : $restartMode$restartLine
$(if ($restartMode -ne 'Nooit') { @"
  Prompt "Restart now" / "Later"; Later = ask again after $restartReminder minutes.
  $(if ($restartDeadline -gt 0) { "Mandatory after $restartDeadline hours, with $restartWarning minutes warning." } else { 'Never mandatory.' })
  The kit then returns 0 to Intune, so Intune does not show a second restart prompt.
"@ })

Uninstall
  Notifications when removing : $(if ($cfg.UninstallNotify -eq $true) { 'on ("being removed", then "removed" or "failed")' } else { 'off' })

Autopilot (new laptops)
  Install during Autopilot : $(if ($duringSetup) { 'yes, without popup (also when the app is not installed yet)' } else { 'no, the app follows after setup' })
$(if ($duringSetup) { @'
  - Assign the app as Required to a device group with the Autopilot laptops; it then installs
    during the device phase of the Enrollment Status Page.
  - Must the app be there before the user can work? Add it to the ESP profile under
    "Block device use until these required apps are installed".
  - Mind the ESP time-out (60 minutes by default) for large packages.
'@ })

Testing on a laptop
  Logs and counter : C:\ProgramData\AppUpdates\$($cfg.AppId)\  (update.log, PostponeState.json)
  Counter at max   : set PostponeCount to $(if ($cfg.MaxPostpones) { $cfg.MaxPostpones } else { 5 }) in PostponeState.json
"@
}
else {
    $restartLine = switch ($restartMode) { 'AlsNodig' { '  (alleen als de installer 3010 of 1641 geeft)' } 'Altijd' { '  (na elke geslaagde installatie)' } default { '  (geen herstartmelding van de kit)' } }
    $settingsText = @"
$($cfg.AppName) $($cfg.Version) - Intune Win32-app
==========================================

Pakket
  install.intunewin
  (zelf inpakken: IntuneWinAppUtil.exe -c .\Pakket -s install.cmd -o .)

Program
  Installer type     : PowerShell script (aanbevolen)
    Install script   : Intune\Install.ps1     (los uploaden; later aan te passen zonder opnieuw te verpakken)
    Uninstall script : Intune\Uninstall.ps1
    32-bit: No  |  Signature check: No
    Parameters zijn schakelaars bovenaan Install.ps1 (`$NoProcessCheck, `$NoPopup, `$Silent, `$Switches).
  Of het oude type Command line:
    Install command  : install.cmd    (eventueel met parameters, zie hieronder)
    Uninstall command: uninstall.cmd
  Install behavior   : System
  Restart behavior   : Determine behavior based on return codes
  Return codes       : standaard laten staan (1618 = Retry zit er al in)

Requirements
  Script             : Intune\Requirement.ps1
  Output data type   : String  |  Operator: Equals  |  Value: Voldaan
  32-bit: No  |  Logged on credentials: No  |  Signature check: No

Detection rules
  Custom script      : Intune\Detection.ps1   ("$($cfg.DetectName)" versie $($cfg.Version) of hoger)
  32-bit: No  |  Signature check: No

Supersedence
  Voeg de vorige versie toe, Uninstall previous version: No

Assignments
  Required. OnlyUpdateExisting = $onlyExisting
  $(if ($onlyExisting) { "-> alleen apparaten waar $($cfg.DetectName) al op staat." } else { '-> iedereen in de toegewezen groep.' })

Wanneer
  Tijdvenster        : $windowText
  Inactief           : $(if ($idleMin -gt 0) { "na $idleMin minuten inactief of bij een vergrendeld scherm direct installeren, zonder popup" } else { 'uit (altijd eerst de popup)' })
  Niemand ingelogd   : $(if ($noUser -eq 'Wachten') { 'wachten tot er iemand is ingelogd' } else { 'direct installeren (ook buiten het tijdvenster)' })
  Buiten het tijdvenster meldt het requirement-script "Buiten tijdvenster"; Intune probeert het
  bij een volgende controle opnieuw. De installatie start dus niet precies op de minuut.

Talen
  Popups             : $(switch ($popupLang) { 'nl' { 'altijd Nederlands' } 'en' { 'altijd Engels' } default { 'Engels voor gebruikers met Engelse Windows, anders Nederlands' } })
  Logs en scripts    : Nederlands

Parameters achter install.cmd (combineren mag, bijv. install.cmd /noshortcuts /noprocesscheck)
  /noprocesscheck  niet controleren of de app open staat.
                   Gebruik dan Intune\Requirement-zonder-procescheck.ps1 als requirement-script,
                   anders houdt het gewone requirement-script de installatie nog steeds tegen.
                   Let op: de installer moet zelf met een open app om kunnen gaan.
  /noconsent       geen popup, direct installeren (meldingen rechtsonder blijven)
  /silent          geen popup en geen meldingen
  /<eigen naam>    beschikbaar in install-app.cmd als APP_<NAAM>, bijv. /noshortcuts -> APP_NOSHORTCUTS
$(if ($appParams) { "  Deze app gebruikt: $($appParams -join ', ')" })

Herstart na de installatie
  RestartMode        : $restartMode$restartLine
$(if ($restartMode -ne 'Nooit') { @"
  Melding "Nu herstarten" / "Later"; Later = na $restartReminder minuten opnieuw.
  $(if ($restartDeadline -gt 0) { "Na $restartDeadline uur verplicht, met $restartWarning minuten waarschuwing." } else { 'Nooit verplicht.' })
  De kit geeft dan 0 aan Intune, zodat Intune geen tweede herstartmelding toont.
"@ })

Verwijderen
  Meldingen bij verwijderen : $(if ($cfg.UninstallNotify -eq $true) { 'aan ("wordt verwijderd", daarna "verwijderd" of "niet gelukt")' } else { 'uit' })

Autopilot (nieuwe laptops)
  Installeren tijdens Autopilot : $(if ($duringSetup) { 'ja, zonder popup (ook als de app er nog niet op staat)' } else { 'nee, de app komt na de inrichting' })
$(if ($duringSetup) { @'
  - Wijs de app Required toe aan een apparaatgroep met de Autopilot-laptops, dan installeert
    hij al in de apparaatfase van de inrichtingspagina.
  - Moet de app er staan voordat de gebruiker kan werken? Zet hem in het ESP-profiel bij
    "Block device use until these required apps are installed".
  - Houd rekening met de ESP-time-out (standaard 60 minuten) bij grote pakketten.
'@ })

Testen op een laptop
  Logs en teller : C:\ProgramData\AppUpdates\$($cfg.AppId)\  (update.log, PostponeState.json)
  Teller op max  : zet PostponeCount op $(if ($cfg.MaxPostpones) { $cfg.MaxPostpones } else { 5 }) in PostponeState.json
"@
}
Write-Text (Join-Path $root 'Intune-instellingen.txt') $settingsText

# ---------- Pack (when IntuneWinAppUtil.exe is available) ----------
$tool = @((Join-Path $KitRoot 'IntuneWinAppUtil.exe'), (Get-Command IntuneWinAppUtil.exe -ErrorAction SilentlyContinue).Source) |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$packed = $false
if ($tool) {
    Write-Host (T 'Bezig met inpakken (IntuneWinAppUtil)...' 'Packing (IntuneWinAppUtil)...')
    & $tool -c $pkg -s 'install.cmd' -o $root -q | Out-Null
    if (Test-Path (Join-Path $root 'install.intunewin')) {
        $packed = $true
        Write-Host "$(T 'Ingepakt' 'Packed'): $(Join-Path $root 'install.intunewin')" -ForegroundColor Green
        if (-not $KeepPackageFolder) { Remove-Item -Path $pkg -Recurse -Force }
    }
    else { Write-Warning (T 'IntuneWinAppUtil heeft geen install.intunewin gemaakt.' 'IntuneWinAppUtil did not create install.intunewin.') }
}
else {
    Write-Host (T 'Tip: zet IntuneWinAppUtil.exe naast dit script, dan wordt install.intunewin ook meteen gemaakt.' 'Tip: put IntuneWinAppUtil.exe next to this script, then install.intunewin is created right away.') -ForegroundColor Yellow
}

Write-Host "`n$(T 'Klaar' 'Done'): $root" -ForegroundColor Green
if ($packed) { Write-Host (T '  install.intunewin        -> uploaden in Intune' '  install.intunewin        -> upload in Intune') }
else         { Write-Host (T '  Pakket\                  -> inpakken met IntuneWinAppUtil' '  Pakket\                  -> pack with IntuneWinAppUtil') }
Write-Host (T '  Intune\                  -> Install.ps1 + Uninstall.ps1 (installer type PowerShell script),' '  Intune\                  -> Install.ps1 + Uninstall.ps1 (installer type PowerShell script),')
Write-Host (T '                              Requirement.ps1 en Detection.ps1 los uploaden' '                              upload Requirement.ps1 and Detection.ps1 separately')
Write-Host (T '  Intune-instellingen.txt  -> alle instellingen voor Intune' '  Intune-instellingen.txt  -> all settings for Intune')
Write-Host (T '  Bron\ + Bouwinfo.txt     -> volledige kopie en gegevens van deze versie' '  Bron\ + Bouwinfo.txt     -> full copy and details of this version')

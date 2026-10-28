<#
.SYNOPSIS
    Step 2: builds the Intune package from a filled-in app folder.

.DESCRIPTION
    Reads Apps\<App>\app.psd1, checks that everything is right and creates a folder per version:
      Output\<AppId>\<version>\install.intunewin        the package for Intune
      Output\<AppId>\<version>\Intune\Requirement.ps1   upload separately at Requirements
      Output\<AppId>\<version>\Intune\Detection.ps1     upload separately at Detection rules
      Output\<AppId>\<version>\Intune\Install.ps1       PowerShell installer for Intune (with Uninstall.ps1)
      Output\<AppId>\<version>\Intune-settings.txt      all Intune settings in one list
      Output\<AppId>\<version>\Source\                  full copy of this version (including the installers)
      Output\<AppId>\_archive\<version>_<date>\         earlier builds of the same version (when rebuilding)
      Output\<AppId>\<version>\BuildInfo.txt            when, by whom, which files (with SHA-256)
    If app.psd1 has an OutputFolder (e.g. I:\...\versions\8.9.8.1\intune-package), all of this goes
    into that folder. Output\<AppId>\<version>\PackageLocation.txt then says where the package is.
    install.intunewin is created if IntuneWinAppUtil.exe is in this folder or in PATH.
    If that works, the temporary folder Package\ is removed (use -KeepPackageFolder to keep it).

.EXAMPLE
    .\Build-Package.ps1 -App NotepadPlusPlus
#>

param
(
    [Parameter(Mandatory)][string]$App,                       # folder name under Apps\, or a full path
    [string]$Output = '',                                     # default: Output next to this script
    [switch]$KeepPackageFolder                                # keep the Package\ folder after packaging
)

$ErrorActionPreference = 'Stop'
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
# Determine the kit folder (also if $PSScriptRoot is empty, e.g. when started from PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Can't find the AppUpdateKit folder. First go to that folder (cd <path to AppUpdateKit>) and start the script there, e.g. .\Build-Package.ps1 -App NotepadPlusPlus"
}
# Language: in another language (chosen in the Builder) this script runs translated, with Language\<language>.xml
. (Join-Path (Join-Path $KitRoot 'Language') 'Translate.ps1')
$translated = Get-AppKitScriptBlock $PSCommandPath; if ($translated) { . $translated @PSBoundParameters; return }   # LANGSWITCH

if (-not $Output) { $Output = Join-Path $KitRoot 'Output' }
$kit = Join-Path $KitRoot '_Kit'
$KitVersion = 'unknown'
try { $KitVersion = ([System.IO.File]::ReadAllText((Join-Path $KitRoot 'VERSION'))).Trim() } catch { }
# Own settings are not in GitHub: create them from the default version if they don't exist yet
# Versions before 1.3 used Dutch file names: move those first.
foreach ($pair in @(@('Instellingen.psd1', 'Settings.psd1'), @('Standaardteksten.psd1', 'DefaultTexts.nl.psd1'), @('Standaardteksten.en.psd1', 'DefaultTexts.psd1'))) {
    $oldFile = Join-Path $kit $pair[0]; $newFile = Join-Path $kit $pair[1]
    if ((Test-Path $oldFile) -and -not (Test-Path $newFile)) { try { Move-Item -LiteralPath $oldFile -Destination $newFile } catch { } }
}
foreach ($kitFileName in 'Settings', 'DefaultTexts', 'DefaultTexts.nl') {
    $kitFileOwn = Join-Path $kit "$kitFileName.psd1"; $kitFileStd = Join-Path $kit "$kitFileName.default.psd1"
    if (-not (Test-Path $kitFileOwn) -and (Test-Path $kitFileStd)) { Copy-Item $kitFileStd $kitFileOwn }
}

$source = if (Test-Path $App) { (Resolve-Path $App).Path } else { Join-Path (Join-Path $KitRoot 'Apps') $App }
if (-not (Test-Path (Join-Path $source 'app.psd1'))) { throw "No app.psd1 found in $source" }

# Read via a copy with BOM: Notepad saves UTF-8 without BOM, and then
# Windows PowerShell 5.1 reads characters like é/ï wrongly.
$psdTemp = [System.IO.Path]::GetTempFileName() + '.psd1'
[System.IO.File]::WriteAllText($psdTemp, [System.IO.File]::ReadAllText((Join-Path $source 'app.psd1')), (New-Object System.Text.UTF8Encoding $true))
try { $cfg = ConvertTo-CurrentSettings (Import-PowerShellDataFile -Path $psdTemp) }
catch { throw "app.psd1 contains an error (check quotes and brackets): $($_.Exception.Message)" }
finally { Remove-Item $psdTemp -Force -ErrorAction SilentlyContinue }
# Language of the app: the scripts from _Kit are translated to it when building (Language\<language>.xml)
$AppLang = if ("$($cfg.Language)" -eq 'en') { 'en' } else { 'nl' }
function Read-KitText([string]$Rel) { Convert-AppKitFile -Path (Join-Path $kit $Rel) -Lang $AppLang }   # file from _Kit, in the language of the app
$stdTextsFile = if ($AppLang -eq 'nl') { Join-Path $kit 'DefaultTexts.nl.psd1' } else { Join-Path $kit 'DefaultTexts.psd1' }

# ---------- Checks ----------
$problems = @(); $warnings = @()
if ($cfg.AppId -notmatch '^[A-Za-z0-9_-]+$')   { $problems += 'AppId may only contain letters, digits, - and _.' }
if (-not $cfg.AppName)                          { $problems += 'AppName is empty.' }
if ($cfg.Version -notmatch '^\d+(\.\d+){0,3}$') { $problems += "Version '$($cfg.Version)' is not a valid version (e.g. 1.2.3)." }
if (-not $cfg.DetectName)                       { $problems += 'DetectName is empty.' }
if (-not @($cfg.Processes | Where-Object { $_ }).Count) { $warnings += 'No processes filled in: the installation does not check whether the app is open.' }
if ($cfg.AccentColor -and $cfg.AccentColor -notmatch '^#[0-9A-Fa-f]{6}$') { $problems += "AccentColor '$($cfg.AccentColor)' must have the form #RRGGBB." }

foreach ($f in 'install-app.cmd', 'uninstall-app.cmd') {
    if (-not (Test-Path (Join-Path $source $f))) { $problems += "$f ontbreekt." }
}

$icon = if ($cfg.Icon) { $cfg.Icon } else { 'app.ico' }
if (-not (Test-Path (Join-Path $source $icon))) { $warnings += "Logo '$icon' not found: the windows then show no logo." }

function Get-InvalidMsiSwitch([string]$Arguments)
{
    # Options msiexec doesn't know (e.g. /S or /VERYSILENT of an .exe installer): msiexec then stops with 1639
    $ok = '^/(i|x|p|a|j[um]?|f[a-z]*|l[a-z\*\+!]*|log|q[nbrf]?[\+\-!]*|quiet|passive|norestart|forcerestart|promptrestart|package|uninstall|update|help|\?|y|z)$'
    return @(("$Arguments" -split '\s+') | Where-Object { $_ -like '/*' -and $_ -notmatch $ok })
}

# Installers named in install-app.cmd must be in the folder
$installText = Get-Content -Path (Join-Path $source 'install-app.cmd') -Raw -ErrorAction SilentlyContinue
if ($installText) {
    $active = ($installText -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(rem|::)' }) -join "`n"
    foreach ($m in [regex]::Matches($active, '"([^"\\/:%]+\.(exe|msi|msp|ps1|cmd|bat|reg))"', 'IgnoreCase')) {
        if (-not (Test-Path (Join-Path $source $m.Groups[1].Value))) {
            $want = $m.Groups[1].Value
            $ext  = [System.IO.Path]::GetExtension($want)
            $have = @(Get-ChildItem -Path $source -File -Filter "*$ext" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
            $msg  = "install-app.cmd uses '$want', but that file is not in the folder."
            $msg += if ($have.Count) { "`n      In the folder ($ext): $($have -join ', ')`n      Different name? Rename the file, or choose it again as a component in tab 2." }
                    else { "`n      There is no $ext file in the folder at all. Put the installer in $source." }
            $problems += $msg
        }
    }
    if ($active -notmatch 'APP_EXITCODE') { $warnings += "install-app.cmd doesn't set APP_EXITCODE; success/failure is then not reported correctly." }
    # msiexec lines with options msiexec doesn't know (e.g. /S of an .exe): that gives error code 1639
    foreach ($line in ($active -split "`n" | Where-Object { $_ -match '^\s*msiexec(\.exe)?\s' })) {
        $bad = Get-InvalidMsiSwitch ($line -replace '"[^"]*"', '')
        if ($bad) { $problems += "install-app.cmd: '$($bad -join ' ')' is not an msiexec option:`n      $($line.Trim())`n      Remove it (in the Builder: tab 2, Parameters column); otherwise the installation fails with error code 1639." }
    }
}

$un = Join-Path $source 'uninstall-app.cmd'
if (Test-Path -LiteralPath $un) {
    # Uninstall steps the Builder couldn't fill in itself (e.g. a script without an uninstall script)
    foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($un), '(?m)^rem (?:VUL IN|FILL IN): (.+)$')) {
        $warnings += "uninstall-app.cmd is not complete yet: $($m.Groups[1].Value.Trim())"
    }
}

$warnings | ForEach-Object { Write-Warning $_ }
if ($problems) {
    $problems | ForEach-Object { Write-Host "ERROR: $_" -ForegroundColor Red }
    throw "Package not built: first fix the errors above in $source"
}

# ---------- Folders: Output\<AppId>\<version>\, or the own folder from OutputFolder ----------
$kitVersionDir  = Join-Path (Join-Path $Output $cfg.AppId) $cfg.Version
$external = "$($cfg.OutputFolder)".Trim()
if ($external) { $external = [Environment]::ExpandEnvironmentVariables($external).TrimEnd('\') }
if ($external) {
    # Is the chosen folder inside the kit's own Output folder? Then use the normal layout Output\<AppId>\<version>,
    # so every version gets its own folder.
    $outFull = [System.IO.Path]::GetFullPath($Output).TrimEnd('\', '/')
    $extFull = [System.IO.Path]::GetFullPath($external).TrimEnd('\', '/')
    if ($extFull -eq $outFull -or $extFull.StartsWith($outFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "Save package to is inside the Output folder of the kit: the package goes into Output\$($cfg.AppId)\$($cfg.Version)." -ForegroundColor Yellow
        $external = ''
    }
}
function Test-IsInside([string]$Child, [string]$Parent) {
    # Is $Child inside (or equal to) $Parent? Full paths, case doesn't matter.
    $c = [System.IO.Path]::GetFullPath($Child).TrimEnd('\', '/')
    $p = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    return ($c -eq $p -or $c.StartsWith($p + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))
}
if ($external -and (Test-IsInside $external (Join-Path $KitRoot 'Apps'))) {
    # The package must not go into the app folder (or Apps\): then every build copies itself into the package
    throw "Save package to is inside the app folder: $external`nChoose a folder outside Apps\, for example the version folder next to the installer (...\versions\<version>). Change OutputFolder in tab 1 or in app.psd1."
}
$root     = if ($external) { $external } else { $kitVersionDir }
$pointer  = Join-Path $kitVersionDir 'PackageLocation.txt'
$oldPointer = Join-Path $kitVersionDir 'Pakketlocatie.txt'   # name in versions before 1.3
if ((Test-Path $oldPointer) -and -not (Test-Path $pointer)) { Move-Item -LiteralPath $oldPointer -Destination $pointer }
# Was there only a reference to an own folder here, and are we now building in the kit? Remove the reference.
if (-not $external -and (Test-Path $pointer) -and @(Get-ChildItem $kitVersionDir -Force).Count -eq 1) { Remove-Item $kitVersionDir -Recurse -Force }

function Get-FreeArchivePath([string]$Path) {
    # Does this archive folder exist already (e.g. after an earlier failed build)? Then add _2, _3 ...
    $p = $Path; $n = 2
    while (Test-Path -LiteralPath $p) { $p = "${Path}_$n"; $n++ }
    return $p
}
function Move-Folder([string]$From, [string]$To) {
    # Move; Move-Item can't move folders to another drive, so copy and clean up afterwards.
    try { Move-Item -LiteralPath $From -Destination $To -ErrorAction Stop; return }
    catch {
        $sameDrive = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($From)) -eq [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($To))
        if ($sameDrive) { throw }
    }
    Copy-Item -LiteralPath $From -Destination $To -Recurse -Force -ErrorAction Stop
    try { Remove-Item -LiteralPath $From -Recurse -Force -ErrorAction Stop }
    catch { Remove-Item -LiteralPath $To -Recurse -Force -ErrorAction SilentlyContinue; throw }
}
function Move-BuildToArchive([string]$From, [string]$To) {
    # The contents of a previous build to the archive, item by item. The folder itself stays:
    # so it may be open in Explorer (the Builder opens it after building).
    # If an item fails (file in use), everything goes back and the build stops: nothing is lost.
    New-Item -Path $To -ItemType Directory -Force | Out-Null
    $moved = New-Object System.Collections.ArrayList
    foreach ($item in @(Get-ChildItem -LiteralPath $From -Force)) {
        $dest = Join-Path $To $item.Name
        try { Move-Folder $item.FullName $dest; [void]$moved.Add($item.Name) }
        catch {
            foreach ($n in $moved) { try { Move-Folder (Join-Path $To $n) (Join-Path $From $n) } catch { } }
            if (@(Get-ChildItem -LiteralPath $To -Force).Count -eq 0) { Remove-Item -LiteralPath $To -Force -ErrorAction SilentlyContinue }
            throw "$($item.FullName) is in use, so the previous build can't be moved to the archive.`nClose the program that has this file or folder open (e.g. a command prompt, Explorer in a subfolder, or an upload of install.intunewin) and build again.`nNothing has been deleted. ($($_.Exception.Message))"
        }
    }
}
if ($external) {
    $parent = Split-Path $root -Parent
    if ($parent -and -not (Test-Path $parent)) {
        # Folder not created yet (e.g. a new version folder): create it, unless the drive can't be reached
        try { New-Item -Path $parent -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        catch { throw "The folder for the package can't be created: $parent (OutputFolder in app.psd1). Is the drive mapped? $($_.Exception.Message)" }
    }
    # Was this version built in the kit itself before (no reference)? That build goes to the archive.
    if ((Test-Path $kitVersionDir) -and -not (Test-Path $pointer)) {
        $old = Get-FreeArchivePath (Join-Path (Join-Path (Join-Path $Output $cfg.AppId) '_archive') "$($cfg.Version)_$((Get-Item $kitVersionDir).LastWriteTime.ToString('yyyyMMdd-HHmmss'))")
        New-Item -Path (Split-Path $old -Parent) -ItemType Directory -Force | Out-Null
        Move-BuildToArchive $kitVersionDir $old
        Remove-Item -LiteralPath $kitVersionDir -Force -ErrorAction SilentlyContinue   # empty folder; if it is open, it simply stays
    }
}
$pkg    = Join-Path $root 'Package'
$intune = Join-Path $root 'Intune'
$sourceCopy   = Join-Path $root 'Source'
# Is there a build here already (BuildInfo.txt, or folders of a half-finished build)? It goes to the archive.
# An empty folder (e.g. just created by the Builder) is simply used.
$previous = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -in 'BuildInfo.txt', 'Package', 'Intune', 'Source', 'Intune-settings.txt', 'install.intunewin', 'Bouwinfo.txt', 'Pakket', 'Bron', 'Intune-instellingen.txt' })   # (also the Dutch names of versions before 1.3)
if ($previous.Count) {
    # Throw nothing away: the previous build of this version goes to the archive
    $infoFile = @('BuildInfo.txt', 'Bouwinfo.txt' | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path -LiteralPath $_ }) | Select-Object -First 1
    $stampSource = if ($infoFile) { Get-Item -LiteralPath $infoFile } else { Get-Item -LiteralPath $root }
    $archiveDir = Join-Path (Join-Path $Output $cfg.AppId) '_archive'
    $archive = Get-FreeArchivePath (Join-Path $archiveDir "$($cfg.Version)_$($stampSource.LastWriteTime.ToString('yyyyMMdd-HHmmss'))")
    New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null
    Move-BuildToArchive $root $archive   # move first: if that fails, the build stops before anything is gone
    # Package\ is a temporary folder: don't keep it in the archive
    foreach ($tmpDir in 'Package', 'Pakket') { if (Test-Path -LiteralPath (Join-Path $archive $tmpDir)) { Remove-Item -LiteralPath (Join-Path $archive $tmpDir) -Recurse -Force -ErrorAction SilentlyContinue } }
    Write-Warning "Version $($cfg.Version) had already been built. That build is kept in _archive\$(Split-Path $archive -Leaf)."
}
New-Item -Path $pkg, $intune, $sourceCopy -ItemType Directory -Force | Out-Null
if ($external) {
    # Reference in the kit, so the Builder (Versions tab) finds this build
    New-Item -Path $kitVersionDir -ItemType Directory -Force | Out-Null
    [System.IO.File]::WriteAllText($pointer, $root, (New-Object System.Text.UTF8Encoding $true))
}

$utf8Bom = New-Object System.Text.UTF8Encoding $true
function Write-Text($Path, $Text, [switch]$Cmd) {
    $Text = $Text -replace "`r?`n", "`r`n"
    if ($Cmd) {
        if ($Text -match '[^\x00-\x7F]') { Write-Warning "$(Split-Path $Path -Leaf) contains special characters (é, ï, ...); cmd may pass them on incorrectly." }
        [System.IO.File]::WriteAllText($Path, $Text, [System.Text.Encoding]::Default)
    }
    else { [System.IO.File]::WriteAllText($Path, $Text, $utf8Bom) }
}
function Read-Text($Path) { [System.IO.File]::ReadAllText($Path) }   # detects UTF-8 with/without BOM itself

$processList = ($cfg.Processes | Where-Object { $_ } | ForEach-Object { "'$($_ -replace '\.exe$', '')'" }) -join ', '
$onlyExisting = if ($null -eq $cfg.OnlyUpdateExisting) { $true } else { [bool]$cfg.OnlyUpdateExisting }
$window   = if ($cfg.InstallWindow) { $cfg.InstallWindow } else { 'Always' }
$hours    = if ($cfg.WorkHours) { (("$($cfg.WorkHours)" -split '[,;]') | ForEach-Object { $_ -replace '\s', '' } | Where-Object { $_ }) -join ',' } else { '08:00-17:00' }
$days     = if ($cfg.WorkDays) { $cfg.WorkDays } else { 'mon,tue,wed,thu,fri' }
$noUser   = if ($cfg.NoUserAction) { $cfg.NoUserAction } else { 'Install' }
$idleMin  = [int]("0$($cfg.IdleMinutes)")
# Own parameters install-app.cmd uses (APP_XXX), for the list in Intune-settings.txt
$appCmdPath = Join-Path $source 'install-app.cmd'
$appParams = @()
if (Test-Path $appCmdPath) {
    $appParams = @([regex]::Matches((Get-Content $appCmdPath -Raw), '(?i)defined\s+APP_(\w+)') | ForEach-Object { '/' + $_.Groups[1].Value.ToLower() } | Sort-Object -Unique)
}
$restartMode = if ($cfg.RestartMode) { $cfg.RestartMode } else { 'Never' }
if ($restartMode -notin 'Never', 'IfNeeded', 'Always') { throw "RestartMode must be 'Never', 'IfNeeded' or 'Always' (now: '$restartMode')." }
$restartReminder = if ($null -ne $cfg.RestartReminderMinutes) { [int]$cfg.RestartReminderMinutes } else { 60 }
$restartDeadline = if ($null -ne $cfg.RestartDeadlineHours) { [int]$cfg.RestartDeadlineHours } else { 24 }
$restartWarning  = if ($null -ne $cfg.RestartWarningMinutes) { [int]$cfg.RestartWarningMinutes } else { 15 }
$duringSetup = if ($null -eq $cfg.InstallDuringSetup) { $true } else { [bool]$cfg.InstallDuringSetup }
if ($window -notin 'Always', 'DuringWorkHours', 'OutsideWorkHours') { throw "InstallWindow must be 'Always', 'DuringWorkHours' or 'OutsideWorkHours' (now: '$window')." }
if ($noUser -notin 'Install', 'Wait') { throw "NoUserAction must be 'Install' or 'Wait' (now: '$noUser')." }
if ($window -ne 'Always' -and @($hours -split ',' | Where-Object { $_ -notmatch '^\d{1,2}:\d{2}-\d{1,2}:\d{2}$' }).Count) { throw "WorkHours must have the form '08:00-17:00', or multiple blocks like '09:00-10:00,13:00-14:00' (now: '$hours')." }
$windowText = switch ($window) {
    'DuringWorkHours'       { "only within the chosen times ($days, $($hours -replace ',', ', '))" }
    'OutsideWorkHours' { "only outside the chosen times (outside $days, $($hours -replace ',', ', '))" }
    default          { 'always' }
}
# ---------- Detection (DetectionMethod in app.psd1) ----------
$detectMethod  = if ($cfg.DetectionMethod) { "$($cfg.DetectionMethod)" } else { 'AppsAndFeatures' }
if ($detectMethod -notin 'AppsAndFeatures', 'File', 'Registry', 'Script') { throw "DetectionMethod must be 'AppsAndFeatures', 'File', 'Registry' or 'Script' (now: '$detectMethod')." }
$detectVersion = if ("$($cfg.DetectVersion)".Trim()) { "$($cfg.DetectVersion)".Trim() } else { "$($cfg.Version)" }
if ($detectVersion -eq '-') { $detectVersion = '' }   # '-' = only check that it exists, no version
if ($detectMethod -eq 'File' -and -not "$($cfg.DetectFile)".Trim()) { throw 'Detection File: DetectFile is empty (e.g. %ProgramFiles%\Remote help\RemoteHelp.exe).' }
if ($detectMethod -eq 'Registry' -and -not "$($cfg.DetectRegKey)".Trim()) { throw 'Detection Registry: DetectRegKey is empty (e.g. HKLM\SOFTWARE\Vendor\App).' }
if ($detectMethod -eq 'Script' -and -not "$($cfg.DetectScript)".Trim()) { throw 'Detection Script: DetectScript is empty.' }
$detectText = switch ($detectMethod) {
    'File'  { "file $($cfg.DetectFile)$(if ($detectVersion) { ", version $detectVersion or higher" })" }
    'Registry' { "registry $($cfg.DetectRegKey)$(if ($cfg.DetectRegValue) { "\$($cfg.DetectRegValue)" })$(if ($detectVersion) { ", version $detectVersion or higher" })" }
    'Script'   { 'own detection script' }
    default    { "`"$($cfg.DetectName)`" in Apps & features$(if ($detectVersion) { ", version $detectVersion or higher" })" }
}

function Fill($Text) {
    $Text.Replace('{{APPID}}', $cfg.AppId).Replace('{{APPNAME}}', $cfg.AppName).
          Replace('{{DETECT_NAME}}', $cfg.DetectName.Replace("'", "''")).Replace('{{VERSION}}', $cfg.Version).
          Replace('{{PROCESSES}}', $processList).Replace('{{ONLY_IF_INSTALLED}}', $onlyExisting.ToString().ToLower()).
          Replace('{{INSTALL_WINDOW}}', $window).Replace('{{WORK_HOURS}}', $hours).Replace('{{WORK_DAYS}}', $days).
          Replace('{{NO_USER_ACTION}}', $noUser).Replace('{{INSTALL_DURING_SETUP}}', $duringSetup.ToString().ToLower()).
          Replace('{{DETECT_METHOD}}', $detectMethod).Replace('{{DETECT_VERSION}}', $detectVersion.Replace("'", "''")).
          Replace('{{DETECT_FILE}}', "$($cfg.DetectFile)".Replace("'", "''")).Replace('{{DETECT_REGKEY}}', "$($cfg.DetectRegKey)".Replace("'", "''")).
          Replace('{{DETECT_REGVALUE}}', "$($cfg.DetectRegValue)".Replace("'", "''"))
}

# ---------- Package ----------
# 1. Everything from the app folder (installers, logo, own scripts, extra files)
#    A folder that is itself a built package (e.g. an old intune-package in the app folder) is left out
$sourceItems = @(Get-ChildItem -Path $source -Force | Where-Object { $_.Extension -ne '.intunewin' } | Where-Object {
    $isBuild = $_.PSIsContainer -and ((Test-Path (Join-Path $_.FullName 'BuildInfo.txt')) -or (Test-Path (Join-Path $_.FullName 'Bouwinfo.txt')) -or (Test-Path (Join-Path $_.FullName 'Package')) -or (Test-Path (Join-Path $_.FullName 'Pakket')) -or $_.Name -eq 'intune-package')
    if ($isBuild) { Write-Warning "The folder $($_.Name) in the app folder looks like a built package and is not included in the package. Remove it from $source." }
    -not $isBuild
})
# _admx\ (ADMX, ADML and the settings chosen in the Builder) is only for the admin: not to the laptop, but in Source\
$sourceItems | Where-Object { $_.Name -ne '_admx' } | Copy-Item -Destination $pkg -Recurse -Force

# 2. app.psd1 and the own cmd files with the right encoding
Write-Text (Join-Path $pkg 'app.psd1') (Read-Text (Join-Path $source 'app.psd1'))
foreach ($f in 'install-app.cmd', 'uninstall-app.cmd') { Write-Text (Join-Path $pkg $f) (Read-Text (Join-Path $source $f)) -Cmd }

# 3. Shared scripts and default texts (identical for every app), in the language of the app
foreach ($f in 'AppUI.ps1', 'AppUI-Launcher.ps1', 'Ask-InstallConsent.ps1', 'Show-Toast.ps1', 'Test-AppRunning.ps1', 'Get-IdleTime.ps1', 'Set-RestartPrompt.ps1', 'Restart-Prompt.ps1', 'Remove-App.ps1', 'Test-AppInstalled.ps1') {
    if (Test-Path (Join-Path $kit $f)) { Write-Text (Join-Path $pkg $f) (Read-KitText $f) }
}
if (Test-Path $stdTextsFile) { Write-Text (Join-Path $pkg 'DefaultTexts.psd1') (Read-Text $stdTextsFile) }
foreach ($f in 'install.cmd', 'uninstall.cmd') {
    Write-Text (Join-Path $pkg $f) (Fill (Read-KitText $f)) -Cmd
}

# ---------- Intune scripts ----------
Write-Text (Join-Path $intune 'Requirement.ps1') ((Fill (Read-KitText 'Intune\Requirement.ps1')).Replace('{{CHECK_PROCESSES}}', 'true'))
if ($detectMethod -ne 'Script') {
    # Short detection script with only the chosen method (Detection-AppsAndFeatures.ps1, -File or -Registry)
    Write-Text (Join-Path $intune 'Detection.ps1') (Fill (Read-KitText "Intune\Detection-$detectMethod.ps1"))
}
else {
    # Own detection script from the Builder (DetectScript in app.psd1)
    $own = @(
        '<#'
        "    Intune detection script for $($cfg.AppName) $($cfg.Version) - own script (Builder, tab 1 > Detection)."
        '    Upload this SEPARATELY in Intune (Detection rules > Use a custom detection script). 32-bit: No, signature check: No.'
        '    Writing something to the output + exit 0 = detected. Writing nothing = not detected.'
        '#>'
        ''
        "$($cfg.DetectScript)".TrimEnd()
    ) -join "`r`n"
    Write-Text (Join-Path $intune 'Detection.ps1') ($own + "`r`n")
    $e = $null; [System.Management.Automation.Language.Parser]::ParseInput($own, [ref]$null, [ref]$e) | Out-Null
    if ($e) { throw "The own detection script contains an error: $($e[0].Message) (line $($e[0].Extent.StartLineNumber - 7))" }
}
# Variant for install.cmd /noprocesscheck: without checking whether the app is open
Write-Text (Join-Path $intune 'Requirement-NoProcessCheck.ps1') ((Fill (Read-KitText 'Intune\Requirement.ps1')).Replace('{{CHECK_PROCESSES}}', 'false'))

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
        'REG'   { "reg.exe import `"$($c.File)`" /reg:64" }
        default { "`"$($c.File)`" $a" }
    }
    return $line.Trim()
}
function Assert-HereString([string]$Text, [string]$What) {
    if ($Text -match "(?m)^'@") { throw "$What contains a line that starts with '@; that is not possible in Install.ps1. Change that line." }
    return $Text.TrimEnd()
}

$settingLines = @()
$settingSpec = [ordered]@{
    AppId                 = @($cfg.AppId, 'do not change: folder, counter and log')
    AppName               = @($cfg.AppName, 'name in the windows')
    DetectName            = @($cfg.DetectName, 'name in Apps & features: determines new installation or update')
    Version               = @($cfg.Version, 'version in this package (new version = new package)')
    Processes             = @(@($cfg.Processes | Where-Object { $_ }), 'also in Requirement.ps1')
    Icon                  = @($(if ($cfg.Icon) { $cfg.Icon } else { 'app.ico' }), 'logo in the package')
    AccentColor           = @($(if ($cfg.AccentColor) { $cfg.AccentColor } else { '#185FA5' }), 'colour of the header and the button')
    MaxPostpones          = @([int]$(if ($null -ne $cfg.MaxPostpones) { $cfg.MaxPostpones } else { 5 }), 'how often Later is allowed')
    PostponeHours         = @([int]$(if ($null -ne $cfg.PostponeHours) { $cfg.PostponeHours } else { 24 }), 'how long one postpone lasts (hours)')
    ConsentTimeoutMinutes = @([int]$(if ($null -ne $cfg.ConsentTimeoutMinutes) { $cfg.ConsentTimeoutMinutes } else { 15 }), 'no choice: close window after (minutes)')
    ForcedDelayMinutes    = @([int]$(if ($null -ne $cfg.ForcedDelayMinutes) { $cfg.ForcedDelayMinutes } else { 5 }), 'warning after the last postpone (minutes)')
    InstallWindow         = @($window, 'Always | DuringWorkHours | OutsideWorkHours  (also in Requirement.ps1)')
    WorkHours             = @($hours, 'times (from-to); multiple blocks: ''09:00-10:00,13:00-14:00''')
    WorkDays              = @($days, 'werkdagen')
    IdleMinutes           = @($idleMin, '> 0 = install right away after this many minutes idle or locked')
    NoUserAction          = @($noUser, 'nobody signed in: Install | Wait')
    InstallDuringSetup    = @($duringSetup, 'install right away on new laptops (Autopilot) (also in Requirement.ps1)')
    RestartMode           = @($restartMode, 'restart prompt after the installation: Never | IfNeeded (exit code 3010/1641) | Always')
    RestartReminderMinutes = @($restartReminder, 'Later on the restart prompt: ask again after (minutes)')
    RestartDeadlineHours  = @($restartDeadline, 'forced restart after this many hours (0 = never forced)')
    RestartWarningMinutes = @($restartWarning, 'warning before the forced restart (minutes)')
}
foreach ($k in $settingSpec.Keys) {
    $settingLines += ('    {0,-22} = {1}   # {2}' -f $k, (ConvertTo-PsLiteral $settingSpec[$k][0]), $settingSpec[$k][1])
}
$textKeys = @('ConsentSubHeading', 'ConsentMessage', 'ForcedSubHeading', 'ForcedMessage', 'ForcedInfo',
              'InstallingHeading', 'InstallingMessage', 'SuccessHeading', 'SuccessMessage', 'ErrorHeading', 'ErrorMessage',
              'RestartSubHeading', 'RestartMessage', 'RestartForcedSubHeading', 'RestartForcedMessage',
              'UninstallingHeading', 'UninstallingMessage', 'UninstalledHeading', 'UninstalledMessage', 'UninstallErrorHeading', 'UninstallErrorMessage',
              'NewConsentSubHeading', 'NewConsentMessage', 'NewForcedSubHeading', 'NewForcedMessage', 'NewForcedInfo', 'NewInstallingHeading', 'NewInstallingMessage', 'NewSuccessHeading', 'NewSuccessMessage', 'NewErrorHeading', 'NewErrorMessage', 'NewRestartMessage', 'NewRestartForcedMessage')
if ($cfg.Texts) { $textKeys += @($cfg.Texts.Keys | Where-Object { $_ -notin $textKeys } | Sort-Object) }
$settingLines += '    Texts = @{'
foreach ($k in $textKeys) {
    $t = if ($cfg.Texts -and $cfg.Texts[$k]) { $cfg.Texts[$k] } else { '' }
    $settingLines += ('        {0,-23} = {1}' -f $k, (ConvertTo-PsLiteral $t))
}
$settingLines += '    }'

$installCmdText = if (Test-Path $appCmdPath) { Read-Text $appCmdPath } else { '' }
$switchNames = @([regex]::Matches($installCmdText + "`n" + "$($cfg.PreInstall)" + "`n" + "$($cfg.PostInstall)", '(?i)defined\s+APP_(\w+)') |
    ForEach-Object { $_.Groups[1].Value.ToUpper() } | Where-Object { $_ -notin 'NOPROCESSCHECK', 'NOCONSENT', 'SILENT', 'EXITCODE' } | Sort-Object -Unique)
$switchLines = if ($switchNames) { ($switchNames | ForEach-Object { "    $_ = `$false" }) -join "`r`n" } else { '    # bijvoorbeeld: NOSHORTCUTS = $true' }

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
    (Fill $Text).Replace('{{BUILDDATE}}', (Get-Date -Format 'yyyy-MM-dd HH:mm')).Replace('{{KITVERSION}}', $KitVersion)
}
$installPs = (& $fillPs (Read-KitText 'Intune\Install.ps1')).
    Replace('{{SCHAKELAARS}}', $switchLines).
    Replace('{{INSTELLINGEN}}', ($settingLines -join "`r`n")).
    Replace('{{ONDERDELEN}}', ($compLines -join "`r`n")).
    Replace('{{VOOR}}', $(if ($useComponents) { Assert-HereString "$($cfg.PreInstall)" 'PreInstall' } else { '' })).
    Replace('{{NA}}', $(if ($useComponents) { Assert-HereString "$($cfg.PostInstall)" 'PostInstall' } else { '' })).
    Replace('{{EIGEN_SCRIPT}}', $(if ($useComponents) { '' } else { Assert-HereString $installCmdText 'install-app.cmd' }))
Write-Text (Join-Path $intune 'Install.ps1') $installPs

$uninstallCmdText = if (Test-Path (Join-Path $source 'uninstall-app.cmd')) { Read-Text (Join-Path $source 'uninstall-app.cmd') } else { '' }
Write-Text (Join-Path $intune 'Uninstall.ps1') ((& $fillPs (Read-KitText 'Intune\Uninstall.ps1')).Replace('{{UNINSTALL}}', (Assert-HereString $uninstallCmdText 'uninstall-app.cmd')).Replace('{{UNINSTALL_NOTIFY}}', $(if ($cfg.UninstallNotify -eq $true) { '$true' } else { '$false' })))
foreach ($f in 'Install.ps1', 'Uninstall.ps1') {
    $kb = [math]::Round((Get-Item (Join-Path $intune $f)).Length / 1KB, 1)
    if ($kb -gt 50) { Write-Warning "$f is $kb KB; Intune allows at most 50 KB. Then use install.cmd as the install command." }
}

# ---------- Bron: full copy of this version (settings, installers, all files) ----------
$sourceItems | Copy-Item -Destination $sourceCopy -Recurse -Force
# Default texts as they were at this build (for the history)
if (Test-Path $stdTextsFile) { Copy-Item $stdTextsFile (Join-Path $sourceCopy 'DefaultTexts.psd1') -Force }

# ---------- BuildInfo ----------
$fileLines = Get-ChildItem -Path $source -File -Force | Where-Object { $_.Extension -ne '.intunewin' } | Sort-Object Name | ForEach-Object {
    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
    '  {0,-50} {1,14:N0} bytes  SHA256 {2}' -f $_.Name, $_.Length, $hash
}
Write-Text (Join-Path $root 'BuildInfo.txt') @"
$($cfg.AppName) $($cfg.Version)
Built on    : $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Kit-versie  : $KitVersion
By          : $env:USERNAME on $env:COMPUTERNAME
Bronmap     : $source

Files in the package:
$($fileLines -join "`r`n")
"@

Write-Text (Join-Path $root 'Intune-settings.txt') @"
$($cfg.AppName) $($cfg.Version) - Intune Win32 app
==========================================

Package
  install.intunewin
  (package it yourself: IntuneWinAppUtil.exe -c .\Pakket -s install.cmd -o .)

Program
  Installer type     : PowerShell script (recommended)
    Install script   : Intune\Install.ps1     (upload separately; can be changed later without repackaging)
    Uninstall script : Intune\Uninstall.ps1
    32-bit: No  |  Signature check: No
    Parameters are switches at the top of Install.ps1 (`$NoProcessCheck, `$NoPopup, `$Silent, `$Switches).
  Or the old Command line type:
    Install command  : install.cmd    (optionally with parameters, see below)
    Uninstall command: uninstall.cmd
  Install behavior   : System
  Restart behavior   : Determine behavior based on return codes
  Return codes       : leave as default (1618 = Retry is already included)

Requirements
  Script             : Intune\Requirement.ps1
  Output data type   : Boolean  |  Operator: Equals  |  Value: Yes
  32-bit: No  |  Logged on credentials: No  |  Signature check: No

Detection rules
  Custom script      : Intune\Detection.ps1   ($detectText)
  32-bit: No  |  Signature check: No

Supersedence (only for a new Win32 app in Intune; not for a fix of the same version)
  Add the previous version. You choose Uninstall previous version yourself:
    No  = the new version installs over the old one (normal update)
    Yes = the old one must be removed first, e.g. with a different product name

Assignments
  Required. OnlyUpdateExisting = $onlyExisting
  $(if ($onlyExisting) { "-> only devices that already have $($cfg.DetectName)." } else { '-> everyone in the assigned group.' })

When
  Tijdvenster        : $windowText
  Idle               : $(if ($idleMin -gt 0) { "install right away after $idleMin minutes idle or with a locked screen, without popup" } else { 'off (always the popup first)' })
  Nobody signed in   : $(if ($noUser -eq 'Wait') { 'wait until someone signs in' } else { 'install right away (also outside the time window)' })
  Outside the time window the requirement script reports "Outside time window"; Intune tries again
  at a later check. So the installation doesn't start at the exact minute.

Parameters after install.cmd (may be combined, e.g. install.cmd /noshortcuts /noprocesscheck)
  /noprocesscheck  don't check whether the app is open.
                   Then use Intune\Requirement-NoProcessCheck.ps1 as the requirement script,
                   otherwise the normal requirement script still blocks the installation.
                   Note: the installer must be able to handle an open app itself.
  /noconsent       no popup, install right away (notifications bottom right stay)
  /silent          no popup and no notifications
  /<own name>      available in install-app.cmd as APP_<NAME>, e.g. /noshortcuts -> APP_NOSHORTCUTS
$(if ($appParams) { "  This app uses: $($appParams -join ', ')" })

Restart after the installation
  RestartMode        : $restartMode$(switch ($restartMode) { 'IfNeeded' { '  (only when the installer returns 3010 or 1641)' } 'Always' { '  (after every successful installation)' } default { '  (no restart prompt from the kit)' } })
$(if ($restartMode -ne 'Never') { @"
  Prompt "Restart now" / "Later"; Later = again after $restartReminder minutes.
  $(if ($restartDeadline -gt 0) { "Forced after $restartDeadline hours, with $restartWarning minutes warning." } else { 'Never forced.' })
  The kit then gives 0 to Intune, so Intune doesn't show a second restart prompt.
"@ })

Uninstall
  Notifications on uninstall : $(if ($cfg.UninstallNotify -eq $true) { 'on ("is being removed", then "removed" or "failed")' } else { 'off' })

Autopilot (new laptops)
  Install during Autopilot : $(if ($duringSetup) { 'yes, without popup (also if the app is not on the device yet)' } else { 'no, the app comes after setup' })
$(if ($duringSetup) { @'
  - Assign the app as Required to a device group with the Autopilot laptops, then it installs
    already in the device phase of the Enrollment Status Page.
  - Must the app be there before the user can work? Put it in the ESP profile at
    "Block device use until these required apps are installed".
  - Keep the ESP time-out (default 60 minutes) in mind for large packages.
'@ })

Testing on a laptop
  Logs and counter : C:\ProgramData\AppUpdates\$($cfg.AppId)\  (update.log, PostponeState.json)
  Counter at max   : set PostponeCount to $(if ($cfg.MaxPostpones) { $cfg.MaxPostpones } else { 5 }) in PostponeState.json
"@

# ---------- Packaging (if IntuneWinAppUtil.exe is available) ----------
$tool = @((Join-Path $KitRoot 'IntuneWinAppUtil.exe'), (Get-Command IntuneWinAppUtil.exe -ErrorAction SilentlyContinue).Source) |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$packed = $false
if ($tool) {
    Write-Host 'Packaging (IntuneWinAppUtil)...'
    & $tool -c $pkg -s 'install.cmd' -o $root -q | Out-Null
    if (Test-Path (Join-Path $root 'install.intunewin')) {
        $packed = $true
        Write-Host "Ingepakt: $(Join-Path $root 'install.intunewin')" -ForegroundColor Green
        if (-not $KeepPackageFolder) { Remove-Item -Path $pkg -Recurse -Force }
    }
    else { Write-Warning "IntuneWinAppUtil didn't create install.intunewin." }
}
else {
    Write-Host 'Tip: put IntuneWinAppUtil.exe next to this script, then install.intunewin is created right away too.' -ForegroundColor Yellow
}

Write-Host "`nDone: $root" -ForegroundColor Green
if ($packed) { Write-Host '  install.intunewin        -> upload in Intune' }
else         { Write-Host '  Package\                 -> package with IntuneWinAppUtil' }
Write-Host '  Intune\                  -> Install.ps1 + Uninstall.ps1 (installer type PowerShell script),'
Write-Host '                              upload Requirement.ps1 and Detection.ps1 separately'
Write-Host '  Intune-settings.txt      -> all settings for Intune'
Write-Host '  Source\ + BuildInfo.txt  -> full copy and details of this version'

<#
.SYNOPSIS
    Stap 2: bouwt het Intune-pakket van een ingevulde app-map.

.DESCRIPTION
    Leest Apps\<App>\app.psd1, controleert of alles klopt en maakt per versie een map:
      Output\<AppId>\<versie>\install.intunewin         het pakket voor Intune
      Output\<AppId>\<versie>\Intune\Requirement.ps1   los uploaden bij Requirements
      Output\<AppId>\<versie>\Intune\Detection.ps1     los uploaden bij Detection rules
      Output\<AppId>\<versie>\Intune\Install.ps1       PowerShell-installer voor Intune (met Uninstall.ps1)
      Output\<AppId>\<versie>\Intune-instellingen.txt   alle Intune-instellingen op een rij
      Output\<AppId>\<versie>\Bron\                     volledige kopie van deze versie (ook de installers)
      Output\<AppId>\_archief\<versie>_<datum>\          eerdere builds van dezelfde versie (bij opnieuw bouwen)
      Output\<AppId>\<versie>\Bouwinfo.txt              wanneer, door wie, welke bestanden (met SHA-256)
    Staat OutputFolder in app.psd1 (bijv. I:\...\versies\8.9.8.1\intune-package), dan komt dit allemaal
    in die map. In Output\<AppId>\<versie>\Pakketlocatie.txt staat dan waar het pakket staat.
    install.intunewin wordt gemaakt als IntuneWinAppUtil.exe in deze map of in PATH staat.
    Lukt dat, dan wordt de tijdelijke map Pakket\ opgeruimd (gebruik -KeepPackageFolder om hem te houden).

.EXAMPLE
    .\2-Bouw-pakket.ps1 -App NotepadPlusPlus
#>

param
(
    [Parameter(Mandatory)][string]$App,                       # mapnaam onder Apps\, of een volledig pad
    [string]$Output = '',                                     # standaard: Output naast dit script
    [switch]$KeepPackageFolder                                # map Pakket\ bewaren na het inpakken
)

$ErrorActionPreference = 'Stop'
# Map van de kit bepalen (ook als $PSScriptRoot leeg is, bijv. bij starten vanuit PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Kan de AppUpdateKit-map niet vinden. Ga eerst naar die map (cd <pad naar AppUpdateKit>) en start het script daar, bijv. .\2-Bouw-pakket.ps1 -App NotepadPlusPlus"
}

if (-not $Output) { $Output = Join-Path $KitRoot 'Output' }
$kit = Join-Path $KitRoot '_Kit'

$source = if (Test-Path $App) { (Resolve-Path $App).Path } else { Join-Path (Join-Path $KitRoot 'Apps') $App }
if (-not (Test-Path (Join-Path $source 'app.psd1'))) { throw "Geen app.psd1 gevonden in $source" }

# Inlezen via een kopie met BOM: Kladblok slaat UTF-8 zonder BOM op, en dan leest
# Windows PowerShell 5.1 tekens als é/ï verkeerd in.
$psdTemp = [System.IO.Path]::GetTempFileName() + '.psd1'
[System.IO.File]::WriteAllText($psdTemp, [System.IO.File]::ReadAllText((Join-Path $source 'app.psd1')), (New-Object System.Text.UTF8Encoding $true))
try { $cfg = Import-PowerShellDataFile -Path $psdTemp }
catch { throw "app.psd1 bevat een fout (controleer aanhalingstekens en haakjes): $($_.Exception.Message)" }
finally { Remove-Item $psdTemp -Force -ErrorAction SilentlyContinue }

# ---------- Controles ----------
$problems = @(); $warnings = @()
if ($cfg.AppId -notmatch '^[A-Za-z0-9_-]+$')   { $problems += 'AppId mag alleen letters, cijfers, - en _ bevatten.' }
if (-not $cfg.AppName)                          { $problems += 'AppName is leeg.' }
if ($cfg.Version -notmatch '^\d+(\.\d+){0,3}$') { $problems += "Version '$($cfg.Version)' is geen geldige versie (bijv. 1.2.3)." }
if (-not $cfg.DetectName)                       { $problems += 'DetectName is leeg.' }
if (-not @($cfg.Processes | Where-Object { $_ }).Count) { $warnings += 'Geen processen ingevuld: de installatie controleert niet of de app open staat.' }
if ($cfg.AccentColor -and $cfg.AccentColor -notmatch '^#[0-9A-Fa-f]{6}$') { $problems += "AccentColor '$($cfg.AccentColor)' moet de vorm #RRGGBB hebben." }

foreach ($f in 'install-app.cmd', 'uninstall-app.cmd') {
    if (-not (Test-Path (Join-Path $source $f))) { $problems += "$f ontbreekt." }
}

$icon = if ($cfg.Icon) { $cfg.Icon } else { 'app.ico' }
if (-not (Test-Path (Join-Path $source $icon))) { $warnings += "Logo '$icon' niet gevonden: de vensters tonen dan geen logo." }

function Get-InvalidMsiSwitch([string]$Arguments)
{
    # Opties die msiexec niet kent (bijv. /S of /VERYSILENT van een .exe-installer): msiexec stopt dan met 1639
    $ok = '^/(i|x|p|a|j[um]?|f[a-z]*|l[a-z\*\+!]*|log|q[nbrf]?[\+\-!]*|quiet|passive|norestart|forcerestart|promptrestart|package|uninstall|update|help|\?|y|z)$'
    return @(("$Arguments" -split '\s+') | Where-Object { $_ -like '/*' -and $_ -notmatch $ok })
}

# Installers die in install-app.cmd genoemd worden, moeten in de map staan
$installText = Get-Content -Path (Join-Path $source 'install-app.cmd') -Raw -ErrorAction SilentlyContinue
if ($installText) {
    $active = ($installText -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(rem|::)' }) -join "`n"
    foreach ($m in [regex]::Matches($active, '"([^"\\/:%]+\.(exe|msi|msp|ps1|cmd|bat|reg))"', 'IgnoreCase')) {
        if (-not (Test-Path (Join-Path $source $m.Groups[1].Value))) {
            $want = $m.Groups[1].Value
            $ext  = [System.IO.Path]::GetExtension($want)
            $have = @(Get-ChildItem -Path $source -File -Filter "*$ext" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
            $msg  = "install-app.cmd gebruikt '$want', maar dat bestand staat niet in de map."
            $msg += if ($have.Count) { "`n      Wel in de map ($ext): $($have -join ', ')`n      Andere naam? Hernoem het bestand, of kies het in tabblad 2 opnieuw als onderdeel." }
                    else { "`n      Er staat geen enkel $ext-bestand in de map. Zet de installer in $source." }
            $problems += $msg
        }
    }
    if ($active -notmatch 'APP_EXITCODE') { $warnings += 'install-app.cmd zet APP_EXITCODE niet; succes/fout wordt dan niet goed gemeld.' }
    # msiexec-regels met opties die msiexec niet kent (bijv. /S van een .exe): dat geeft foutcode 1639
    foreach ($line in ($active -split "`n" | Where-Object { $_ -match '^\s*msiexec(\.exe)?\s' })) {
        $bad = Get-InvalidMsiSwitch ($line -replace '"[^"]*"', '')
        if ($bad) { $problems += "install-app.cmd: '$($bad -join ' ')' hoort niet bij msiexec:`n      $($line.Trim())`n      Haal het weg (in de Builder: tabblad 2, kolom Parameters); anders mislukt de installatie met foutcode 1639." }
    }
}

$warnings | ForEach-Object { Write-Warning $_ }
if ($problems) {
    $problems | ForEach-Object { Write-Host "FOUT: $_" -ForegroundColor Red }
    throw "Pakket niet gebouwd: los eerst de fouten hierboven op in $source"
}

# ---------- Mappen: Output\<AppId>\<versie>\, of de eigen map uit OutputFolder ----------
$kitVersionDir  = Join-Path (Join-Path $Output $cfg.AppId) $cfg.Version
$external = "$($cfg.OutputFolder)".Trim()
if ($external) { $external = [Environment]::ExpandEnvironmentVariables($external).TrimEnd('\') }
if ($external) {
    # Ligt de gekozen map in de Output-map van de kit zelf? Dan de gewone indeling Output\<AppId>\<versie> gebruiken,
    # zodat elke versie een eigen map krijgt.
    $outFull = [System.IO.Path]::GetFullPath($Output).TrimEnd('\', '/')
    $extFull = [System.IO.Path]::GetFullPath($external).TrimEnd('\', '/')
    if ($extFull -eq $outFull -or $extFull.StartsWith($outFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "Pakket opslaan in ligt in de Output-map van de kit: het pakket komt in Output\$($cfg.AppId)\$($cfg.Version)." -ForegroundColor Yellow
        $external = ''
    }
}
function Test-IsInside([string]$Child, [string]$Parent) {
    # Ligt $Child in (of is het) $Parent? Volledige paden, hoofdletters maken niet uit.
    $c = [System.IO.Path]::GetFullPath($Child).TrimEnd('\', '/')
    $p = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    return ($c -eq $p -or $c.StartsWith($p + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))
}
if ($external -and (Test-IsInside $external (Join-Path $KitRoot 'Apps'))) {
    # Het pakket mag niet in de app-map (of in Apps\) komen: dan kopieert elke build zichzelf in het pakket
    throw "Pakket opslaan in ligt in de app-map: $external`nKies een map buiten Apps\, bijvoorbeeld de versiemap naast de installer (...\versies\<versie>). Pas OutputFolder aan in tabblad 1 of in app.psd1."
}
$root     = if ($external) { $external } else { $kitVersionDir }
$pointer  = Join-Path $kitVersionDir 'Pakketlocatie.txt'
# Stond hier alleen een verwijzing naar een eigen map, en bouwen we nu in de kit? Verwijzing weghalen.
if (-not $external -and (Test-Path $pointer) -and @(Get-ChildItem $kitVersionDir -Force).Count -eq 1) { Remove-Item $kitVersionDir -Recurse -Force }

function Move-Folder([string]$From, [string]$To) {
    # Verplaatsen, ook naar een andere schijf (Move-Item kan dat niet met mappen)
    try { Move-Item -Path $From -Destination $To -ErrorAction Stop }
    catch { Copy-Item -Path $From -Destination $To -Recurse -Force; Remove-Item -Path $From -Recurse -Force }
}
if ($external) {
    $parent = Split-Path $root -Parent
    if ($parent -and -not (Test-Path $parent)) {
        # Map nog niet aangemaakt (bijv. een nieuwe versiemap): aanmaken, tenzij de schijf niet bereikbaar is
        try { New-Item -Path $parent -ItemType Directory -Force -ErrorAction Stop | Out-Null }
        catch { throw "De map voor het pakket kan niet worden aangemaakt: $parent (OutputFolder in app.psd1). Is de schijf gekoppeld? $($_.Exception.Message)" }
    }
    # Stond deze versie eerder in de kit zelf (geen verwijzing)? Die build gaat naar het archief.
    if ((Test-Path $kitVersionDir) -and -not (Test-Path $pointer)) {
        $old = Join-Path (Join-Path (Join-Path $Output $cfg.AppId) '_archief') "$($cfg.Version)_$((Get-Item $kitVersionDir).LastWriteTime.ToString('yyyyMMdd-HHmmss'))"
        New-Item -Path (Split-Path $old -Parent) -ItemType Directory -Force | Out-Null
        Move-Folder $kitVersionDir $old
    }
}
$pkg    = Join-Path $root 'Pakket'
$intune = Join-Path $root 'Intune'
$bron   = Join-Path $root 'Bron'
if (Test-Path $root) {
    # Niets weggooien: de vorige build van deze versie gaat naar het archief
    $stampSource = if (Test-Path (Join-Path $root 'Bouwinfo.txt')) { Get-Item (Join-Path $root 'Bouwinfo.txt') } else { Get-Item $root }
    $archiveDir = Join-Path (Join-Path $Output $cfg.AppId) '_archief'
    $archive = Join-Path $archiveDir "$($cfg.Version)_$($stampSource.LastWriteTime.ToString('yyyyMMdd-HHmmss'))"
    New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null
    if (Test-Path (Join-Path $root 'Pakket')) { Remove-Item -Path (Join-Path $root 'Pakket') -Recurse -Force }   # tijdelijke map, niet bewaren
    Move-Folder $root $archive
    Write-Warning "Versie $($cfg.Version) was al gebouwd. Die build is bewaard in _archief\$(Split-Path $archive -Leaf)."
}
New-Item -Path $pkg, $intune, $bron -ItemType Directory -Force | Out-Null
if ($external) {
    # Verwijzing in de kit, zodat de Builder (tabblad Versies) deze build terugvindt
    New-Item -Path $kitVersionDir -ItemType Directory -Force | Out-Null
    [System.IO.File]::WriteAllText($pointer, $root, (New-Object System.Text.UTF8Encoding $true))
}

$utf8Bom = New-Object System.Text.UTF8Encoding $true
function Write-Text($Path, $Text, [switch]$Cmd) {
    $Text = $Text -replace "`r?`n", "`r`n"
    if ($Cmd) {
        if ($Text -match '[^\x00-\x7F]') { Write-Warning "$(Split-Path $Path -Leaf) bevat speciale tekens (é, ï, ...); cmd geeft die mogelijk verkeerd door." }
        [System.IO.File]::WriteAllText($Path, $Text, [System.Text.Encoding]::Default)
    }
    else { [System.IO.File]::WriteAllText($Path, $Text, $utf8Bom) }
}
function Read-Text($Path) { [System.IO.File]::ReadAllText($Path) }   # herkent zelf UTF-8 met/zonder BOM

$processList = ($cfg.Processes | Where-Object { $_ } | ForEach-Object { "'$($_ -replace '\.exe$', '')'" }) -join ', '
$onlyExisting = if ($null -eq $cfg.OnlyUpdateExisting) { $true } else { [bool]$cfg.OnlyUpdateExisting }
$window   = if ($cfg.InstallWindow) { $cfg.InstallWindow } else { 'Altijd' }
$hours    = if ($cfg.WorkHours) { (("$($cfg.WorkHours)" -split '[,;]') | ForEach-Object { $_ -replace '\s', '' } | Where-Object { $_ }) -join ',' } else { '08:00-17:00' }
$days     = if ($cfg.WorkDays) { $cfg.WorkDays } else { 'ma,di,wo,do,vr' }
$noUser   = if ($cfg.NoUserAction) { $cfg.NoUserAction } else { 'Installeren' }
$idleMin  = [int]("0$($cfg.IdleMinutes)")
# Eigen parameters die install-app.cmd gebruikt (APP_XXX), voor de lijst in Intune-instellingen.txt
$appCmdPath = Join-Path $source 'install-app.cmd'
$appParams = @()
if (Test-Path $appCmdPath) {
    $appParams = @([regex]::Matches((Get-Content $appCmdPath -Raw), '(?i)defined\s+APP_(\w+)') | ForEach-Object { '/' + $_.Groups[1].Value.ToLower() } | Sort-Object -Unique)
}
$restartMode = if ($cfg.RestartMode) { $cfg.RestartMode } else { 'Nooit' }
if ($restartMode -notin 'Nooit', 'AlsNodig', 'Altijd') { throw "RestartMode moet 'Nooit', 'AlsNodig' of 'Altijd' zijn (nu: '$restartMode')." }
$restartReminder = if ($null -ne $cfg.RestartReminderMinutes) { [int]$cfg.RestartReminderMinutes } else { 60 }
$restartDeadline = if ($null -ne $cfg.RestartDeadlineHours) { [int]$cfg.RestartDeadlineHours } else { 24 }
$restartWarning  = if ($null -ne $cfg.RestartWarningMinutes) { [int]$cfg.RestartWarningMinutes } else { 15 }
$duringSetup = if ($null -eq $cfg.InstallDuringSetup) { $true } else { [bool]$cfg.InstallDuringSetup }
if ($window -notin 'Altijd', 'Werktijd', 'BuitenWerktijd') { throw "InstallWindow moet 'Altijd', 'Werktijd' of 'BuitenWerktijd' zijn (nu: '$window')." }
if ($noUser -notin 'Installeren', 'Wachten') { throw "NoUserAction moet 'Installeren' of 'Wachten' zijn (nu: '$noUser')." }
if ($window -ne 'Altijd' -and @($hours -split ',' | Where-Object { $_ -notmatch '^\d{1,2}:\d{2}-\d{1,2}:\d{2}$' }).Count) { throw "WorkHours moet de vorm '08:00-17:00' hebben, of meerdere blokken zoals '09:00-10:00,13:00-14:00' (nu: '$hours')." }
$windowText = switch ($window) {
    'Werktijd'       { "alleen binnen de gekozen tijden ($days, $($hours -replace ',', ', '))" }
    'BuitenWerktijd' { "alleen buiten de gekozen tijden (buiten $days, $($hours -replace ',', ', '))" }
    default          { 'altijd' }
}
# ---------- Detectie (DetectionMethod in app.psd1) ----------
$detectMethod  = if ($cfg.DetectionMethod) { "$($cfg.DetectionMethod)" } else { 'AppsEnOnderdelen' }
if ($detectMethod -notin 'AppsEnOnderdelen', 'Bestand', 'Register', 'Script') { throw "DetectionMethod moet 'AppsEnOnderdelen', 'Bestand', 'Register' of 'Script' zijn (nu: '$detectMethod')." }
$detectVersion = if ("$($cfg.DetectVersion)".Trim()) { "$($cfg.DetectVersion)".Trim() } else { "$($cfg.Version)" }
if ($detectVersion -eq '-') { $detectVersion = '' }   # '-' = alleen kijken of het bestaat, geen versie
if ($detectMethod -eq 'Bestand' -and -not "$($cfg.DetectFile)".Trim()) { throw 'Detectie Bestand: DetectFile is leeg (bijv. %ProgramFiles%\Remote help\RemoteHelp.exe).' }
if ($detectMethod -eq 'Register' -and -not "$($cfg.DetectRegKey)".Trim()) { throw 'Detectie Register: DetectRegKey is leeg (bijv. HKLM\SOFTWARE\Leverancier\App).' }
if ($detectMethod -eq 'Script' -and -not "$($cfg.DetectScript)".Trim()) { throw 'Detectie Script: DetectScript is leeg.' }
$detectText = switch ($detectMethod) {
    'Bestand'  { "bestand $($cfg.DetectFile)$(if ($detectVersion) { ", versie $detectVersion of hoger" })" }
    'Register' { "register $($cfg.DetectRegKey)$(if ($cfg.DetectRegValue) { "\$($cfg.DetectRegValue)" })$(if ($detectVersion) { ", versie $detectVersion of hoger" })" }
    'Script'   { 'eigen detectiescript' }
    default    { "`"$($cfg.DetectName)`" in Apps en onderdelen$(if ($detectVersion) { ", versie $detectVersion of hoger" })" }
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

# ---------- Pakket ----------
# 1. Alles uit de app-map (installers, logo, eigen scripts, extra bestanden)
#    Een map die zelf een gebouwd pakket is (bijv. een oude intune-package in de app-map) gaat niet mee
$sourceItems = @(Get-ChildItem -Path $source -Force | Where-Object { $_.Extension -ne '.intunewin' } | Where-Object {
    $isBuild = $_.PSIsContainer -and ((Test-Path (Join-Path $_.FullName 'Bouwinfo.txt')) -or (Test-Path (Join-Path $_.FullName 'Pakket')) -or $_.Name -eq 'intune-package')
    if ($isBuild) { Write-Warning "De map $($_.Name) in de app-map lijkt een gebouwd pakket en gaat niet mee in het pakket. Haal hem weg uit $source." }
    -not $isBuild
})
$sourceItems | Copy-Item -Destination $pkg -Recurse -Force

# 2. app.psd1 en de eigen cmd-bestanden met de juiste codering
Write-Text (Join-Path $pkg 'app.psd1') (Read-Text (Join-Path $source 'app.psd1'))
foreach ($f in 'install-app.cmd', 'uninstall-app.cmd') { Write-Text (Join-Path $pkg $f) (Read-Text (Join-Path $source $f)) -Cmd }

# 3. Gedeelde scripts en standaardteksten (identiek voor elke app)
foreach ($f in 'AppUI.ps1', 'AppUI-Launcher.ps1', 'Ask-InstallConsent.ps1', 'Show-Toast.ps1', 'Test-AppRunning.ps1', 'Get-IdleTime.ps1', 'Set-RestartPrompt.ps1', 'Restart-Prompt.ps1', 'Remove-App.ps1', 'Test-AppInstalled.ps1', 'Standaardteksten.psd1') {
    if (Test-Path (Join-Path $kit $f)) { Write-Text (Join-Path $pkg $f) (Read-Text (Join-Path $kit $f)) }
}
foreach ($f in 'install.cmd', 'uninstall.cmd') {
    Write-Text (Join-Path $pkg $f) (Fill (Read-Text (Join-Path $kit $f))) -Cmd
}

# ---------- Intune-scripts ----------
foreach ($f in 'Requirement.ps1', 'Detection.ps1') {
    Write-Text (Join-Path $intune $f) ((Fill (Read-Text (Join-Path (Join-Path $kit 'Intune') $f))).Replace('{{CHECK_PROCESSES}}', 'true'))
}
if ($detectMethod -eq 'Script') {
    # Eigen detectiescript uit de Builder (DetectScript in app.psd1)
    $own = @(
        '<#'
        "    Intune detectiescript voor $($cfg.AppName) $($cfg.Version) - eigen script (Builder, tabblad 1 > Detectie)."
        '    Upload dit LOS in Intune (Detection rules > Use a custom detection script). 32-bit: No, signature check: No.'
        '    Iets op het scherm schrijven + exit 0 = gedetecteerd. Niets schrijven = niet gedetecteerd.'
        '#>'
        ''
        "$($cfg.DetectScript)".TrimEnd()
    ) -join "`r`n"
    Write-Text (Join-Path $intune 'Detection.ps1') ($own + "`r`n")
    $e = $null; [System.Management.Automation.Language.Parser]::ParseInput($own, [ref]$null, [ref]$e) | Out-Null
    if ($e) { throw "Het eigen detectiescript bevat een fout: $($e[0].Message) (regel $($e[0].Extent.StartLineNumber - 7))" }
}
# Variant voor install.cmd /noprocesscheck: zonder controle of de app open staat
Write-Text (Join-Path $intune 'Requirement-zonder-procescheck.ps1') ((Fill (Read-Text (Join-Path (Join-Path $kit 'Intune') 'Requirement.ps1'))).Replace('{{CHECK_PROCESSES}}', 'false'))

# ---------- PowerShell-installer voor Intune (Install.ps1 / Uninstall.ps1, los uploaden) ----------
function ConvertTo-PsLiteral($v) {
    if ($null -eq $v) { return "''" }
    if ($v -is [bool]) { return '$' + $v.ToString().ToLower() }
    if ($v -is [int] -or $v -is [long] -or $v -is [double]) { return "$v" }
    if ($v -is [array]) { return '@(' + ((@($v) | ForEach-Object { ConvertTo-PsLiteral $_ }) -join ', ') + ')' }
    return "'" + ([string]$v).Replace("'", "''") + "'"
}
function Get-StepCommand($c) {
    # Zelfde opdrachtregels als install-app.cmd
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
    if ($Text -match "(?m)^'@") { throw "$What bevat een regel die begint met '@; dat kan niet in Install.ps1. Pas die regel aan." }
    return $Text.TrimEnd()
}

$settingLines = @()
$settingSpec = [ordered]@{
    AppId                 = @($cfg.AppId, 'niet wijzigen: map, teller en log')
    AppName               = @($cfg.AppName, 'naam in de vensters')
    DetectName            = @($cfg.DetectName, 'naam in Apps en onderdelen: bepaalt nieuwe installatie of update')
    Version               = @($cfg.Version, 'versie in dit pakket (nieuwe versie = nieuw pakket)')
    Processes             = @(@($cfg.Processes | Where-Object { $_ }), 'staan ook in Requirement.ps1')
    Icon                  = @($(if ($cfg.Icon) { $cfg.Icon } else { 'app.ico' }), 'logo in het pakket')
    AccentColor           = @($(if ($cfg.AccentColor) { $cfg.AccentColor } else { '#185FA5' }), 'kleur van de kop en de knop')
    MaxPostpones          = @([int]$(if ($null -ne $cfg.MaxPostpones) { $cfg.MaxPostpones } else { 5 }), 'hoe vaak Later mag')
    PostponeHours         = @([int]$(if ($null -ne $cfg.PostponeHours) { $cfg.PostponeHours } else { 24 }), 'hoe lang een keer uitstellen duurt (uren)')
    ConsentTimeoutMinutes = @([int]$(if ($null -ne $cfg.ConsentTimeoutMinutes) { $cfg.ConsentTimeoutMinutes } else { 15 }), 'geen keuze: venster sluiten na (minuten)')
    ForcedDelayMinutes    = @([int]$(if ($null -ne $cfg.ForcedDelayMinutes) { $cfg.ForcedDelayMinutes } else { 5 }), 'waarschuwing na de laatste keer uitstellen (minuten)')
    InstallWindow         = @($window, 'Altijd | Werktijd | BuitenWerktijd  (staat ook in Requirement.ps1)')
    WorkHours             = @($hours, 'tijden (van-tot); meerdere blokken: ''09:00-10:00,13:00-14:00''')
    WorkDays              = @($days, 'werkdagen')
    IdleMinutes           = @($idleMin, '> 0 = na zoveel minuten inactief of vergrendeld direct installeren')
    NoUserAction          = @($noUser, 'niemand ingelogd: Installeren | Wachten')
    InstallDuringSetup    = @($duringSetup, 'nieuwe laptops (Autopilot) direct installeren (staat ook in Requirement.ps1)')
    RestartMode           = @($restartMode, 'herstartmelding na de installatie: Nooit | AlsNodig (exitcode 3010/1641) | Altijd')
    RestartReminderMinutes = @($restartReminder, 'Later bij de herstartmelding: opnieuw vragen na (minuten)')
    RestartDeadlineHours  = @($restartDeadline, 'na zoveel uur verplicht herstarten (0 = nooit verplicht)')
    RestartWarningMinutes = @($restartWarning, 'waarschuwing voor de verplichte herstart (minuten)')
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
        $compLines += "    @{ Naam = $(ConvertTo-PsLiteral $name); Opdracht = $(ConvertTo-PsLiteral (Get-StepCommand $c)); Geslaagd = $($codes -join ', ') }"
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
    if ($kb -gt 50) { Write-Warning "$f is $kb KB; Intune staat maximaal 50 KB toe. Gebruik dan install.cmd als install command." }
}

# ---------- Bron: volledige kopie van deze versie (instellingen, installers, alle bestanden) ----------
$sourceItems | Copy-Item -Destination $bron -Recurse -Force
# Standaardteksten zoals ze bij deze build waren (voor de geschiedenis)
if (Test-Path (Join-Path $kit 'Standaardteksten.psd1')) { Copy-Item (Join-Path $kit 'Standaardteksten.psd1') $bron -Force }

# ---------- Bouwinfo ----------
$fileLines = Get-ChildItem -Path $source -File -Force | Where-Object { $_.Extension -ne '.intunewin' } | Sort-Object Name | ForEach-Object {
    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
    '  {0,-50} {1,14:N0} bytes  SHA256 {2}' -f $_.Name, $_.Length, $hash
}
Write-Text (Join-Path $root 'Bouwinfo.txt') @"
$($cfg.AppName) $($cfg.Version)
Gebouwd op  : $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Door        : $env:USERNAME op $env:COMPUTERNAME
Bronmap     : $source

Bestanden in het pakket:
$($fileLines -join "`r`n")
"@

Write-Text (Join-Path $root 'Intune-instellingen.txt') @"
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
    Parameters zijn schakelaars bovenaan Install.ps1 (`$GeenProcescheck, `$GeenPopup, `$Stil, `$Schakelaars).
  Of het oude type Command line:
    Install command  : install.cmd    (eventueel met parameters, zie hieronder)
    Uninstall command: uninstall.cmd
  Install behavior   : System
  Restart behavior   : Determine behavior based on return codes
  Return codes       : standaard laten staan (1618 = Retry zit er al in)

Requirements
  Script             : Intune\Requirement.ps1
  Output data type   : Boolean  |  Operator: Equals  |  Value: Yes
  32-bit: No  |  Logged on credentials: No  |  Signature check: No

Detection rules
  Custom script      : Intune\Detection.ps1   ($detectText)
  32-bit: No  |  Signature check: No

Supersedence (alleen bij een nieuwe Win32-app in Intune; niet bij een fix van dezelfde versie)
  Voeg de vorige versie toe. Uninstall previous version kies je zelf:
    No  = de nieuwe versie installeert over de oude heen (gewone update)
    Yes = de oude moet eerst weg, bijv. bij een andere productnaam

Assignments
  Required. OnlyUpdateExisting = $onlyExisting
  $(if ($onlyExisting) { "-> alleen apparaten waar $($cfg.DetectName) al op staat." } else { '-> iedereen in de toegewezen groep.' })

Wanneer
  Tijdvenster        : $windowText
  Inactief           : $(if ($idleMin -gt 0) { "na $idleMin minuten inactief of bij een vergrendeld scherm direct installeren, zonder popup" } else { 'uit (altijd eerst de popup)' })
  Niemand ingelogd   : $(if ($noUser -eq 'Wachten') { 'wachten tot er iemand is ingelogd' } else { 'direct installeren (ook buiten het tijdvenster)' })
  Buiten het tijdvenster meldt het requirement-script "Buiten tijdvenster"; Intune probeert het
  bij een volgende controle opnieuw. De installatie start dus niet precies op de minuut.

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
  RestartMode        : $restartMode$(switch ($restartMode) { 'AlsNodig' { '  (alleen als de installer 3010 of 1641 geeft)' } 'Altijd' { '  (na elke geslaagde installatie)' } default { '  (geen herstartmelding van de kit)' } })
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

# ---------- Inpakken (als IntuneWinAppUtil.exe beschikbaar is) ----------
$tool = @((Join-Path $KitRoot 'IntuneWinAppUtil.exe'), (Get-Command IntuneWinAppUtil.exe -ErrorAction SilentlyContinue).Source) |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$packed = $false
if ($tool) {
    Write-Host 'Bezig met inpakken (IntuneWinAppUtil)...'
    & $tool -c $pkg -s 'install.cmd' -o $root -q | Out-Null
    if (Test-Path (Join-Path $root 'install.intunewin')) {
        $packed = $true
        Write-Host "Ingepakt: $(Join-Path $root 'install.intunewin')" -ForegroundColor Green
        if (-not $KeepPackageFolder) { Remove-Item -Path $pkg -Recurse -Force }
    }
    else { Write-Warning 'IntuneWinAppUtil heeft geen install.intunewin gemaakt.' }
}
else {
    Write-Host 'Tip: zet IntuneWinAppUtil.exe naast dit script, dan wordt install.intunewin ook meteen gemaakt.' -ForegroundColor Yellow
}

Write-Host "`nKlaar: $root" -ForegroundColor Green
if ($packed) { Write-Host '  install.intunewin        -> uploaden in Intune' }
else         { Write-Host '  Pakket\                  -> inpakken met IntuneWinAppUtil' }
Write-Host '  Intune\                  -> Install.ps1 + Uninstall.ps1 (installer type PowerShell script),'
Write-Host '                              Requirement.ps1 en Detection.ps1 los uploaden'
Write-Host '  Intune-instellingen.txt  -> alle instellingen voor Intune'
Write-Host '  Bron\ + Bouwinfo.txt     -> volledige kopie en gegevens van deze versie'

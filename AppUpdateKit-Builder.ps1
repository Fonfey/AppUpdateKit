<#
.SYNOPSIS
    AppUpdateKit Builder - invulscherm om update-pakketten met popup te maken.
    Start via Start-Builder.cmd (dubbelklikken).

.DESCRIPTION
    - Apps kiezen of een nieuwe app aanmaken (map Apps\<AppId>)
    - Installer kiezen: naam, versie, type en stille parameters worden herkend
    - Detectie kiezen (Apps en onderdelen, bestand, register of eigen script) en testen op deze pc
    - Logo (.svg/.ico/.png/.jpg, of uit de installer), kleur, uitstelregels, tijdblokken en teksten invullen
    - Voorbeeld van elke popup op je eigen scherm
    - Opslaan en het .intunewin-pakket bouwen (via 2-Bouw-pakket.ps1) in de gekozen pakketmap
    - Alle eerdere builds terugzien op het tabblad Versies
#>

$ErrorActionPreference = 'Stop'
# Map van de kit bepalen (ook als $PSScriptRoot leeg is, bijv. bij starten vanuit PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Kan de AppUpdateKit-map niet vinden. Ga eerst naar die map (cd <pad naar AppUpdateKit>) en start het script daar, bijv. .\2-Bouw-pakket.ps1 -App NotepadPlusPlus"
}
$AppsRoot = Join-Path $KitRoot 'Apps'
$KitDir   = Join-Path $KitRoot '_Kit'

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
    NewRestartForcedMessage = '{AppName} is geïnstalleerd en je laptop moet herstarten om de installatie af te ronden. Sla je werk op en sluit je programmas af.'
}
$StandardTextsPath = Join-Path $KitDir 'Standaardteksten.psd1'

# Instellingen voor deze kit: standaardmap voor installers en de submap voor het pakket (_Kit\Instellingen.psd1)
$KitSettings = @{ InstallerMap = ''; PakketSubmap = '' }
$kitSettingsPath = Join-Path $KitDir 'Instellingen.psd1'
function Save-InstallerMap([string]$Folder)
{
    # InstallerMap in _Kit\Instellingen.psd1 aanpassen; de rest van het bestand (commentaar, PakketSubmap) blijft staan
    $Folder = $Folder.TrimEnd('\') + '\'
    $value = "InstallerMap = '$($Folder.Replace("'", "''"))'"
    if (Test-Path $kitSettingsPath)
    {
        $text = [System.IO.File]::ReadAllText($kitSettingsPath)
        if ($text -match "(?m)^(\s*)InstallerMap\s*=\s*'(?:[^']|'')*'") { $text = [regex]::Replace($text, "(?m)^(\s*)InstallerMap\s*=\s*'(?:[^']|'')*'", { param($m) $m.Groups[1].Value + $value }, 1) }
        else { $text = $text -replace '@\{', "@{`r`n    $value" }
    }
    else
    {
        $text = "# AppUpdateKit - instellingen voor deze kit (geldt voor alle apps). Pas aan met Kladblok.`r`n@{`r`n    # Map waar het venster 'Kiezen...' standaard opent bij het kiezen van een installer.`r`n    $value`r`n`r`n    # Kies je bij 'Pakket opslaan in' de versiemap, dan zet de Builder deze submap erachter.`r`n    PakketSubmap = 'intune-package'`r`n}`r`n"
    }
    [System.IO.File]::WriteAllText($kitSettingsPath, $text, (New-Object System.Text.UTF8Encoding $true))
    $KitSettings.InstallerMap = $Folder
}

if (Test-Path $kitSettingsPath) { try { $kitSettingsFile = Import-PowerShellDataFile $kitSettingsPath; foreach ($settingName in 'InstallerMap', 'PakketSubmap') { if ($kitSettingsFile[$settingName]) { $KitSettings[$settingName] = "$($kitSettingsFile[$settingName])" } } } catch { } }
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

#region ===================== Logica (ook zonder venster te gebruiken) =====================

function Read-AppPsd1
{
    # Inlezen via een kopie met BOM (Kladblok slaat UTF-8 zonder BOM op)
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
    # Standaardteksten voor alle apps: _Kit\Standaardteksten.psd1, aangevuld met de ingebouwde teksten
    $r = [ordered]@{}
    foreach ($k in $TextKeys) { $r[$k] = $BuiltinTexts[$k] }
    if (Test-Path $StandardTextsPath)
    {
        try
        {
            $f = Read-AppPsd1 $StandardTextsPath
            foreach ($k in $TextKeys) { if ($f[$k]) { $r[$k] = $f[$k] } }
        }
        catch { }
    }
    return $r
}

function ConvertTo-StandardTextsPsd1
{
    param ($Texts)
    $q = { param($s) "'" + ([string]$s).Replace("'", "''") + "'" }
    $lines = @(
        '#  STANDAARDTEKSTEN voor alle apps (bewerkt met de AppUpdateKit Builder).'
        '#  Een app gebruikt deze tekst, tenzij er in app.psd1 een eigen tekst staat.'
        '#  Ingevuld worden: {AppName}, {Versie}, {Minuten} en {MaxUitstel}'
        '@{'
    )
    foreach ($k in $TextKeys) { $lines += "    $($k.PadRight(18))= $(& $q $Texts[$k])" }
    $lines += '}'
    return ($lines -join "`r`n") + "`r`n"
}

function Get-VersionFolder([string]$InstallerPath)
{
    # Versiemap bij een installer, als startpunt voor 'Kiezen...' bij 'Pakket opslaan in' (vult niets automatisch in):
    #   ...\versies\2.4.0\source\setup.exe      -> ...\versies\2.4.0
    #   ...\versies\2.4.0\source\x64\setup.exe  -> ...\versies\2.4.0
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

function Get-AppVersions
{
    # Alle builds van een app: Output\<AppId>\<versie>\ en eerdere builds in Output\<AppId>\_archief\<versie>_<datum>\
    param ([string]$AppId)
    $dir = Join-Path (Join-Path $KitRoot 'Output') $AppId
    if (-not (Test-Path $dir)) { return @() }

    $make = {
        param ($folder, [string]$ver, [bool]$isArchive)
        # Staat het pakket in een eigen map (OutputFolder)? Dan staat hier alleen een verwijzing.
        $ptr = Join-Path $folder.FullName 'Pakketlocatie.txt'
        if (Test-Path $ptr)
        {
            $target = ([System.IO.File]::ReadAllText($ptr)).Trim()
            if ($target -and (Test-Path $target)) { $folder = Get-Item -LiteralPath $target }
        }
        $v = $null; try { $v = [version]$ver } catch { }
        $pkgFile = Join-Path $folder.FullName 'install.intunewin'
        $bi = Join-Path $folder.FullName 'Bouwinfo.txt'
        $built = if (Test-Path $bi) { (Get-Item $bi).LastWriteTime } else { $folder.LastWriteTime }
        $bron = Join-Path $folder.FullName 'Bron'
        [pscustomobject]@{
            Version       = $ver
            Label         = if ($isArchive) { "$ver  (vervangen)" } else { $ver }
            IsArchive     = $isArchive
            SortKey       = $v
            Path          = $folder.FullName
            Pointer       = if (Test-Path $ptr) { $ptr } else { '' }
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

    $lines = @(
        '#  Gemaakt met de AppUpdateKit Builder. Je kunt dit bestand ook met de hand aanpassen.'
        '#  In teksten worden ingevuld: {AppName}, {Versie}, {Minuten} en {MaxUitstel}. Leeg = standaardtekst.'
        '@{'
        '    # ---------- 1. Basis ----------'
        "    AppId      = $(& $q $d.AppId)"
        "    AppName    = $(& $q $d.AppName)"
        "    Version    = $(& $q $d.Version)"
        "    DetectName = $(& $q $d.DetectName)"
        "    Processes  = @($procs)"
        "    OutputFolder = $(& $q $d.OutputFolder)   # map voor het pakket; leeg = Output\<AppId>\<versie> in de kit"
        ''
        '    # ---------- 1b. Detectie: hoe Intune ziet dat de app er staat ----------'
        "    DetectionMethod = $(& $q $(if ($d.DetectionMethod) { $d.DetectionMethod } else { 'AppsEnOnderdelen' }))   # AppsEnOnderdelen | Bestand | Register | Script"
        "    DetectVersion   = $(& $q $d.DetectVersion)   # leeg = versie van dit pakket; '-' = alleen kijken of het bestaat"
        "    DetectFile      = $(& $q $d.DetectFile)   # bij Bestand, bijv. %ProgramFiles%\Remote help\RemoteHelp.exe"
        "    DetectRegKey    = $(& $q $d.DetectRegKey)   # bij Register, bijv. HKLM\SOFTWARE\Leverancier\App"
        "    DetectRegValue  = $(& $q $d.DetectRegValue)   # bij Register, bijv. Version (leeg = alleen de sleutel)"
        "    DetectScript    = $(& $q $d.DetectScript)"
        ''
        '    # ---------- 2. Uiterlijk ----------'
        "    Icon        = $(& $q $d.Icon)"
        "    AccentColor = $(& $q $d.AccentColor)"
        ''
        '    # ---------- 3. Wie krijgt de update ----------'
        "    OnlyUpdateExisting = $bool"
        "    InstallDuringSetup = $(if ($d.InstallDuringSetup -eq $false) { '$false' } else { '$true' })   # `$true = nieuwe laptops (Autopilot) direct installeren, zonder popup"
        ''
        '    # ---------- 4. Uitstellen ----------'
        "    MaxPostpones          = $([int]$d.MaxPostpones)"
        "    PostponeHours         = $([int]$d.PostponeHours)"
        "    ConsentTimeoutMinutes = $([int]$d.ConsentTimeoutMinutes)"
        "    ForcedDelayMinutes    = $([int]$d.ForcedDelayMinutes)"
        ''
        '    # ---------- 4b. Wanneer ----------'
        "    InstallWindow = $(& $q $(if ($d.InstallWindow) { $d.InstallWindow } else { 'Altijd' }))   # Altijd | Werktijd | BuitenWerktijd"
        "    WorkHours     = $(& $q $(if ($d.WorkHours) { $d.WorkHours } else { '08:00-17:00' }))   # meerdere blokken mag: '09:00-10:00,13:00-14:00'"
        "    WorkDays      = $(& $q $(if ($d.WorkDays) { $d.WorkDays } else { 'ma,di,wo,do,vr' }))"
        "    IdleMinutes   = $([int]("0$($d.IdleMinutes)"))   # > 0 = na zoveel minuten inactief of vergrendeld direct installeren"
        "    NoUserAction  = $(& $q $(if ($d.NoUserAction) { $d.NoUserAction } else { 'Installeren' }))   # Installeren | Wachten"
        ''
        '    # ---------- 4c. Herstart na de installatie ----------'
        "    RestartMode            = $(& $q $(if ($d.RestartMode) { $d.RestartMode } else { 'Nooit' }))   # Nooit | AlsNodig (3010/1641) | Altijd"
        "    RestartReminderMinutes = $([int]$(if ($null -ne $d.RestartReminderMinutes -and "$($d.RestartReminderMinutes)" -ne '') { $d.RestartReminderMinutes } else { 60 }))   # Later: opnieuw vragen na (minuten)"
        "    RestartDeadlineHours   = $([int]$(if ($null -ne $d.RestartDeadlineHours -and "$($d.RestartDeadlineHours)" -ne '') { $d.RestartDeadlineHours } else { 24 }))   # verplicht herstarten na (uren, 0 = nooit)"
        "    RestartWarningMinutes  = $([int]$(if ($null -ne $d.RestartWarningMinutes -and "$($d.RestartWarningMinutes)" -ne '') { $d.RestartWarningMinutes } else { 15 }))   # waarschuwing voor de verplichte herstart (minuten)"
        ''
        '    # ---------- 4d. Verwijderen ----------'
        "    UninstallNotify = $(if ($d.UninstallNotify -eq $true) { '$true' } else { '$false' })   # `$true = meldingen rechtsonder bij het verwijderen"
        ''
        '    # ---------- 5. Installatie (onderdelen worden in deze volgorde geïnstalleerd) ----------'
        "    AutoInstallSteps = $(if ($d.AutoInstallSteps) { '$true' } else { '$false' })   # `$true = install-app.cmd wordt hieruit gemaakt"
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
        "    PreInstall  = $(& $q $d.PreInstall)    # cmd-regels vóór de onderdelen"
        "    PostInstall = $(& $q $d.PostInstall)    # cmd-regels na de onderdelen"
        ''
        '    # ---------- 6. Teksten voor deze app/versie (leeg = _Kit\Standaardteksten.psd1) ----------'
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
        Haalt het pictogram uit de tabel Icon van een MSI en geeft het pad naar een tijdelijk .ico/.exe/.dll terug
        (of $null als de MSI geen pictogram heeft). Voorkeur: ARPPRODUCTICON (het icoon in Apps en onderdelen), anders het grootste.
    #>
    param ([string]$MsiPath, [string]$WorkDir)
    $db = $null
    try
    {
        $wi = New-Object -ComObject WindowsInstaller.Installer
        $db = $wi.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $wi, @($MsiPath, 0))
        # Tabel Icon exporteren: de pictogrammen komen als losse bestanden in de submap Icon
        $db.GetType().InvokeMember('Export', 'InvokeMethod', $null, $db, @('Icon', $WorkDir, 'Icon.idt')) | Out-Null
    }
    catch { return $null }
    finally { if ($db) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($db) } }

    $files = @(Get-ChildItem -Path $WorkDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'Icon.idt' -and $_.Length -gt 0 })
    if (-not $files.Count) { return $null }
    $pref = Get-MsiProperty $MsiPath 'ARPPRODUCTICON'
    $pick = if ($pref) { $files | Where-Object { $_.Name -like "$pref*" } | Select-Object -First 1 }
    if (-not $pick) { $pick = $files | Sort-Object Length -Descending | Select-Object -First 1 }

    # Soort bestand bepalen aan de eerste bytes: 00 00 01 00 = .ico, 'MZ' = .exe/.dll
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
    # Herkent het type installer en stelt stille parameters voor
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
        $info.Note        = 'MSI: wordt stil geïnstalleerd met msiexec /qn.'
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

    # Eerste 4 MB doorzoeken op kenmerken van het installatieprogramma
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
        $info.Kind = 'Inno'; $info.Args = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'; $info.Note = 'Inno Setup-installer.'
    }
    elseif ($text -match 'InstallShield')
    {
        $info.Kind = 'InstallShield'; $info.Args = '/s /v"/qn /norestart"'; $info.Note = 'InstallShield: controleer de parameters bij de leverancier.'
    }
    elseif ($text -match 'WixBundle|WiX Toolset|\.wixburn')
    {
        $info.Kind = 'WiX'; $info.Args = '/quiet /norestart'; $info.Note = 'WiX-bundle.'
    }
    else
    {
        $info.Note = 'Type niet herkend: controleer de stille parameters bij de leverancier.'
    }
    return $info
}

function Find-UninstallString
{
    # Zoekt op DEZE pc in "Apps en onderdelen" naar een verwijdercommando
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
rem  INSTALLATIESTAPPEN - $AppName
rem  Gemaakt met de Builder; je mag dit aanpassen (extra stappen, bestanden, ...).
rem  De popup, de procescheck en de meldingen regelt install.cmd al.
rem ===========================================================================

rem ---- Voorbereiding (bijv. een runtime die eerst nodig is) ----

rem ---- De app zelf ($($Info.Kind)) ----
$line
set APP_EXITCODE=%ERRORLEVEL%

rem ---- Nazorg (extra bestanden, snelkoppelingen, ingebouwde updater uitzetten, ...) ----

exit /b %APP_EXITCODE%
"@
}

function Get-ComponentInfo
{
    # Type, voorgestelde parameters en (bij MSI) productcode van een bestand dat geïnstalleerd moet worden
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
        '.reg' { $r.Kind = 'REG'; $r.Codes = '0'; $r.Note = 'Registerbestand (reg import).' }
    }
    # Typische hulponderdelen: "al geïnstalleerd" (1638) ook goedkeuren
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
    # Maakt install-app.cmd: onderdelen in volgorde, met eigen parameters en toegestane exitcodes.
    # Mislukt een onderdeel, dan stopt de installatie met de exitcode van dat onderdeel.
    param ([string]$AppName, $Components, [string]$PreInstall, [string]$PostInstall)

    $L = @(
        'rem ==========================================================================='
        "rem  INSTALLATIESTAPPEN - $AppName"
        'rem  Automatisch gemaakt door de Builder uit de onderdelen in tabblad 2.'
        'rem  Wijzig de onderdelen in de Builder (of zet "automatisch maken" uit).'
        'rem ==========================================================================='
        ''
        'set APP_EXITCODE=0'
    )
    if ("$PreInstall".Trim())
    {
        $L += ''; $L += 'rem ---- Voor de installatie ----'; $L += ("$PreInstall".TrimEnd() -split "`r?`n")
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
        $L += "rem ---- Onderdeel ${i}: $($c.File) ($($c.Kind))$(if ($c.Main) { ' - hoofdonderdeel' }) ----"
        $L += Get-ComponentCommand $c
        $L += 'set STEP=%ERRORLEVEL%'
        $L += 'set OK='
        $L += "for %%c in ($($codes -join ' ')) do if `"%STEP%`"==`"%%c`" set OK=1"
        $L += 'if not defined OK ('
        $L += "    echo Onderdeel $i - $safe - is mislukt met exitcode %STEP%"
        $L += '    exit /b %STEP%'
        $L += ')'
        $L += 'if "%STEP%"=="3010" set APP_EXITCODE=3010'
        $L += 'if "%STEP%"=="1641" set APP_EXITCODE=1641'
    }
    if ("$PostInstall".Trim())
    {
        $L += ''; $L += 'rem ---- Na de installatie ----'; $L += ("$PostInstall".TrimEnd() -split "`r?`n")
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
        # Op naam verwijderen (MSI-productcode of het eigen verwijderprogramma); werkt op elke laptop
        $line = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"Remove-App.ps1`" -Name `"$DetectName`""
        if ($Info.Kind -in 'NSIS', 'Inno', 'EXE') { $line += " -ExeArgs `"$(if ($Info.Kind -eq 'Inno') { '/VERYSILENT /NORESTART' } else { '/S' })`"" }
    }
    if (-not $line)
    {
        $line = "rem VUL IN: het verwijdercommando, bijvoorbeeld:`r`nrem `"%ProgramFiles%\$AppName\uninstall.exe`" /S`r`nver > nul"
    }
@"
rem ===========================================================================
rem  VERWIJDERSTAPPEN - $AppName
rem ===========================================================================

$line
set APP_EXITCODE=%ERRORLEVEL%

exit /b %APP_EXITCODE%
"@
}

function Find-HeadlessBrowser
{
    # Edge staat op elke Windows 10/11-laptop; Chrome als reserve
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
        Zet een .svg om naar een PNG van Size x Size met transparante achtergrond.
        Windows kan zelf geen SVG tekenen; daarom doet Edge (headless) het.
    #>
    param ([string]$Svg, [string]$Png, [int]$Size = 256, [string]$Browser = (Find-HeadlessBrowser), [string[]]$ExtraArgs = @(), [switch]$NoCrop)
    if (-not $Browser) { throw 'Microsoft Edge of Google Chrome is nodig om een SVG om te zetten, maar is niet gevonden. Sla het logo op als .png en kies dat.' }

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

        # Eigen profielmap: anders geeft Edge de opdracht door aan een al geopend Edge-venster
        $argList = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
                     '--disable-extensions', '--force-device-scale-factor=1', '--default-background-color=00000000',
                     "--window-size=$($Size * 2 + 200),$($Size * 2 + 200)", "--user-data-dir=`"$(Join-Path $work 'profiel')`"",
                     "--screenshot=`"$out`"") + $ExtraArgs + @("`"file:///$($html.Replace('\', '/').TrimStart('/'))`"")
        $hide = @{}; if ($IsWindows -ne $false) { $hide.WindowStyle = 'Hidden' }   # PS 5.1: $IsWindows bestaat niet
        $proc = Start-Process -FilePath $Browser -ArgumentList $argList -PassThru @hide
        $null = $proc.Handle
        if (-not $proc.WaitForExit(30000)) { try { $proc.Kill() } catch { }; throw 'Het omzetten van de SVG duurde te lang.' }
        if (-not (Test-Path $out) -or (Get-Item $out).Length -lt 100) { throw 'De SVG kon niet worden omgezet. Klopt het bestand? Probeer anders een .png.' }
        if ($NoCrop) { Copy-Item -LiteralPath $out -Destination $Png -Force; return }

        # Het venster is groter gerenderd (kleine headless-vensters worden onderaan afgekapt): logo linksboven uitknippen
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
    # Maakt een .ico (256x256, PNG erin) van een .svg/.png/.jpg/.bmp, of haalt het icoon uit een .exe
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
        # Eerst de grootste versie (256x256) opvragen; ExtractAssociatedIcon geeft alleen 32x32 (wazig)
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
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)          # header: 1 afbeelding
    $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)  # 256x256
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$png.Length); $bw.Write([uint32]22)
    $bw.Write($png); $bw.Flush()
    [System.IO.File]::WriteAllBytes($Target, $out.ToArray())
}

function Expand-AppText
{
    param ([string]$Text, [hashtable]$d)
    return $Text.Replace('{AppName}', $d.AppName).Replace('{Versie}', [string]$d.Version).Replace('{Minuten}', [string]$d.ForcedDelayMinutes).Replace('{MaxUitstel}', [string]$d.MaxPostpones)
}

function Get-EffectiveText
{
    param ([string]$Key, [hashtable]$d, $Std = $null, [switch]$New)
    if (-not $Std) { $Std = Get-StandardTexts }
    $t = $null
    if ($New -and $Key -notlike 'New*')
    {
        # Nieuwe installatie: eerst de New-tekst van de app, dan de standaard New-tekst
        $nk = "New$Key"
        if ($d.Texts -and $d.Texts[$nk]) { $t = $d.Texts[$nk] } elseif ($Std[$nk]) { $t = $Std[$nk] }
    }
    if (-not $t) { $t = if ($d.Texts -and $d.Texts[$Key]) { $d.Texts[$Key] } else { $Std[$Key] } }
    return Expand-AppText $t $d
}

function Get-VersionDetails
{
    # Alles over een gebouwde versie, uit Output\<AppId>\<versie>\Bron en Bouwinfo.txt
    param ([string]$Path)
    $bron = Join-Path $Path 'Bron'
    $r = @{ Data = $null; Std = $null; Icon = $null; Summary = ''; Install = ''; Texts = ''; BuildInfo = '' }

    $psd = Join-Path $bron 'app.psd1'
    if (-not (Test-Path $psd))
    {
        $r.Summary = 'Van deze versie zijn geen instellingen bewaard (gebouwd met een oudere versie van de kit).'
        return $r
    }
    $d = Read-AppPsd1 $psd
    $r.Data = $d

    # Standaardteksten zoals ze bij het bouwen van deze versie waren
    $std = [ordered]@{}
    foreach ($k in $TextKeys) { $std[$k] = $BuiltinTexts[$k] }
    $stdFile = Join-Path $bron 'Standaardteksten.psd1'
    if (Test-Path $stdFile) { try { $f = Read-AppPsd1 $stdFile; foreach ($k in $TextKeys) { if ($f[$k]) { $std[$k] = $f[$k] } } } catch { } }
    $r.Std = $std

    $icon = Join-Path $bron $(if ($d.Icon) { $d.Icon } else { 'app.ico' })
    if (Test-Path $icon) { $r.Icon = $icon }

    $timeout = if ($null -ne $d.ConsentTimeoutMinutes) { "$($d.ConsentTimeoutMinutes) minuten" }
               elseif ($null -ne $d.ConsentTimeoutSeconds) { "$($d.ConsentTimeoutSeconds) seconden" } else { '15 minuten' }
    $who = if ($d.OnlyUpdateExisting -eq $false) { 'iedereen in de toegewezen groep' } else { 'alleen apparaten waar de app al staat' }
    $r.Summary = @(
        "Naam in popup        : $($d.AppName)"
        "Versie               : $($d.Version)"
        "Apps en onderdelen   : $($d.DetectName)"
        "Detectie             : $(switch ("$($d.DetectionMethod)") { 'Bestand' { "bestand $($d.DetectFile)" } 'Register' { "register $($d.DetectRegKey)$(if ($d.DetectRegValue) { "\$($d.DetectRegValue)" })" } 'Script' { 'eigen script' } default { 'Apps en onderdelen' } })$(if ("$($d.DetectionMethod)" -ne 'Script') { if ("$($d.DetectVersion)" -eq '-') { ', geen versie' } elseif ($d.DetectVersion) { ", minimaal $($d.DetectVersion)" } else { ", minimaal $($d.Version)" } })"
        "Processen            : $(@($d.Processes) -join ', ')"
        "Kleur                : $($d.AccentColor)"
        "Logo                 : $(if ($r.Icon) { 'aanwezig' } else { 'ontbreekt' })"
        "Wie krijgt de update : $who"
        "Uitstellen           : $($d.MaxPostpones) keer, telkens $($d.PostponeHours) uur"
        "Geen keuze           : venster sluit na $timeout"
        "Waarschuwing vooraf  : $($d.ForcedDelayMinutes) minuten na de laatste keer uitstellen"
        "Tijdvenster          : $(Get-WindowText $d)"
        "Inactief             : $(if ([int]("0$($d.IdleMinutes)") -gt 0) { "na $($d.IdleMinutes) minuten inactief of vergrendeld direct installeren" } else { 'uit' })"
        "Autopilot            : $(if ($d.InstallDuringSetup -eq $false) { 'overslaan, de app komt na de inrichting' } else { 'direct installeren, zonder popup' })"
        "Herstart             : $(switch ($d.RestartMode) { 'AlsNodig' { "alleen als de installer erom vraagt; Later = $($d.RestartReminderMinutes) min, verplicht na $(if ([int]("0$($d.RestartDeadlineHours)")) { "$($d.RestartDeadlineHours) uur" } else { 'nooit' })" } 'Altijd' { "altijd; Later = $($d.RestartReminderMinutes) min, verplicht na $(if ([int]("0$($d.RestartDeadlineHours)")) { "$($d.RestartDeadlineHours) uur" } else { 'nooit' })" } default { 'geen melding' } })"
        "Verwijderen          : $(if ($d.UninstallNotify -eq $true) { 'met meldingen' } else { 'zonder meldingen' })"
        "Niemand ingelogd     : $(if ($d.NoUserAction -eq 'Wachten') { 'wachten tot er iemand is ingelogd' } else { 'direct installeren' })"
    ) -join "`r`n"
    $comps = @($d.Components | Where-Object { $_ })
    if ($comps.Count)
    {
        $n = 0
        $r.Summary += "`r`n`r`nOnderdelen (in volgorde):"
        foreach ($c in $comps)
        {
            $n++
            $r.Summary += "`r`n  $n. $($c.File)  [$($c.Kind)]$(if ($c.Main) { '  (hoofdonderdeel)' })"
            $r.Summary += "`r`n     parameters : $(if ($c.Args) { $c.Args } else { '(geen)' })"
            $r.Summary += "`r`n     geslaagd bij exitcode: $($c.Codes)"
        }
        if ("$($d.PreInstall)".Trim())  { $r.Summary += "`r`n`r`nVoor de installatie:`r`n$($d.PreInstall)" }
        if ("$($d.PostInstall)".Trim()) { $r.Summary += "`r`n`r`nNa de installatie:`r`n$($d.PostInstall)" }
    }

    $parts = @()
    foreach ($fname in 'install-app.cmd', 'uninstall-app.cmd')
    {
        $p = Join-Path $bron $fname
        $parts += "==================== $fname ===================="
        $parts += if (Test-Path $p) { [System.IO.File]::ReadAllText($p).TrimEnd() } else { '(niet bewaard)' }
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
        $lines += "[$($TextLabels[$k])]  $(if ($own) { '(eigen tekst)' } else { '(standaardtekst)' })"
        $lines += (Get-EffectiveText $k $d $std)
        $lines += ''
    }
    $r.Texts = $lines -join "`r`n"

    $bi = Join-Path $Path 'Bouwinfo.txt'
    $r.BuildInfo = if (Test-Path $bi) { [System.IO.File]::ReadAllText($bi) } else { '(geen Bouwinfo.txt)' }
    return $r
}

function Get-WindowText([hashtable]$d)
{
    $h = if ($d.WorkHours) { "$($d.WorkHours)" -replace '\s*,\s*', ', ' } else { '08:00-17:00' }
    $w = if ($d.WorkDays) { $d.WorkDays } else { 'ma,di,wo,do,vr' }
    switch ($d.InstallWindow)
    {
        'Werktijd'       { return "alleen binnen de gekozen tijden ($w, $h)" }
        'BuitenWerktijd' { return "alleen buiten de gekozen tijden (buiten $w, $h)" }
        default          { return 'altijd' }
    }
}

function Compare-AppData
{
    # Korte lijst met verschillen tussen een oude versie en wat nu in de Builder staat
    param ([hashtable]$Old, [hashtable]$New, [string]$OldInstall, [string]$NewInstall)
    $diff = @()
    $labels = [ordered]@{ Version = 'Versie'; AppName = 'Naam'; DetectName = 'Apps en onderdelen'; AccentColor = 'Kleur'
                          MaxPostpones = 'Aantal keer uitstellen'; PostponeHours = 'Uren per keer'; ForcedDelayMinutes = 'Waarschuwing (min)'
                          InstallWindow = 'Tijdvenster'; WorkHours = 'Tijden'; WorkDays = 'Werkdagen'; IdleMinutes = 'Inactief (min)'; NoUserAction = 'Niemand ingelogd'
                          RestartMode = 'Herstart'; RestartReminderMinutes = 'Herstart: Later (min)'; RestartDeadlineHours = 'Herstart: verplicht na (uur)'; RestartWarningMinutes = 'Herstart: waarschuwing (min)'; UninstallNotify = 'Meldingen bij verwijderen' }
    foreach ($k in $labels.Keys)
    {
        if ("$($Old[$k])" -ne "$($New[$k])") { $diff += "$($labels[$k]): $($Old[$k])  ->  $($New[$k])" }
    }
    if ((@($Old.Processes) -join ',') -ne (@($New.Processes) -join ',')) { $diff += "Processen: $(@($Old.Processes) -join ', ')  ->  $(@($New.Processes) -join ', ')" }
    if ([bool]$Old.OnlyUpdateExisting -ne [bool]$New.OnlyUpdateExisting) { $diff += 'Wie krijgt de update: gewijzigd' }
    if (($Old.InstallDuringSetup -ne $false) -ne ($New.InstallDuringSetup -ne $false)) { $diff += "Installeren tijdens Autopilot: $(if ($New.InstallDuringSetup -ne $false) { 'aan' } else { 'uit' })" }
    $fmt = { param($list) (@($list | Where-Object { $_ } | ForEach-Object { "$($_.File)|$($_.Args)|$($_.Codes)|$([bool]$_.Main)" }) -join ';') }
    if ((& $fmt $Old.Components) -ne (& $fmt $New.Components))
    {
        $oldF = @($Old.Components | Where-Object { $_ } | ForEach-Object { $_.File }) -join ', '
        $newF = @($New.Components | Where-Object { $_ } | ForEach-Object { $_.File }) -join ', '
        $diff += if ($oldF -ne $newF) { "Onderdelen: $oldF  ->  $newF" } else { 'Parameters of exitcodes van onderdelen gewijzigd' }
    }
    foreach ($k in $TextKeys)
    {
        $o = if ($Old.Texts) { "$($Old.Texts[$k])" } else { '' }
        $n = if ($New.Texts) { "$($New.Texts[$k])" } else { '' }
        if ($o.Trim() -ne $n.Trim()) { $diff += "Tekst gewijzigd: $($TextLabels[$k])" }
    }
    $norm = { param($s) (("$s" -replace "`r", '').Trim()) }
    if ($OldInstall -and (& $norm $OldInstall) -ne (& $norm $NewInstall)) { $diff += 'Installatiestappen (install-app.cmd) gewijzigd' }
    return $diff
}

function Test-InAppsFolder([string]$Path)
{
    # Ligt dit pad in Apps\ van de kit (de app-mappen)? Daar mag het pakket niet komen.
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
    if ($d.AppId -notmatch '^[A-Za-z0-9_-]+$')        { $e += 'AppId: alleen letters, cijfers, - en _ (geen spaties).' }
    if (-not $d.AppName)                               { $e += 'Naam is leeg.' }
    if ($d.Version -notmatch '^\d+(\.\d+){0,3}$')      { $e += 'Versie moet de vorm 1.2.3 hebben.' }
    if (-not $d.DetectName)                            { $e += 'Naam in Apps en onderdelen is leeg.' }
    switch ("$($d.DetectionMethod)")
    {
        'Bestand'  { if (-not $d.DetectFile)   { $e += 'Detectie: vul het bestand in (bijv. %ProgramFiles%\Remote help\RemoteHelp.exe).' } }
        'Register' { if (-not $d.DetectRegKey) { $e += 'Detectie: vul de registersleutel in.' } }
        'Script'   {
            if (-not "$($d.DetectScript)".Trim()) { $e += 'Detectie: het eigen detectiescript is leeg.' }
            else { $pe = $null; [System.Management.Automation.Language.Parser]::ParseInput("$($d.DetectScript)", [ref]$null, [ref]$pe) | Out-Null; if ($pe) { $e += "Detectie: fout in het eigen script, regel $($pe[0].Extent.StartLineNumber): $($pe[0].Message)" } }
        }
    }
    if ("$($d.DetectVersion)" -and "$($d.DetectVersion)" -ne '-' -and "$($d.DetectVersion)" -notmatch '^\d+(\.\d+){0,3}$') { $e += 'Detectie: de minimale versie moet de vorm 1.2.3 hebben.' }
    if ($d.AccentColor -notmatch '^#[0-9A-Fa-f]{6}$')  { $e += 'Kleur moet de vorm #RRGGBB hebben.' }
    # Pakketmap: bij opslaan mag hij nog leeg zijn of nog niet bestaan; bij bouwen is hij verplicht (Confirm-OutputFolder)
    if ("$($d.OutputFolder)".Trim())
    {
        $of = [Environment]::ExpandEnvironmentVariables("$($d.OutputFolder)")
        if ($of -notmatch '^([A-Za-z]:\\|\\\\)') { $e += "Pakket opslaan in: gebruik een volledig pad, bijv. I:\...\intune-package (nu: $($d.OutputFolder))." }
        elseif (Test-InAppsFolder $of) { $e += "Pakket opslaan in ligt in de app-map ($of). Kies een map buiten Apps\, bijv. de versiemap naast de installer; anders kopieert elke build zichzelf in het pakket." }
    }
    if ($d.AutoInstallSteps -and -not @($d.Components | Where-Object { $_ }).Count) { $e += 'Voeg in tabblad 2 minstens één onderdeel toe (of zet automatisch maken uit).' }
    if ($d.InstallWindow -and $d.InstallWindow -ne 'Altijd')
    {
        $blocks = @("$($d.WorkHours)" -split ',' | Where-Object { $_ })
        if (-not $blocks.Count) { $e += 'Vul minstens één tijdblok in, bijv. 08:00-17:00.' }
        foreach ($b in $blocks)
        {
            if ($b -notmatch '^([01]?\d|2[0-3]):[0-5]\d-([01]?\d|2[0-3]):[0-5]\d$') { $e += "Tijden: '$b' moet de vorm 08:00-17:00 hebben. Meerdere blokken scheid je met een komma." }
            elseif (($b -split '-')[0] -eq ($b -split '-')[1]) { $e += "Tijden: in '$b' zijn begin en einde gelijk." }
        }
        if (-not "$($d.WorkDays)".Trim()) { $e += 'Kies minstens één werkdag.' }
    }
    if ("$($d.IdleMinutes)" -notmatch '^\d+$') { $e += 'Minuten inactief moet een heel getal zijn.' }
    if ($d.RestartMode -and $d.RestartMode -ne 'Nooit')
    {
        if ("$($d.RestartReminderMinutes)" -notmatch '^\d+$' -or [int]$d.RestartReminderMinutes -lt 15) { $e += 'Herstart: opnieuw vragen na moet minstens 15 minuten zijn.' }
        if ("$($d.RestartDeadlineHours)" -notmatch '^\d+$')  { $e += 'Herstart: verplicht na (uur) moet een heel getal zijn (0 = nooit).' }
        if ("$($d.RestartWarningMinutes)" -notmatch '^\d+$' -or [int]$d.RestartWarningMinutes -lt 1) { $e += 'Herstart: waarschuwing vooraf moet minstens 1 minuut zijn.' }
    }
    foreach ($n in 'MaxPostpones', 'PostponeHours', 'ConsentTimeoutMinutes', 'ForcedDelayMinutes')
    {
        if ("$($d[$n])" -notmatch '^\d+$') { $e += "$n moet een heel getal zijn." }
    }
    return $e
}

#endregion

function Get-DetectionScriptText([hashtable]$d)
{
    # Het detectiescript zoals de build het maakt (voor 'Testen op deze pc')
    if ($d.DetectionMethod -eq 'Script') { return "$($d.DetectScript)" }
    $ver = if ("$($d.DetectVersion)".Trim()) { "$($d.DetectVersion)".Trim() } else { "$($d.Version)" }
    if ($ver -eq '-') { $ver = '' }
    $q = { param($v) "$v".Replace("'", "''") }
    return ([System.IO.File]::ReadAllText((Join-Path $KitDir 'Intune\Detection.ps1'))).
        Replace('{{APPNAME}}', $d.AppName).Replace('{{DETECT_METHOD}}', $(if ($d.DetectionMethod) { $d.DetectionMethod } else { 'AppsEnOnderdelen' })).
        Replace('{{DETECT_NAME}}', (& $q $d.DetectName)).Replace('{{DETECT_VERSION}}', (& $q $ver)).
        Replace('{{DETECT_FILE}}', (& $q $d.DetectFile)).Replace('{{DETECT_REGKEY}}', (& $q $d.DetectRegKey)).Replace('{{DETECT_REGVALUE}}', (& $q $d.DetectRegValue))
}

if ($env:APPKIT_NOGUI) { return }   # voor tests: alleen de functies laden

#region ===================== Venster =====================

# Scherp op schermen met schaal 125%/150%/200%: Windows laten weten dat de Builder zelf schaalt.
# Zonder dit vergroot Windows het venster als plaatje en wordt het wazig. Moet vóór het eerste venster.
try
{
    Add-Type -Namespace AppKit -Name Dpi -ErrorAction Stop -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(System.IntPtr value);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
'@
    # -2 = DPI_AWARENESS_CONTEXT_SYSTEM_AWARE (Windows 10 1703+); anders de oudere aanroep
    $dpiOk = $false
    try { $dpiOk = [AppKit.Dpi]::SetProcessDpiAwarenessContext([System.IntPtr]::new(-2)) } catch { }
    if (-not $dpiOk) { [void][AppKit.Dpi]::SetProcessDPIAware() }
}
catch { }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic

# Eigen identiteit in de taakbalk, zodat Windows het Builder-icoon toont en niet dat van PowerShell
try
{
    Add-Type -Namespace AppKit -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string id);'
    [void][AppKit.Shell]::SetCurrentProcessExplicitAppUserModelID('AppUpdateKit.Builder')
}
catch { $script:AumidError = $_.Exception.Message }
$BuilderIcon = Join-Path $KitDir 'Builder.ico'
# Vanaf een netwerkschijf (bijv. I:\apps) laadt Windows het icoon niet altijd: lokale kopie in het eigen profiel gebruiken
# Wat er met het icoon gebeurt, komt in %LOCALAPPDATA%\AppUpdateKit\opstarten.log (bij elke start overschreven)
$script:StartLog = Join-Path (Join-Path $env:LOCALAPPDATA 'AppUpdateKit') 'opstarten.log'
function Write-StartLog([string]$Text)
{
    try { Add-Content -LiteralPath $script:StartLog -Value "$(Get-Date -Format 'HH:mm:ss')  $Text" -Encoding UTF8 } catch { }
}
try
{
    $localIconDir = Join-Path $env:LOCALAPPDATA 'AppUpdateKit'
    if (-not (Test-Path -LiteralPath $localIconDir)) { New-Item -Path $localIconDir -ItemType Directory -Force | Out-Null }
    Set-Content -LiteralPath $script:StartLog -Value "AppUpdateKit Builder gestart $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-StartLog "Kit-map        : $KitRoot"
    Write-StartLog "Icoon in kit   : $BuilderIcon (bestaat: $(Test-Path -LiteralPath $BuilderIcon))"
    $localIcon = Join-Path $localIconDir 'Builder.ico'
    if ((Test-Path -LiteralPath $BuilderIcon) -and (-not (Test-Path -LiteralPath $localIcon) -or (Get-Item -LiteralPath $localIcon).Length -ne (Get-Item -LiteralPath $BuilderIcon).Length))
    {
        Copy-Item -LiteralPath $BuilderIcon -Destination $localIcon -Force
        Write-StartLog "Lokale kopie   : gemaakt in $localIcon"
    }
    if (Test-Path -LiteralPath $localIcon) { $BuilderIcon = $localIcon; Write-StartLog "Icoon gebruikt : $localIcon ($((Get-Item -LiteralPath $localIcon).Length) bytes)" }
    else { Write-StartLog 'Icoon gebruikt : GEEN lokale kopie, het icoon uit de kit wordt gebruikt' }
    # Kopie voor de snelkoppeling in de kit-map: Verkenner toont een icoon dat zelf op een netwerkschijf staat vaak niet.
    # %ProgramData% is op elke pc lokaal en voor elk account leesbaar.
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
    catch { Write-StartLog "Gedeeld icoon  : niet gelukt ($($_.Exception.Message))" }
    if ($script:AumidError) { Write-StartLog "FOUT bij de taakbalk-identiteit: $($script:AumidError)" }
    else { Write-StartLog 'Taakbalk-id    : AppUpdateKit.Builder' }
}
catch { Write-StartLog "FOUT bij het kopiëren van het icoon: $($_.Exception.Message)" }

# Startmenu-snelkoppeling met dezelfde taakbalk-identiteit (AppUserModelID) en het icoon.
# Windows haalt het taakbalkicoon van een app met een eigen identiteit uit zo'n snelkoppeling; zonder snelkoppeling
# toont de taakbalk bij de eerste start (vooral vanaf een netwerkschijf) soms een leeg icoon.
# Wordt gemaakt voordat het venster verschijnt, en staat daarna ook in het Startmenu als "AppUpdateKit Builder".
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
                link.SetShowCmd(7);   // geminimaliseerd: het PowerShell-venster blijft weg
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
        Write-StartLog "Startmenu      : $startMenu bijgewerkt"
    }
    else { Write-StartLog 'Startmenu      : niet gemaakt (hulpcode kon niet laden)' }
}
catch { Write-StartLog "FOUT bij de Startmenu-snelkoppeling: $($_.Exception.Message)" }

function Get-BuilderIconImage
{
    # Icoon uit de bytes laden (niet via een bestandsadres): werkt ook vanaf een netwerkschijf
    try
    {
        $ms = New-Object System.IO.MemoryStream (, [System.IO.File]::ReadAllBytes($BuilderIcon))
        return [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, [System.Windows.Media.Imaging.BitmapCreateOptions]::None, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    }
    catch { return $null }
}

# Rij in de onderdelen-tabel
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

# Fout bij het opstarten (voordat het venster er is): toch een melding geven
trap
{
    $log = Join-Path ([System.IO.Path]::GetTempPath()) 'AppUpdateKit-Builder-fouten.log'
    Add-Content -Path $log -Value "$(Get-Date)`r`n$($_ | Out-String)" -ErrorAction SilentlyContinue
    [void][System.Windows.MessageBox]::Show("De Builder kon niet starten:`n`n$($_.Exception.Message)`n`nDetails: $log", 'AppUpdateKit Builder', 'OK', 'Error')
    exit 1
}

# Gedeeld thema voor alle Builder-vensters (knoppen, velden, tabbladen, lijsten, schuifbalken)
$ThemeXaml = @'
    <!-- Thema: kleuren -->
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

    <!-- Tekst -->
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

    <!-- Invoervelden: afgerond, blauwe rand bij focus -->
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

    <!-- Knoppen -->
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

    <!-- Vinkjes -->
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

    <!-- Keuzerondjes -->
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

    <!-- Keuzelijsten -->
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

    <!-- Lijsten -->
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

    <!-- Tabel (onderdelen) -->
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
      <Setter Property="Padding" Value="6,0"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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
        <!-- Bij bewerken in een cel: gewoon tekstvak zonder afronding en marges -->
        <Style TargetType="TextBox">
          <Setter Property="Padding" Value="2,0"/>
          <Setter Property="Margin" Value="0"/>
          <Setter Property="BorderThickness" Value="0"/>
        </Style>
      </Style.Resources>
    </Style>

    <!-- Tabbladen: platte tabs met een blauwe streep onder het actieve tabblad -->
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

    <!-- Smalle schuifbalken -->
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
<!--THEMA-->
  </Window.Resources>

  <DockPanel>
    <!-- Kop -->
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
          <TextBlock Text="AppUpdateKit Builder" Foreground="White" FontSize="19" FontWeight="SemiBold"/>
          <TextBlock Text="Vul de gegevens in, bekijk de popup en bouw het Intune-pakket." Foreground="#CFE0F3" FontSize="12.5" Margin="0,1,0,0"/>
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Onderbalk -->
    <Border DockPanel.Dock="Bottom" Background="White" BorderBrush="#E6E9EE" BorderThickness="0,1,0,0" Padding="20,12">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button Name="BtnSave" Content="Opslaan"/>
          <Button Name="BtnOpenOutput" Content="Map met pakket openen" IsEnabled="False"/>
          <Button Name="BtnBuild" Content="Bouw pakket (.intunewin)" Style="{StaticResource Primary}" Margin="0"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" Margin="0,0,16,0">
          <Button Name="BtnPrevTab" Content="‹  Vorige" IsEnabled="False" ToolTip="Naar het vorige tabblad"/>
          <Button Name="BtnNextTab" Content="Volgende  ›" IsEnabled="False" ToolTip="Naar het volgende tabblad" Margin="0"/>
        </StackPanel>
        <TextBlock Name="TxtStatus" VerticalAlignment="Center" Foreground="#6B7280" TextTrimming="CharacterEllipsis"/>
      </DockPanel>
    </Border>

    <!-- Apps -->
    <Border DockPanel.Dock="Left" Width="230" Background="White" BorderBrush="#E6E9EE" BorderThickness="0,0,1,0" Padding="14,16">
      <DockPanel>
        <TextBlock DockPanel.Dock="Top" Text="APPS" FontWeight="SemiBold" FontSize="11" Foreground="#6B7280" Margin="10,0,0,8"/>
        <Button DockPanel.Dock="Bottom" Name="BtnInstallerMap" Content="Standaardmap..." Margin="0,6,0,0"
                ToolTip="Map waar 'Kiezen...' standaard opent bij het kiezen van een installer (_Kit\Instellingen.psd1)"/>
        <Button DockPanel.Dock="Bottom" Name="BtnNewApp" Content="+ Nieuwe app" Margin="0,8,0,0" Style="{StaticResource Primary}"/>
        <ListBox Name="LstApps" BorderThickness="0" Padding="0"/>
      </DockPanel>
    </Border>

    <!-- Tabbladen -->
    <TabControl Name="Tabs" Margin="16,10,16,0" IsEnabled="False">

      <TabItem Header="1. Basis">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Installer"/>
                <DockPanel>
                  <Button DockPanel.Dock="Right" Name="BtnInstaller" Content="Kiezen..." Margin="8,2,0,8"/>
                  <TextBox Name="TxtInstaller" IsReadOnly="True" Background="#F7F8FA"/>
                </DockPanel>
                <TextBlock Name="TxtInstallerInfo" Style="{StaticResource Hint}" Text="Kies de installer (.exe of .msi). Naam, versie en stille parameters worden dan automatisch ingevuld."/>
                <Label Content="Pakket opslaan in (verplicht)"/>
                <DockPanel>
                  <Button DockPanel.Dock="Right" Name="BtnOutputFolder" Content="Kiezen..." Margin="8,2,0,8"/>
                  <TextBox Name="TxtOutputFolder"/>
                </DockPanel>
                <TextBlock Name="TxtOutputHint" Style="{StaticResource Hint}" Text="Klik op Kiezen... en kies de versiemap, bijv. ...\versies\2.4.0. De Builder zet er \intune-package achter. Je kunt het pad ook typen of plakken."/>
              </StackPanel>
            </Border>

            <Border Style="{StaticResource Card}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="20"/><ColumnDefinition/></Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                  <Label Content="AppId (interne naam, geen spaties)"/>
                  <TextBox Name="TxtAppId" IsReadOnly="True" Background="#F7F8FA"/>
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
                  <TextBlock Style="{StaticResource Hint}" Text="Zonder .exe, gescheiden door komma's. Bijv.: notepad++   of   winword, excel. Leeg = geen procescheck (voor apps zonder eigen programma, zoals een runtime of driver)."/>
                  <CheckBox Name="ChkOnlyExisting" Content="Alleen bijwerken op apparaten waar de app al staat" Margin="0,6,0,0"/>
                  <CheckBox Name="ChkDuringSetup" Content="Installeren op nieuwe laptops (Autopilot), zonder popup" Margin="0,6,0,0"/>
                  <TextBlock Style="{StaticResource Hint}" Margin="0,2,0,0" Text="Tijdens de inrichting wordt de app direct geïnstalleerd, ook als hij er nog niet op staat. Uit = de app komt pas na de inrichting, met popup."/>
                </StackPanel>
              </Grid>
            </Border>

            <Border Style="{StaticResource Card}">
              <StackPanel>
                <Label Content="Detectie: zo ziet Intune dat de app (in deze versie) op de laptop staat"/>
                <ComboBox Name="CmbDetect" Width="420" HorizontalAlignment="Left" Margin="0,2,0,8" SelectedIndex="0">
                  <ComboBoxItem Tag="AppsEnOnderdelen" Content="Apps en onderdelen (naam en versie, standaard)"/>
                  <ComboBoxItem Tag="Bestand" Content="Bestand (pad en bestandsversie)"/>
                  <ComboBoxItem Tag="Register" Content="Register (sleutel en waarde)"/>
                  <ComboBoxItem Tag="Script" Content="Eigen detectiescript"/>
                </ComboBox>
                <TextBlock Name="TxtDetectHint" Style="{StaticResource Hint}"/>
                <StackPanel Name="PnlDetectFile">
                  <Label Content="Bestand"/>
                  <TextBox Name="TxtDetectFile"/>
                  <TextBlock Style="{StaticResource Hint}" Text="Volledig pad; %ProgramFiles% en andere omgevingsvariabelen mogen. Bijv. %ProgramFiles%\Remote help\RemoteHelp.exe"/>
                </StackPanel>
                <Grid Name="PnlDetectReg">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="2*"/><ColumnDefinition Width="16"/><ColumnDefinition/></Grid.ColumnDefinitions>
                  <StackPanel Grid.Column="0">
                    <Label Content="Registersleutel"/>
                    <TextBox Name="TxtDetectRegKey"/>
                    <TextBlock Style="{StaticResource Hint}" Text="Bijv. HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{GUID} (kopieer het pad uit regedit)"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2">
                    <Label Content="Waarde"/>
                    <TextBox Name="TxtDetectRegValue"/>
                    <TextBlock Style="{StaticResource Hint}" Text="Bijv. DisplayVersion of Version. Leeg = alleen kijken of de sleutel bestaat."/>
                  </StackPanel>
                </Grid>
                <StackPanel Name="PnlDetectVersion" Orientation="Horizontal" Margin="0,2,0,0">
                  <Label Content="Minimale versie" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <TextBox Name="TxtDetectVersion" Width="160" Margin="0,2,12,2"/>
                  <CheckBox Name="ChkDetectAnyVersion" Content="Geen versie, alleen kijken of het bestaat" VerticalAlignment="Center"/>
                </StackPanel>
                <TextBlock Name="TxtDetectVersionHint" Style="{StaticResource Hint}" Margin="0,2,0,8" Text="Leeg = de versie van dit pakket (tabblad 1). Vul een andere versie in als de app zich met een ander nummer registreert."/>
                <StackPanel Name="PnlDetectScript">
                  <Label Content="Eigen detectiescript (PowerShell)"/>
                  <TextBox Name="TxtDetectScript" AcceptsReturn="True" AcceptsTab="True" FontFamily="Consolas" FontSize="12" Height="150"
                           VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
                  <TextBlock Style="{StaticResource Hint}" Text="Schrijf iets naar het scherm (Write-Output) als de app er staat; niets schrijven = niet gedetecteerd. Eindig met exit 0."/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                  <Button Name="BtnDetectTest" Content="Testen op deze pc"/>
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
                    <Button Name="BtnIcon" Content="Logo kiezen..."/>
                    <Button Name="BtnIconFromInstaller" Content="Uit installer halen"/>
                  </StackPanel>
                  <TextBlock Style="{StaticResource Hint}" Text=".ico, .png of .jpg (wordt omgezet). Liefst vierkant en minstens 256x256."/>
                </StackPanel>
                <StackPanel Grid.Column="3">
                  <Label Content="Kleur van kop en knop"/>
                  <DockPanel>
                    <Border Name="RectAccent" DockPanel.Dock="Left" Width="30" Height="28" CornerRadius="5" Margin="0,2,8,8" Background="#185FA5"/>
                    <TextBox Name="TxtAccent" Text="#185FA5"/>
                  </DockPanel>
                  <TextBlock Style="{StaticResource Hint}" Text="Vorm #RRGGBB. Standaard #185FA5 (blauw); leeg = standaard. Ander voorbeeld: #3B7A1E (groen)."/>
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
                          Background="White" BorderBrush="#D5DAE1" RowHeight="30">
                  <DataGrid.Columns>
                    <DataGridCheckBoxColumn Header="Hoofd" Width="50" Binding="{Binding Main, UpdateSourceTrigger=PropertyChanged}"/>
                    <DataGridTextColumn Header="Bestand" Width="2*" IsReadOnly="True" Binding="{Binding File}"/>
                    <DataGridTextColumn Header="Type" Width="60" IsReadOnly="True" Binding="{Binding Kind}"/>
                    <DataGridTextColumn Header="Parameters" Width="2*" FontFamily="Consolas" Binding="{Binding Args, UpdateSourceTrigger=PropertyChanged}"/>
                    <DataGridTextColumn Header="Geslaagd bij exitcode" Width="150" FontFamily="Consolas" Binding="{Binding Codes, UpdateSourceTrigger=PropertyChanged}"/>
                  </DataGrid.Columns>
                </DataGrid>
                <WrapPanel>
                  <Button Name="BtnCompAdd" Content="Toevoegen..." Margin="0,0,8,6" Style="{StaticResource Primary}"/>
                  <Button Name="BtnCompRemove" Content="Verwijderen" Margin="0,0,8,6"/>
                  <Button Name="BtnCompUp" Content="Omhoog" Margin="0,0,8,6"/>
                  <Button Name="BtnCompDown" Content="Omlaag" Margin="0,0,8,6"/>
                </WrapPanel>
                <TextBlock Name="TxtCompInfo" Style="{StaticResource Hint}" Margin="0,2,0,0" Text="Toevoegen: kies per bestand of het geïnstalleerd wordt (onderdeel), naar een map op de laptop gekopieerd wordt, of alleen meegaat. Installeren kan bij .exe, .msi, .msp, .ps1, .cmd/.bat en .reg; stille parameters worden voorgesteld."/>
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
                <Label Content="In het pakket"/>
                <TextBlock Style="{StaticResource Hint}" Text="Overzicht van alles wat meegaat in het .intunewin-pakket, met wat de installatie ermee doet. Toevoegen doe je bovenaan bij Onderdelen."/>
                <ListBox Name="LstFiles" Height="130" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal">
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
                <TextBlock TextWrapping="Wrap" Margin="0,0,0,4">Teksten voor deze app en versie. Laat een veld leeg voor de standaardtekst (grijs eronder). Staat de app nog niet op de laptop, dan gelden de teksten "Nieuwe installatie" (onderaan). Je kunt {AppName}, {Versie}, {Minuten} en {MaxUitstel} gebruiken; die worden automatisch ingevuld.</TextBlock>
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
              <StackPanel Name="PnlTexts"/>
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
                  <ComboBoxItem Tag="Werktijd" Content="Alleen binnen de gekozen tijden"/>
                  <ComboBoxItem Tag="BuitenWerktijd" Content="Alleen buiten de gekozen tijden (bijv. avond, nacht, weekend)"/>
                </ComboBox>
                <StackPanel Name="PnlWorkTime" Margin="0,0,0,4">
                  <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                    <Label Content="Tijden" VerticalAlignment="Center"/>
                    <Border Name="InfoTimes" Width="18" Height="18" CornerRadius="9" Background="#185FA5" Margin="8,4,0,0"
                            VerticalAlignment="Center" Cursor="Hand" ToolTipService.ShowDuration="60000" ToolTipService.InitialShowDelay="100">
                      <TextBlock Text="i" Foreground="White" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,-1,0,0"/>
                      <Border.ToolTip>
                        <ToolTip MaxWidth="380">
                          <StackPanel Margin="4">
                            <TextBlock FontWeight="SemiBold" Text="Meerdere tijdblokken invullen" Margin="0,0,0,6"/>
                            <TextBlock TextWrapping="Wrap" Text="Zet elk blok als van-tot neer en scheid de blokken met een komma."/>
                            <TextBlock TextWrapping="Wrap" Margin="0,8,0,2" FontWeight="SemiBold" Text="Voorbeelden"/>
                            <TextBlock FontFamily="Consolas" Text="08:00-17:00"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#555" Margin="0,0,0,4" Text="één blok: de hele werkdag"/>
                            <TextBlock FontFamily="Consolas" Text="08:00-09:00, 12:00-13:00, 16:00-17:00"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#555" Margin="0,0,0,4" Text="drie blokken: bij het inloggen, in de pauze en bij het afsluiten"/>
                            <TextBlock FontFamily="Consolas" Text="22:00-06:00"/>
                            <TextBlock TextWrapping="Wrap" Foreground="#555" Margin="0,0,0,4" Text="over middernacht: 's avonds en 's nachts"/>
                            <TextBlock TextWrapping="Wrap" Margin="0,6,0,0" Text="Gebruik 24-uurs tijden met een dubbele punt (08:00, niet 8.00). De eindtijd telt niet mee: bij 08:00-09:00 kan de popup om 08:59 nog komen, om 09:00 niet meer. Klik op het icoon voor meer uitleg."/>
                          </StackPanel>
                        </ToolTip>
                      </Border.ToolTip>
                    </Border>
                  </StackPanel>
                  <TextBox Name="TxtWorkHours" Width="340" HorizontalAlignment="Left"/>
                  <TextBlock Style="{StaticResource Hint}" Margin="0,-4,0,0" Text="Eén of meer blokken, gescheiden door komma's. Bijv. 08:00-17:00, of 09:00-10:00, 13:00-14:00. Over middernacht mag ook: 22:00-06:00."/>
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
                  <Image Name="ImgVerIcon" Width="40" Height="40" RenderOptions.BitmapScalingMode="HighQuality"/>
                </Border>
                <StackPanel>
                  <TextBlock Name="TxtVerTitle" FontSize="15" FontWeight="SemiBold" Text="Kies links een versie"/>
                  <TextBlock Name="TxtVerSub" Style="{StaticResource Hint}" Margin="0,2,0,8"/>
                  <StackPanel Orientation="Horizontal">
                    <ComboBox Name="CmbVerPreview" Width="190" Margin="0,0,8,0" SelectedIndex="0" VerticalAlignment="Center">
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
                    <Button Name="BtnVerPreview" Content="Voorbeeld van deze versie" VerticalAlignment="Center"/>
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
        <TextBox Name="TxtLog" Margin="12" Padding="12,10" BorderThickness="0" IsReadOnly="True" FontFamily="Consolas" FontSize="12" Background="#1E2430" Foreground="#E6E6E6"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
      </TabItem>
    </TabControl>
  </DockPanel>
</Window>
'@
[xml]$xaml = $xamlText.Replace('<!--THEMA-->', $ThemeXaml)

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
if (Test-Path -LiteralPath $BuilderIcon) { $img = Get-BuilderIconImage; if ($img) { $Window.Icon = $img; Write-StartLog "Venstericoon   : ingesteld ($($img.PixelWidth)x$($img.PixelHeight))" } else { Write-StartLog 'Venstericoon   : FOUT, icoon kon niet worden gelezen' } }
else { Write-StartLog "Venstericoon   : FOUT, $BuilderIcon niet gevonden" }
# Kop: grootste formaat uit het .ico (scherp), anders blijft het symbool staan
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
    # Snelkoppeling "AppUpdateKit Builder" in de kit-map (bij elke start bijgewerkt).
    # Het icoon wijst naar een lokale kopie (%ProgramData% of %LOCALAPPDATA%): Verkenner laat een icoon op een
    # netwerkschijf in een snelkoppeling vaak leeg. De variabele wordt op elke pc en voor elk account zelf ingevuld.
    $lnk    = Join-Path $KitRoot 'AppUpdateKit Builder.lnk'
    $target = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnkArgs = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $KitRoot 'AppUpdateKit-Builder.ps1')`""
    $icon   = if ($script:SharedIcon) { $script:SharedIcon } else { '%LOCALAPPDATA%\AppUpdateKit\Builder.ico' }
    try
    {
        if (-not ('AppKit.AumidShortcut' -as [type])) { throw 'hulpcode niet geladen' }
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
        catch { Write-StartLog "FOUT bij de snelkoppeling in de kit-map: $($_.Exception.Message)" }
    }
}
$ui = @{}
$xaml.SelectNodes('//*[@Name]') | ForEach-Object { $ui[$_.Name] = $Window.FindName($_.Name) }

$script:CurrentApp = $null     # AppId van de geladen app
$script:Info = @{ Kind = 'EXE'; ProductCode = '' }
$script:Components = New-Object 'System.Collections.ObjectModel.ObservableCollection[AppKit.Component]'
$ui.DgComponents.ItemsSource = $script:Components
$script:TextBoxes = @{}
$script:TextHints = @{}

function Set-Status([string]$Text) { $ui.TxtStatus.Text = $Text }
function Show-Error([string]$Text) { [void][System.Windows.MessageBox]::Show($Text, 'AppUpdateKit Builder', 'OK', 'Warning') }
function Show-Info([string]$Text) { [void][System.Windows.MessageBox]::Show($Text, 'AppUpdateKit Builder', 'OK', 'Information') }

$script:ErrorLog = Join-Path $KitRoot 'Builder-fouten.log'
function Write-BuilderError($ErrorRecord)
{
    # Fout in beeld tonen en wegschrijven, in plaats van dat de Builder zonder melding sluit
    if ($ErrorRecord -is [System.Management.Automation.RuntimeException] -and $ErrorRecord.ErrorRecord) { $ErrorRecord = $ErrorRecord.ErrorRecord }
    $msg = if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
        "$($ErrorRecord.Exception.Message)`r`n$($ErrorRecord.InvocationInfo.PositionMessage)`r`n$($ErrorRecord.ScriptStackTrace)"
    } else { "$ErrorRecord" }
    try { Add-Content -Path $script:ErrorLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n$msg`r`n" -ErrorAction Stop }
    catch { $script:ErrorLog = Join-Path ([System.IO.Path]::GetTempPath()) 'AppUpdateKit-Builder-fouten.log'; Add-Content -Path $script:ErrorLog -Value $msg -ErrorAction SilentlyContinue }
    $first = ($msg -split "`r?`n")[0]
    Show-Error "Er ging iets mis:`n`n$first`n`nDe details staan in:`n$($script:ErrorLog)"
    Set-Status "Fout: $first"
}

# Vangnet: elke onverwachte fout in een knop of timer geeft een melding in plaats van af te sluiten
$Window.Dispatcher.Add_UnhandledException({
    param($s, $e)
    $e.Handled = $true
    Write-BuilderError $e.Exception
})
function Get-AppFolder { if ($script:CurrentApp) { Join-Path $AppsRoot $script:CurrentApp } }

function Get-OutputRoot
{
    # Waar het pakket van deze versie komt: de map bij 'Pakket opslaan in', anders Output\<AppId>\<versie> in de kit
    $o = $ui.TxtOutputFolder.Text.Trim()
    $kitOut = Join-Path $KitRoot 'Output'
    $kitVersion = Join-Path (Join-Path $kitOut $script:CurrentApp) $ui.TxtVersion.Text.Trim()
    if (-not $o) { return $kitVersion }
    $p = [Environment]::ExpandEnvironmentVariables($o).TrimEnd('\')
    # In de Output-map van de kit: gewone indeling Output\<AppId>\<versie> (zelfde regel als 2-Bouw-pakket.ps1)
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
    # Bestandskeuzevenster openen in de map van de huidige installer, anders in de standaardmap (_Kit\Instellingen.psd1).
    # Bij een nieuwe installer (een update) in de map 'versies', zodat alle versies naast elkaar staan.
    $candidates = @()
    $o = $ui.TxtOutputFolder.Text.Trim()
    if ($o)
    {
        $versionDir = Split-Path $o -Parent
        $versionsDir = Split-Path $versionDir -Parent
        if ($NewInstaller -and $versionsDir -and (Split-Path $versionsDir -Leaf) -ieq 'versies') { $candidates += $versionsDir }
        $candidates += (Join-Path $versionDir 'source')   # daar staan meestal de installers
        $candidates += $versionDir
    }
    if ($KitSettings.InstallerMap) { $candidates += $KitSettings.InstallerMap }
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { $Dialog.InitialDirectory = $c; return } }
}

# Tekstvelden opbouwen
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
    $std = Get-StandardTexts
    foreach ($k in $TextKeys) { $script:TextHints[$k].Text = "Standaard: $($std[$k])" }
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
}

function Add-ComponentFile([string]$Source, [bool]$AsMain = $false)
{
    # Kopieert het bestand naar de app-map en voegt het toe als onderdeel; geeft de info terug
    $dir = Get-AppFolder
    $name = [System.IO.Path]::GetFileName($Source)
    $dest = Join-Path $dir $name
    if ($Source -ne $dest) { Set-Status "Kopieren van $name..."; Copy-Item -LiteralPath $Source -Destination $dest -Force }
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

function Get-FileUse([string]$Name)
{
    # Wat de installatie met een bestand uit de app-map doet (voor de lijst "Bestanden in het pakket")
    if (@($script:Components | ForEach-Object { $_.File }) -contains $Name) { return 'onderdeel (tabblad 2)' }
    $steps = "$($ui.TxtPreInstall.Text)`n$($ui.TxtPostInstall.Text)"
    $m = [regex]::Match($steps, 'copy /Y "' + [regex]::Escape($Name) + '" "([^"]+)"', 'IgnoreCase')
    if ($m.Success) { return "kopiëren naar $($m.Groups[1].Value.TrimEnd('\'))" }
    if ($steps -match [regex]::Escape($Name)) { return 'gebruikt in extra stappen' }
    if ($Name -in @('app.ico', 'logo.svg')) { return 'logo' }
    return 'nog niet gebruikt in een stap'
}

function Update-FileList
{
    $ui.LstFiles.Items.Clear()
    $dir = Get-AppFolder
    if (-not $dir) { return }
    $skip = @('app.psd1', 'install-app.cmd', 'uninstall-app.cmd')
    Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -notin $skip } | Sort-Object Name | ForEach-Object {
        $size = if ($_.Length -ge 1MB) { '{0:N0} MB' -f ($_.Length / 1MB) } else { '{0:N0} kB' -f [math]::Max(1, $_.Length / 1KB) }
        [void]$ui.LstFiles.Items.Add("$($_.Name)   ($size)   ->  $(Get-FileUse $_.Name)")
    }
}

function Test-InstallerFile([string]$Name)
{
    return ([System.IO.Path]::GetExtension($Name).ToLower() -in @('.exe', '.msi', '.msp', '.ps1', '.cmd', '.bat', '.reg'))
}

function Remove-CopyStep([string]$Name, [string]$Text)
{
    # Haalt het blok "rem Bestand: <naam> kopieren naar ..." (plus de md- en copy-regel) uit de extra stappen
    $out = New-Object System.Collections.Generic.List[string]
    $lines = @("$Text" -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++)
    {
        if ($lines[$i] -like "rem Bestand: $Name kopieren naar *")
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
    # Zet een kopieerstap in "Extra stappen na de onderdelen" (vervangt een eerdere stap voor hetzelfde bestand)
    $t = $Target.Trim().TrimEnd('\')
    $block = "rem Bestand: $Name kopieren naar $t`r`nif not exist `"$t\`" md `"$t`"`r`ncopy /Y `"$Name`" `"$t\`" >nul"
    $cur = Remove-CopyStep $Name $ui.TxtPostInstall.Text
    $ui.TxtPostInstall.Text = if ($cur) { "$cur`r`n$block" } else { $block }
}

$FileActionXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Bestand toevoegen" Width="580" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" FontSize="13" Background="#F4F6F9" Foreground="#1F2937" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
<!--THEMA-->
  </Window.Resources>
  <StackPanel Margin="20">
    <TextBlock Name="TxtTitle" FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <TextBlock Style="{StaticResource Hint}" Margin="0,4,0,14" Text="Het bestand gaat mee in het pakket. Kies wat de installatie ermee doet; de Builder zet de stap klaar in tabblad 2."/>
    <Border Style="{StaticResource Card}" Margin="0,0,0,12">
      <StackPanel>
        <RadioButton Name="OptComp" GroupName="Actie" Content="Installeren als onderdeel (met eigen parameters en exitcodes)" Margin="0,0,0,10"/>
        <RadioButton Name="OptCopy" GroupName="Actie" Content="Kopiëren naar een map op de laptop"/>
        <TextBox Name="TxtTarget" Margin="22,6,0,4"/>
        <TextBlock Style="{StaticResource Hint}" Margin="22,0,0,10" Text="Bijv. %ProgramData%\Mijn app of %ProgramFiles%\Mijn app. De installatie draait als SYSTEM: %APPDATA% en %USERPROFILE% wijzen dan niet naar de gebruiker."/>
        <RadioButton Name="OptKeep" GroupName="Actie" Content="Alleen meenemen in het pakket (ik gebruik het zelf in een extra stap)"/>
      </StackPanel>
    </Border>
    <CheckBox Name="ChkAll" Margin="0,0,0,12"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
      <Button Name="BtnCancel" Content="Overslaan"/>
      <Button Name="BtnOk" Content="Toevoegen" Style="{StaticResource Primary}" Margin="0"/>
    </StackPanel>
  </StackPanel>
</Window>
'@

function Show-FileActionDialog([string]$Name, [int]$Others)
{
    # Vraagt wat er met een toegevoegd bestand moet gebeuren. Geeft @{ Action; Target; All } terug, of $null bij Overslaan.
    [xml]$x = $FileActionXaml.Replace('<!--THEMA-->', $ThemeXaml)
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $w.Owner = $Window; $w.Icon = $Window.Icon
    $f = @{}
    foreach ($n in 'TxtTitle', 'OptComp', 'OptCopy', 'OptKeep', 'TxtTarget', 'ChkAll', 'BtnOk', 'BtnCancel') { $f[$n] = $w.FindName($n) }
    $f.TxtTitle.Text = "Wat moet de installatie doen met $Name?"
    $isInstaller = Test-InstallerFile $Name
    $f.OptComp.IsEnabled = $isInstaller
    if (-not $isInstaller) { $f.OptComp.Content = 'Installeren als onderdeel (alleen voor .exe, .msi, .msp, .ps1, .cmd, .bat en .reg)' }
    if ([System.IO.Path]::GetExtension($Name).ToLower() -in @('.exe', '.msi', '.msp')) { $f.OptComp.IsChecked = $true } else { $f.OptCopy.IsChecked = $true }
    $appName = if ($ui.TxtAppName.Text.Trim()) { $ui.TxtAppName.Text.Trim() } else { "$script:CurrentApp" }
    $f.TxtTarget.Text = "%ProgramData%\$appName"
    $f.TxtTarget.IsEnabled = [bool]$f.OptCopy.IsChecked
    $f.OptCopy.Add_Checked({ $f.TxtTarget.IsEnabled = $true })
    $f.OptCopy.Add_Unchecked({ $f.TxtTarget.IsEnabled = $false })
    if ($Others -gt 0) { $f.ChkAll.Content = "Hetzelfde doen met de andere $Others gekozen bestand$(if ($Others -gt 1) { 'en' })" }
    else { $f.ChkAll.Visibility = 'Collapsed' }
    $script:FileActionResult = $null
    $f.BtnOk.Add_Click({
        $action = if ($f.OptComp.IsChecked) { 'Onderdeel' } elseif ($f.OptCopy.IsChecked) { 'Kopieren' } else { 'Meenemen' }
        if ($action -eq 'Kopieren' -and -not $f.TxtTarget.Text.Trim())
        {
            [void][System.Windows.MessageBox]::Show($w, 'Vul de map in waar het bestand naartoe moet.', 'Bestand toevoegen', 'OK', 'Warning'); return
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
            HasBron   = $v.HasBron
            BuiltText = $v.Built.ToString('dd-MM-yyyy HH:mm')
            PkgText   = if ($v.HasPkg) { "$($v.SizeMB) MB" } else { 'nee' }
            BronText  = if ($v.HasBron) { 'ja' } else { 'nee' }
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
        $ui.TxtVerTitle.Text = 'Kies links een versie'
        $ui.TxtVerSub.Text = ''
        foreach ($n in 'TxtVerSummary', 'TxtVerInstall', 'TxtVerTexts', 'TxtVerBuildInfo') { $ui[$n].Text = '' }
        return
    }
    $det = Get-VersionDetails $v.Path
    $script:SelectedVersion = $det
    $ui.PnlVerDetails.IsEnabled = $true
    $ui.TxtVerTitle.Text = "$(if ($det.Data) { $det.Data.AppName } else { $script:CurrentApp }) $($v.Version)"
    $ui.TxtVerSub.Text = "Gebouwd op $($v.BuiltText)  |  install.intunewin: $($v.PkgText)" +
                         $(if ($v.IsArchive) { '  |  eerdere build, later opnieuw gebouwd' } else { '' }) +
                         $(if (-not $v.HasInstallers) { '  |  installers niet bewaard (oude build)' } else { '' })

    $summary = $det.Summary
    if ($det.Data)
    {
        $installNow = $ui.TxtInstallCmd.Text
        $installOld = if (Test-Path (Join-Path $v.Path 'Bron\install-app.cmd')) { [System.IO.File]::ReadAllText((Join-Path $v.Path 'Bron\install-app.cmd')) } else { '' }
        $diff = @(Compare-AppData $det.Data (Read-Form) $installOld $installNow)
        $summary += "`r`n`r`n---------- Verschil met wat nu in de Builder staat ----------`r`n"
        $summary += if ($diff.Count) { ($diff | ForEach-Object { "- $_" }) -join "`r`n" } else { 'Geen verschillen.' }
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
    if (-not $v) { Show-Error 'Selecteer eerst een versie in de lijst.' }
    return $v
}

function Show-StandardTextsEditor
{
    # Klein venster om _Kit\Standaardteksten.psd1 te bewerken (geldt voor alle apps)
    [xml]$x = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Standaardteksten voor alle apps" Width="760" Height="680" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" FontSize="13" Background="#F4F6F9" Foreground="#1F2937" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
<!--THEMA-->
  </Window.Resources>
  <DockPanel Margin="16">
    <TextBlock DockPanel.Dock="Top" TextWrapping="Wrap" Margin="0,0,0,10">Deze teksten gebruikt elke app, tenzij je bij een app in tabblad 3 een eigen tekst invult. Je kunt {AppName}, {Versie}, {Minuten} en {MaxUitstel} gebruiken. Bouw de pakketten daarna opnieuw.</TextBlock>
    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
      <Button Name="BtnReset" Content="Ingebouwde teksten terugzetten"/>
      <Button Name="BtnCancel" Content="Annuleren"/>
      <Button Name="BtnOk" Content="Opslaan" Style="{StaticResource Primary}" Margin="0"/>
    </StackPanel>
    <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel Name="Pnl"/></ScrollViewer>
  </DockPanel>
</Window>
'@
    $x = [xml]$x.OuterXml.Replace('<!--THEMA-->', $ThemeXaml)
    $w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $x))
    $w.Owner = $Window
    $w.Icon = $Window.Icon
    $boxes = @{}
    $std = Get-StandardTexts
    foreach ($k in $TextKeys)
    {
        $l = New-Object System.Windows.Controls.Label; $l.Content = $TextLabels[$k]; $l.FontWeight = 'SemiBold'; $l.Padding = '0,6,0,2'
        $b = New-Object System.Windows.Controls.TextBox; $b.Text = $std[$k]; $b.TextWrapping = 'Wrap'; $b.Padding = '6,4'
        if ($k -like '*Message' -or $k -eq 'ForcedInfo') { $b.MinHeight = 48 }
        [void]$w.FindName('Pnl').Children.Add($l); [void]$w.FindName('Pnl').Children.Add($b)
        $boxes[$k] = $b
    }
    $w.FindName('BtnReset').Add_Click({ foreach ($k in $TextKeys) { $boxes[$k].Text = $BuiltinTexts[$k] } })
    $w.FindName('BtnCancel').Add_Click({ $w.Close() })
    $w.FindName('BtnOk').Add_Click({
        $texts = @{}
        foreach ($k in $TextKeys) { $texts[$k] = $boxes[$k].Text.Trim() }
        [System.IO.File]::WriteAllText($StandardTextsPath, (ConvertTo-StandardTextsPsd1 $texts), (New-Object System.Text.UTF8Encoding $true))
        Update-TextHints
        Set-Status 'Standaardteksten opgeslagen. Bouw de pakketten opnieuw om ze te gebruiken.'
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
        'Werktijd'       { 'De popup en de installatie komen alleen op de gekozen dagen, binnen een van de tijdblokken. Daarbuiten wacht de update tot het volgende blok.' }
        'BuitenWerktijd' { "De update komt alleen buiten de tijdblokken en op de dagen die niet zijn aangevinkt, bijvoorbeeld 's avonds, 's nachts en in het weekend. Let op: laptops staan dan vaak uit of slapen. De update komt dan pas als het apparaat buiten werktijd aan staat." }
        default          { 'De popup kan op elk moment van de dag komen.' }
    }
}

function Update-DetectPanels
{
    $m = [string]$ui.CmbDetect.SelectedItem.Tag
    $ui.PnlDetectFile.Visibility    = if ($m -eq 'Bestand') { 'Visible' } else { 'Collapsed' }
    $ui.PnlDetectReg.Visibility     = if ($m -eq 'Register') { 'Visible' } else { 'Collapsed' }
    $ui.PnlDetectScript.Visibility  = if ($m -eq 'Script') { 'Visible' } else { 'Collapsed' }
    $ver = if ($m -eq 'Script') { 'Collapsed' } else { 'Visible' }
    $ui.PnlDetectVersion.Visibility = $ver; $ui.TxtDetectVersionHint.Visibility = $ver
    $ui.TxtDetectVersion.IsEnabled  = -not $ui.ChkDetectAnyVersion.IsChecked
    $ui.TxtDetectHint.Text = switch ($m)
    {
        'Bestand'  { 'Gedetecteerd als het bestand bestaat en de bestandsversie minimaal de versie hieronder is.' }
        'Register' { 'Gedetecteerd als de registersleutel (en waarde) bestaat en de waarde minimaal de versie hieronder is.' }
        'Script'   { 'Je eigen PowerShell-script wordt het detectiescript voor Intune.' }
        default    { "Gedetecteerd als in Apps en onderdelen een app staat waarvan de naam begint met '$($ui.TxtDetectName.Text.Trim())' (veld hierboven), met minimaal de versie hieronder." }
    }
    $ui.TxtDetectResult.Text = ''
}

function Set-DetectionFromMsi($Info)
{
    # Bij een MSI de detectie invullen: de uninstall-sleutel van de productcode, DisplayVersion, minimaal de ProductVersion
    if (-not $Info.ProductCode) { return }
    $key = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($Info.ProductCode)"
    $m = [string]$ui.CmbDetect.SelectedItem.Tag
    $isDefault    = $m -eq 'AppsEnOnderdelen' -and -not $ui.TxtDetectVersion.Text.Trim() -and -not $ui.ChkDetectAnyVersion.IsChecked
    $isEarlierMsi = $m -eq 'Register' -and $ui.TxtDetectRegKey.Text.Trim() -match '\\Uninstall\\\{[0-9A-Fa-f-]{36}\}\\?$' -and $ui.TxtDetectRegValue.Text.Trim() -eq 'DisplayVersion'
    if ($ui.TxtDetectRegKey.Text.Trim().TrimEnd('\') -eq $key -and $m -eq 'Register') { return }
    if (-not ($isDefault -or $isEarlierMsi))
    {
        $q = "Uit de MSI: productcode $($Info.ProductCode), versie $($Info.Version).`n`n" +
             "Detectie instellen op:`n$key`nwaarde DisplayVersion, minimaal $($Info.Version)?`n`nJe huidige detectie-instelling wordt dan vervangen."
        if ([System.Windows.MessageBox]::Show($q, 'Detectie uit de MSI', 'YesNo', 'Question') -ne 'Yes') { return }
    }
    Set-ComboByTag $ui.CmbDetect 'Register'
    $ui.TxtDetectRegKey.Text   = $key
    $ui.TxtDetectRegValue.Text = 'DisplayVersion'
    $ui.ChkDetectAnyVersion.IsChecked = $false
    $ui.TxtDetectVersion.Text  = ''        # leeg = de versie van het pakket (= ProductVersion uit de MSI)
    Update-DetectPanels
    $ui.TxtDetectResult.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#555555')
    $ui.TxtDetectResult.Text = "  Detectie ingevuld uit de MSI (productcode $($Info.ProductCode)). Klik op Testen op deze pc als deze versie hier al geïnstalleerd is."
}

function Update-RestartPanel
{
    $on = [string]$ui.CmbRestart.SelectedItem.Tag -ne 'Nooit'
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
        AccentColor           = if ($ui.TxtAccent.Text.Trim()) { $ui.TxtAccent.Text.Trim() } else { '#185FA5' }   # leeg = standaardkleur
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
    catch { Show-Error "app.psd1 van $AppId kan niet gelezen worden:`n$($_.Exception.Message)"; return }

    $script:CurrentApp = $AppId; $script:LastInstallerPath = $null   # andere app: startmap opnieuw bepalen
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
    Set-ComboByTag $ui.CmbWindow $(if ($d.InstallWindow) { $d.InstallWindow } else { 'Altijd' })
    Set-ComboByTag $ui.CmbNoUser $(if ($d.NoUserAction) { $d.NoUserAction } else { 'Installeren' })
    $ui.TxtWorkHours.Text = if ($d.WorkHours) { ("$($d.WorkHours)" -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ', ' } else { '08:00-17:00' }
    $dayText = if ($d.WorkDays) { "$($d.WorkDays)".ToLower() } else { 'ma,di,wo,do,vr' }
    foreach ($k in $DayBoxes.Keys) { $ui[$DayBoxes[$k]].IsChecked = $dayText -match "(^|[,; ])$k" }
    $idle = [int]("0$($d.IdleMinutes)")
    $ui.ChkIdle.IsChecked = $idle -gt 0
    $ui.TxtIdleMinutes.Text = if ($idle -gt 0) { $idle } else { 30 }
    Update-WindowHint
    Set-ComboByTag $ui.CmbRestart $(if ($d.RestartMode) { $d.RestartMode } else { 'Nooit' })
    Set-ComboByTag $ui.CmbDetect $(if ($d.DetectionMethod) { $d.DetectionMethod } else { 'AppsEnOnderdelen' })
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

    # Onderdelen en extra stappen
    $script:Components.Clear()
    foreach ($c in @($d.Components)) { if ($c) { $script:Components.Add((New-ComponentRow $c)) } }
    $ui.TxtPreInstall.Text  = "$($d.PreInstall)"
    $ui.TxtPostInstall.Text = "$($d.PostInstall)"
    $isTemplate = $ui.TxtInstallCmd.Text -match 'MijnApp-Setup\.exe'
    # Automatisch maken alleen als er onderdelen zijn (of bij een nieuwe app uit het sjabloon);
    # een met de hand geschreven install-app.cmd zonder onderdelen wordt nooit overschreven.
    $auto = if ($null -ne $d.AutoInstallSteps) { [bool]$d.AutoInstallSteps } else { $script:Components.Count -gt 0 }
    if ($script:Components.Count -eq 0) { $auto = $isTemplate }
    $ui.ChkAutoSteps.IsChecked = $auto
    Update-InstallPreview

    # Hoofdinstaller: het hoofdonderdeel, anders de grootste .exe/.msi in de map
    $main = Get-MainComponent
    $inst = if ($main -and (Test-Path (Join-Path $dir $main.File))) { Get-Item (Join-Path $dir $main.File) }
            else { Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Sort-Object Length -Descending | Select-Object -First 1 }
    $ui.TxtInstaller.Text = if ($inst) { $inst.Name } else { '' }
    $ui.TxtInstallerInfo.Text = if ($inst) { 'Kies de installer opnieuw om naam, versie en parameters opnieuw te laten herkennen.' } else { 'Nog geen installer gekozen.' }
    $script:Info = @{ Kind = if ($inst -and $inst.Extension -eq '.msi') { 'MSI' } else { 'EXE' }; ProductCode = '' }

    Update-FileList; Update-IconPreview; Update-AccentPreview; Update-VersionList
    $ui.BtnOpenOutput.IsEnabled = (Test-Path (Join-Path (Join-Path $KitRoot 'Output') $AppId)) -or ($d.OutputFolder -and (Test-Path "$($d.OutputFolder)"))
    Set-Status "Geladen: $AppId"
}

function Save-App
{
    if (-not $script:CurrentApp) { return $false }
    Update-InstallPreview
    $d = Read-Form
    $errors = Test-AppData $d
    if ($errors) { Show-Error ("Controleer de volgende punten:`n`n- " + ($errors -join "`n- ")); return $false }

    $dir = Get-AppFolder
    [System.IO.File]::WriteAllText((Join-Path $dir 'app.psd1'), (ConvertTo-Psd1Text $d), (New-Object System.Text.UTF8Encoding $true))

    foreach ($pair in @(@('install-app.cmd', $ui.TxtInstallCmd.Text), @('uninstall-app.cmd', $ui.TxtUninstallCmd.Text)))
    {
        $txt = ($pair[1] -replace "`r?`n", "`r`n")
        if ($txt -match '[^\x00-\x7F]')
        {
            Show-Error "$($pair[0]) bevat speciale tekens (zoals é of ï). Die geeft cmd niet goed door; zet zulke teksten in tabblad 3."
        }
        [System.IO.File]::WriteAllText((Join-Path $dir $pair[0]), $txt, [System.Text.Encoding]::Default)
    }
    Set-Status "Opgeslagen: Apps\$($script:CurrentApp)"
    return $true
}

function Show-Preview([string]$Kind, [hashtable]$Data = $null, $Std = $null, [string]$IconPath = '')
{
    # Zonder -Data: wat nu in het formulier staat. Met -Data: een eerder gebouwde versie.
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
        LaterHint     = 'morgen'
    }
    switch ($Kind)
    {
        'consent' { $cfg.Mode = 'consent'; $cfg.Remaining = 3; $cfg.TimeoutSeconds = 900; $cfg.IsNew = $newMode; if ($newMode) { $cfg.NowText = 'Nu installeren' }
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'ConsentSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'ConsentMessage' $d $Std }
        'last'    { $cfg.Mode = 'consent'; $cfg.Remaining = 1; $cfg.TimeoutSeconds = 900; $cfg.IsNew = $newMode; if ($newMode) { $cfg.NowText = 'Nu installeren' }
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'ConsentSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'ConsentMessage' $d $Std }
        'forced'  { $cfg.Mode = 'forced'; $cfg.TimeoutSeconds = [math]::Max(60, $cfg.ForcedMinutes * 60)
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'ForcedSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'ForcedMessage' $d $Std
                    $cfg.InfoText = Get-EffectiveText -New:$newMode 'ForcedInfo' $d $Std }
        'restart' { $cfg.Mode = 'consent'; $cfg.TimeoutSeconds = 900; $cfg.NowText = 'Nu herstarten'; $cfg.LaterText = 'Later'
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'RestartSubHeading' $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'RestartMessage' $d $Std
                    $rem = [int]("0$($d.RestartReminderMinutes)"); if (-not $rem) { $rem = 60 }
                    $cfg.InfoOverride = "Kies je Later, dan vragen we het $(if ($rem % 60 -eq 0) { "over $($rem / 60) uur" } else { "over $rem minuten" }) opnieuw."
                    $cfg.TimeoutText = 'Maak je geen keuze, dan vragen we het later opnieuw ({tijd}).' }
        'restartforced' {
                    $wm = [int]("0$($d.RestartWarningMinutes)"); if (-not $wm) { $wm = 15 }
                    $dw = @{} + $d; $dw.ForcedDelayMinutes = $wm      # {Minuten} = waarschuwingstijd voor de herstart
                    $cfg.Mode = 'forced'; $cfg.TimeoutSeconds = $wm * 60; $cfg.NowText = 'Nu herstarten'; $cfg.InfoWarning = $true
                    $cfg.InfoOverride = 'Klaar om te herstarten? Sla je werk op en klik op Nu herstarten.'
                    $cfg.CountdownText = 'De laptop herstart automatisch over {tijd}.'
                    $cfg.SubHeading = Get-EffectiveText -New:$newMode 'RestartForcedSubHeading' $dw $Std; $cfg.Message = Get-EffectiveText -New:$newMode 'RestartForcedMessage' $dw $Std }
        default   { $cfg.Mode = 'toast'; $cfg.AutoCloseSeconds = 30
                    $cfg.Type = @{ uninstalling = 'installing'; uninstalled = 'success' }[$Kind]; if (-not $cfg.Type) { $cfg.Type = $Kind }
                    $prefix = @{ installing = 'Installing'; success = 'Success'; error = 'Error'; uninstalling = 'Uninstalling'; uninstalled = 'Uninstalled' }[$Kind]
                    $cfg.Heading = Get-EffectiveText -New:$newMode "$($prefix)Heading" $d $Std; $cfg.Message = Get-EffectiveText -New:$newMode "$($prefix)Message" $d $Std }
    }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "AppUI_preview_$(Get-Random).json"
    [System.IO.File]::WriteAllText($tmp, ($cfg | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $KitDir 'AppUI.ps1')`"", '-ConfigPath', "`"$tmp`"")
    Set-Status 'Voorbeeld geopend (rechtsonder in je scherm). Sluiten via de knoppen; er wordt niets geïnstalleerd.'
}

function Get-IntuneWinAppUtil
{
    $local = Join-Path $KitRoot 'IntuneWinAppUtil.exe'
    if (Test-Path $local) { return $local }
    $cmd = Get-Command IntuneWinAppUtil.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $r = [System.Windows.MessageBox]::Show(
        "IntuneWinAppUtil.exe (van Microsoft) is nodig om het .intunewin-pakket te maken, maar staat nog niet naast de Builder.`n`nNu downloaden van GitHub (microsoft/Microsoft-Win32-Content-Prep-Tool)?",
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
        Show-Error "Downloaden lukte niet: $($_.Exception.Message)`n`nDownload IntuneWinAppUtil.exe handmatig en zet hem in $KitRoot."
        return $null
    }
}

$script:BuildProc = $null
$buildTimer = New-Object System.Windows.Threading.DispatcherTimer
$buildTimer.Interval = [TimeSpan]::FromMilliseconds(500)
function Read-SharedText([string]$Path)
{
    # Lezen terwijl het bouwscript nog in het bestand schrijft (ReadAllText zou dan weigeren)
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
            Set-Status "Klaar: $(Join-Path $out 'install.intunewin')"
            $r = [System.Windows.MessageBox]::Show("Het pakket is klaar:`n$($pkgFile.FullName)`n`nIn dezelfde map staan Intune\Requirement.ps1, Intune\Detection.ps1, Intune-instellingen.txt en Bouwinfo.txt.`n`nMap openen?", 'Pakket klaar', 'YesNo', 'Information')
            if ($r -eq 'Yes') { Start-Process explorer.exe $out }
        }
        elseif ($script:BuildProc.ExitCode -eq 0)
        {
            Set-Status 'Bestanden gemaakt, maar geen .intunewin (zie Resultaat).'
            $ui.BtnOpenOutput.IsEnabled = $true
        }
        else
        {
            Set-Status 'Bouwen mislukt: zie het tabblad Resultaat.'
            Show-Error 'Het pakket kon niet gebouwd worden. In het tabblad Resultaat staat wat er mis is.'
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
    # Voor het bouwen: pakketmap verplicht; bestaat hij nog niet, dan aanbieden om hem aan te maken
    $o = $ui.TxtOutputFolder.Text.Trim()
    if (-not $o)
    {
        Show-Error "Kies eerst in tabblad 1 bij 'Pakket opslaan in' de map voor het pakket, bijv. ...\versies\2.4.0\intune-package."
        $ui.Tabs.SelectedIndex = 0
        return $false
    }
    $path = [Environment]::ExpandEnvironmentVariables($o).TrimEnd('\')
    if (Test-InAppsFolder $path)
    {
        Show-Error "Pakket opslaan in ligt in de app-map:`n`n$path`n`nKies in tabblad 1 een map buiten Apps\, bijv. de versiemap naast de installer."
        $ui.Tabs.SelectedIndex = 0
        return $false
    }
    if (Test-Path -LiteralPath $path -PathType Container) { return $true }
    # Schijf of netwerkshare bereikbaar? (I:\ of \\server\share)
    $root = if ($path -match '^(\\\\[^\\]+\\[^\\]+)') { $Matches[1] } else { [System.IO.Path]::GetPathRoot($path) }
    if (-not $root -or -not (Test-Path -LiteralPath $root))
    {
        Show-Error "De schijf of share $root is niet bereikbaar. Is de schijf gekoppeld?`n`nPakket opslaan in: $path"
        return $false
    }
    $q = "De map voor het pakket bestaat nog niet:`n`n$path`n`nNu aanmaken?"
    if ([System.Windows.MessageBox]::Show($q, 'Map aanmaken', 'YesNo', 'Question') -ne 'Yes') { return $false }
    try { New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop | Out-Null; return $true }
    catch { Show-Error "De map kon niet worden aangemaakt: $($_.Exception.Message)"; return $false }
}

function Start-Build
{
    if (-not (Save-App)) { return }
    if (-not (Confirm-OutputFolder)) { return }
    if (-not (Get-IntuneWinAppUtil)) { Set-Status 'Zonder IntuneWinAppUtil.exe worden alleen de bestanden gemaakt.' }

    $script:BuildVersion = $ui.TxtVersion.Text.Trim()
    $script:BuildRoot = Get-OutputRoot
    $kitCopy = Join-Path (Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp) $script:BuildVersion
    if ((Test-Path (Join-Path $script:BuildRoot 'Bouwinfo.txt')) -or ((Test-Path $kitCopy) -and $script:BuildRoot -eq $kitCopy))
    {
        $q = "Versie $($script:BuildVersion) is al eens gebouwd.`n`nOpnieuw bouwen? De huidige build van deze versie wordt bewaard in het archief (zichtbaar in tabblad Versies als 'vervangen').`n`nWil je juist een nieuwe versie maken? Kies Nee en pas eerst het versienummer aan of kies de nieuwe installer."
        if ([System.Windows.MessageBox]::Show($q, 'Versie bestaat al', 'YesNo', 'Question') -ne 'Yes') { return }
    }
    $script:BuildLog = Join-Path ([System.IO.Path]::GetTempPath()) "AppUpdateKit_build_$(Get-Random).log"
    $script:BuildStart = Get-Date
    $ui.TxtLog.Text = ''
    $ui.TabLog.IsSelected = $true
    $ui.BtnBuild.IsEnabled = $false
    Set-Status "Bezig met bouwen van $($script:CurrentApp)... (grote installers kunnen even duren)"

    $script:BuildProc = Start-Process -FilePath 'powershell.exe' -NoNewWindow -PassThru `
        -RedirectStandardOutput $script:BuildLog -RedirectStandardError "$($script:BuildLog).err" `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $KitRoot '2-Bouw-pakket.ps1')`"", '-App', $script:CurrentApp)
    # Handle vasthouden: anders geeft Windows PowerShell 5.1 na afloop geen ExitCode terug
    $null = $script:BuildProc.Handle
    $buildTimer.Start()
}

#region Gebeurtenissen
$ui.LstApps.Add_SelectionChanged({ if ($ui.LstApps.SelectedItem) { Import-App ([string]$ui.LstApps.SelectedItem) } })

$ui.BtnNewApp.Add_Click({
    $id = [Microsoft.VisualBasic.Interaction]::InputBox("AppId van de nieuwe app (alleen letters, cijfers, - en _), bijv. 7Zip:", 'Nieuwe app', '')
    if (-not $id) { return }
    if ($id -notmatch '^[A-Za-z0-9_-]+$') { Show-Error 'Alleen letters, cijfers, - en _ (geen spaties).'; return }
    $dir = Join-Path $AppsRoot $id
    if (Test-Path $dir) { Show-Error "Apps\$id bestaat al."; return }
    New-Item $dir -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path (Join-Path $KitRoot '_Template') '*') $dir
    $d = Read-AppPsd1 (Join-Path $dir 'app.psd1')
    $d.AppId = $id; $d.AppName = $id; $d.DetectName = $id; $d.Processes = @()
    [System.IO.File]::WriteAllText((Join-Path $dir 'app.psd1'), (ConvertTo-Psd1Text $d), (New-Object System.Text.UTF8Encoding $true))
    Update-AppList
    $ui.LstApps.SelectedItem = $id
    Set-Status "Nieuwe app $id aangemaakt. Begin met het kiezen van de installer."
})

$ui.BtnInstaller.Add_Click({
    # Tabblad 1: de installer van de app zelf = het hoofdonderdeel
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Installers (*.exe;*.msi)|*.exe;*.msi'
    Set-StartFolder $dlg -NewInstaller
    if (-not $dlg.ShowDialog()) { return }
    $script:LastInstallerPath = $dlg.FileName   # startpunt voor 'Kiezen...' bij 'Pakket opslaan in'
    $src = $dlg.FileName; $dir = Get-AppFolder
    $name = [System.IO.Path]::GetFileName($src)

    # Vorige installer (oud hoofdonderdeel) en losse installers die geen onderdeel zijn: opruimen?
    $oldMain = $script:Components | Where-Object { $_.Main } | Select-Object -First 1
    $oldIndex = if ($oldMain) { $script:Components.IndexOf($oldMain) } else { -1 }
    $usedFiles = @($script:Components | Where-Object { -not $_.Main } | ForEach-Object { $_.File })
    $old = @(Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' -and $_.Name -ne $name -and $_.Name -notin $usedFiles })
    if ($old.Count -gt 0)
    {
        $list = ($old | ForEach-Object { "  - $($_.Name)" }) -join "`n"
        $q = "In de app-map staan nog deze installers:`n$list`n`nZijn dat oude versies? Kies Ja om ze te verwijderen, zodat ze niet in het nieuwe pakket komen.`n(Andere onderdelen uit tabblad 2 blijven gewoon staan.)"
        if ([System.Windows.MessageBox]::Show($q, 'Oude installers opruimen', 'YesNo', 'Question') -eq 'Yes')
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
    $ui.TxtInstallerInfo.Text = "Herkend: $($info.Kind)$(if ($info.ProductName) { ' - ' + $info.ProductName })$(if ($info.Version) { ' ' + $info.Version }). $($info.Note) Parameters en extra onderdelen: tabblad 2."
    if ($info.Version) { $ui.TxtVersion.Text = $info.Version }
    if ($info.ProductName)
    {
        if (-not $ui.TxtAppName.Text -or $ui.TxtAppName.Text -eq $script:CurrentApp) { $ui.TxtAppName.Text = $info.ProductName }
        if (-not $ui.TxtDetectName.Text -or $ui.TxtDetectName.Text -eq $script:CurrentApp) { $ui.TxtDetectName.Text = $info.ProductName }
    }
    if ($info.Kind -eq 'MSI' -and $info.ProductCode) { Set-DetectionFromMsi $info }

    if (-not $ui.ChkAutoSteps.IsChecked)
    {
        $q = 'De installatiestappen zijn met de hand geschreven. Voortaan automatisch maken uit de onderdelen (tabblad 2)?'
        if ([System.Windows.MessageBox]::Show($q, 'Installer gekozen', 'YesNo', 'Question') -eq 'Yes') { $ui.ChkAutoSteps.IsChecked = $true }
    }
    Update-InstallPreview

    if (-not $ui.TxtUninstallCmd.Text.Trim() -or $ui.TxtUninstallCmd.Text -match 'MijnApp|VUL IN')
    {
        $ui.TxtUninstallCmd.Text = New-UninstallCmdText $ui.TxtAppName.Text $info $ui.TxtDetectName.Text
    }
    Update-FileList

    # Pakket opslaan in: past die nog bij de map van deze installer? Bij een update staat hij vaak nog op de vorige versie.
    $newVersionDir = Get-VersionFolder $src
    if ($newVersionDir -and -not (Test-InAppsFolder $newVersionDir))
    {
        $sub = $KitSettings.PakketSubmap
        $newOut = if ($sub) { Join-Path $newVersionDir $sub } else { $newVersionDir }
        $curOut = $ui.TxtOutputFolder.Text.Trim().TrimEnd('\')
        if ($curOut -ine $newOut.TrimEnd('\'))
        {
            $q = if ($curOut) { "Pakket opslaan in staat nog op:`n`n$curOut`n`nAanpassen naar de map van de gekozen installer?`n`n$newOut" }
                 else { "Pakket opslaan in invullen met de map van de gekozen installer?`n`n$newOut" }
            if ([System.Windows.MessageBox]::Show($q, 'Pakket opslaan in', 'YesNo', 'Question') -eq 'Yes') { $ui.TxtOutputFolder.Text = $newOut }
        }
    }
    Set-Status "Installer $name toegevoegd als hoofdonderdeel. Controleer versie, processen en tabblad 2."
})

$ui.BtnGenerate.Add_Click({
    $main = Get-MainComponent
    if (-not $main) { Show-Error 'Voeg eerst een onderdeel toe (tabblad 1 of 2).'; return }
    if ($ui.TxtUninstallCmd.Text.Trim() -and [System.Windows.MessageBox]::Show('De huidige verwijderstappen vervangen?', 'Opnieuw maken', 'YesNo', 'Question') -ne 'Yes') { return }
    $info = @{ Kind = $main.Kind; ProductCode = $main.ProductCode }
    $ui.TxtUninstallCmd.Text = New-UninstallCmdText $ui.TxtAppName.Text $info $ui.TxtDetectName.Text
})


$ui.BtnCompRemove.Add_Click({
    $c = $ui.DgComponents.SelectedItem
    if (-not $c) { Show-Error 'Selecteer eerst een onderdeel.'; return }
    $r = [System.Windows.MessageBox]::Show("Onderdeel $($c.File) verwijderen.`n`nOok het bestand uit de app-map verwijderen?", 'Onderdeel verwijderen', 'YesNoCancel', 'Question')
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

# Na het wijzigen van een cel (parameters, exitcodes, hoofd) het voorbeeld bijwerken
$ui.DgComponents.Add_CellEditEnding({
    $null = $Window.Dispatcher.BeginInvoke([action]{
        # Maar één hoofdonderdeel tegelijk
        $sel = $ui.DgComponents.SelectedItem
        if ($sel -and $sel.Main) { foreach ($c in $script:Components) { if ($c -ne $sel) { $c.Main = $false } } ; $ui.DgComponents.Items.Refresh() }
        Update-InstallPreview
    }, [System.Windows.Threading.DispatcherPriority]::Background)
})
$ui.DgComponents.Add_CurrentCellChanged({ Update-InstallPreview })
$ui.TxtPreInstall.Add_TextChanged({ Update-InstallPreview })
$ui.CmbWindow.Add_SelectionChanged({ Update-WindowHint })
$ui.InfoTimes.Add_MouseLeftButtonUp({
    $msg = "Tijdblokken bepalen wanneer de popup en de installatie mogen komen.`n`n" +
           "Zo vul je ze in:`n" +
           "- Elk blok als van-tot, in 24-uurs tijd met een dubbele punt: 08:00-09:00`n" +
           "- Meerdere blokken scheid je met een komma`n" +
           "- Over middernacht mag: 22:00-06:00`n" +
           "- De eindtijd telt niet mee: bij 08:00-09:00 kan de popup om 08:59 nog komen, om 09:00 niet meer`n`n" +
           "Voorbeelden:`n" +
           "  08:00-17:00`t`t`t`thele werkdag`n" +
           "  08:00-09:00, 12:00-13:00, 16:00-17:00`tinloggen, pauze, afsluiten`n" +
           "  22:00-06:00`t`t`t`t's avonds en 's nachts`n`n" +
           "Met 'Alleen buiten de gekozen tijden' werkt het andersom: dan komt de popup juist buiten de blokken.`n`n" +
           "Let op: Intune controleert met tussenpozen, niet continu. Bij korte blokken (een uur) kan de popup daardoor soms pas in een volgend blok komen. " +
           "Zet 'Hoe lang duurt een keer uitstellen?' korter (bijv. 3 uur) als de popup dezelfde dag in een volgend blok terug moet komen."
    [void][System.Windows.MessageBox]::Show($msg, 'Tijdblokken invullen', 'OK', 'Information')
})
$ui.ChkIdle.Add_Click({ Update-WindowHint })
$ui.TxtPostInstall.Add_TextChanged({ Update-InstallPreview })
$ui.TxtPostInstall.Add_LostFocus({ Update-FileList })
$ui.TxtPreInstall.Add_LostFocus({ Update-FileList })
$ui.ChkAutoSteps.Add_Click({
    if (-not $ui.ChkAutoSteps.IsChecked)
    {
        Set-Status 'Automatisch maken staat uit: je kunt install-app.cmd nu met de hand aanpassen.'
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
        if ([System.IO.Path]::GetExtension($dlg.FileName) -ieq '.svg') { Set-Status 'SVG wordt omgezet naar een icoon...' }
        New-IcoFromImage $dlg.FileName (Join-Path (Get-AppFolder) 'app.ico'); Update-IconPreview; Update-FileList
        # Origineel bewaren, zodat je later een scherpere versie kunt maken (gaat ook mee in de versiegeschiedenis)
        if ([System.IO.Path]::GetExtension($dlg.FileName) -ieq '.svg') {
            Copy-Item -LiteralPath $dlg.FileName -Destination (Join-Path (Get-AppFolder) 'logo.svg') -Force
            Update-FileList; Set-Status 'SVG-logo omgezet naar app.ico (256 x 256).'
        }
    }
    catch { Show-Error "Logo kon niet worden omgezet: $($_.Exception.Message)" }
})

$ui.BtnIconFromInstaller.Add_Click({
    $inst = $ui.TxtInstaller.Text
    if (-not $inst -or $inst -notmatch '\.(exe|msi)$') { Show-Error 'Dit kan alleen met een .exe- of .msi-installer. Kies anders zelf een logo.'; return }
    $work = $null
    try
    {
        $source = Join-Path (Get-AppFolder) $inst
        if ($inst -like '*.msi')
        {
            $work = Join-Path ([System.IO.Path]::GetTempPath()) ("AppKitMsiIcon_" + [guid]::NewGuid().ToString('N'))
            New-Item -Path $work -ItemType Directory -Force | Out-Null
            $source = Get-MsiIcon -MsiPath $source -WorkDir $work
            if (-not $source) { Show-Error 'Deze MSI bevat geen pictogram. Kies zelf een logo (.svg, .png of .ico).'; return }
        }
        New-IcoFromImage $source (Join-Path (Get-AppFolder) 'app.ico')
        Update-IconPreview; Update-FileList
        Set-Status 'Logo uit de installer gehaald. Is hij wazig? Kies dan een groter logo (.svg, .png of .ico).'
    }
    catch { Show-Error "Logo kon niet uit de installer worden gehaald: $($_.Exception.Message)" }
    finally { if ($work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } }
})

$ui.TxtAccent.Add_TextChanged({ Update-AccentPreview })

$ui.BtnCompAdd.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Multiselect = $true
    Set-StartFolder $dlg
    $dlg.Filter = 'Alle bestanden (*.*)|*.*|Installatiebestanden (*.exe;*.msi;*.msp;*.ps1;*.cmd;*.bat;*.reg)|*.exe;*.msi;*.msp;*.ps1;*.cmd;*.bat;*.reg'
    if (-not $dlg.ShowDialog()) { return }
    $files = @($dlg.FileNames)
    $all = $null; $added = @(); $copied = @()
    for ($i = 0; $i -lt $files.Count; $i++)
    {
        $fn = $files[$i]; $name = [System.IO.Path]::GetFileName($fn)
        # "Hetzelfde voor alle bestanden" geldt niet voor "onderdeel" bij een bestand dat geen installer is
        $choice = if ($all -and -not ($all.Action -eq 'Onderdeel' -and -not (Test-InstallerFile $name))) { $all } else { Show-FileActionDialog $name ($files.Count - $i - 1) }
        if (-not $choice) { continue }
        if ($choice.All) { $all = $choice }
        switch ($choice.Action)
        {
            'Onderdeel'
            {
                $info = Add-ComponentFile $fn $false
                $ui.TxtCompInfo.Text = "$($info.File): $($info.Kind). $($info.Note)  Controleer de parameters; dubbelklik om te wijzigen."
                # Nieuwe onderdelen vóór het hoofdonderdeel (meestal een voorbereiding, zoals een runtime)
                $main = $script:Components | Where-Object { $_.Main } | Select-Object -First 1
                if ($main) { $mi = $script:Components.IndexOf($main); if ($mi -lt $script:Components.Count - 1) { $script:Components.Move($mi, $script:Components.Count - 1) } }
                $added += $name
            }
            'Kopieren' { Copy-Item -LiteralPath $fn -Destination (Get-AppFolder) -Force; Add-CopyStep $name $choice.Target; $copied += $name }
            default    { Copy-Item -LiteralPath $fn -Destination (Get-AppFolder) -Force }
        }
    }
    Update-InstallPreview; Update-FileList
    if ($copied -and -not $ui.ChkAutoSteps.IsChecked)
    {
        Show-Info "De kopieerstappen staan in 'Extra stappen na de onderdelen'. Je schrijft de installatiestappen met de hand (automatisch maken staat uit): neem ze daar ook over."
    }
    elseif ($added -or $copied) { Set-Status "Toegevoegd: $((@($added) + @($copied)) -join ', '). Zie tabblad 2 voor de stappen." }
})

$ui.BtnRemoveFile.Add_Click({
    $sel = [string]$ui.LstFiles.SelectedItem
    if (-not $sel) { return }
    $name = ($sel -split '   \(')[0]
    if ([System.Windows.MessageBox]::Show("$name verwijderen uit de app-map?", 'Verwijderen', 'YesNo', 'Question') -eq 'Yes')
    {
        Remove-Item -LiteralPath (Join-Path (Get-AppFolder) $name) -Force
        $ui.TxtPostInstall.Text = Remove-CopyStep $name $ui.TxtPostInstall.Text
        foreach ($c in @($script:Components | Where-Object { $_.File -eq $name })) { [void]$script:Components.Remove($c) }
        $ui.DgComponents.Items.Refresh()
        if ("$($ui.TxtPreInstall.Text)`n$($ui.TxtPostInstall.Text)" -match [regex]::Escape($name)) { Show-Info "$name wordt nog genoemd in de extra stappen (tabblad 2). Haal die regels weg, anders mislukt de installatie." }
        Update-InstallPreview; Update-FileList; Update-IconPreview
    }
})

$ui.BtnOpenAppFolder.Add_Click({ if (Get-AppFolder) { Start-Process explorer.exe (Get-AppFolder) } })
# Moderne Windows-mapkiezer (zoals in Verkenner: adresbalk om een pad te typen of plakken, snelle toegang links).
# De oude FolderBrowserDialog (boomstructuur) is alleen nog de reserve als deze niet werkt.
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

        // Geeft het gekozen pad terug, of null bij Annuleren
        public static string Show(IntPtr owner, string title, string okLabel, string startFolder) {
            IFileOpenDialog dlg = (IFileOpenDialog)new FileOpenDialogCom();
            try {
                uint opts;
                dlg.GetOptions(out opts);
                dlg.SetOptions(opts | 0x20 | 0x40 | 0x8 | 0x800);   // mappen kiezen, alleen bestandssysteem, map niet wijzigen, pad moet bestaan
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
                if (hr == unchecked((int)0x800704C7)) return null;   // Annuleren
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

function Select-Folder([string]$Title, [string]$StartFolder, [string]$OkLabel = 'Map kiezen')
{
    # Geeft het gekozen pad terug, of $null bij Annuleren
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
    # Startpunt: de versiemap van de zojuist gekozen installer, anders de huidige map, anders de standaardmap
    $start = @()
    if ($script:LastInstallerPath) { $start += (Get-VersionFolder $script:LastInstallerPath) }
    if ($cur) { $start += $cur; $start += (Split-Path $cur -Parent) }
    $start += $KitSettings.InstallerMap
    $startDir = $start | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    $picked = Select-Folder 'Kies de versiemap (het pakket komt in \intune-package daarbinnen)' $startDir
    if ($picked)
    {
        # Gekozen versiemap -> <versiemap>\intune-package (PakketSubmap in _Kit\Instellingen.psd1)
        $chosen = $picked.TrimEnd('\')
        if (Test-InAppsFolder $chosen)
        {
            Show-Error "Deze map ligt in de app-map van de kit ($chosen).`n`nHet pakket mag daar niet komen: dan kopieert elke build zichzelf in het pakket. Kies de versiemap naast de installer, bijv. ...\versies\2.4.0."
            return
        }
        $sub = $KitSettings.PakketSubmap
        $ui.TxtOutputFolder.Text = if ($sub -and (Split-Path $chosen -Leaf) -ine $sub) { Join-Path $chosen $sub } else { $chosen }
        Set-Status "Pakket komt in: $($ui.TxtOutputFolder.Text)"
    }
})

$ui.BtnOpenOutput.Add_Click({
    $o = Get-OutputRoot
    if (-not (Test-Path $o)) { $o = Join-Path (Join-Path $KitRoot 'Output') $script:CurrentApp }
    if (Test-Path $o) { Start-Process explorer.exe $o }
})

$ui.BtnStdTexts.Add_Click({ Show-StandardTextsEditor })

$ui.LstVersions.Add_SelectionChanged({ Show-VersionDetails })
$ui.BtnVerPreview.Add_Click({
    $det = $script:SelectedVersion
    if (-not $det -or -not $det.Data) { return }
    $kind = [string]$ui.CmbVerPreview.SelectedItem.Tag
    Show-Preview $kind $det.Data $det.Std $det.Icon
})
$ui.BtnVerOpen.Add_Click({ $v = Get-SelectedVersion; if ($v) { Start-Process explorer.exe $v.Path } })

$ui.BtnVerRestore.Add_Click({
    # Volledige kopie van deze build (instellingen, teksten, stappen, installers) als werkversie klaarzetten
    $v = Get-SelectedVersion
    if (-not $v) { return }
    if (-not $v.HasBron) { Show-Error "Van build $($v.Label) zijn geen gegevens bewaard."; return }
    $q = "Een kopie maken van $($v.Label) en die als werkversie klaarzetten?`n`n" +
         "Wat nu in de Builder staat (en nog niet gebouwd is) wordt daarmee vervangen. Gebouwde versies blijven altijd bewaard.`n`n" +
         "Daarna:`n- zelfde versienummer houden = deze versie verbeteren (de huidige build gaat naar het archief)`n" +
         "- nieuwe installer of nieuw versienummer = een nieuwe versie"
    if ([System.Windows.MessageBox]::Show($q, 'Kopie maken en aanpassen', 'YesNo', 'Question') -ne 'Yes') { return }

    $bronDir = Join-Path $v.Path 'Bron'
    $appDir  = Get-AppFolder
    Set-Status "Kopie maken van $($v.Label)..."
    Get-ChildItem $appDir -Force | Remove-Item -Recurse -Force
    Get-ChildItem $bronDir -Force | Where-Object { $_.Name -ne 'Standaardteksten.psd1' } | Copy-Item -Destination $appDir -Recurse -Force
    Import-App $script:CurrentApp
    $ui.Tabs.SelectedIndex = 0

    $msg = "Kopie van $($v.Label) staat klaar. Pas aan wat nodig is en klik op Bouw pakket."
    if (-not $v.HasInstallers) { $msg += ' Let op: in deze oude build zijn de installers niet bewaard; voeg ze opnieuw toe.' }
    Set-Status $msg
})

$ui.BtnVerDelete.Add_Click({
    $v = Get-SelectedVersion
    if (-not $v) { return }
    if ([System.Windows.MessageBox]::Show("Versie $($v.Version) met install.intunewin en alle bestanden in deze map verwijderen?`n`n$($v.Path)", 'Versie verwijderen', 'YesNo', 'Warning') -ne 'Yes') { return }
    Remove-Item -LiteralPath $v.Path -Recurse -Force
    if ($v.Pointer) { Remove-Item -LiteralPath (Split-Path $v.Pointer -Parent) -Recurse -Force -ErrorAction SilentlyContinue }
    Update-VersionList
    Set-Status "Versie $($v.Version) verwijderd."
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
$ui.TxtDetectName.Add_TextChanged({ if ([string]$ui.CmbDetect.SelectedItem.Tag -eq 'AppsEnOnderdelen') { Update-DetectPanels } })
$ui.BtnDetectTest.Add_Click({
    # Het detectiescript hier uitvoeren (64-bit PowerShell, zoals Intune) en de uitkomst tonen
    $d = Read-Form
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "AppKit_detect_$(Get-Random).ps1"
    try
    {
        [System.IO.File]::WriteAllText($tmp, (Get-DetectionScriptText $d), (New-Object System.Text.UTF8Encoding $true))
        $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $psi = New-Object System.Diagnostics.ProcessStartInfo $ps, "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $psi.EnvironmentVariables['APPKIT_DETECT_DEBUG'] = '1'   # uitleg op de foutuitvoer; Intune zet dit nooit
        $p = [System.Diagnostics.Process]::Start($psi)
        $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd()
        if (-not $p.WaitForExit(30000)) { $p.Kill() }
        $brush = New-Object System.Windows.Media.BrushConverter
        $why = (("$err" -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 6) -join "`n  "
        if ("$out".Trim())
        {
            $ui.TxtDetectResult.Foreground = $brush.ConvertFromString('#2E7D32')
            $ui.TxtDetectResult.Text = "  Gedetecteerd op deze pc.$(if ($why) { "`n  $why" } else { "`n  $("$out".Trim())" })"
        }
        else
        {
            $ui.TxtDetectResult.Foreground = $brush.ConvertFromString('#C62828')
            $ui.TxtDetectResult.Text = "  Niet gedetecteerd op deze pc.$(if ($why) { "`n  $why" })"
        }
    }
    catch { Show-Error "Testen lukte niet: $($_.Exception.Message)" }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
})
$ui.BtnPrevInstalling.Add_Click({ Show-Preview 'installing' })
$ui.BtnPrevSuccess.Add_Click({ Show-Preview 'success' })
$ui.BtnPrevError.Add_Click({ Show-Preview 'error' })

$ui.BtnSave.Add_Click({ [void](Save-App) })

# Vorige / Volgende: door alle tabbladen (Basis t/m Resultaat)
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

function Select-InstallerMap([switch]$FirstRun)
{
    # Standaardmap voor installers kiezen en opslaan in _Kit\Instellingen.psd1
    $startDir = if ($KitSettings.InstallerMap -and (Test-Path -LiteralPath $KitSettings.InstallerMap)) { $KitSettings.InstallerMap } else { $null }
    $picked = Select-Folder 'Standaardmap voor installers kiezen (hier opent "Kiezen..." straks)' $startDir
    if (-not $picked) { return }
    try
    {
        Save-InstallerMap $picked
        Set-Status "Standaardmap voor installers: $($KitSettings.InstallerMap)"
    }
    catch { Show-Error "De standaardmap kon niet worden opgeslagen in _Kit\Instellingen.psd1: $($_.Exception.Message)" }
}

$ui.BtnInstallerMap.Add_Click({ Select-InstallerMap })

# Eerste keer opstarten: standaardmap voor installers nog niet ingesteld? Eén keer per gebruiker vragen.
$Window.Add_ContentRendered({
    $marker = Join-Path (Join-Path $env:LOCALAPPDATA 'AppUpdateKit') 'standaardmap-gevraagd.txt'
    if ($KitSettings.InstallerMap -or (Test-Path $marker)) { return }
    try { New-Item -Path (Split-Path $marker -Parent) -ItemType Directory -Force | Out-Null; Set-Content -Path $marker -Value (Get-Date -Format 's') } catch { }
    $q = "Welkom bij de AppUpdateKit Builder.`n`nWil je een standaardmap voor installers instellen? Bij 'Kiezen...' opent het venster dan meteen in die map, bijvoorbeeld I:\Software\projecten.`n`nJe kunt dit later wijzigen met de knop Standaardmap... (links)."
    if ([System.Windows.MessageBox]::Show($Window, $q, 'Standaardmap instellen', 'YesNo', 'Question') -eq 'Yes') { Select-InstallerMap -FirstRun }
})

try
{
    Update-BuilderShortcut
    Update-AppList
    Set-Status 'Kies links een app, of maak een nieuwe aan.'
    [void]$Window.ShowDialog()
}
catch
{
    Write-BuilderError $_
}
#endregion

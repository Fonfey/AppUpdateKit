<#
.SYNOPSIS
    Intune-installatiescript voor {{APPNAME}} {{VERSION}}  (AppUpdateKit)

.DESCRIPTION
    Upload dit script in Intune bij de Win32-app:
      Program > Installer type: PowerShell script > Install script
    Het hoort NIET in het .intunewin-pakket. Daardoor kun je het later in Intune aanpassen
    (teksten, uitstellen, tijden, parameters, extra stappen) zonder opnieuw te verpakken.

    Opnieuw verpakken is alleen nodig bij een nieuwe installer, een ander logo of een nieuwe kit-versie.
    Neem een wijziging die je hier in Intune doet ook over in de Builder, anders is hij bij de volgende build weg.

    Gemaakt door de AppUpdateKit Builder op {{BUILDDATE}} (kit-versie {{KITVERSION}}).
#>

# =============================================================================
#  1. SCHAKELAARS  ($true = aan)
# =============================================================================
$GeenProcescheck = $false   # niet controleren of de app open staat
                            #   gebruik dan ook Requirement-zonder-procescheck.ps1 in Intune
$GeenPopup       = $false   # geen popup, direct installeren (meldingen rechtsonder blijven)
$Stil            = $false   # geen popup en geen meldingen

# Eigen schakelaars voor de stappen hieronder (in de cmd-regels beschikbaar als APP_<NAAM>)
$Schakelaars = @{
{{SCHAKELAARS}}
}

# =============================================================================
#  2. INSTELLINGEN EN TEKSTEN  (zelfde betekenis als in app.psd1)
#     In teksten: {AppName}, {Versie}, {Minuten}, {MaxUitstel}. Leeg ('') = standaardtekst.
# =============================================================================
$App = @{
{{INSTELLINGEN}}
}

# =============================================================================
#  3. INSTALLATIESTAPPEN
#     Onderdelen worden in volgorde uitgevoerd vanuit de pakketmap.
#     Opdracht = de opdrachtregel (met parameters); Geslaagd = exitcodes die als gelukt tellen.
# =============================================================================
$Onderdelen = @(
{{ONDERDELEN}}
)

# cmd-regels voor en na de onderdelen (mogen leeg blijven)
$VoorInstallatie = @'
{{VOOR}}
'@

$NaInstallatie = @'
{{NA}}
'@

# Eigen installatiescript (alleen gebruikt als er hierboven geen onderdelen staan)
$EigenScript = @'
{{EIGEN_SCRIPT}}
'@


# =============================================================================
#  VANAF HIER NIET AANPASSEN
# =============================================================================
$ErrorActionPreference = 'Stop'

# Pakketmap: Intune start dit script vanuit de uitgepakte inhoud van het .intunewin-pakket
$Pakket = (Get-Location).Path
foreach ($kandidaat in @($Pakket, $PSScriptRoot)) {
    if ($kandidaat -and (Test-Path (Join-Path $kandidaat 'AppUI-Launcher.ps1'))) { $Pakket = $kandidaat; break }
}
$AppMap = Join-Path 'C:\ProgramData\AppUpdates' $App.AppId
if (-not (Test-Path $AppMap)) { New-Item -Path $AppMap -ItemType Directory -Force | Out-Null }
$LogPad = Join-Path $AppMap 'update.log'

function Write-InstallLog([string]$Tekst) {
    $regel = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [install] $Tekst"
    Add-Content -Path $LogPad -Value $regel -ErrorAction SilentlyContinue
    Write-Host $regel   # Write-Host: komt niet in de uitvoer van functies terecht
}

if (-not (Test-Path (Join-Path $Pakket 'AppUI-Launcher.ps1'))) {
    Write-InstallLog "FOUT: de pakketinhoud is niet gevonden (map: $Pakket). Hoort install.intunewin van $($App.AppName) bij dit script?"
    exit 1
}
Set-Location $Pakket
Write-InstallLog "Start $($App.AppName) $($App.Version) (PowerShell-installer, pakket: $Pakket)"

# Instellingen klaarzetten voor de vensters (die lezen dit bestand in plaats van app.psd1)
$configPad = Join-Path $AppMap 'app.json'
[System.IO.File]::WriteAllText($configPad, ($App | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
$env:APPKIT_CONFIG = $configPad

# Schakelaars doorgeven aan de cmd-regels
foreach ($naam in @($Schakelaars.Keys)) {
    if ($Schakelaars[$naam]) { Set-Item -Path "env:APP_$($naam.ToUpper())" -Value '1' }
}
# Nieuwe installatie of update? (bepaalt de teksten in de vensters)
$ps0 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $ps0 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Pakket 'Test-AppInstalled.ps1') | Out-Null
$env:APPKIT_NEWINSTALL = if ($LASTEXITCODE -ne 0) { '1' } else { '0' }

$aan = @(@{ GeenProcescheck = $GeenProcescheck; GeenPopup = $GeenPopup; Stil = $Stil }.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key }) +
       @($Schakelaars.Keys | Where-Object { $Schakelaars[$_] })
if ($aan) { Write-InstallLog "Schakelaars aan: $($aan -join ', ')" }

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Invoke-KitScript([string]$Naam, [string[]]$Argumenten = @()) {
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Pakket $Naam) @Argumenten | Out-Null
    return $LASTEXITCODE
}

function Invoke-CmdBlok([string]$Tekst, [string]$Naam) {
    # cmd-regels uitvoeren in de pakketmap; geeft de exitcode terug
    $stapMap = Join-Path $AppMap 'Stappen'
    if (-not (Test-Path $stapMap)) { New-Item -Path $stapMap -ItemType Directory -Force | Out-Null }
    $bestand = Join-Path $stapMap "$Naam.cmd"
    $inhoud = "@echo off`r`ncd /d `"$Pakket`"`r`n" + ($Tekst -replace "`r?`n", "`r`n") + "`r`nexit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText($bestand, $inhoud, [System.Text.Encoding]::Default)
    & $env:ComSpec /c $bestand | ForEach-Object { Add-Content -Path $LogPad -Value "    $_" -ErrorAction SilentlyContinue }
    $rc = $LASTEXITCODE
    Remove-Item -Path $bestand -Force -ErrorAction SilentlyContinue
    return $rc
}

function Invoke-Installatie {
    $resultaat = 0
    if ($VoorInstallatie.Trim()) {
        $rc = Invoke-CmdBlok $VoorInstallatie 'voor'
        Write-InstallLog "Stappen voor de installatie klaar (exitcode $rc)"
    }

    $lijst = @($Onderdelen | Where-Object { $_ })
    if (-not $lijst.Count -and $EigenScript.Trim()) {
        Write-InstallLog 'Eigen installatiescript wordt uitgevoerd'
        return (Invoke-CmdBlok ("set APP_EXITCODE=0`r`n" + $EigenScript) 'eigen-script')
    }

    $n = 0
    foreach ($o in $lijst) {
        $n++
        Write-InstallLog "Onderdeel $n ($($o.Naam)): $($o.Opdracht)"
        $rc = Invoke-CmdBlok $o.Opdracht "onderdeel$n"
        $geslaagd = @($o.Geslaagd | ForEach-Object { [int]$_ })
        if (-not $geslaagd.Count) { $geslaagd = 0, 3010, 1641 }
        if ($geslaagd -notcontains $rc) {
            Write-InstallLog "Onderdeel $n ($($o.Naam)) is mislukt met exitcode $rc"
            return $rc
        }
        Write-InstallLog "Onderdeel $n ($($o.Naam)) gelukt (exitcode $rc)"
        if ($rc -eq 3010 -or $rc -eq 1641) { $resultaat = $rc }
    }

    if ($NaInstallatie.Trim()) {
        $rc = Invoke-CmdBlok $NaInstallatie 'na'
        Write-InstallLog "Stappen na de installatie klaar (exitcode $rc)"
    }
    return $resultaat
}

try {
    if ($Stil) { $GeenPopup = $true }

    # 1. App mag niet open staan (Intune probeert het later opnieuw)
    if (-not $GeenProcescheck -and (Invoke-KitScript 'Test-AppRunning.ps1') -ne 0) { exit 1618 }

    # 2. Toestemming vragen (Later = uitstellen: stoppen zonder installatie)
    if (-not $GeenPopup) {
        if ((Invoke-KitScript 'Ask-InstallConsent.ps1') -ne 0) {
            Write-InstallLog 'Installatie voor nu overgeslagen (uitgesteld, buiten tijdvenster of geen reactie).'
            exit 0
        }
        # 3. Nogmaals: de app kan geopend zijn terwijl het venster of de aftelklok liep
        if (-not $GeenProcescheck -and (Invoke-KitScript 'Test-AppRunning.ps1') -ne 0) { exit 1618 }
    }

    if (-not $Stil) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Installing') | Out-Null }

    # 4. Installatiestappen
    $exitCode = [int](Invoke-Installatie)

    # 5. Resultaat (0, 3010, 1641 = gelukt)
    if (@(0, 3010, 1641) -contains $exitCode) {
        Remove-Item -Path (Join-Path $AppMap 'PostponeState.json') -Force -ErrorAction SilentlyContinue
        if (-not $Stil) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Success') | Out-Null }
        Write-InstallLog "Installatie gelukt (exitcode $exitCode)"
        # Herstartmelding (RestartMode); geeft 0 terug als de kit de herstart regelt
        if (-not $Stil) { $exitCode = Invoke-KitScript 'Set-RestartPrompt.ps1' @('-ExitCode', "$exitCode") }
    }
    else {
        if (-not $Stil) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Error') | Out-Null }
        Write-InstallLog "Installatie mislukt (exitcode $exitCode)"
    }
    exit $exitCode
}
catch {
    Write-InstallLog "FOUT: $($_.Exception.Message)"
    exit 1
}

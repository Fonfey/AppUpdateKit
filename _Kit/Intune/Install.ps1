<#
.SYNOPSIS
    {{T:Intune-installatiescript voor|Intune install script for}} {{APPNAME}} {{VERSION}}  (AppUpdateKit)

.DESCRIPTION
    {{T:Upload dit script in Intune bij de Win32-app:|Upload this script in Intune with the Win32 app:}}
      Program > Installer type: PowerShell script > Install script
    {{T:Het hoort NIET in het .intunewin-pakket. Daardoor kun je het later in Intune aanpassen|It does NOT belong in the .intunewin package. That way you can change it later in Intune}}
    {{T:(teksten, uitstellen, tijden, parameters, extra stappen) zonder opnieuw te verpakken.|(texts, postponing, times, parameters, extra steps) without repackaging.}}

    {{T:Opnieuw verpakken is alleen nodig bij een nieuwe installer, een ander logo of een nieuwe kit-versie.|Repackaging is only needed for a new installer, another logo or a new kit version.}}
    {{T:Neem een wijziging die je hier in Intune doet ook over in de Builder, anders is hij bij de volgende build weg.|Copy any change you make here in Intune into the Builder too, otherwise it is gone after the next build.}}

    {{T:Gemaakt door de AppUpdateKit Builder op|Created by the AppUpdateKit Builder on}} {{BUILDDATE}}.
#>

# =============================================================================
#  1. {{T:SCHAKELAARS  ($true = aan)|SWITCHES  ($true = on)}}
# =============================================================================
# {{T:Niet controleren of de app open staat (gebruik dan ook Requirement-NoProcessCheck.ps1)|Do not check whether the app is running (then also use Requirement-NoProcessCheck.ps1)}}
$NoProcessCheck = $false
# {{T:Geen popup, direct installeren (meldingen rechtsonder blijven)|No popup, install right away (notifications remain)}}
$NoPopup        = $false
# {{T:Geen popup en geen meldingen|No popup and no notifications}}
$Silent         = $false

# {{T:Eigen schakelaars voor de stappen hieronder (in de cmd-regels beschikbaar als APP_<NAAM>)|Own switches for the steps below (available in the cmd lines as APP_<NAME>)}}
$Switches = @{
{{SCHAKELAARS}}
}

# =============================================================================
#  2. {{T:INSTELLINGEN EN TEKSTEN  (zelfde betekenis als in app.psd1)|SETTINGS AND TEXTS  (same meaning as in app.psd1)}}
#     {{T:Texts = Nederlands, TextsEn = Engels (voor gebruikers met Engelse Windows). Leeg ('') = standaardtekst.|Texts = Dutch, TextsEn = English (for users with English Windows). Empty ('') = standard text.}}
# =============================================================================
$App = @{
{{INSTELLINGEN}}
}

# =============================================================================
#  3. {{T:INSTALLATIESTAPPEN|INSTALLATION STEPS}}
#     {{T:Onderdelen worden in volgorde uitgevoerd vanuit de pakketmap.|Components run in order from the package folder.}}
#     {{T:Command = de opdrachtregel (met parameters); SuccessCodes = exitcodes die als gelukt tellen.|Command = the command line (with parameters); SuccessCodes = exit codes that count as success.}}
# =============================================================================
$Components = @(
{{ONDERDELEN}}
)

# {{T:cmd-regels voor en na de onderdelen (mogen leeg blijven)|cmd lines before and after the components (may stay empty)}}
$PreInstall = @'
{{VOOR}}
'@

$PostInstall = @'
{{NA}}
'@

# {{T:Eigen installatiescript (alleen gebruikt als er hierboven geen onderdelen staan)|Own installation script (only used when there are no components above)}}
$CustomScript = @'
{{EIGEN_SCRIPT}}
'@


# =============================================================================
#  {{T:VANAF HIER NIET AANPASSEN|DO NOT EDIT BELOW THIS LINE}}
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
    Write-InstallLog "{{T:FOUT: de pakketinhoud is niet gevonden|ERROR: the package content was not found}} ($PackageDir). {{T:Hoort install.intunewin van|Does install.intunewin of}} $($App.AppName) {{T:bij dit script?|belong to this script?}}"
    exit 1
}
Set-Location $PackageDir
Write-InstallLog "Start $($App.AppName) $($App.Version) ({{T:PowerShell-installer, pakket|PowerShell installer, package}}: $PackageDir)"

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
if ($on) { Write-InstallLog "{{T:Schakelaars aan|Switches on}}: $($on -join ', ')" }

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
        Write-InstallLog "{{T:Stappen voor de installatie klaar|Pre-installation steps done}} (exitcode $rc)"
    }

    $list = @($Components | Where-Object { $_ })
    if (-not $list.Count -and $CustomScript.Trim()) {
        Write-InstallLog '{{T:Eigen installatiescript wordt uitgevoerd|Running own installation script}}'
        return (Invoke-CmdBlock ("set APP_EXITCODE=0`r`n" + $CustomScript) 'custom-script')
    }

    $n = 0
    foreach ($c in $list) {
        $n++
        Write-InstallLog "{{T:Onderdeel|Component}} $n ($($c.Name)): $($c.Command)"
        $rc = Invoke-CmdBlock $c.Command "component$n"
        $ok = @($c.SuccessCodes | ForEach-Object { [int]$_ })
        if (-not $ok.Count) { $ok = 0, 3010, 1641 }
        if ($ok -notcontains $rc) {
            Write-InstallLog "{{T:Onderdeel|Component}} $n ($($c.Name)) {{T:is mislukt met exitcode|failed with exit code}} $rc"
            return $rc
        }
        Write-InstallLog "{{T:Onderdeel|Component}} $n ($($c.Name)) {{T:gelukt|succeeded}} (exitcode $rc)"
        if ($rc -eq 3010 -or $rc -eq 1641) { $result = $rc }
    }

    if ($PostInstall.Trim()) {
        $rc = Invoke-CmdBlock $PostInstall 'post'
        Write-InstallLog "{{T:Stappen na de installatie klaar|Post-installation steps done}} (exitcode $rc)"
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
            Write-InstallLog '{{T:Installatie voor nu overgeslagen (uitgesteld, buiten tijdvenster of geen reactie).|Installation skipped for now (postponed, outside the time window or no response).}}'
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
        Write-InstallLog "{{T:Installatie gelukt|Installation succeeded}} (exitcode $exitCode)"
        # Restart prompt (RestartMode); returns 0 when the kit handles the restart
        if (-not $Silent) { $exitCode = Invoke-KitScript 'Set-RestartPrompt.ps1' @('-ExitCode', "$exitCode") }
    }
    else {
        if (-not $Silent) { Invoke-KitScript 'Show-Toast.ps1' @('-Type', 'Error') | Out-Null }
        Write-InstallLog "{{T:Installatie mislukt|Installation failed}} (exitcode $exitCode)"
    }
    exit $exitCode
}
catch {
    Write-InstallLog "{{T:FOUT|ERROR}}: $($_.Exception.Message)"
    exit 1
}

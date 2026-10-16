<#
.SYNOPSIS
    Step 1: creates a new app folder from the template.

.EXAMPLE
    .\1-New-App.ps1 -AppId 7Zip -AppName '7-Zip'

    Creates Apps\7Zip with:
      app.psd1           -> details, logo, colour, postpone rules and texts
      install-app.cmd    -> your installation steps (installers + parameters, extra files)
      uninstall-app.cmd  -> your uninstall steps
    Then put the installer(s), the logo (app.ico) and any extra files in that folder
    and run .\2-Build-Package.ps1 -App 7Zip

    The template is in the kit language (_Kit\Settings.psd1), or use -Lang nl | en.
#>

param
(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$AppId,
    [string]$AppName = $AppId,
    [ValidateSet('', 'nl', 'en')][string]$Lang = ''
)

$ErrorActionPreference = 'Stop'
# Kit folder (also when $PSScriptRoot is empty, e.g. when started from PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Kan de AppUpdateKit-map niet vinden / Cannot find the AppUpdateKit folder. cd <AppUpdateKit> ; .\1-New-App.ps1 -AppId <AppId>"
}
if (-not $Lang) {
    $Lang = 'nl'
    $settingsFile = Join-Path (Join-Path $KitRoot '_Kit') 'Settings.psd1'
    if (Test-Path $settingsFile) { try { if ((Import-PowerShellDataFile $settingsFile).Language -eq 'en') { $Lang = 'en' } } catch { } }
}
function T([string]$Nl, [string]$En) { if ($Lang -eq 'en') { return $En } else { return $Nl } }

$target = Join-Path (Join-Path $KitRoot 'Apps') $AppId
if (Test-Path $target) { throw (T "Apps\$AppId bestaat al." "Apps\$AppId already exists.") }

New-Item -Path $target -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path (Join-Path $KitRoot '_Template') '*') -Destination $target -Recurse

# Template in the right language: *.en.* for English, otherwise the Dutch files
foreach ($f in 'app.psd1', 'install-app.cmd', 'uninstall-app.cmd') {
    $enFile = Join-Path $target ([System.IO.Path]::GetFileNameWithoutExtension($f) + '.en' + [System.IO.Path]::GetExtension($f))
    if (Test-Path $enFile) {
        if ($Lang -eq 'en') { Move-Item -Path $enFile -Destination (Join-Path $target $f) -Force }
        else { Remove-Item -Path $enFile -Force }
    }
}

# Fill in AppId, AppName and DetectName
$psd = Join-Path $target 'app.psd1'
$t = Get-Content -Path $psd -Raw -Encoding UTF8
$safeName = $AppName.Replace("'", "''")
$t = $t.Replace("AppId      = 'MijnApp'", "AppId      = '$AppId'").
        Replace("AppName    = 'Mijn App'", "AppName    = '$safeName'").
        Replace("DetectName = 'Mijn App'", "DetectName = '$safeName'")
[System.IO.File]::WriteAllText($psd, $t, (New-Object System.Text.UTF8Encoding $true))

Write-Host "`n$(T 'Aangemaakt' 'Created'): Apps\$AppId" -ForegroundColor Green
Write-Host (T '  1. Vul app.psd1 in (versie, processen, kleur, teksten)' '  1. Fill in app.psd1 (version, processes, colour, texts)')
Write-Host (T '  2. Zet de installer(s) en app.ico in de map' '  2. Put the installer(s) and app.ico in the folder')
Write-Host (T '  3. Zet je installatiestappen in install-app.cmd en uninstall-app.cmd' '  3. Put your installation steps in install-app.cmd and uninstall-app.cmd')
Write-Host "  4. .\2-Build-Package.ps1 -App $AppId"

if ($env:OS -eq 'Windows_NT') { Start-Process explorer.exe $target }

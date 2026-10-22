<#
.SYNOPSIS
    Stap 1: maakt een nieuwe app-map aan vanuit het sjabloon.

.EXAMPLE
    .\1-Nieuwe-app.ps1 -AppId 7Zip -AppName '7-Zip'

    Maakt Apps\7Zip aan met:
      app.psd1           -> gegevens, logo, kleur, uitstelregels en teksten invullen
      install-app.cmd    -> je installatiestappen (installers + parameters, extra bestanden)
      uninstall-app.cmd  -> je verwijderstappen
    Zet daarna de installer(s), het logo (app.ico) en eventuele extra bestanden in die map
    en draai .\2-Bouw-pakket.ps1 -App 7Zip
#>

param
(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$AppId,
    [string]$AppName = $AppId
)

$ErrorActionPreference = 'Stop'
# Map van de kit bepalen (ook als $PSScriptRoot leeg is, bijv. bij starten vanuit PowerShell ISE)
$KitRoot = if ($PSScriptRoot) { $PSScriptRoot }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
if (-not (Test-Path (Join-Path $KitRoot '_Kit'))) {
    throw "Kan de AppUpdateKit-map niet vinden. Ga eerst naar die map (cd <pad naar AppUpdateKit>) en start het script daar, bijv. .\2-Bouw-pakket.ps1 -App NotepadPlusPlus"
}

$target = Join-Path (Join-Path $KitRoot 'Apps') $AppId
if (Test-Path $target) { throw "Apps\$AppId bestaat al." }

New-Item -Path $target -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path (Join-Path $KitRoot '_Template') '*') -Destination $target -Recurse

# AppId, AppName en DetectName alvast invullen
$psd = Join-Path $target 'app.psd1'
$t = Get-Content -Path $psd -Raw -Encoding UTF8
$safeName = $AppName.Replace("'", "''")
$t = $t.Replace("AppId      = 'MijnApp'", "AppId      = '$AppId'").
        Replace("AppName    = 'Mijn App'", "AppName    = '$safeName'").
        Replace("DetectName = 'Mijn App'", "DetectName = '$safeName'")
[System.IO.File]::WriteAllText($psd, $t, (New-Object System.Text.UTF8Encoding $true))

Write-Host "`nAangemaakt: Apps\$AppId" -ForegroundColor Green
Write-Host '  1. Vul app.psd1 in (versie, processen, kleur, teksten)'
Write-Host '  2. Zet de installer(s) en app.ico in de map'
Write-Host '  3. Zet je installatiestappen in install-app.cmd en uninstall-app.cmd'
Write-Host "  4. .\2-Bouw-pakket.ps1 -App $AppId"

if ($env:OS -eq 'Windows_NT') { Start-Process explorer.exe $target }

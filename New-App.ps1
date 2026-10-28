<#
.SYNOPSIS
    Step 1: creates a new app folder from the template.

.EXAMPLE
    .\New-App.ps1 -AppId 7Zip -AppName '7-Zip'

    Creates Apps\7Zip with:
      app.psd1           -> fill in details, logo, colour, postpone rules and texts
      install-app.cmd    -> your installation steps (installers + parameters, extra files)
      uninstall-app.cmd  -> your uninstall steps
    Then put the installer(s), the logo (app.ico) and any extra files in that folder
    and run .\Build-Package.ps1 -App 7Zip
#>

param
(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$AppId,
    [string]$AppName = $AppId
)

$ErrorActionPreference = 'Stop'
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

$target = Join-Path (Join-Path $KitRoot 'Apps') $AppId
if (Test-Path $target) { throw "Apps\$AppId already exists." }

New-Item -Path $target -ItemType Directory -Force | Out-Null
$template = Join-Path $KitRoot '_Template'
$lang = Get-AppKitLanguage   # language of the app = language you chose in the Builder
foreach ($f in Get-ChildItem -LiteralPath $template -File)
{
    $enc = if ($f.Extension -eq '.cmd') { New-Object System.Text.UTF8Encoding $false } else { New-Object System.Text.UTF8Encoding $true }
    $Text = Convert-AppKitFile -Path $f.FullName -Lang $lang -Special @{ "Language    = 'en'" = "Language    = '$lang'" }
    [System.IO.File]::WriteAllText((Join-Path $target $f.Name), $Text, $enc)
}

# Fill in AppId, AppName and DetectName already
$psd = Join-Path $target 'app.psd1'
$t = Get-Content -Path $psd -Raw -Encoding UTF8
$safeName = $AppName.Replace("'", "''")
$t = $t.Replace("AppId      = 'MyApp'", "AppId      = '$AppId'").
        Replace("AppName    = 'My App'", "AppName    = '$safeName'").
        Replace("DetectName = 'My App'", "DetectName = '$safeName'")
[System.IO.File]::WriteAllText($psd, $t, (New-Object System.Text.UTF8Encoding $true))

Write-Host "`nCreated: Apps\$AppId" -ForegroundColor Green
Write-Host '  1. Fill in app.psd1 (version, processes, colour, texts)'
Write-Host '  2. Put the installer(s) and app.ico in the folder'
Write-Host '  3. Put your installation steps in install-app.cmd and uninstall-app.cmd'
Write-Host "  4. .\Build-Package.ps1 -App $AppId"

if ($env:OS -eq 'Windows_NT') { Start-Process explorer.exe $target }

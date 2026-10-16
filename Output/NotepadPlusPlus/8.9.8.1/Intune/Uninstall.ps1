<#
.SYNOPSIS
    Intune-verwijderscript voor Notepad++ 8.9.8.1  (AppUpdateKit)

.DESCRIPTION
    Upload dit script in Intune bij de Win32-app:
      Program > Installer type: PowerShell script > Uninstall script
    Je kunt de stappen hieronder later in Intune aanpassen zonder opnieuw te verpakken.
#>

$AppId  = 'NotepadPlusPlus'
# $true = meldingen rechtsonder: "wordt verwijderd" en daarna "verwijderd" / "niet gelukt"
$Notify = $false

# cmd-regels om de app te verwijderen (uitgevoerd vanuit de pakketmap)
$UninstallSteps = @'
rem ===========================================================================
rem  VERWIJDERSTAPPEN - Notepad++
rem ===========================================================================

"%ProgramFiles%\Notepad++\uninstall.exe" /S
set APP_EXITCODE=%ERRORLEVEL%

exit /b %APP_EXITCODE%
'@

# =============================================================================
#  VANAF HIER NIET AANPASSEN
# =============================================================================
$PackageDir = (Get-Location).Path
$AppDir = Join-Path 'C:\ProgramData\AppUpdates' $AppId
if (-not (Test-Path $AppDir)) { New-Item -Path $AppDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $AppDir 'update.log'
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] Start (pakket: $PackageDir)" -Encoding UTF8 -ErrorAction SilentlyContinue

# Notifications use the texts from Install.ps1 (app.json), otherwise from the package
$config = Join-Path $AppDir 'app.json'
if (Test-Path $config) { $env:APPKIT_CONFIG = $config }
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Show-Notification([string]$Type) {
    if ($Notify -and (Test-Path (Join-Path $PackageDir 'Show-Toast.ps1'))) {
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackageDir 'Show-Toast.ps1') -Type $Type -Force | Out-Null
    }
}
Show-Notification 'Uninstalling'

$file = Join-Path $AppDir 'uninstall-steps.cmd'
$content = "@echo off`r`ncd /d `"$PackageDir`"`r`nset APP_EXITCODE=0`r`n" + ($UninstallSteps -replace "`r?`n", "`r`n") + "`r`nexit /b %ERRORLEVEL%`r`n"
[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::Default)
& $env:ComSpec /c $file | ForEach-Object { Add-Content -Path $LogFile -Value "    $_" -ErrorAction SilentlyContinue }
$rc = $LASTEXITCODE
Remove-Item -Path $file -Force -ErrorAction SilentlyContinue

if (@(0, 3010, 1641) -contains $rc) { Show-Notification 'Uninstalled' } else { Show-Notification 'UninstallError' }

# Clean up the update data; update.log is kept
Unregister-ScheduledTask -TaskName "AppUpdateKit Herstart $AppId" -Confirm:$false -ErrorAction SilentlyContinue
foreach ($name in 'PostponeState.json', 'app.json', 'UI', 'Herstart', 'Stappen') {
    Remove-Item -Path (Join-Path $AppDir $name) -Recurse -Force -ErrorAction SilentlyContinue
}

Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] Klaar (exitcode $rc)" -Encoding UTF8 -ErrorAction SilentlyContinue
exit $rc

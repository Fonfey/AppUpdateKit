<#
.SYNOPSIS
    {{T:Intune-verwijderscript voor|Intune uninstall script for}} {{APPNAME}} {{VERSION}}  (AppUpdateKit)

.DESCRIPTION
    {{T:Upload dit script in Intune bij de Win32-app:|Upload this script in Intune with the Win32 app:}}
      Program > Installer type: PowerShell script > Uninstall script
    {{T:Je kunt de stappen hieronder later in Intune aanpassen zonder opnieuw te verpakken.|You can change the steps below later in Intune without repackaging.}}
#>

$AppId  = '{{APPID}}'
# {{T:$true = meldingen rechtsonder: "wordt verwijderd" en daarna "verwijderd" / "niet gelukt"|$true = notifications bottom right: "being removed", then "removed" / "failed"}}
$Notify = {{UNINSTALL_NOTIFY}}

# {{T:cmd-regels om de app te verwijderen (uitgevoerd vanuit de pakketmap)|cmd lines that remove the app (run from the package folder)}}
$UninstallSteps = @'
{{UNINSTALL}}
'@

# =============================================================================
#  {{T:VANAF HIER NIET AANPASSEN|DO NOT EDIT BELOW THIS LINE}}
# =============================================================================
$PackageDir = (Get-Location).Path
$AppDir = Join-Path 'C:\ProgramData\AppUpdates' $AppId
if (-not (Test-Path $AppDir)) { New-Item -Path $AppDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $AppDir 'update.log'
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] Start ({{T:pakket|package}}: $PackageDir)" -Encoding UTF8 -ErrorAction SilentlyContinue

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

Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] {{T:Klaar|Done}} (exitcode $rc)" -Encoding UTF8 -ErrorAction SilentlyContinue
exit $rc

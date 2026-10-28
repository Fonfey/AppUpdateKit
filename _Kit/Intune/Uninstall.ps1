<#
.SYNOPSIS
    Intune uninstall script for {{APPNAME}} {{VERSION}}  (AppUpdateKit)

.DESCRIPTION
    Upload this script in Intune with the Win32 app:
      Program > Installer type: PowerShell script > Uninstall script
    You can change the steps below later in Intune without repackaging.
#>

$AppId   = '{{APPID}}'
$Notify = {{UNINSTALL_NOTIFY}}   # $true = notifications bottom right: "is being removed" and then "removed" / "failed"

# cmd lines to remove the app (run from the package folder)
$UninstallSteps = @'
{{UNINSTALL}}
'@

# =============================================================================
#  DO NOT CHANGE FROM HERE
# =============================================================================
$PackageDir = (Get-Location).Path
$AppDataDir = Join-Path 'C:\ProgramData\AppUpdates' $AppId
if (-not (Test-Path $AppDataDir)) { New-Item -Path $AppDataDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $AppDataDir 'update.log'
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] Start (package: $PackageDir)" -ErrorAction SilentlyContinue

# Notifications use the texts from Install.ps1 (app.json), otherwise from the package
$config = Join-Path $AppDataDir 'app.json'
if (Test-Path $config) { $env:APPKIT_CONFIG = $config }
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Show-Notification([string]$Type) {
    if ($Notify -and (Test-Path (Join-Path $PackageDir 'Show-Toast.ps1'))) {
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackageDir 'Show-Toast.ps1') -Type $Type -Force | Out-Null
    }
}
Show-Notification 'Uninstalling'

$cmdFile = Join-Path $AppDataDir 'uninstall-steps.cmd'
$content = "@echo off`r`ncd /d `"$PackageDir`"`r`nset APP_EXITCODE=0`r`n" + ($UninstallSteps -replace "`r?`n", "`r`n") + "`r`nexit /b %ERRORLEVEL%`r`n"
[System.IO.File]::WriteAllText($cmdFile, $content, [System.Text.Encoding]::Default)
& $env:ComSpec /c $cmdFile | ForEach-Object { Add-Content -Path $LogFile -Value "    $_" -ErrorAction SilentlyContinue }
$rc = $LASTEXITCODE
Remove-Item -Path $cmdFile -Force -ErrorAction SilentlyContinue

if (@(0, 3010, 1641) -contains $rc) { Show-Notification 'Uninstalled' } else { Show-Notification 'UninstallError' }

# Clean up update data; update.log is kept
# (Herstart and Stappen: the names in versions before 1.3)
foreach ($task in "AppUpdateKit Restart $AppId", "AppUpdateKit Herstart $AppId") { Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue }
foreach ($name in 'PostponeState.json', 'app.json', 'UI', 'Restart', 'Steps', 'Herstart', 'Stappen', 'verwijderen.cmd') {
    Remove-Item -Path (Join-Path $AppDataDir $name) -Recurse -Force -ErrorAction SilentlyContinue
}

Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [uninstall] Done (exit code $rc)" -ErrorAction SilentlyContinue
exit $rc

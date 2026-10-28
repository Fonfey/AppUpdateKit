<#
.SYNOPSIS
    Sets up the restart prompt after a successful installation (setting RestartMode). Do NOT change per app.

.DESCRIPTION
    RestartMode in app.psd1 (or Install.ps1):
      Never    : do nothing (a 3010 from the installer simply goes to Intune)
      IfNeeded : only when the installer asks for a restart (exit code 3010 or 1641)
      Always   : after every successful installation

    Copies what is needed to C:\ProgramData\AppUpdates\<AppId>\Herstart and creates a
    scheduled task (SYSTEM) that shows the prompt until the laptop has restarted.

.NOTES
    Exit code = the exit code that goes to Intune. If the kit handles the restart, then 0,
    so Intune doesn't give its own restart prompt as well.
#>
param ([int]$ExitCode = 0)

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

$mode   = Get-AppSetting 'RestartMode' 'Never'
$needed = @(3010, 1641) -contains $ExitCode
if (-not (($mode -eq 'Always') -or ($mode -eq 'IfNeeded' -and $needed))) { exit $ExitCode }

$phase = Get-SetupPhase
if ($phase) {
    # During Autopilot the Enrollment Status Page handles the restart
    Write-Log "Restart needed, but the device is being set up ($phase): no prompt, exit code 3010 to Intune." 'restart'
    exit 3010
}

try {
    # A restart prompt of a version before 1.3 (task and folder with a Dutch name) is replaced by this one
    Unregister-ScheduledTask -TaskName "AppUpdateKit Herstart $($script:App.AppId)" -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $script:AppFolder 'Herstart') -Recurse -Force -ErrorAction SilentlyContinue
    $dir = Join-Path $script:AppFolder 'Restart'
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $iconName = Get-AppSetting 'Icon' 'app.ico'
    foreach ($f in 'AppUI.ps1', 'AppUI-Launcher.ps1', 'Restart-Prompt.ps1', 'Test-AppInstalled.ps1', 'Get-IdleTime.ps1', 'DefaultTexts.psd1', 'app.psd1', $iconName) {
        $src = Join-Path $PSScriptRoot $f
        if (Test-Path $src) { Copy-Item -Path $src -Destination $dir -Force }
    }
    if ($env:APPKIT_CONFIG -and (Test-Path $env:APPKIT_CONFIG)) { Copy-Item -Path $env:APPKIT_CONFIG -Destination (Join-Path $dir 'app.json') -Force }
    else { Remove-Item -Path (Join-Path $dir 'app.json') -Force -ErrorAction SilentlyContinue }

    $deadlineHours = [int](Get-AppSetting 'RestartDeadlineHours' 24)
    $now = Get-Date
    [PSCustomObject]@{
        InstalledAt = $now.ToString('o')
        DeadlineAt  = if ($deadlineHours -gt 0) { $now.AddHours($deadlineHours).ToString('o') } else { $null }
        ExitCode    = $ExitCode
        IsNew       = $script:IsNewInstall
    } | ConvertTo-Json | Set-Content -Path (Join-Path $dir 'RestartState.json') -Encoding UTF8 -Force

    $reminder = [math]::Max(15, [int](Get-AppSetting 'RestartReminderMinutes' 60))
    $taskName = "AppUpdateKit Restart $($script:App.AppId)"
    $script   = Join-Path $dir 'Restart-Prompt.ps1'
    $action   = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
                    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $repeat   = New-ScheduledTaskTrigger -Once -At $now.AddMinutes($reminder) -RepetitionInterval (New-TimeSpan -Minutes $reminder) -RepetitionDuration (New-TimeSpan -Days 30)
    $boot     = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($repeat, $boot) -Settings $settings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName

    Write-Log "Restart prompt set up (RestartMode=$mode, installer exit code $ExitCode, reminder every $reminder min, deadline $(if ($deadlineHours -gt 0) { "$deadlineHours hours" } else { 'none' }))." 'restart'
    exit 0
}
catch {
    Write-Log "ERROR setting up the restart prompt: $($_.Exception.Message). Exit code 3010 to Intune." 'restart'
    exit 3010
}

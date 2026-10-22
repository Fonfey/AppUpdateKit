<#
.SYNOPSIS
    Zet na een geslaagde installatie de herstartmelding klaar (instelling RestartMode). NIET aanpassen per app.

.DESCRIPTION
    RestartMode in app.psd1 (of Install.ps1):
      Nooit    : niets doen (een 3010 van de installer gaat gewoon naar Intune)
      AlsNodig : alleen als de installer om een herstart vraagt (exitcode 3010 of 1641)
      Altijd   : na elke geslaagde installatie

    Kopieert wat nodig is naar C:\ProgramData\AppUpdates\<AppId>\Herstart en maakt een
    geplande taak (SYSTEM) die de melding toont tot de laptop herstart is.

.NOTES
    Exit code = de exitcode die naar Intune gaat. Regelt de kit de herstart, dan 0,
    zodat Intune niet ook nog een eigen herstartmelding geeft.
#>
param ([int]$ExitCode = 0)

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

$mode   = Get-AppSetting 'RestartMode' 'Nooit'
$needed = @(3010, 1641) -contains $ExitCode
if (-not (($mode -eq 'Altijd') -or ($mode -eq 'AlsNodig' -and $needed))) { exit $ExitCode }

$phase = Get-SetupPhase
if ($phase) {
    # Tijdens Autopilot regelt de inrichtingspagina de herstart
    Write-Log "Herstart nodig, maar het apparaat wordt ingericht ($phase): geen melding, exitcode 3010 naar Intune." 'restart'
    exit 3010
}

try {
    $dir = Join-Path $script:AppFolder 'Herstart'
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $iconName = Get-AppSetting 'Icon' 'app.ico'
    foreach ($f in 'AppUI.ps1', 'AppUI-Launcher.ps1', 'Restart-Prompt.ps1', 'Test-AppInstalled.ps1', 'Get-IdleTime.ps1', 'Standaardteksten.psd1', 'app.psd1', $iconName) {
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
    $taskName = "AppUpdateKit Herstart $($script:App.AppId)"
    $script   = Join-Path $dir 'Restart-Prompt.ps1'
    $action   = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
                    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $repeat   = New-ScheduledTaskTrigger -Once -At $now.AddMinutes($reminder) -RepetitionInterval (New-TimeSpan -Minutes $reminder) -RepetitionDuration (New-TimeSpan -Days 30)
    $boot     = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($repeat, $boot) -Settings $settings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName

    Write-Log "Herstartmelding klaargezet (RestartMode=$mode, installer-exitcode $ExitCode, herinnering elke $reminder min, deadline $(if ($deadlineHours -gt 0) { "$deadlineHours uur" } else { 'geen' }))." 'restart'
    exit 0
}
catch {
    Write-Log "FOUT bij klaarzetten herstartmelding: $($_.Exception.Message). Exitcode 3010 naar Intune." 'restart'
    exit 3010
}

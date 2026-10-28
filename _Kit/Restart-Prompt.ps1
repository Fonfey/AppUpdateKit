<#
.SYNOPSIS
    Shows the restart prompt. Runs as a scheduled task (SYSTEM) from
    C:\ProgramData\AppUpdates\<AppId>\Herstart, set up by Set-RestartPrompt.ps1. Do NOT change per app.

.DESCRIPTION
    - If the laptop has restarted since the installation: clean up the task and folder.
    - Nobody signed in: restart right away.
    - Before the deadline: window "Restart now" / "Later" (Later = ask again later).
    - After the deadline: warning with countdown, then restart.
#>

$json = Join-Path $PSScriptRoot 'app.json'
if (Test-Path $json) { $env:APPKIT_CONFIG = $json }
$early = Join-Path $PSScriptRoot 'RestartState.json'
if (Test-Path $early) { try { if ((Get-Content $early -Raw | ConvertFrom-Json).IsNew) { $env:APPKIT_NEWINSTALL = '1' } } catch { } }
. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

$taskName  = "AppUpdateKit Restart $($script:App.AppId)"
$statePath = Join-Path $PSScriptRoot 'RestartState.json'

function Remove-RestartReminder {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path $PSScriptRoot -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Restart([int]$Seconds, [string]$Reason) {
    Write-Log "Laptop restarts in $Seconds seconds ($Reason)." 'restart'
    & shutdown.exe /r /t $Seconds /d p:4:1 /c "$($script:App.AppName) has been updated. The laptop restarts to finish the update."
}

if (-not (Test-Path $statePath)) { Remove-RestartReminder; exit 0 }
$state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
$installedAt = [datetime]$state.InstalledAt

$lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
if ($lastBoot -gt $installedAt) {
    Write-Log "Laptop restarted at $lastBoot; restart prompt cleaned up." 'restart'
    Remove-RestartReminder
    exit 0
}

if (Get-SetupPhase) { exit 0 }

$user = Get-InteractiveUser
if (-not $user) { Invoke-Restart 60 'nobody signed in'; exit 0 }

$warnMinutes = [math]::Max(1, [int](Get-AppSetting 'RestartWarningMinutes' 15))
$script:App.ForcedDelayMinutes = $warnMinutes          # {Minutes} in the restart texts = warning time
$deadline = if ($state.DeadlineAt) { [datetime]$state.DeadlineAt } else { $null }
$nl = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')

if ($deadline -and (Get-Date) -ge $deadline) {
    Write-Log "Restart deadline passed: warning of $warnMinutes minutes." 'restart'
    $r = Start-UserPopup -WaitSeconds ($warnMinutes * 60 + 15) -Settings @{
        Mode          = 'forced'
        Heading       = $script:App.AppName
        SubHeading    = Get-AppText 'RestartForcedSubHeading' 'Your laptop will restart in {Minutes} minutes'
        Message       = Get-AppText 'RestartForcedMessage' '{AppName} has been updated and your laptop needs to restart to finish the update. Save your work and close your programs.'
        InfoOverride  = 'Ready to restart? Save your work and click Restart now.'
        InfoWarning   = $true
        NowText       = 'Restart now'
        CountdownText = 'The laptop restarts automatically in {time}.'
        ForcedMinutes = $warnMinutes
    }
    Invoke-Restart $(if ($r -eq 'Yes') { 15 } else { 30 }) "after deadline, response: '$r'"
    exit 0
}

$reminder = [int](Get-AppSetting 'RestartReminderMinutes' 60)
$laterText = if ($reminder % 60 -eq 0) { "in $($reminder / 60) hours" } else { "in $reminder minutes" }
$info = "If you choose Later, we'll ask again $laterText."
if ($deadline) { $info += " The laptop restarts automatically on $($deadline.ToString('dddd d MMMM HH:mm', $nl)) at the latest." }

$timeoutMin = [int](Get-AppSetting 'ConsentTimeoutMinutes' 15)
$r = Start-UserPopup -WaitSeconds ([math]::Min($timeoutMin, [math]::Max(1, $reminder - 1)) * 60) -Settings @{
    Mode             = 'consent'
    Heading          = $script:App.AppName
    SubHeading       = Get-AppText 'RestartSubHeading' 'Restart required'
    Message          = Get-AppText 'RestartMessage' '{AppName} has been updated. Restart your laptop to finish the update. Save your work first.'
    InfoOverride     = $info
    NowText          = 'Restart now'
    LaterText        = 'Later'
    TimeoutText      = 'If you don''t choose, we''ll ask again later ({time}).'
    FallbackQuestion = 'Do you want to restart now?'
}
Write-Log "Restart prompt, response: '$r'" 'restart'
if ($r -eq 'Yes') { Invoke-Restart 15 'user chose Restart now' }
exit 0

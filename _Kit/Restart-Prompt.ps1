<#
.SYNOPSIS
    Shows the restart prompt. Runs as a scheduled task (SYSTEM) from
    C:\ProgramData\AppUpdates\<AppId>\Herstart, prepared by Set-RestartPrompt.ps1. Do NOT edit per app.

.DESCRIPTION
    - Laptop restarted since the installation: remove the task and the folder.
    - Nobody signed in: restart right away.
    - Before the deadline: window "Restart now" / "Later" (Later = ask again later).
    - After the deadline: warning with countdown, then restart.
#>

$json = Join-Path $PSScriptRoot 'app.json'
if (Test-Path $json) { $env:APPKIT_CONFIG = $json }
$early = Join-Path $PSScriptRoot 'RestartState.json'
if (Test-Path $early) { try { if ((Get-Content $early -Raw | ConvertFrom-Json).IsNew) { $env:APPKIT_NEWINSTALL = '1' } } catch { } }
. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

$taskName  = "AppUpdateKit Herstart $($script:App.AppId)"
$statePath = Join-Path $PSScriptRoot 'RestartState.json'

function Remove-RestartReminder {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path $PSScriptRoot -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Restart([int]$Seconds, [string]$Reason) {
    Write-Log (L "Laptop wordt herstart over $Seconds seconden ($Reason)." "Laptop restarts in $Seconds seconds ($Reason).") 'restart'
    $msg = T "$($script:App.AppName) is bijgewerkt. De laptop wordt herstart om de update af te ronden." "$($script:App.AppName) has been updated. The laptop restarts to finish the update."
    & shutdown.exe /r /t $Seconds /d p:4:1 /c $msg
}

if (-not (Test-Path $statePath)) { Remove-RestartReminder; exit 0 }
$state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
$installedAt = [datetime]$state.InstalledAt

$lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
if ($lastBoot -gt $installedAt) {
    Write-Log (L "Laptop is herstart op $lastBoot; herstartmelding opgeruimd." "Laptop restarted at $lastBoot; restart reminder removed.") 'restart'
    Remove-RestartReminder
    exit 0
}

if (Get-SetupPhase) { exit 0 }

$user = Get-InteractiveUser
if (-not $user) { Invoke-Restart 60 (L 'niemand ingelogd' 'nobody signed in'); exit 0 }

$warnMinutes = [math]::Max(1, [int](Get-AppSetting 'RestartWarningMinutes' 15))
$script:App.ForcedDelayMinutes = $warnMinutes          # {Minuten}/{Minutes} in the restart texts = warning time
$deadline = if ($state.DeadlineAt) { [datetime]$state.DeadlineAt } else { $null }
$culture = [System.Globalization.CultureInfo]::GetCultureInfo((T 'nl-NL' 'en-GB'))

if ($deadline -and (Get-Date) -ge $deadline) {
    Write-Log (L "Deadline voor herstart verstreken: waarschuwing van $warnMinutes minuten." "Restart deadline passed: $warnMinutes minutes warning.") 'restart'
    $r = Start-UserPopup -WaitSeconds ($warnMinutes * 60 + 15) -Settings @{
        Mode          = 'forced'
        Heading       = $script:App.AppName
        SubHeading    = Get-AppText 'RestartForcedSubHeading' 'Je laptop wordt over {Minuten} minuten herstart'
        Message       = Get-AppText 'RestartForcedMessage' '{AppName} is bijgewerkt en je laptop moet herstarten om de update af te ronden. Sla je werk op en sluit je programma''s af.'
        InfoOverride  = T 'Klaar om te herstarten? Sla je werk op en klik op Nu herstarten.' 'Ready to restart? Save your work and click Restart now.'
        InfoWarning   = $true
        NowText       = T 'Nu herstarten' 'Restart now'
        CountdownText = T 'De laptop herstart automatisch over {tijd}.' 'The laptop restarts automatically in {tijd}.'
        ForcedMinutes = $warnMinutes
    }
    Invoke-Restart $(if ($r -eq 'Yes') { 15 } else { 30 }) (L "na deadline, reactie: '$r'" "after deadline, response: '$r'")
    exit 0
}

$reminder = [int](Get-AppSetting 'RestartReminderMinutes' 60)
$laterText = if ($reminder % 60 -eq 0) { T "over $($reminder / 60) uur" "in $($reminder / 60) hour(s)" } else { T "over $reminder minuten" "in $reminder minutes" }
$info = T "Kies je Later, dan vragen we het $laterText opnieuw." "If you choose Later, we will ask again $laterText."
if ($deadline) {
    $when = $deadline.ToString((T 'dddd d MMMM HH:mm' 'dddd d MMMM HH:mm'), $culture)
    $info += T " Uiterlijk $when wordt de laptop automatisch herstart." " The laptop will restart automatically no later than $when."
}

$timeoutMin = [int](Get-AppSetting 'ConsentTimeoutMinutes' 15)
$r = Start-UserPopup -WaitSeconds ([math]::Min($timeoutMin, [math]::Max(1, $reminder - 1)) * 60) -Settings @{
    Mode             = 'consent'
    Heading          = $script:App.AppName
    SubHeading       = Get-AppText 'RestartSubHeading' 'Herstart nodig'
    Message          = Get-AppText 'RestartMessage' '{AppName} is bijgewerkt. Herstart je laptop om de update af te ronden. Sla eerst je werk op.'
    InfoOverride     = $info
    NowText          = T 'Nu herstarten' 'Restart now'
    LaterText        = 'Later'
    TimeoutText      = T 'Maak je geen keuze, dan vragen we het later opnieuw ({tijd}).' 'If you do not choose, we will ask again later ({tijd}).'
    FallbackQuestion = T 'Wil je nu herstarten?' 'Do you want to restart now?'
}
Write-Log (L "Herstartmelding, reactie: '$r'" "Restart prompt, response: '$r'") 'restart'
if ($r -eq 'Yes') { Invoke-Restart 15 (L 'gebruiker koos Nu herstarten' 'user chose Restart now') }
exit 0

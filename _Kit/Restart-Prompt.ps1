<#
.SYNOPSIS
    Toont de herstartmelding. Draait als geplande taak (SYSTEM) vanuit
    C:\ProgramData\AppUpdates\<AppId>\Herstart, klaargezet door Set-RestartPrompt.ps1. NIET aanpassen per app.

.DESCRIPTION
    - Is de laptop sinds de installatie herstart: taak en map opruimen.
    - Niemand ingelogd: direct herstarten.
    - Voor de deadline: venster "Nu herstarten" / "Later" (Later = later opnieuw vragen).
    - Na de deadline: waarschuwing met aftelklok, daarna herstart.
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
    Write-Log "Laptop wordt herstart over $Seconds seconden ($Reason)." 'restart'
    & shutdown.exe /r /t $Seconds /d p:4:1 /c "$($script:App.AppName) is bijgewerkt. De laptop wordt herstart om de update af te ronden."
}

if (-not (Test-Path $statePath)) { Remove-RestartReminder; exit 0 }
$state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
$installedAt = [datetime]$state.InstalledAt

$lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
if ($lastBoot -gt $installedAt) {
    Write-Log "Laptop is herstart op $lastBoot; herstartmelding opgeruimd." 'restart'
    Remove-RestartReminder
    exit 0
}

if (Get-SetupPhase) { exit 0 }

$user = Get-InteractiveUser
if (-not $user) { Invoke-Restart 60 'niemand ingelogd'; exit 0 }

$warnMinutes = [math]::Max(1, [int](Get-AppSetting 'RestartWarningMinutes' 15))
$script:App.ForcedDelayMinutes = $warnMinutes          # {Minuten} in de herstartteksten = waarschuwingstijd
$deadline = if ($state.DeadlineAt) { [datetime]$state.DeadlineAt } else { $null }
$nl = [System.Globalization.CultureInfo]::GetCultureInfo('nl-NL')

if ($deadline -and (Get-Date) -ge $deadline) {
    Write-Log "Deadline voor herstart verstreken: waarschuwing van $warnMinutes minuten." 'restart'
    $r = Start-UserPopup -WaitSeconds ($warnMinutes * 60 + 15) -Settings @{
        Mode          = 'forced'
        Heading       = $script:App.AppName
        SubHeading    = Get-AppText 'RestartForcedSubHeading' 'Je laptop wordt over {Minuten} minuten herstart'
        Message       = Get-AppText 'RestartForcedMessage' '{AppName} is bijgewerkt en je laptop moet herstarten om de update af te ronden. Sla je werk op en sluit je programma''s af.'
        InfoOverride  = 'Klaar om te herstarten? Sla je werk op en klik op Nu herstarten.'
        InfoWarning   = $true
        NowText       = 'Nu herstarten'
        CountdownText = 'De laptop herstart automatisch over {tijd}.'
        ForcedMinutes = $warnMinutes
    }
    Invoke-Restart $(if ($r -eq 'Yes') { 15 } else { 30 }) "na deadline, reactie: '$r'"
    exit 0
}

$reminder = [int](Get-AppSetting 'RestartReminderMinutes' 60)
$laterText = if ($reminder % 60 -eq 0) { "over $($reminder / 60) uur" } else { "over $reminder minuten" }
$info = "Kies je Later, dan vragen we het $laterText opnieuw."
if ($deadline) { $info += " Uiterlijk $($deadline.ToString('dddd d MMMM HH:mm', $nl)) wordt de laptop automatisch herstart." }

$timeoutMin = [int](Get-AppSetting 'ConsentTimeoutMinutes' 15)
$r = Start-UserPopup -WaitSeconds ([math]::Min($timeoutMin, [math]::Max(1, $reminder - 1)) * 60) -Settings @{
    Mode             = 'consent'
    Heading          = $script:App.AppName
    SubHeading       = Get-AppText 'RestartSubHeading' 'Herstart nodig'
    Message          = Get-AppText 'RestartMessage' '{AppName} is bijgewerkt. Herstart je laptop om de update af te ronden. Sla eerst je werk op.'
    InfoOverride     = $info
    NowText          = 'Nu herstarten'
    LaterText        = 'Later'
    TimeoutText      = 'Maak je geen keuze, dan vragen we het later opnieuw ({tijd}).'
    FallbackQuestion = 'Wil je nu herstarten?'
}
Write-Log "Herstartmelding, reactie: '$r'" 'restart'
if ($r -eq 'Yes') { Invoke-Restart 15 'gebruiker koos Nu herstarten' }
exit 0

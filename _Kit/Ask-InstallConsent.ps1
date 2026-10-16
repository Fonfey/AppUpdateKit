<#
.SYNOPSIS
    Asks the logged-on user whether the update may run now. Do NOT edit per app;
    settings and texts come from app.psd1 (or Install.ps1).

.DESCRIPTION
    - Times 1 to MaxPostpones: window with "Later" / "Update now".
    - After that: warning "The update starts in X minutes" without a Later button;
      after the countdown (or earlier with "Install now") the installation continues.
    - Autopilot (OOBE or Enrollment Status Page): install right away, no popups.
    - No logged-on user: install right away, or wait when NoUserAction = 'Wachten'.
    - Outside the time window (InstallWindow): do nothing, try again later.
    - User idle (IdleMinutes) or screen locked: install right away, no popup.

    The postpone state is kept in C:\ProgramData\AppUpdates\<AppId>\PostponeState.json.
    Requirement.ps1 reads that file and holds the installation back while it is postponed.
    The installer removes the file only when the installation really succeeded.

.NOTES
    Exit code 0 = installation may continue
    Exit code 1 = installation is skipped for now ("Later", no answer, outside the time window)
#>

. (Join-Path $PSScriptRoot 'AppUI-Launcher.ps1')

$maxPostpones       = [int](Get-AppSetting 'MaxPostpones' 5)
$postponeHours      = [int](Get-AppSetting 'PostponeHours' 24)
# Wait time without a choice in minutes (older app.psd1 files with seconds keep working)
$waitTimeoutSeconds = if ($null -ne $script:App.ConsentTimeoutMinutes) { [int]$script:App.ConsentTimeoutMinutes * 60 }
                      else { [int](Get-AppSetting 'ConsentTimeoutSeconds' 900) }
$forcedMinutes      = [int](Get-AppSetting 'ForcedDelayMinutes' 5)

$postponeCount = 0
if (Test-Path $script:StatePath) {
    try {
        $postponeCount = [int]((Get-Content -Path $script:StatePath -Raw | ConvertFrom-Json).PostponeCount)
    }
    catch {
        Write-Log (L "Kon PostponeState.json niet lezen, begin met schone staat: $($_.Exception.Message)" "Could not read PostponeState.json, starting clean: $($_.Exception.Message)") 'consent'
    }
}

Write-Log (L "Gestart voor $($script:App.AppName). PostponeCount=$postponeCount (max=$maxPostpones)" "Started for $($script:App.AppName). PostponeCount=$postponeCount (max=$maxPostpones)") 'consent'

function Save-State {
    param([int]$Count, [Nullable[datetime]]$PostponeUntil)
    [PSCustomObject]@{
        PostponeCount = $Count
        PostponeUntil = if ($PostponeUntil) { $PostponeUntil.ToString("o") } else { $null }
    } | ConvertTo-Json | Set-Content -Path $script:StatePath -Encoding UTF8 -Force
}

# ---- New device through Autopilot: install right away, nobody to ask ----
$phase = Get-SetupPhase
if ($phase) {
    if ((Get-AppSetting 'InstallDuringSetup' $true) -eq $false) {
        Write-Log (L "Apparaat wordt ingericht ($phase); InstallDuringSetup staat uit, installatie komt na de inrichting." "Device is being set up ($phase); InstallDuringSetup is off, installation follows after setup.") 'consent'
        exit 1
    }
    Write-Log (L "Apparaat wordt ingericht ($phase), installatie gaat door zonder te vragen." "Device is being set up ($phase), installing without asking.") 'consent'
    exit 0
}

try { $user = Get-InteractiveUser }
catch {
    Write-Log (L "FOUT bij bepalen ingelogde gebruiker: $($_.Exception.Message)" "ERROR determining the logged-on user: $($_.Exception.Message)") 'consent'
    exit 0
}
if (-not $user) {
    if ((Get-AppSetting 'NoUserAction' 'Installeren') -eq 'Wachten') {
        Write-Log (L "Geen ingelogde gebruiker gevonden, installatie wacht tot er iemand is ingelogd." "No logged-on user found, installation waits until someone signs in.") 'consent'
        exit 1
    }
    Write-Log (L "Geen ingelogde gebruiker gevonden, installatie gaat door zonder te vragen." "No logged-on user found, installing without asking.") 'consent'
    exit 0
}

# ---- Time window: only inside or only outside working hours ----
$window = Get-AppSetting 'InstallWindow' 'Altijd'
if (-not (Test-InTimeWindow $window (Get-AppSetting 'WorkHours' '08:00-17:00') (Get-AppSetting 'WorkDays' 'ma,di,wo,do,vr'))) {
    Write-Log (L "Buiten het tijdvenster ($window), installatie wordt voor nu overgeslagen (teller niet verhoogd)." "Outside the time window ($window), installation skipped for now (counter not increased).") 'consent'
    exit 1
}

# ---- User not working: install right away, no popup ----
$idleMinutes = [int](Get-AppSetting 'IdleMinutes' 0)
if ($idleMinutes -gt 0) {
    $activity = Get-UserActivity -User $user
    if ($activity.Locked) {
        Write-Log (L "Scherm van $($user.Name) is vergrendeld, installatie gaat door zonder te vragen." "Screen of $($user.Name) is locked, installing without asking.") 'consent'
        exit 0
    }
    if ($null -ne $activity.IdleMinutes -and $activity.IdleMinutes -ge $idleMinutes) {
        Write-Log (L "$($user.Name) is $($activity.IdleMinutes) minuten inactief (grens $idleMinutes), installatie gaat door zonder te vragen." "$($user.Name) has been idle for $($activity.IdleMinutes) minutes (limit $idleMinutes), installing without asking.") 'consent'
        exit 0
    }
    $idleText = if ($null -ne $activity.IdleMinutes) { "$($activity.IdleMinutes) min" } else { L 'onbekend' 'unknown' }
    Write-Log (L "Gebruiker is actief (inactief: $idleText), popup wordt getoond." "User is active (idle: $idleText), showing popup.") 'consent'
}

# ---- Postponing no longer possible: warning with countdown, then install ----
if ($postponeCount -ge $maxPostpones) {
    Write-Log (L "Maximaal aantal keer uitstellen bereikt: waarschuwing van $forcedMinutes minuten, daarna installatie." "Maximum number of postpones reached: $forcedMinutes minutes warning, then installation.") 'consent'

    if ($forcedMinutes -gt 0) {
        # +15 s: the launcher gives the window WaitSeconds - 15 as countdown
        $forcedResponse = Start-UserPopup -WaitSeconds ($forcedMinutes * 60 + 15) -Settings @{
            Mode          = 'forced'
            Heading       = $script:App.AppName
            SubHeading    = Get-AppText 'ForcedSubHeading' 'De update start over {Minuten} minuten'
            Message       = Get-AppText 'ForcedMessage' 'Je hebt de update van {AppName} {MaxUitstel} keer uitgesteld. Over {Minuten} minuten wordt de nieuwe versie automatisch geïnstalleerd. Sla je werk op en sluit {AppName} af.'
            InfoText      = Get-AppText 'ForcedInfo' 'Wil je niet wachten? Sla je werk op, sluit {AppName} af en klik op Nu installeren.'
            ForcedMinutes = $forcedMinutes
            IsNew         = $script:IsNewInstall
        }
        Write-Log (L "Geforceerde installatie gaat door (reactie: '$forcedResponse')." "Forced installation continues (response: '$forcedResponse').") 'consent'
    }
    exit 0
}

# ---- Normal question: Later / Update now ----
$laterHint = if ($postponeHours -eq 24) { T 'morgen' 'tomorrow' }
             elseif ($postponeHours % 24 -eq 0) { T "over $($postponeHours / 24) dagen" "in $($postponeHours / 24) days" }
             else { T "over $postponeHours uur" "in $postponeHours hours" }

$response = Start-UserPopup -WaitSeconds $waitTimeoutSeconds -Settings @{
    Mode          = 'consent'
    Heading       = $script:App.AppName
    SubHeading    = Get-AppText 'ConsentSubHeading' 'Er is een update beschikbaar'
    Message       = Get-AppText 'ConsentMessage' 'Er staat een nieuwe versie van {AppName} voor je klaar. Tijdens de update (een paar minuten) kun je {AppName} even niet gebruiken.'
    Remaining     = $maxPostpones - $postponeCount
    IsNew         = $script:IsNewInstall
    NowText       = if ($script:IsNewInstall) { T 'Nu installeren' 'Install now' } else { T 'Nu bijwerken' 'Update now' }
    LaterHint     = $laterHint
    ForcedMinutes = $forcedMinutes
}

Write-Log (L "Ontvangen reactie: '$response'" "Response received: '$response'") 'consent'

switch ($response) {
    "Yes" {
        Write-Log (L "Gebruiker koos om nu te installeren, installatie gaat door." "User chose to install now, installation continues.") 'consent'
        exit 0
    }
    "No" {
        $newCount = $postponeCount + 1
        $postponeUntil = (Get-Date).AddHours($postponeHours)
        Write-Log (L "Gebruiker koos Later. PostponeCount wordt $newCount, uitgesteld tot $postponeUntil." "User chose Later. PostponeCount becomes $newCount, postponed until $postponeUntil.") 'consent'
        Save-State -Count $newCount -PostponeUntil $postponeUntil
        exit 1
    }
    default {
        Write-Log (L "Geen (geldige) reactie binnen de time-out, installatie wordt voor nu overgeslagen (teller niet verhoogd)." "No (valid) response within the time-out, installation skipped for now (counter not increased).") 'consent'
        exit 1
    }
}
